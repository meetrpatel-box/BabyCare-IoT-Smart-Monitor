import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/shared_preferences_helper.dart';
import '../../../services/esp32_audio_service.dart';
import '../../../services/audio_udp_service.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../models/mqtt_device_model.dart';
import 'cry_history_entry.dart';

enum _AnalyzerState { idle, recording, uploading, result, error }

class CryAnalyzerScreen extends StatefulWidget {
  const CryAnalyzerScreen({super.key});

  @override
  State<CryAnalyzerScreen> createState() => _CryAnalyzerScreenState();
}

class _CryAnalyzerScreenState extends State<CryAnalyzerScreen> {
  _AnalyzerState _state = _AnalyzerState.idle;
  String? _fileName;
  Map<String, dynamic>? _result;
  String? _errorMsg;
  int _selectedTab = 0; // 0 = Record, 1 = Upload, 2 = History

  // Random background index — refreshes each usage
  int _bgIndex = Random().nextInt(4);

  // Recording
  final AudioRecorder _recorder = AudioRecorder();
  int _recordSeconds = 0;
  static const int _maxRecordSeconds = 8;
  Timer? _recordTimer;
  String? _recordedFilePath;

  // ESP32 recording
  late final AudioUdpService _audioWsService = AudioUdpService();
  late final Esp32AudioService _esp32Audio = Esp32AudioService(_audioWsService);
  bool _esp32Recording = false;
  int _esp32ChunksReceived = 0;
  int _esp32ChunksTotal = 0;
  static const String _esp32DeviceId = 'device001'; // matches ESP32 firmware
  StreamSubscription? _esp32ProgressSub;

  // Edge ML
  bool _isEdgeMonitorActive = false;

  // History
  List<CryHistoryEntry> _historyEntries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final raw = SharedPrefsHelper.getCryHistory();
    setState(() {
      _historyEntries = raw
          .map(CryHistoryEntry.fromJsonString)
          .whereType<CryHistoryEntry>()
          .toList();
    });
  }

  Future<void> _saveHistoryEntry(CryHistoryEntry entry) async {
    await SharedPrefsHelper.addCryHistoryEntry(entry.toJsonString());
    _loadHistory();
  }

  static const String _apiUrl =
      'https://cry-classifier-832843143406.asia-south1.run.app/predict';

  static const Map<String, String> _emojis = {
    'hungry': '🍼',
    'tired': '😴',
    'discomfort': '😣',
    'belly_pain': '🤢',
    'burping': '💨',
  };

  static const Map<String, String> _advice = {
    'hungry':
        'Your baby is likely hungry. Offer a feed in a calm, quiet spot — make eye contact and speak softly. If breastfeeding, ensure a good latch. If bottle-feeding, warm the milk to body temperature. After feeding, hold your baby upright for 10–15 minutes to prevent reflux.',
    'tired':
        'Your baby needs rest. Dim the lights and reduce noise around them. Try gentle rocking, swaddling snugly, or a soft lullaby. A consistent sleep routine — same time, same cues — helps your baby learn when it\'s time to sleep. Avoid stimulating play right before bed.',
    'discomfort':
        'Your baby seems uncomfortable. Check if their clothing is too tight or scratchy, whether the room is too hot or cold, or if a diaper change is needed. Gentle skin-to-skin contact can be very soothing. A warm bath or a gentle massage with baby oil may also help calm them.',
    'belly_pain':
        'Your baby may have gas or belly discomfort. Try laying them on their back and gently moving their legs in a cycling motion. A soft clockwise tummy massage can help move trapped gas. Holding them tummy-down across your forearm (the "colic hold") often brings relief. If pain seems severe or persistent, consult your pediatrician.',
    'burping':
        'Your baby needs to burp. Hold them upright against your shoulder and gently pat or rub their back in circular motions. You can also try sitting them on your lap, leaning slightly forward, while supporting their chin. Give it 5–10 minutes — some babies take a little time to release air.',
  };

  static const Map<String, Color> _classColors = {
    'hungry':     AppColors.warning,           // peach/orange
    'tired':      AppColors.primary,            // sage
    'discomfort': AppColors.warning,          // amber
    'belly_pain': AppColors.error,            // red
    'burping':    AppColors.primary,            // sage
  };

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _esp32ProgressSub?.cancel();
    _esp32Audio.dispose();
    _audioWsService.disconnect();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _errorMsg = 'Microphone permission denied. Please allow it in Settings.';
        _state = _AnalyzerState.error;
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordedFilePath = '${dir.path}/cry_recording.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: _recordedFilePath!,
    );
    _recordSeconds = 0;
    setState(() => _state = _AnalyzerState.recording);
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _recordSeconds++;
      setState(() {});
      if (_recordSeconds >= _maxRecordSeconds) _stopAndAnalyze();
    });
  }

  Future<void> _stopAndAnalyze() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (path == null) return;
    _recordedFilePath = path;
    setState(() {
      _state = _AnalyzerState.uploading;
      _fileName = 'Live Recording (${_recordSeconds}s)';
      _result = null;
      _errorMsg = null;
    });
    await _sendFile(_recordedFilePath!);
  }

  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  Future<void> _pickAndAnalyze() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'ogg', 'flac', 'm4a'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;

    // Reject files that are too large
    if ((file.size) > _maxFileSizeBytes) {
      setState(() {
        _errorMsg = 'File too large. Please upload an audio file under 25 MB.';
        _state = _AnalyzerState.error;
      });
      return;
    }

    setState(() {
      _state = _AnalyzerState.uploading;
      _fileName = file.name;
      _result = null;
      _errorMsg = null;
    });
    await _sendFile(file.path!);
  }

  Future<void> _sendFile(String filePath) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      req.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final data = json.decode(body) as Map<String, dynamic>;
        // Save to history if it's a valid cry classification
        final isCry = data['is_cry'] as bool? ?? false;
        if (isCry) {
          final cls = (data['prediction'] as String? ??
              data['predicted_class'] as String? ?? 'unknown').toLowerCase();
          final conf = (data['confidence'] as num?)?.toDouble() ?? 0.0;
          final rel = data['reliability'] as String? ?? 'medium';
          await _saveHistoryEntry(CryHistoryEntry(
            prediction: cls,
            confidence: conf,
            reliability: rel,
            timestamp: DateTime.now(),
            fileName: _fileName,
          ));
        }
        setState(() {
          _result = data;
          _state = _AnalyzerState.result;
        });
      } else {
        setState(() {
          _errorMsg = 'Server returned error ${streamed.statusCode}. The service may not be available yet.';
          _state = _AnalyzerState.error;
        });
      }
    } on SocketException {
      setState(() {
        _errorMsg = 'No internet connection. Please check your network.';
        _state = _AnalyzerState.error;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Something went wrong. Please try again later.';
        _state = _AnalyzerState.error;
      });
    }
  }

  Future<void> _startEsp32Recording() async {
    final mqttProvider = context.read<DeviceMqttProvider>();
    final matches = mqttProvider.devices.where((d) => d.deviceId == _esp32DeviceId);
    if (matches.isNotEmpty && matches.first.deviceIp != null) {
      _audioWsService.connect(matches.first.deviceIp!);
    }

    setState(() {
      _esp32Recording = true;
      _esp32ChunksReceived = 0;
      _esp32ChunksTotal = 0;
      _state = _AnalyzerState.recording;
      _fileName = 'ESP32 Recording';
    });

    _esp32ProgressSub?.cancel();
    _esp32ProgressSub = _esp32Audio.onProgress.listen((progress) {
      setState(() {
        _esp32ChunksReceived = progress.$1;
        _esp32ChunksTotal = progress.$2;
      });
    });

    final wavPath = await _esp32Audio.startRecording(_esp32DeviceId);

    _esp32ProgressSub?.cancel();
    setState(() => _esp32Recording = false);

    if (wavPath == null) {
      setState(() {
        _errorMsg = 'ESP32 recording failed. Ensure device is online and MQTT broker is reachable.';
        _state = _AnalyzerState.error;
      });
      return;
    }

    setState(() {
      _state = _AnalyzerState.uploading;
      _fileName = 'ESP32 Recording (8s)';
      _recordedFilePath = wavPath;
    });
    await _sendFile(wavPath);
  }

  Future<void> _toggleEdgeMonitor() async {
    final mqttProvider = context.read<DeviceMqttProvider>();
    if (_isEdgeMonitorActive) {
      await mqttProvider.stopCryMonitor(_esp32DeviceId);
      setState(() => _isEdgeMonitorActive = false);
    } else {
      await mqttProvider.startCryMonitor(_esp32DeviceId);
      setState(() => _isEdgeMonitorActive = true);
    }
  }

  void _reset() {
    _recordTimer?.cancel();
    if (_state == _AnalyzerState.recording) _recorder.stop();
    setState(() {
      _state = _AnalyzerState.idle;
      _result = null;
      _errorMsg = null;
      _fileName = null;
      _recordSeconds = 0;
      _recordedFilePath = null;
      _bgIndex = Random().nextInt(4); // fresh random image each usage
    });
  }

  String _backgroundImage() {
    final n = _bgIndex + 1; // 1–4
    switch (_state) {
      case _AnalyzerState.idle:
      case _AnalyzerState.recording:
        return 'assets/images/cry_analyzer/sad baby$n.jpg';
      case _AnalyzerState.uploading:
        return 'assets/images/cry_analyzer/pacifying baby$n.jpg';
      case _AnalyzerState.result:
      case _AnalyzerState.error:
        return 'assets/images/cry_analyzer/happy baby$n.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.background;
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.card : AppColors.card;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Cry Analyzer',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: textPrimary,
                fontSize: 20,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Full-screen faded background image — changes randomly each usage
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Opacity(
                key: ValueKey(_backgroundImage()),
                opacity: 0.13,
                child: Image.asset(
                  _backgroundImage(),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          // Soft vignette: darken edges so centre content stays readable
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    bg.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          // Main scrollable content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: _buildBody(isDark, textPrimary, textSecondary, cardBg),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      bool isDark, Color textPrimary, Color textSecondary, Color cardBg) {
    switch (_state) {
      case _AnalyzerState.idle:
        return _buildIdle(isDark, textPrimary, textSecondary, cardBg);
      case _AnalyzerState.recording:
        return _buildRecording(textPrimary, textSecondary, cardBg);
      case _AnalyzerState.uploading:
        return _buildUploading(textPrimary, textSecondary);
      case _AnalyzerState.result:
        return _buildResult(isDark, textPrimary, textSecondary, cardBg);
      case _AnalyzerState.error:
        return _buildError(textPrimary, textSecondary, cardBg);
    }
  }

  Widget _buildIdle(
      bool isDark, Color textPrimary, Color textSecondary, Color cardBg) {
    final items = [
      ('🍼', 'Hungry', 'Baby needs feeding'),
      ('😴', 'Tired', 'Baby needs sleep'),
      ('😣', 'Discomfort', 'Clothing or temperature issue'),
      ('🤢', 'Belly Pain', 'Gas or tummy discomfort'),
      ('💨', 'Burping', 'Needs to be burped'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎙️', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(
                'AI Cry Analysis',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Record your baby\'s cry or upload an audio file and our AI will tell you exactly what your baby needs.',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0),
        const SizedBox(height: 24),

        // Tab selector
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              _buildTab(0, '🎙️  Record', textPrimary, cardBg),
              _buildTab(1, '📁  Upload', textPrimary, cardBg),
              _buildTab(2, '📋  History', textPrimary, cardBg),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 20),

        // Tab content
        if (_selectedTab == 0) _buildRecordTab(textPrimary, textSecondary, cardBg),
        if (_selectedTab == 1) _buildUploadTab(textPrimary, textSecondary, cardBg),
        if (_selectedTab == 2) _buildHistoryTab(isDark, textPrimary, textSecondary, cardBg),

        if (_selectedTab != 2) ...[
          const SizedBox(height: 24),

          // Detectable classes
          Text(
            'What can it detect?',
            style: GoogleFonts.nunito(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF7C6FD4).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: GoogleFonts.nunito(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        item.$3,
                        style: GoogleFonts.nunito(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(
                duration: 400.ms,
                delay: Duration(milliseconds: 100 + i * 60));
          }),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '⚕️ AI tool only. Always consult a pediatrician.',
              style: GoogleFonts.nunito(color: textSecondary, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTab(int index, String label, Color textPrimary, Color cardBg) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                color: selected ? Colors.white : textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTab(Color textPrimary, Color textSecondary, Color cardBg) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Text('🎙️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Record Baby\'s Cry',
                style: GoogleFonts.nunito(
                    color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the button below to start an 8-second recording. Hold the phone close to your baby.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(color: textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              // Phone microphone button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isEdgeMonitorActive ? null : _startRecording,
                  icon: const Icon(Icons.mic_rounded, size: 22),
                  label: Text(
                    'Record with Phone Mic (8s)',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                   shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ESP32 device microphone button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isEdgeMonitorActive ? null : _startEsp32Recording,
                  icon: const Icon(Icons.memory, size: 22),
                  label: Text(
                    'Record with ESP32 Device Mic',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              // Edge AI Cry Monitor Button
              Text(
                'Continuous Edge AI Monitoring',
                style: GoogleFonts.nunito(
                    color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Runs ML detection locally on the ESP32. Disables standard recording & playback while active.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(color: textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _toggleEdgeMonitor,
                  icon: Icon(
                    _isEdgeMonitorActive ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                    size: 22,
                  ),
                  label: Text(
                    _isEdgeMonitorActive ? 'Stop Edge AI Monitor' : 'Start Edge AI Monitor',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEdgeMonitorActive ? AppColors.error : AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms),
      ],
    );
  }

  Widget _buildUploadTab(Color textPrimary, Color textSecondary, Color cardBg) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickAndAnalyze,
            icon: const Icon(Icons.upload_file_rounded, size: 22),
            label: Text(
              'Upload Audio File',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ).animate().fadeIn(duration: 350.ms),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Supports WAV · MP3 · OGG · FLAC · M4A',
            style: GoogleFonts.nunito(color: textSecondary, fontSize: 12),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  // ── History tab ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab(
      bool isDark, Color textPrimary, Color textSecondary, Color cardBg) {
    if (_historyEntries.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            const Text('📋', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'No History Yet',
              style: GoogleFonts.nunito(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Your past cry analysis results will\nappear here after each session.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  color: textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with clear button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_historyEntries.length} Analysis${_historyEntries.length == 1 ? '' : 'es'}',
              style: GoogleFonts.nunito(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
            TextButton.icon(
              onPressed: () => _confirmClearHistory(textPrimary, textSecondary, cardBg),
              icon: Icon(Icons.delete_sweep_rounded,
                  size: 16, color: AppColors.error),
              label: Text(
                'Clear All',
                style: GoogleFonts.nunito(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // History cards
        ..._historyEntries.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return _buildHistoryCard(
              item, i, isDark, textPrimary, textSecondary, cardBg);
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHistoryCard(CryHistoryEntry entry, int index, bool isDark,
      Color textPrimary, Color textSecondary, Color cardBg) {
    const classColors = {
      'hungry':     AppColors.warning,
      'tired':      AppColors.primary,
      'discomfort': AppColors.warning,
      'belly_pain': AppColors.error,
      'burping':    AppColors.primary,
    };
    final clsColor = classColors[entry.prediction] ?? AppColors.primary;

    Color relColor() {
      switch (entry.reliability) {
        case 'high':   return AppColors.success;
        case 'medium': return AppColors.warning;
        default:       return AppColors.error;
      }
    }

    String timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    }

    String timeLabel(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return Dismissible(
      key: ValueKey('${entry.timestamp.toIso8601String()}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded,
            color: AppColors.error, size: 22),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => _deleteHistoryEntry(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: clsColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Emoji badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: clsColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(entry.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayName,
                          style: GoogleFonts.nunito(
                            color: clsColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Confidence badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: clsColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.confidence.toStringAsFixed(0)}%',
                          style: GoogleFonts.nunito(
                              color: clsColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: relColor().withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.reliability.toUpperCase(),
                          style: GoogleFonts.nunito(
                              color: relColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (entry.fileName != null)
                        Expanded(
                          child: Text(
                            entry.fileName!,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                                color: textSecondary, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeAgo(entry.timestamp),
                  style: GoogleFonts.nunito(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  timeLabel(entry.timestamp),
                  style: GoogleFonts.nunito(
                      color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 50 * index.clamp(0, 8))),
    );
  }

  Future<void> _deleteHistoryEntry(int index) async {
    final raw = SharedPrefsHelper.getCryHistory();
    if (index < raw.length) {
      raw.removeAt(index);
      await _rewriteHistory(raw);
    }
  }

  Future<void> _rewriteHistory(List<String> raw) async {
    await SharedPrefsHelper.clearCryHistory();
    // Insert in reverse so oldest is added first (addEntry inserts at 0)
    for (final e in raw.reversed) {
      await SharedPrefsHelper.addCryHistoryEntry(e);
    }
    _loadHistory();
  }

  void _confirmClearHistory(
      Color textPrimary, Color textSecondary, Color cardBg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear History',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently delete all saved cry analysis records. This action cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.nunito(
                    color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SharedPrefsHelper.clearCryHistory();
              _loadHistory();
            },
            child: Text('Clear All',
                style: GoogleFonts.nunito(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecording(Color textPrimary, Color textSecondary, Color cardBg) {
    // ESP32 recording progress
    if (_esp32Recording) {
      final esp32Progress = _esp32ChunksTotal > 0
          ? _esp32ChunksReceived / _esp32ChunksTotal
          : 0.0;
      return SizedBox(
        height: 480,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.deepOrange, AppColors.primary]),
                  boxShadow: [BoxShadow(color: Colors.deepOrange.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
                ),
                child: const Icon(Icons.memory, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text('ESP32 Recording...', style: GoogleFonts.nunito(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _esp32ChunksTotal > 0
                    ? 'Receiving chunk $_esp32ChunksReceived / $_esp32ChunksTotal'
                    : 'Waiting for device...',
                style: GoogleFonts.nunito(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: esp32Progress > 0 ? esp32Progress : null,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final progress = _recordSeconds / _maxRecordSeconds;
    final remaining = _maxRecordSeconds - _recordSeconds;
    return SizedBox(
      height: 480,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing mic icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.12),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              onEnd: () => setState(() {}),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.warning, AppColors.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recording...',
              style: GoogleFonts.nunito(
                  color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '$remaining second${remaining == 1 ? '' : 's'} remaining',
              style: GoogleFonts.nunito(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0s', style: GoogleFonts.nunito(color: textSecondary, fontSize: 11)),
                      Text('${_recordSeconds}s', style: GoogleFonts.nunito(
                          color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${_maxRecordSeconds}s', style: GoogleFonts.nunito(color: textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _stopAndAnalyze,
              icon: Icon(Icons.stop_circle_rounded, color: AppColors.error),
              label: Text(
                'Stop & Analyze Now',
                style: GoogleFonts.nunito(
                    color: AppColors.error, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploading(Color textPrimary, Color textSecondary) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing cry...',
              style: GoogleFonts.nunito(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _fileName ?? '',
              style: GoogleFonts.nunito(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Our AI is listening carefully 🧠',
              style: GoogleFonts.nunito(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(
      bool isDark, Color textPrimary, Color textSecondary, Color cardBg) {
    if (_result == null) return const SizedBox.shrink();

    final isCry = _result!['is_cry'] as bool? ?? false;
    if (!isCry) return _buildNotACry(textPrimary, textSecondary, cardBg);

    final cls = (_result!['prediction'] as String? ??
        _result!['predicted_class'] as String? ?? 'unknown').toLowerCase();
    final confidence =
        (_result!['confidence'] as num?)?.toDouble() ?? 0.0;
    final reliability = _result!['reliability'] as String? ?? 'medium';
    final probMap =
        (_result!['probabilities'] as Map?)?.cast<String, num>() ?? {};

    final emoji = _emojis[cls] ?? '🍼';
    final advice = _advice[cls] ?? 'Check on your baby.';
    final clsColor = _classColors[cls] ?? AppColors.primary;
    final clsDisplay = cls.replaceAll('_', ' ').toUpperCase();

    Color reliabilityColor() {
      switch (reliability) {
        case 'high':
          return AppColors.success;
        case 'medium':
          return AppColors.warning;
        default:
          return AppColors.error;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main result card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                clsColor.withValues(alpha: isDark ? 0.25 : 0.15),
                clsColor.withValues(alpha: isDark ? 0.10 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: clsColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                clsDisplay,
                style: GoogleFonts.nunito(
                    color: clsColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: clsColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${confidence.toStringAsFixed(0)}% confidence',
                      style: GoogleFonts.nunito(
                          color: clsColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: reliabilityColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${reliability.toUpperCase()} reliability',
                      style: GoogleFonts.nunito(
                          color: reliabilityColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).scale(
            begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
        const SizedBox(height: 16),

        // Advice card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: clsColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: clsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lightbulb_rounded,
                    color: clsColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to do',
                      style: GoogleFonts.nunito(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      advice,
                      style: GoogleFonts.lato(
                          color: textSecondary, fontSize: 13.5, height: 1.65,
                          letterSpacing: 0.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
        const SizedBox(height: 16),

        // Probability bars
        Text(
          'All Probabilities',
          style: GoogleFonts.nunito(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...probMap.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final label = e.key;
          final prob = e.value.toDouble();
          final color = _classColors[label] ?? AppColors.primary;
          final isTop = label == cls;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: isTop
                  ? Border.all(color: clsColor.withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                Text(_emojis[label] ?? '•',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 82,
                  child: Text(
                    label.replaceAll('_', ' '),
                    style: GoogleFonts.nunito(
                      color: isTop ? color : textSecondary,
                      fontSize: 12,
                      fontWeight: isTop
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: prob / 100,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${prob.toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(
                    color: isTop ? color : textSecondary,
                    fontSize: 12,
                    fontWeight: isTop
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: 200 + i * 50));
        }),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Analyze Another',
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildDisclaimer(cardBg, textSecondary),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDisclaimer(Color cardBg, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚕️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Disclaimer',
                  style: GoogleFonts.nunito(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This analysis is generated by an AI model for informational and educational purposes only. '
                  'It is not a substitute for professional medical advice, diagnosis, or treatment. '
                  'Baby cry patterns can vary significantly — always consult a qualified pediatrician '
                  'or healthcare provider if you have concerns about your baby\'s health or behavior.',
                  style: GoogleFonts.lato(
                    color: textSecondary,
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotACry(
      Color textPrimary, Color textSecondary, Color cardBg) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              const Text('🔇', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('No Cry Detected',
                  style: GoogleFonts.nunito(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                "The audio doesn't appear to contain a baby cry. Make sure the recording is clear and contains the actual cry sound.",
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    color: textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Try Another File',
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(
      Color textPrimary, Color textSecondary, Color cardBg) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Analysis Failed',
                  style: GoogleFonts.nunito(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _errorMsg ?? 'An unexpected error occurred.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    color: textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Try Again',
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
