import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/models/audio_track.dart';
import 'package:flutter/material.dart';

void main() {
  group('AudioTrack Model', () {
    test('creates audio track with all properties', () {
      final track = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      expect(track.id, equals('lullaby_1'));
      expect(track.name, equals('Brahms\' Lullaby'));
      expect(track.duration, equals(const Duration(minutes: 3)));
      expect(track.icon, equals(Icons.music_note));
    });

    test('creates continuous track with null duration', () {
      final track = AudioTrack(
        id: 'white_noise',
        name: 'White Noise',
        duration: null,
        icon: Icons.graphic_eq,
      );

      expect(track.id, equals('white_noise'));
      expect(track.name, equals('White Noise'));
      expect(track.duration, isNull);
      expect(track.icon, equals(Icons.graphic_eq));
    });

    test('isContinuous returns true when duration is null', () {
      final continuousTrack = AudioTrack(
        id: 'rain',
        name: 'Rain',
        duration: null,
        icon: Icons.water_drop,
      );

      final timedTrack = AudioTrack(
        id: 'lullaby',
        name: 'Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      expect(continuousTrack.isContinuous, isTrue);
      expect(timedTrack.isContinuous, isFalse);
    });

    test('durationText returns formatted duration for timed tracks', () {
      final track = AudioTrack(
        id: 'lullaby',
        name: 'Lullaby',
        duration: const Duration(minutes: 3, seconds: 30),
        icon: Icons.music_note,
      );

      expect(track.durationText, equals('3:30'));
    });

    test('durationText returns "Continuous" for continuous tracks', () {
      final track = AudioTrack(
        id: 'white_noise',
        name: 'White Noise',
        duration: null,
        icon: Icons.graphic_eq,
      );

      expect(track.durationText, equals('Continuous'));
    });

    test('equality comparison works correctly', () {
      final track1 = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      final track2 = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      final track3 = AudioTrack(
        id: 'lullaby_2',
        name: 'Different Lullaby',
        duration: const Duration(minutes: 2),
        icon: Icons.music_note,
      );

      expect(track1, equals(track2));
      expect(track1, isNot(equals(track3)));
    });

    test('hashCode is consistent for equal objects', () {
      final track1 = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      final track2 = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      expect(track1.hashCode, equals(track2.hashCode));
    });

    test('copyWith creates new instance with updated properties', () {
      final original = AudioTrack(
        id: 'lullaby_1',
        name: 'Brahms\' Lullaby',
        duration: const Duration(minutes: 3),
        icon: Icons.music_note,
      );

      final updated = original.copyWith(
        name: 'Updated Lullaby',
        duration: const Duration(minutes: 5),
      );

      expect(updated.id, equals(original.id));
      expect(updated.name, equals('Updated Lullaby'));
      expect(updated.duration, equals(const Duration(minutes: 5)));
      expect(updated.icon, equals(original.icon));
    });

    group('Validation', () {
      test('throws when id is empty', () {
        expect(
          () => AudioTrack(
            id: '',
            name: 'Test',
            duration: null,
            icon: Icons.music_note,
          ),
          throwsAssertionError,
        );
      });

      test('throws when name is empty', () {
        expect(
          () => AudioTrack(
            id: 'test',
            name: '',
            duration: null,
            icon: Icons.music_note,
          ),
          throwsAssertionError,
        );
      });

      test('allows valid duration values', () {
        expect(
          () => AudioTrack(
            id: 'test',
            name: 'Test',
            duration: const Duration(seconds: 1),
            icon: Icons.music_note,
          ),
          returnsNormally,
        );

        expect(
          () => AudioTrack(
            id: 'test',
            name: 'Test',
            duration: const Duration(hours: 1),
            icon: Icons.music_note,
          ),
          returnsNormally,
        );
      });
    });
  });
}
