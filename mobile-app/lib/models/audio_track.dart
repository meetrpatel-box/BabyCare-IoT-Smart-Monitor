import 'package:flutter/material.dart';

class AudioTrack {
  final String id;
  final String name;
  final Duration? duration;  // null for continuous sounds
  final IconData icon;
  
  const AudioTrack({
    required this.id,
    required this.name,
    required this.duration,
    required this.icon,
  }) : assert(id != '', 'id cannot be empty'),
       assert(name != '', 'name cannot be empty');

  /// Returns true if this is a continuous track (no fixed duration)
  bool get isContinuous => duration == null;

  /// Returns formatted duration string
  String get durationText {
    if (duration == null) return 'Continuous';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with updated properties
  AudioTrack copyWith({
    String? id,
    String? name,
    Duration? duration,
    IconData? icon,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrack &&
        other.id == id &&
        other.name == name &&
        other.duration == duration &&
        other.icon == icon;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, duration, icon);
  }

  @override
  String toString() {
    return 'AudioTrack(id: $id, name: $name, duration: $duration)';
  }
}
