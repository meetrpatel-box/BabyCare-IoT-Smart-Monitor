import 'package:flutter_test/flutter_test.dart';
import 'package:baby_track_flutter/services/admin_service.dart';

void main() {
  group('ModelBackend', () {
    test('fromString parses valid values', () {
      expect(ModelBackend.fromString('heuristic'), ModelBackend.heuristic);
      expect(ModelBackend.fromString('tfjs'), ModelBackend.tfjs);
      expect(ModelBackend.fromString('vertex-ai'), ModelBackend.vertexAi);
    });

    test('fromString returns heuristic for null/invalid', () {
      expect(ModelBackend.fromString(null), ModelBackend.heuristic);
      expect(ModelBackend.fromString('invalid'), ModelBackend.heuristic);
    });

    test('value returns API string', () {
      expect(ModelBackend.heuristic.value, 'heuristic');
      expect(ModelBackend.tfjs.value, 'tfjs');
      expect(ModelBackend.vertexAi.value, 'vertex-ai');
    });

    test('label returns human-readable text', () {
      expect(ModelBackend.heuristic.label, 'Heuristic');
      expect(ModelBackend.tfjs.label, 'TensorFlow.js');
      expect(ModelBackend.vertexAi.label, 'Vertex AI');
    });
  });

  group('ModelConfig', () {
    test('fromMap creates valid instance', () {
      final config = ModelConfig.fromMap({
        'activeVersion': 'yamnet-v1.2',
        'backend': 'tfjs',
        'storagePath': 'models/cry-classifier/yamnet-v1.2/',
        'vertexEndpointId': null,
        'lastUpdatedBy': 'admin-uid',
      });

      expect(config.activeVersion, 'yamnet-v1.2');
      expect(config.backend, ModelBackend.tfjs);
      expect(config.storagePath, 'models/cry-classifier/yamnet-v1.2/');
      expect(config.abTest, isNull);
      expect(config.lastUpdatedBy, 'admin-uid');
    });

    test('fromMap with A/B test config', () {
      final config = ModelConfig.fromMap({
        'activeVersion': 'yamnet-v1.0',
        'backend': 'tfjs',
        'abTest': {
          'challengerVersion': 'yamnet-v2.0-beta',
          'challengerBackend': 'vertex-ai',
          'challengerStoragePath': 'models/challenger/',
          'trafficPercent': 15,
        },
      });

      expect(config.abTest, isNotNull);
      expect(config.abTest!.challengerVersion, 'yamnet-v2.0-beta');
      expect(config.abTest!.challengerBackend, ModelBackend.vertexAi);
      expect(config.abTest!.trafficPercent, 15);
    });

    test('fromMap handles missing fields', () {
      final config = ModelConfig.fromMap({});

      expect(config.activeVersion, 'heuristic-v1.0');
      expect(config.backend, ModelBackend.heuristic);
      expect(config.abTest, isNull);
    });
  });

  group('ABTestConfig', () {
    test('fromMap creates valid instance', () {
      final config = ABTestConfig.fromMap({
        'challengerVersion': 'v2.0',
        'challengerBackend': 'tfjs',
        'challengerStoragePath': 'models/v2/',
        'trafficPercent': 25,
      });

      expect(config.challengerVersion, 'v2.0');
      expect(config.challengerBackend, ModelBackend.tfjs);
      expect(config.challengerStoragePath, 'models/v2/');
      expect(config.trafficPercent, 25);
    });

    test('toMap serializes correctly', () {
      const config = ABTestConfig(
        challengerVersion: 'v2.0',
        challengerBackend: ModelBackend.tfjs,
        challengerStoragePath: 'models/v2/',
        trafficPercent: 25,
      );

      final map = config.toMap();

      expect(map['challengerVersion'], 'v2.0');
      expect(map['challengerBackend'], 'tfjs');
      expect(map['challengerStoragePath'], 'models/v2/');
      expect(map['trafficPercent'], 25);
    });

    test('toMap omits null storagePath', () {
      const config = ABTestConfig(
        challengerVersion: 'v2.0',
        challengerBackend: ModelBackend.heuristic,
        trafficPercent: 50,
      );

      final map = config.toMap();
      expect(map.containsKey('challengerStoragePath'), false);
    });
  });

  group('ModelPerformanceStats', () {
    test('fromMap creates valid instance', () {
      final stats = ModelPerformanceStats.fromMap({
        'totalClassified': 100,
        'totalWithGroundTruth': 30,
        'cloudAccuracy': 0.85,
        'edgeAccuracy': 0.72,
        'classificationBreakdown': {'hungry': 40, 'tired': 30, 'pain': 20},
        'avgProcessingTimeMs': 55,
        'modelVersionBreakdown': {'yamnet-v1.0': 80, 'yamnet-v1.2': 20},
      });

      expect(stats.totalClassified, 100);
      expect(stats.totalWithGroundTruth, 30);
      expect(stats.cloudAccuracy, closeTo(0.85, 0.01));
      expect(stats.edgeAccuracy, closeTo(0.72, 0.01));
      expect(stats.classificationBreakdown['hungry'], 40);
      expect(stats.avgProcessingTimeMs, 55);
      expect(stats.modelVersionBreakdown['yamnet-v1.0'], 80);
      expect(stats.abTestStats, isNull);
    });

    test('fromMap with A/B test stats', () {
      final stats = ModelPerformanceStats.fromMap({
        'totalClassified': 200,
        'totalWithGroundTruth': 50,
        'cloudAccuracy': 0.80,
        'edgeAccuracy': 0.65,
        'classificationBreakdown': {},
        'avgProcessingTimeMs': 60,
        'modelVersionBreakdown': {},
        'abTestStats': {
          'primaryCount': 35,
          'challengerCount': 15,
          'primaryAccuracy': 0.82,
          'challengerAccuracy': 0.90,
        },
      });

      expect(stats.abTestStats, isNotNull);
      expect(stats.abTestStats!.primaryCount, 35);
      expect(stats.abTestStats!.challengerCount, 15);
      expect(stats.abTestStats!.primaryAccuracy, closeTo(0.82, 0.01));
      expect(stats.abTestStats!.challengerAccuracy, closeTo(0.90, 0.01));
    });

    test('fromMap handles empty data', () {
      final stats = ModelPerformanceStats.fromMap({});

      expect(stats.totalClassified, 0);
      expect(stats.cloudAccuracy, 0);
      expect(stats.classificationBreakdown, isEmpty);
    });
  });

  group('ABTestStats', () {
    test('fromMap creates valid instance', () {
      final stats = ABTestStats.fromMap({
        'primaryCount': 100,
        'challengerCount': 50,
        'primaryAccuracy': 0.8,
        'challengerAccuracy': 0.9,
      });

      expect(stats.primaryCount, 100);
      expect(stats.challengerCount, 50);
      expect(stats.primaryAccuracy, 0.8);
      expect(stats.challengerAccuracy, 0.9);
    });
  });
}
