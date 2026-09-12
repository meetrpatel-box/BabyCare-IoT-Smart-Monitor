import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_udp_service.dart';

/// Wraps the AudioUdpService to manage recording commands and generate WAV files.
class Esp32AudioService {
  final AudioUdpService _audioService;
  
  bool _isRecording = false;
  final List<Uint8List> _chunks = [];
  StreamSubscription? _audioSub;
  Completer<String?>? _completer;

  // Progress: (received, total expected chunks)
  // 8 seconds * 16000 bytes/sec = 128,000 bytes
  final _progressController = StreamController<(int, int)>.broadcast();
  Stream<(int, int)> get onProgress => _progressController.stream;

  Esp32AudioService(this._audioService);

  bool get isRecording => _isRecording;

  /// Start receiving mic audio from ESP32 and save as a WAV file.
  /// Ensure _audioService.connect(ip) has been called before this.
  Future<String?> startRecording(String deviceId) async {
    if (_isRecording) return null;
    _isRecording = true;
    _chunks.clear();
    _completer = Completer<String?>();

    _audioSub = _audioService.onAudioReceived.listen((chunk) {
      _chunks.add(chunk);
      int totalReceived = _chunks.fold<int>(0, (sum, c) => sum + c.length);
      int maxExpected = 128000;
      _progressController.add((totalReceived, maxExpected));
      
      if (totalReceived >= maxExpected) {
        stopRecording(deviceId);
      }
    });

    _audioService.sendCommand("start_recording");

    return _completer!.future.timeout(const Duration(seconds: 12), onTimeout: () {
      stopRecording(deviceId);
      return _completer!.isCompleted ? null : _completer!.future;
    });
  }

  /// Stop receiving mic audio from ESP32.
  Future<void> stopRecording(String deviceId) async {
    if (!_isRecording) return;
    _isRecording = false;

    _audioService.sendCommand("stop_recording");
    _audioSub?.cancel();

    if (!(_completer?.isCompleted ?? true)) {
       try {
          final totalBytes = _chunks.fold<int>(0, (sum, c) => sum + c.length);
          if (totalBytes == 0) {
            _completer?.complete(null);
            return;
          }
          final pcm = BytesBuilder();
          for (final chunk in _chunks) pcm.add(chunk);
          
          final wavBytes = _buildWav(pcm.toBytes());
          final dir = await getTemporaryDirectory();
          final wavFile = File('${dir.path}/esp32_recording.wav');
          await wavFile.writeAsBytes(wavBytes);
          _completer?.complete(wavFile.path);
       } catch (e) {
          _completer?.complete(null);
       }
    }
  }

  Uint8List _buildWav(Uint8List pcm) {
    const sampleRate = 16000;
    const bitsPerSample = 16;
    const numChannels = 1;
    final dataSize = pcm.length;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);

    final header = ByteData(44);
    _setAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    _setAscii(header, 8, 'WAVE');
    _setAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    _setAscii(header, 36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcm);
    return result;
  }

  void _setAscii(ByteData bd, int offset, String s) {
    for (int i = 0; i < s.length; i++) bd.setUint8(offset + i, s.codeUnitAt(i));
  }

  void dispose() {
    _audioSub?.cancel();
    _progressController.close();
  }
}
