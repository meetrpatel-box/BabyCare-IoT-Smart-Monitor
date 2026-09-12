import re
import sys

with open("C:/Users/patel/Downloads/BabyCareApp-feature-BabyCryAnalysis/BabyCareApp-feature-BabyCryAnalysis/baby_track_flutter/lib/screens/main/dashboard_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace State class setup
old_state = '''class _CameraBottomSheetState extends State<_CameraBottomSheet> {
  // Current JPEG frame shown in the viewer
  Uint8List? _frame;
  String? _error;
  bool _running = false;
  http.Client? _client;
  
  // Audio streaming service
  final AudioUdpService _audioService = AudioUdpService();

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _running = false;
    _client?.close();
    _audioService.disconnect();
    super.dispose();
  }'''

new_state = '''class _CameraBottomSheetState extends State<_CameraBottomSheet> {
  // Current JPEG frame shown in the viewer
  Uint8List? _frame;
  String? _error;
  bool _running = false;
  http.Client? _client;
  
  // Audio streaming service
  final AudioUdpService _audioService = AudioUdpService();
  late final LiveSpeakService _speakService;

  @override
  void initState() {
    super.initState();
    _speakService = LiveSpeakService(_audioService);
    _startStream();
  }

  @override
  void dispose() {
    _running = false;
    _speakService.dispose();
    _client?.close();
    _audioService.disconnect();
    super.dispose();
  }'''

content = content.replace(old_state, new_state)

# Replace Stream View and Controls
old_ui = '''          // Stream view
          AspectRatio(
            aspectRatio: 3 / 4, // Swapped aspect ratio due to 90-degree rotation
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _startStream,
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.teal)),
                        ),
                      ],
                    ),
                  )
                : _frame != null
                    ? RotatedBox(
                        quarterTurns: -1, // -90 degrees (anti-clockwise)
                        child: Image.memory(_frame!,
                            fit: BoxFit.contain, gaplessPlayback: true),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.teal),
                            SizedBox(height: 12),
                            Text('Connecting to camera...',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
          ),
          
          const SizedBox(height: 16),
          
          // Motor Controls (D-Pad)'''

new_ui = '''          // Stream view
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 40),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _startStream,
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.teal)),
                            ),
                          ],
                        ),
                      )
                    : _frame != null
                        ? RotatedBox(
                            quarterTurns: -1,
                            child: Image.memory(_frame!,
                                fit: BoxFit.contain, gaplessPlayback: true),
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.teal),
                                SizedBox(height: 12),
                                Text('Connecting to camera...',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: StreamBuilder<Uint8List>(
                  stream: _audioService.onAudioReceived,
                  builder: (context, snapshot) {
                    final hasData = snapshot.hasData;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasData ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasData ? "Audio RX: OK" : "Audio RX: Wait",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Walkie-Talkie Button
          ListenableBuilder(
            listenable: _speakService,
            builder: (ctx, _) {
              final isSpeaking = _speakService.isSpeaking;
              return GestureDetector(
                onTapDown: (_) => _speakService.startSpeaking(widget.device.deviceId),
                onTapUp: (_) => _speakService.stopSpeaking(widget.device.deviceId),
                onTapCancel: () => _speakService.stopSpeaking(widget.device.deviceId),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isSpeaking ? Colors.red : const Color(0xFF0F766E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isSpeaking ? Colors.red : const Color(0xFF0F766E)).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSpeaking ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text('Hold to Speak', style: TextStyle(color: Colors.white70, fontSize: 12)),
          
          const SizedBox(height: 16),
          
          // Motor Controls (D-Pad)'''

content = content.replace(old_ui, new_ui)

with open("C:/Users/patel/Downloads/BabyCareApp-feature-BabyCryAnalysis/BabyCareApp-feature-BabyCryAnalysis/baby_track_flutter/lib/screens/main/dashboard_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Done")
