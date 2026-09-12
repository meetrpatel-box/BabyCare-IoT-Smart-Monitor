import 'dart:math';
import 'dart:typed_data';
import '../../utils/platform_view_registry.dart'
    if (dart.library.html) '../../utils/platform_view_registry_web.dart'
    as platform_registry;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baby_provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../services/video_call_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/webrtc_js_service.dart';
import '../../services/audio_udp_service.dart';
import '../../services/live_speak_service.dart';
import '../../models/video_call_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../theme/design_tokens.dart';

/// Video Call Screen - "Lollipop" style baby monitor dashboard
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  bool _breathingMonitored = true;
  bool _musicPlaying = false;
  bool _micActive = false;
  bool _soundOn = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late final AudioUdpService _audioUdpService;
  late final LiveSpeakService _speakService;

  @override
  void initState() {
    super.initState();
    _audioUdpService = AudioUdpService();
    _speakService = LiveSpeakService(_audioUdpService);
    
    _pulseController = AnimationController(
      duration: AppAnimations.pulseDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: AppAnimations.easeInOutQuad,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
        _initializeWebRTC();
      }
    });
  }

  /// Initialize WebRTC renderers
  Future<void> _initializeWebRTC() async {
    try {
      if (kIsWeb) {
        final jsService = Provider.of<WebRTCJsService>(context, listen: false);
        await jsService.initializeRenderers();
      } else {
        final webrtcService = Provider.of<WebRTCService>(context, listen: false);
        await webrtcService.initializeRenderers();
      }
      debugPrint('[VideoCall] WebRTC renderers initialized');
    } catch (e) {
      debugPrint('[VideoCall] Error initializing WebRTC: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speakService.dispose();
    _audioUdpService.disconnect();
    super.dispose();
  }

  Future<void> _startCall() async {
    final videoService = Provider.of<VideoCallService>(context, listen: false);
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final babyProvider = Provider.of<BabyProvider>(context, listen: false);
    final mqttProvider = Provider.of<DeviceMqttProvider>(context, listen: false);

    final userId = authProvider.userId ?? '';
    final deviceId = babyProvider.selectedBaby?.assignedDeviceId ?? 'test-device-001';

    try {
      // Create Firestore session
      final session = await videoService.startVideoCall(
        deviceId: deviceId,
        userId: userId,
        quality: StreamQuality.medium,
      );

      debugPrint('[VideoCall] Session created: ${session.sessionId}');

      // Connect UDP Audio for 2-way Walkie-Talkie
      final matches = mqttProvider.devices.where((d) => d.deviceId == deviceId);
      if (matches.isNotEmpty && matches.first.deviceIp != null) {
        debugPrint('[VideoCall] Connecting UDP Audio to ${matches.first.deviceIp}');
        await _audioUdpService.connect(matches.first.deviceIp!);
      }

      if (kIsWeb) {
        final jsService = Provider.of<WebRTCJsService>(context, listen: false);
        await jsService.startSession(
          sessionId: session.sessionId,
          deviceId: deviceId,
          isOffer: true,
        );
      } else {
        await webrtcService.startSession(
          sessionId: session.sessionId,
          deviceId: deviceId,
          isOffer: true,
        );
      }

      debugPrint('[VideoCall] WebRTC session started');

      // Watch session for state updates
      videoService.watchSession(session.sessionId).listen(
        (updatedSession) {
          debugPrint('[VideoCall] Session updated: state=${updatedSession.state.name}');
        },
        onError: (error) {
          debugPrint('[VideoCall] Session watch error: $error');
        },
      );
    } catch (e) {
      debugPrint('[VideoCall] Error starting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start video call: $e')),
        );
      }
    }
  }

  Future<void> _endCall() async {
    final videoService = Provider.of<VideoCallService>(context, listen: false);
    final webrtcService = Provider.of<WebRTCService>(context, listen: false);
    final session = videoService.currentSession;
    
    // Disconnect UDP audio
    final babyProvider = Provider.of<BabyProvider>(context, listen: false);
    final deviceId = babyProvider.selectedBaby?.assignedDeviceId ?? '';
    await _speakService.stopSpeaking(deviceId);
    await _audioUdpService.disconnect();
    if (mounted) setState(() => _micActive = false);

    if (session != null) {
      if (kIsWeb) {
        final jsService = Provider.of<WebRTCJsService>(context, listen: false);
        await jsService.endSession();
      } else {
        await webrtcService.endSession();
      }

      await videoService.endVideoCall(session.sessionId);
      debugPrint('[VideoCall] Call ended');
    }
  }

  Future<void> _toggleMicrophone() async {
    final babyProvider = Provider.of<BabyProvider>(context, listen: false);
    final deviceId = babyProvider.selectedBaby?.assignedDeviceId ?? '';
    final newState = !_micActive;
    
    try {
      if (newState) {
        final success = await _speakService.startSpeaking(deviceId, cloudStreamId: deviceId);
        if (success && mounted) {
           setState(() => _micActive = true);
        }
      } else {
        await _speakService.stopSpeaking(deviceId);
        if (mounted) setState(() => _micActive = false);
      }
      debugPrint('[VideoCall] Walkie-Talkie ${newState ? 'enabled' : 'muted'}');
    } catch (e) {
      debugPrint('[VideoCall] Error toggling mic: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    // For now, UDP audio always plays when connected.
    // If we wanted to mute it, we would add a mute function to _audioUdpService.
    final newState = !_soundOn;
    if (mounted) setState(() => _soundOn = newState);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final videoHeight = min(screenWidth * 0.75, 500.0);

    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildVideoFeed(screenWidth, videoHeight),
                    _buildControlBar(),
                    _buildDashboardGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios, color: AppColors.foreground, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Lollipop baby',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.apps_outlined, color: AppColors.foreground, size: 24),
              const SizedBox(width: 16),
              Icon(Icons.notifications_outlined, color: AppColors.foreground, size: 24),
              const SizedBox(width: 16),
              Icon(Icons.settings_outlined, color: AppColors.foreground, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed(double screenWidth, double height) {
    return Consumer3<VideoCallService, WebRTCService, WebRTCJsService>(
      builder: (context, videoService, webrtcService, jsService, _) {
        final session = videoService.currentSession;
        final isInCall = session != null;
        final isConnecting = session?.state == CameraSessionState.connecting;
        final isStreaming = session?.state == CameraSessionState.streaming;

        final isWebRTCConnected = kIsWeb ? jsService.isConnected : webrtcService.isConnected;
        final remoteRenderer = kIsWeb ? null : webrtcService.remoteRenderer;
        final jsVideoElement = kIsWeb ? jsService.remoteVideoElement : null;

        return Container(
          width: screenWidth,
          height: height,
          color: const Color(0xFFE2E8F0),
          child: Stack(
            children: [
              if (kIsWeb && jsService.hasRemoteStream && jsVideoElement != null)
                _WebRTCHtmlVideoView(videoElement: jsVideoElement, width: screenWidth, height: height)
              else if (!kIsWeb && isWebRTCConnected && remoteRenderer != null)
                ClipRect(
                  child: SizedBox(
                    width: screenWidth,
                    height: height,
                    child: RTCVideoView(
                      remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: false,
                    ),
                  ),
                )
              else if (isStreaming && session!.latestFrameUrl != null)
                Image.network(
                  session.latestFrameUrl!,
                  key: ValueKey(session.frameCount),
                  fit: BoxFit.cover,
                  width: screenWidth,
                  height: height,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Opacity(
                        opacity: 0.5,
                        child: Text('??', style: TextStyle(fontSize: 60)),
                      ),
                    );
                  },
                )
              else
                const Center(
                  child: Opacity(
                    opacity: 0.5,
                    child: Text('??', style: TextStyle(fontSize: 60)),
                  ),
                ),

              if (isConnecting)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Connecting to camera...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isStreaming)
                Positioned(
                  top: 16,
                  left: 16,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: _pulseAnimation.value,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (isInCall && session != null) ...[
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(session.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: StreamBuilder<Uint8List>(
                    stream: _audioUdpService.onAudioReceived,
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
                )
              ]
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControlBar() {
    return Consumer<VideoCallService>(
      builder: (context, videoService, _) {
        final isInCall = videoService.isInCall;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _musicPlaying ? Icons.music_note : Icons.music_note_outlined,
                label: 'Music',
                isActive: _musicPlaying,
                onTap: () => setState(() => _musicPlaying = !_musicPlaying),
              ),
              _buildControlButton(
                icon: _micActive ? Icons.mic : Icons.mic_off_outlined,
                label: 'Talk',
                isActive: _micActive,
                onTap: isInCall ? () => _toggleMicrophone() : () {},
              ),
              _buildCameraButton(isInCall),
              _buildControlButton(
                icon: _soundOn ? Icons.volume_up : Icons.volume_off_outlined,
                label: 'Listen',
                isActive: _soundOn,
                onTap: isInCall ? () => _toggleSpeaker() : () {},
              ),
              _buildControlButton(
                icon: _breathingMonitored
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: 'Breathing',
                isActive: _breathingMonitored,
                onTap: () =>
                    setState(() => _breathingMonitored = !_breathingMonitored),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraButton(bool isInCall) {
    return GestureDetector(
      onTap: isInCall ? _endCall : _startCall,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isInCall
                ? [Colors.red.shade400, Colors.red.shade600]
                : [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isInCall ? Colors.red : AppColors.primary)
                  .withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isInCall ? Icons.videocam_off : Icons.videocam,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? AppColors.primary : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDashboardCard('???', '22.5°C', 'Temperature')),
              const SizedBox(width: 12),
              Expanded(child: _buildDashboardCard('??', '45%', 'Humidity')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDashboardCard('??', '2h 15m', 'Sleep Time')),
              const SizedBox(width: 12),
              Expanded(child: _buildDashboardCard('??', '125 BPM', 'Heart Rate')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebRTCHtmlVideoView extends StatefulWidget {
  final dynamic videoElement;
  final double width;
  final double height;

  const _WebRTCHtmlVideoView({
    required this.videoElement,
    required this.width,
    required this.height,
  });

  @override
  State<_WebRTCHtmlVideoView> createState() => _WebRTCHtmlVideoViewState();
}

class _WebRTCHtmlVideoViewState extends State<_WebRTCHtmlVideoView> {
  late final String _viewType;
  static final Set<String> _registeredViewTypes = {};

  @override
  void initState() {
    super.initState();
    _viewType = 'webrtc-remote-${widget.videoElement.hashCode}';
    if (!_registeredViewTypes.contains(_viewType)) {
      _registeredViewTypes.add(_viewType);
      platform_registry.registerViewFactory(
        _viewType,
        (int viewId) => widget.videoElement as Object,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
