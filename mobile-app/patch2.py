import re

with open("C:/Users/patel/Downloads/BabyCareApp-feature-BabyCryAnalysis/BabyCareApp-feature-BabyCryAnalysis/baby_track_flutter/lib/services/audio_udp_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

old_connect = '''      await _audioPlayer.openPlayer();
      await _audioPlayer.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000, bufferSize: 8192, interleaved: true,
      );
      
      _isPlaying = true;
      
      _socket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          Datagram? d;
          while ((d = _socket!.receive()) != null) {
            _audioStreamController.add(d!.data);
            
            if (_isPlaying) {
               try {
                 _audioPlayer.feedFromStream(d.data);
               } catch (err) {
                 // ignore
               }
            }
          }
        }
      });
        
      // Send a keepalive packet so ESP32 knows our IP and port!
      for(int i = 0; i < 3; i++) {
        sendCommand("{\\"cmd\\":\\"start_recording\\"}");
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint("UDP: Connected successfully.");
    } catch (e) {
      debugPrint("UDP Connect Error: $e");
    }'''

new_connect = '''      // First, set up the listener so the UI badge updates
      _socket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          Datagram? d;
          while ((d = _socket!.receive()) != null) {
            _audioStreamController.add(d!.data);
            
            if (_isPlaying) {
               try {
                 _audioPlayer.feedFromStream(d.data);
               } catch (err) {
                 // ignore
               }
            }
          }
        }
      });
        
      // Send a keepalive packet so ESP32 knows our IP and port!
      for(int i = 0; i < 3; i++) {
        sendCommand("{\\"cmd\\":\\"start_recording\\"}");
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint("UDP: Socket listening and command sent.");
      
      try {
        await _audioPlayer.openPlayer();
        await _audioPlayer.startPlayerFromStream(
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: 16000, bufferSize: 8192, interleaved: true,
        );
        _isPlaying = true;
        debugPrint("UDP: Player started successfully.");
      } catch (playerError) {
        debugPrint("UDP Player Error (Redmi Note 5 Pro compatibility): $playerError");
      }
      
    } catch (e) {
      debugPrint("UDP Connect Error: $e");
    }'''

if old_connect in content:
    content = content.replace(old_connect, new_connect)
    with open("C:/Users/patel/Downloads/BabyCareApp-feature-BabyCryAnalysis/BabyCareApp-feature-BabyCryAnalysis/baby_track_flutter/lib/services/audio_udp_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Patched successfully")
else:
    print("Could not find old_connect block")
