import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_call_session.dart';
import '../../services/video_call_service.dart';

/// Video call widget for baby monitoring
class VideoCallWidget extends StatefulWidget {
  final String deviceId;
  final String userId;
  
  const VideoCallWidget({
    super.key,
    required this.deviceId,
    required this.userId,
  });
  
  @override
  State<VideoCallWidget> createState() => _VideoCallWidgetState();
}

class _VideoCallWidgetState extends State<VideoCallWidget> {
  VideoCallSession? _session;
  StreamQuality _selectedQuality = StreamQuality.medium;
  bool _isLoading = false;
  String? _error;
  
  @override
  Widget build(BuildContext context) {
    final videoService = Provider.of<VideoCallService>(context);
    final session = videoService.currentSession;
    final isInCall = session != null && session.deviceId == widget.deviceId;
    
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade700,
                  Colors.deepPurple.shade900,
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Baby Monitor Camera',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isInCall)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
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
                  ),
              ],
            ),
          ),
          
          // Video Preview Area
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: Colors.black,
              child: isInCall
                  ? _buildVideoStream(session!)
                  : _buildPlaceholder(),
            ),
          ),
          
          // Session Info
          if (isInCall) _buildSessionInfo(session!),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: isInCall
                ? _buildActiveCallControls(session!)
                : _buildStartCallControls(),
          ),
          
          // Error message
          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _error = null),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildVideoStream(VideoCallSession session) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video stream (using simulated feed for now)
        if (session.streamUrl != null)
          Image.network(
            session.streamUrl!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildStreamError();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildStreamLoading();
            },
          )
        else
          _buildStreamLoading(),
        
        // Overlay controls
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              // Quality indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.quality.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // FPS counter
              if (session.fps != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${session.fps} FPS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Duration indicator
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(session.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStreamLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Connecting to camera...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStreamError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            'Failed to load video stream',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera is off',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Start Video Call" to connect',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionInfo(VideoCallSession session) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            Icons.signal_cellular_alt,
            session.state.name.toUpperCase(),
            _getStateColor(session.state),
          ),
          if (session.resolution != null)
            _buildInfoItem(
              Icons.aspect_ratio,
              session.resolution!,
              Colors.blue,
            ),
          if (session.bitrate != null)
            _buildInfoItem(
              Icons.speed,
              '${(session.bitrate! / 1000).toStringAsFixed(0)} kbps',
              Colors.orange,
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStartCallControls() {
    return Column(
      children: [
        // Quality selector
        Row(
          children: [
            const Icon(Icons.high_quality, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Video Quality:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            DropdownButton<StreamQuality>(
              value: _selectedQuality,
              items: StreamQuality.values.map((quality) {
                return DropdownMenuItem(
                  value: quality,
                  child: Text(_getQualityLabel(quality)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedQuality = value);
                }
              },
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Start button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _startCall,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.videocam),
            label: Text(
              _isLoading ? 'Connecting...' : 'Start Video Call',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActiveCallControls(VideoCallSession session) {
    return Column(
      children: [
        // Quick actions row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Snapshot
            _buildActionButton(
              Icons.camera_alt,
              'Snapshot',
              () => _captureSnapshot(session),
              Colors.blue,
            ),
            
            // Change quality
            _buildActionButton(
              Icons.settings,
              'Quality',
              () => _showQualityDialog(session),
              Colors.orange,
            ),
            
            // End call
            _buildActionButton(
              Icons.call_end,
              'End Call',
              () => _endCall(session),
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
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
    );
  }
  
  Future<void> _startCall() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final videoService = context.read<VideoCallService>();
      final session = await videoService.startVideoCall(
        deviceId: widget.deviceId,
        userId: widget.userId,
        quality: _selectedQuality,
      );
      
      setState(() => _session = session);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Video call started'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      setState(() => _error = 'Failed to start call: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _endCall(VideoCallSession session) async {
    try {
      final videoService = context.read<VideoCallService>();
      await videoService.endVideoCall(session.sessionId);
      
      setState(() => _session = null);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended'),
          ),
        );
      }
      
    } catch (e) {
      setState(() => _error = 'Failed to end call: $e');
    }
  }
  
  Future<void> _captureSnapshot(VideoCallSession session) async {
    try {
      final videoService = context.read<VideoCallService>();
      await videoService.captureSnapshot(
        sessionId: session.sessionId,
        deviceId: widget.deviceId,
        userId: widget.userId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Snapshot captured'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      setState(() => _error = 'Failed to capture snapshot: $e');
    }
  }
  
  Future<void> _showQualityDialog(VideoCallSession session) async {
    final newQuality = await showDialog<StreamQuality>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StreamQuality.values.map((quality) {
            return ListTile(
              leading: Radio<StreamQuality>(
                value: quality,
                groupValue: session.quality,
                onChanged: (value) {
                  Navigator.pop(context, value);
                },
              ),
              title: Text(_getQualityLabel(quality)),
              subtitle: Text(_getQualityDescription(quality)),
            );
          }).toList(),
        ),
      ),
    );
    
    if (newQuality != null && newQuality != session.quality) {
      try {
        final videoService = context.read<VideoCallService>();
        await videoService.changeQuality(session.sessionId, newQuality);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quality changed to ${newQuality.name}'),
            ),
          );
        }
      } catch (e) {
        setState(() => _error = 'Failed to change quality: $e');
      }
    }
  }
  
  String _getQualityLabel(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.low:
        return 'Low (320p)';
      case StreamQuality.medium:
        return 'Medium (480p)';
      case StreamQuality.high:
        return 'High (720p)';
    }
  }
  
  String _getQualityDescription(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.low:
        return 'Low bandwidth, 10 FPS';
      case StreamQuality.medium:
        return 'Balanced, 15 FPS';
      case StreamQuality.high:
        return 'High quality, 30 FPS';
    }
  }
  
  Color _getStateColor(CameraSessionState state) {
    switch (state) {
      case CameraSessionState.disconnected:
        return Colors.grey;
      case CameraSessionState.connecting:
        return Colors.orange;
      case CameraSessionState.connected:
      case CameraSessionState.streaming:
        return Colors.green;
      case CameraSessionState.error:
        return Colors.red;
    }
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
