import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';

class AudioUdpService {
  RawDatagramSocket? _socket;
  InternetAddress? _esp32Address;
  Timer? _heartbeatTimer;
  
  bool _isPlaying = false;
  
  // Stream to expose incoming raw audio chunks
  final _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onAudioReceived => _audioStreamController.stream;

  int _packetCount = 0;

  // Native MethodChannel for Android AudioTrack
  static const MethodChannel _audioChannel = MethodChannel('com.babytrack/audio');

  Future<void> connect(String esp32Ip) async {
    try {
      debugPrint('UDP: Attempting to connect to $esp32Ip');
      await disconnect(); // ensure closed before new connection
      
      _esp32Address = InternetAddress(esp32Ip);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      
      try {
        // Initialize Native Android AudioTrack with VoIP communication mode
        await _audioChannel.invokeMethod('initAudioTrack', {'sampleRate': 16000});
        
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
        await session.setActive(true);

        _isPlaying = true;
        debugPrint('UDP: Native AudioTrack started successfully');
      } catch (playerErr) {
        debugPrint('UDP Native Player Error: $playerErr');
      }

      // Simple listener: drain socket, amplify quiet ESP32 mic, and feed speaker
      _socket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          Datagram? d;
          while ((d = _socket?.receive()) != null) {
            final rawData = d!.data;
            _audioStreamController.add(rawData);
            
            _packetCount++;
            if (_packetCount % 50 == 0) {
              int sum = 0;
              final view = ByteData.sublistView(rawData);
              for (int i = 0; i < rawData.length - 1; i += 2) {
                 sum += view.getInt16(i, Endian.little).abs();
              }
              int avgLevel = sum ~/ (rawData.length / 2);
              debugPrint('🔊 ESP32 Mic -> Phone Speaker | Packet: $_packetCount | Raw Volume: $avgLevel');
            }
            
            if (_isPlaying && rawData.length >= 2) {
               try {
                 // Create an aligned copy to safely read/write 16-bit PCM samples
                 final pcm = Uint8List.fromList(rawData);
                 final bd = ByteData.sublistView(pcm);
                 for (int i = 0; i < pcm.length - 1; i += 2) {
                   int s = bd.getInt16(i, Endian.little);
                   s = (s * 4).clamp(-32768, 32767); // 4x clear volume boost
                   bd.setInt16(i, s, Endian.little);
                 }
                 
                 // Immediately feed chunk to native AudioTrack with zero delay
                 _audioChannel.invokeMethod('writeAudio', {'data': pcm});
               } catch (e) {
                 debugPrint('Feed error: $e');
               }
            }
          }
        }
      });
      
      // Send the start recording command immediately!
      for(int i = 0; i < 3; i++) {
        sendCommand('{"cmd":"start_recording"}');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Periodic heartbeat every 2 seconds so ESP32 keeps streaming mic audio continuously
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_socket != null && _esp32Address != null) {
          sendCommand('{"cmd":"start_recording"}');
        }
      });

      debugPrint('UDP: Socket listening and heartbeat active!');
      
    } catch (e) {
      debugPrint('UDP Connect Error: $e');
    }
  }

  bool get isConnected => _socket != null && _esp32Address != null;

  Future<void> setTargetIp(String ip) async {
    _esp32Address = InternetAddress(ip);
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  void sendAudioToSpeaker(Uint8List pcmChunk, {String? targetIp}) async {
    if (targetIp != null && (_socket == null || _esp32Address == null)) {
      await setTargetIp(targetIp);
    }
    if (_socket != null && _esp32Address != null) {
      _socket!.send(pcmChunk, _esp32Address!, 8282);
    } else {
      debugPrint('UDP sendAudioToSpeaker FAILED: Socket or ESP32 Address is null!');
    }
  }

  void sendCommand(String jsonString) {
    if (_socket != null && _esp32Address != null) {
      _socket!.send(utf8.encode(jsonString), _esp32Address!, 8282);
    }
  }
  
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isPlaying = false;
    sendCommand('{"cmd":"stop_recording"}');
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      await _audioChannel.invokeMethod('stopAudioTrack');
    } catch (e) {
      debugPrint('Failed to stop native AudioTrack: $e');
    }
    _socket?.close();
    _socket = null;
  }
}
