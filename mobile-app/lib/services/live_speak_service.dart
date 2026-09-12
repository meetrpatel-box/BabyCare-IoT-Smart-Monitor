import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/relay_config.dart';
import 'audio_udp_service.dart';

/// Streams phone microphone audio to the ESP32 speaker via WebSockets / UDP or Cloud Relay.
class LiveSpeakService extends ChangeNotifier {
  // 1024 raw PCM bytes = 32 ms at 16kHz 16-bit mono
  static const _chunkBytes = 1024; // 32ms unfragmented MTU-safe chunks for instant playback

  final AudioUdpService _audioService;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _streamSub;
  WebSocketChannel? _cloudWsChannel;
  
  bool _isSpeaking = false;
  final List<int> _pcmBuffer = [];
  String? _activeCloudStreamId;

  LiveSpeakService(this._audioService);

  bool get isSpeaking => _isSpeaking;

  /// Start streaming phone mic -> device speaker.
  /// Supports local UDP (if deviceIp provided) or cloud relay (if cloudStreamId provided).
  Future<bool> startSpeaking(String deviceId, {String? deviceIp, String? cloudStreamId}) async {
    if (_isSpeaking) return false;

    if (!await _recorder.hasPermission()) {
      debugPrint('[LiveSpeak] Mic permission denied');
      return false;
    }

    _activeCloudStreamId = cloudStreamId;

    // In Local LAN mode: connect UDP if not already connected, or refresh session
    if (deviceIp != null && _activeCloudStreamId == null) {
      if (!_audioService.isConnected) {
        debugPrint('[LiveSpeak] Audio UDP not connected yet, connecting to $deviceIp...');
        await _audioService.connect(deviceIp);
      } else {
        _audioService.sendCommand('{"cmd":"start_recording"}');
      }
    }

    if (_activeCloudStreamId != null) {
      final wsUrl = RelayConfig.speakWsUrl(_activeCloudStreamId!);
      try {
        _cloudWsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        debugPrint('[LiveSpeak] Connected talkback WebSocket to $wsUrl');
      } catch (e) {
        debugPrint('[LiveSpeak] Error connecting talkback WebSocket: $e');
      }
    }

    _pcmBuffer.clear();
    _isSpeaking = true;
    notifyListeners();

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
      );

      _streamSub = stream.listen(
        (chunk) {
          _pcmBuffer.addAll(chunk);
          while (_pcmBuffer.length >= _chunkBytes) {
            final rawChunk = Uint8List.fromList(_pcmBuffer.sublist(0, _chunkBytes));
            _pcmBuffer.removeRange(0, _chunkBytes);
            
            // Apply 4.0x digital software gain boost with int16 clamping for loud, clear speech
            final bd = ByteData.sublistView(rawChunk);
            for (int i = 0; i < rawChunk.length - 1; i += 2) {
              int s = bd.getInt16(i, Endian.little);
              s = (s * 4).clamp(-32768, 32767);
              bd.setInt16(i, s, Endian.little);
            }

            // Cloud relay playback via dedicated WebSocket (instant zero-latency)
            if (_cloudWsChannel != null) {
              try {
                _cloudWsChannel!.sink.add(rawChunk);
              } catch (err) {
                debugPrint('[LiveSpeak] Talkback WS send error: $err, falling back to HTTP POST');
                if (_activeCloudStreamId != null) {
                  _sendCloudSpeakChunk(_activeCloudStreamId!, rawChunk);
                }
              }
            } else if (_audioService.isConnected) {
              // Local UDP fallback
              _audioService.sendAudioToSpeaker(rawChunk);
            } else if (_activeCloudStreamId != null) {
              _sendCloudSpeakChunk(_activeCloudStreamId!, rawChunk);
            }
          }
        },
        onError: (e) {
          debugPrint('[LiveSpeak] Stream error: $e');
          stopSpeaking(deviceId);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[LiveSpeak] startStream error: $e');
      _isSpeaking = false;
      notifyListeners();
      return false;
    }

    return true;
  }

  void _sendCloudSpeakChunk(String streamId, Uint8List chunk) {
    try {
      final uri = Uri.parse(RelayConfig.speakUrl(streamId));
      http.post(
        uri,
        headers: {'Content-Type': 'application/octet-stream'},
        body: chunk,
      ).catchError((err) {
        debugPrint('[LiveSpeak] Cloud speak chunk error: $err');
        return http.Response('', 500);
      });
    } catch (_) {}
  }

  /// Stop streaming and release resources.
  Future<void> stopSpeaking(String deviceId) async {
    if (!_isSpeaking) return;
    _isSpeaking = false;

    await _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();

    if (_pcmBuffer.isNotEmpty) {
      final remaining = Uint8List.fromList(List.from(_pcmBuffer));
      final bd = ByteData.sublistView(remaining);
      for (int i = 0; i < remaining.length - 1; i += 2) {
        int s = bd.getInt16(i, Endian.little);
        s = (s * 4).clamp(-32768, 32767);
        bd.setInt16(i, s, Endian.little);
      }

      if (_cloudWsChannel != null) {
        try {
          _cloudWsChannel!.sink.add(remaining);
        } catch (_) {
          if (_activeCloudStreamId != null) {
            _sendCloudSpeakChunk(_activeCloudStreamId!, remaining);
          }
        }
      } else if (_audioService.isConnected) {
        _audioService.sendAudioToSpeaker(remaining);
      } else if (_activeCloudStreamId != null) {
        _sendCloudSpeakChunk(_activeCloudStreamId!, remaining);
      }
      _pcmBuffer.clear();
    }

    if (_cloudWsChannel != null) {
      try {
        await _cloudWsChannel!.sink.close();
      } catch (_) {}
      _cloudWsChannel = null;
      debugPrint('[LiveSpeak] Talkback WebSocket closed');
    }

    // Keep _audioService connected so parent continues to hear baby audio seamlessly!
    _activeCloudStreamId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _cloudWsChannel?.sink.close();
    _recorder.dispose();
    if (_audioService.isConnected) {
      _audioService.disconnect();
    }
    super.dispose();
  }
}
