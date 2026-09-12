import 'package:cloud_functions/cloud_functions.dart';

/// Model backend types for cry classification
enum ModelBackend {
  heuristic,
  tfjs,
  vertexAi;

  String get value {
    switch (this) {
      case ModelBackend.heuristic:
        return 'heuristic';
      case ModelBackend.tfjs:
        return 'tfjs';
      case ModelBackend.vertexAi:
        return 'vertex-ai';
    }
  }

  String get label {
    switch (this) {
      case ModelBackend.heuristic:
        return 'Heuristic';
      case ModelBackend.tfjs:
        return 'TensorFlow.js';
      case ModelBackend.vertexAi:
        return 'Vertex AI';
    }
  }

  static ModelBackend fromString(String? value) {
    switch (value) {
      case 'tfjs':
        return ModelBackend.tfjs;
      case 'vertex-ai':
        return ModelBackend.vertexAi;
      default:
        return ModelBackend.heuristic;
    }
  }
}

/// Model configuration from Firestore
class ModelConfig {
  final String activeVersion;
  final ModelBackend backend;
  final String? storagePath;
  final String? vertexEndpointId;
  final ABTestConfig? abTest;
  final String? lastUpdatedBy;

  const ModelConfig({
    required this.activeVersion,
    required this.backend,
    this.storagePath,
    this.vertexEndpointId,
    this.abTest,
    this.lastUpdatedBy,
  });

  factory ModelConfig.fromMap(Map<String, dynamic> data) {
    return ModelConfig(
      activeVersion: data['activeVersion'] as String? ?? 'heuristic-v1.0',
      backend: ModelBackend.fromString(data['backend'] as String?),
      storagePath: data['storagePath'] as String?,
      vertexEndpointId: data['vertexEndpointId'] as String?,
      abTest: data['abTest'] != null
          ? ABTestConfig.fromMap(data['abTest'] as Map<String, dynamic>)
          : null,
      lastUpdatedBy: data['lastUpdatedBy'] as String?,
    );
  }
}

/// A/B test configuration
class ABTestConfig {
  final String challengerVersion;
  final ModelBackend challengerBackend;
  final String? challengerStoragePath;
  final int trafficPercent;

  const ABTestConfig({
    required this.challengerVersion,
    required this.challengerBackend,
    this.challengerStoragePath,
    required this.trafficPercent,
  });

  factory ABTestConfig.fromMap(Map<String, dynamic> data) {
    return ABTestConfig(
      challengerVersion: data['challengerVersion'] as String? ?? '',
      challengerBackend:
          ModelBackend.fromString(data['challengerBackend'] as String?),
      challengerStoragePath: data['challengerStoragePath'] as String?,
      trafficPercent: data['trafficPercent'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'challengerVersion': challengerVersion,
        'challengerBackend': challengerBackend.value,
        if (challengerStoragePath != null)
          'challengerStoragePath': challengerStoragePath,
        'trafficPercent': trafficPercent,
      };
}

/// Model performance statistics
class ModelPerformanceStats {
  final int totalClassified;
  final int totalWithGroundTruth;
  final double cloudAccuracy;
  final double edgeAccuracy;
  final Map<String, int> classificationBreakdown;
  final int avgProcessingTimeMs;
  final Map<String, int> modelVersionBreakdown;
  final ABTestStats? abTestStats;

  const ModelPerformanceStats({
    required this.totalClassified,
    required this.totalWithGroundTruth,
    required this.cloudAccuracy,
    required this.edgeAccuracy,
    required this.classificationBreakdown,
    required this.avgProcessingTimeMs,
    required this.modelVersionBreakdown,
    this.abTestStats,
  });

  factory ModelPerformanceStats.fromMap(Map<String, dynamic> data) {
    final rawBreakdown = data['classificationBreakdown'];
    final rawVersions = data['modelVersionBreakdown'];
    final rawAbStats = data['abTestStats'];

    return ModelPerformanceStats(
      totalClassified: data['totalClassified'] as int? ?? 0,
      totalWithGroundTruth: data['totalWithGroundTruth'] as int? ?? 0,
      cloudAccuracy: (data['cloudAccuracy'] as num?)?.toDouble() ?? 0,
      edgeAccuracy: (data['edgeAccuracy'] as num?)?.toDouble() ?? 0,
      classificationBreakdown: rawBreakdown != null
          ? Map<String, dynamic>.from(rawBreakdown as Map)
                  .map((k, v) => MapEntry(k, (v as num).toInt()))
          : {},
      avgProcessingTimeMs: data['avgProcessingTimeMs'] as int? ?? 0,
      modelVersionBreakdown: rawVersions != null
          ? Map<String, dynamic>.from(rawVersions as Map)
                  .map((k, v) => MapEntry(k, (v as num).toInt()))
          : {},
      abTestStats: rawAbStats != null
          ? ABTestStats.fromMap(
              Map<String, dynamic>.from(rawAbStats as Map))
          : null,
    );
  }
}

/// A/B test performance comparison
class ABTestStats {
  final int primaryCount;
  final int challengerCount;
  final double primaryAccuracy;
  final double challengerAccuracy;

  const ABTestStats({
    required this.primaryCount,
    required this.challengerCount,
    required this.primaryAccuracy,
    required this.challengerAccuracy,
  });

  factory ABTestStats.fromMap(Map<String, dynamic> data) {
    return ABTestStats(
      primaryCount: data['primaryCount'] as int? ?? 0,
      challengerCount: data['challengerCount'] as int? ?? 0,
      primaryAccuracy: (data['primaryAccuracy'] as num?)?.toDouble() ?? 0,
      challengerAccuracy:
          (data['challengerAccuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Admin service for model management and A/B testing.
///
/// All operations require admin-level authentication.
class AdminService {
  final FirebaseFunctions _functions;

  AdminService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Get current model configuration.
  Future<ModelConfig> getModelConfig() async {
    final callable = _functions.httpsCallable('getModelConfig');
    final result = await callable.call<Map<String, dynamic>>();
    return ModelConfig.fromMap(result.data);
  }

  /// Update model configuration.
  Future<ModelConfig> updateModelConfig({
    String? activeVersion,
    ModelBackend? backend,
    String? storagePath,
    String? vertexEndpointId,
    ABTestConfig? abTest,
    bool disableAbTest = false,
  }) async {
    final callable = _functions.httpsCallable('updateModelConfig');
    final params = <String, dynamic>{};

    if (activeVersion != null) params['activeVersion'] = activeVersion;
    if (backend != null) params['backend'] = backend.value;
    if (storagePath != null) params['storagePath'] = storagePath;
    if (vertexEndpointId != null) {
      params['vertexEndpointId'] = vertexEndpointId;
    }

    if (disableAbTest) {
      params['abTest'] = null;
    } else if (abTest != null) {
      params['abTest'] = abTest.toMap();
    }

    final result = await callable.call<Map<String, dynamic>>(params);
    return ModelConfig.fromMap(result.data);
  }

  /// Get model performance statistics.
  Future<ModelPerformanceStats> getModelPerformance({
    List<String>? babyIds,
    int days = 30,
  }) async {
    final callable = _functions.httpsCallable('getModelPerformance');
    final params = <String, dynamic>{'days': days};
    if (babyIds != null) params['babyIds'] = babyIds;

    final result = await callable.call<Map<String, dynamic>>(params);
    return ModelPerformanceStats.fromMap(result.data);
  }

  /// Grant or revoke admin privileges for a user.
  Future<bool> setAdminClaim({
    required String targetUid,
    required bool isAdmin,
  }) async {
    final callable = _functions.httpsCallable('setAdminClaim');
    final result = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'isAdmin': isAdmin,
    });
    return result.data['success'] as bool? ?? false;
  }
}
