/// Audio-related test fixtures for remote playback testing
library fixtures;

import 'package:baby_track_flutter/models/audio_track.dart';
import 'package:flutter/material.dart';

/// Sample audio tracks for testing
class AudioFixtures {
  /// Lullaby track (fixed duration)
  static final lullaby1 = AudioTrack(
    id: 'lullaby_1',
    name: 'Brahms\' Lullaby',
    duration: const Duration(minutes: 3),
    icon: Icons.music_note,
  );

  /// White noise track (continuous)
  static final whiteNoise = AudioTrack(
    id: 'white_noise',
    name: 'White Noise',
    duration: null, // Continuous
    icon: Icons.graphic_eq,
  );

  /// Rain sounds track (continuous)
  static final rain = AudioTrack(
    id: 'rain',
    name: 'Gentle Rain',
    duration: null,
    icon: Icons.water_drop,
  );

  /// All available tracks
  static final allTracks = [
    lullaby1,
    AudioTrack(
      id: 'lullaby_2',
      name: 'Twinkle Twinkle',
      duration: const Duration(minutes: 2, seconds: 30),
      icon: Icons.music_note,
    ),
    whiteNoise,
    rain,
    AudioTrack(
      id: 'heartbeat',
      name: 'Heartbeat',
      duration: null,
      icon: Icons.favorite,
    ),
    AudioTrack(
      id: 'ocean_waves',
      name: 'Ocean Waves',
      duration: null,
      icon: Icons.waves,
    ),
    AudioTrack(
      id: 'shushing',
      name: 'Shushing Sound',
      duration: null,
      icon: Icons.volume_up,
    ),
  ];

  /// Device command data for playing audio
  static Map<String, dynamic> playAudioCommand({
    String deviceId = 'test-device-001',
    String trackId = 'white_noise',
    int volume = 50,
    bool loop = false,
  }) {
    return {
      'deviceId': deviceId,
      'command': 'play_audio',
      'track': trackId,
      'volume': volume,
      'loop': loop,
      'status': 'pending',
      'createdAt': DateTime.now(),
    };
  }

  /// Device command data for stopping audio
  static Map<String, dynamic> stopAudioCommand({
    String deviceId = 'test-device-001',
  }) {
    return {
      'deviceId': deviceId,
      'command': 'stop_audio',
      'status': 'pending',
      'createdAt': DateTime.now(),
    };
  }

  /// Device command data for setting volume
  static Map<String, dynamic> setVolumeCommand({
    String deviceId = 'test-device-001',
    int volume = 75,
  }) {
    return {
      'deviceId': deviceId,
      'command': 'set_volume',
      'volume': volume,
      'status': 'pending',
      'createdAt': DateTime.now(),
    };
  }

  /// Audio status data
  static Map<String, dynamic> audioStatus({
    String status = 'playing',
    String? track,
    int volume = 50,
    bool isPlaying = true,
  }) {
    return {
      'status': status,
      'track': track,
      'volume': volume,
      'isPlaying': isPlaying,
      'updatedAt': DateTime.now(),
    };
  }
}
