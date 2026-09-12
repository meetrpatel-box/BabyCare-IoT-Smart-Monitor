import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../utils/platform_view_registry.dart'
    if (dart.library.html) '../../utils/platform_view_registry_web.dart'
    as platform_registry;
import '../../services/webrtc_js_service.dart';
import '../../theme/design_tokens.dart';

/// Test screen for JavaScript WebRTC interop
class WebRTCJsTestScreen extends StatefulWidget {
  const WebRTCJsTestScreen({super.key});

  @override
  State<WebRTCJsTestScreen> createState() => _WebRTCJsTestScreenState();
}

class _WebRTCJsTestScreenState extends State<WebRTCJsTestScreen> {
  bool _initialized = false;
  String _testSessionId = 'test-session-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeTest();
    }
  }

  Future<void> _initializeTest() async {
    final jsService = Provider.of<WebRTCJsService>(context, listen: false);
    await jsService.initializeRenderers();
    setState(() {
      _initialized = true;
    });
    debugPrint('[Test] WebRTC JS Test initialized');
  }

  Future<void> _startTestCall() async {
    final jsService = Provider.of<WebRTCJsService>(context, listen: false);

    try {
      debugPrint('[Test] Starting test call...');
      await jsService.startSession(
        sessionId: _testSessionId,
        deviceId: 'test-device-001',
        isOffer: true,
      );
      debugPrint('[Test] Test call started');
    } catch (e) {
      debugPrint('[Test] Error starting test call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _endTestCall() async {
    final jsService = Provider.of<WebRTCJsService>(context, listen: false);
    await jsService.endSession();
    debugPrint('[Test] Test call ended');
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('WebRTC JS Test')),
        body: const Center(
          child: Text('This test only works on web platform'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        title: const Text('WebRTC JS Test'),
        backgroundColor: DesignTokens.primaryTeal,
        foregroundColor: Colors.white,
      ),
      body: Consumer<WebRTCJsService>(
        builder: (context, jsService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeXl,
                            fontWeight: DesignTokens.fontWeightBold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceMd),
                        _buildStatusRow(
                          'Initialized',
                          _initialized ? '✅' : '⏳',
                          _initialized ? Colors.green : Colors.orange,
                        ),
                        _buildStatusRow(
                          'Connection',
                          jsService.connectionState,
                          jsService.isConnected ? Colors.green : Colors.grey,
                        ),
                        _buildStatusRow(
                          'Remote Stream',
                          jsService.hasRemoteStream ? 'Yes' : 'No',
                          jsService.hasRemoteStream ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceLg),

                // Controls
                ElevatedButton(
                  onPressed: _initialized ? _startTestCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceMd,
                    ),
                  ),
                  child: const Text('Start Test Call'),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                ElevatedButton(
                  onPressed: jsService.isConnected ? _endTestCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceMd,
                    ),
                  ),
                  child: const Text('End Test Call'),
                ),

                const SizedBox(height: DesignTokens.spaceLg),

                // Video Display
                if (_initialized && jsService.remoteVideoElement != null)
                  Card(
                    child: Container(
                      height: 400,
                      color: Colors.black,
                      child: _WebRTCVideoView(
                        videoElement: jsService.remoteVideoElement!,
                      ),
                    ),
                  ),

                const SizedBox(height: DesignTokens.spaceLg),

                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Instructions',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeLg,
                            fontWeight: DesignTokens.fontWeightSemiBold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        const Text('1. Make sure device simulator is running'),
                        const Text('2. Click "Start Test Call"'),
                        const Text('3. Check browser console (F12) for WebRTC logs'),
                        const Text('4. Look for "🧊 ICE candidate generated!" logs'),
                        const Text('5. Video should appear if connection succeeds'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display HTML video element in Flutter
class _WebRTCVideoView extends StatefulWidget {
  final html.VideoElement videoElement;

  const _WebRTCVideoView({required this.videoElement});

  @override
  State<_WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends State<_WebRTCVideoView> {
  final String _viewType = 'webrtc-video-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Register the video element as a platform view
    if (kIsWeb) {
      platform_registry.registerViewFactory(
        _viewType,
        (int viewId) => widget.videoElement,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
