import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import '../models/models.dart';
import '../services/data_fetching_service.dart';
import '../services/firestore_service.dart';
import '../services/mock_vitals_service.dart';

/// Baby state provider with hybrid data fetching strategy
/// Uses real-time listeners for critical data only,
/// on-demand queries for historical/analytics data
class BabyProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final DataFetchingService _dataFetchingService = DataFetchingService();

  List<BabyModel> _babies = [];
  BabyModel? _selectedBaby;
  bool _isLoading = false;
  String? _error;

  // Real-time subscriptions (only for critical data)
  StreamSubscription? _babySubscription;
  StreamSubscription? _latestVitalsSubscription;
  StreamSubscription? _activeSleepSessionSubscription;

  // Latest vitals from real-time stream
  Map<String, dynamic>? _latestVitals;

  // Getters
  List<BabyModel> get babies => _babies;
  BabyModel? get selectedBaby => _selectedBaby;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBabies => _babies.isNotEmpty;
  Map<String, dynamic>? get latestVitals => _latestVitals;

  /// Load babies for parent
  Future<void> loadBabiesForParent(String parentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _babies = await _firestoreService.getBabiesForParent(parentId);
      if (_babies.isNotEmpty && _selectedBaby == null) {
        _selectedBaby = _babies.first;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load babies for family
  Future<void> loadBabiesForFamily(String familyId) async {
    debugPrint(
        '🍼 BabyProvider.loadBabiesForFamily called with familyId: $familyId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _babies = await _firestoreService.getBabiesForFamily(familyId);
      debugPrint('  ✅ Loaded ${_babies.length} babies');
      if (_babies.isNotEmpty && _selectedBaby == null) {
        _selectedBaby = _babies.first;
        debugPrint('  ✅ Selected baby: ${_selectedBaby?.name}');
      }
      _isLoading = false;
      notifyListeners();
      debugPrint('  ✅ notifyListeners called - hasBabies: $hasBabies');
    } catch (e) {
      debugPrint('  ❌ Error loading babies: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a baby
  void selectBaby(BabyModel baby) {
    _selectedBaby = baby;
    notifyListeners();
  }

  /// Select baby by ID
  void selectBabyById(String babyId) {
    final baby = _babies.firstWhere(
      (b) => b.id == babyId,
      orElse: () => _babies.first,
    );
    selectBaby(baby);
  }

  /// Subscribe to selected baby updates
  void subscribeToBaby(String babyId) {
    _babySubscription?.cancel();
    _babySubscription = _firestoreService.subscribeToBaby(babyId).listen(
      (baby) {
        if (baby != null) {
          _selectedBaby = baby;
          // Update in list
          final index = _babies.indexWhere((b) => b.id == babyId);
          if (index >= 0) {
            _babies[index] = baby;
          }
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Error subscribing to baby: $e');
      },
    );

    // NEW: Subscribe to latest vitals (real-time, embedded in baby document)
    subscribeToLatestVitals(babyId);
  }

  /// Subscribe to latest vitals (real-time)
  /// This replaces continuous listening to entire vital_signs collection
  /// Cost savings: ~95% reduction in reads
  void subscribeToLatestVitals(String babyId) {
    _latestVitalsSubscription?.cancel();
    if (kMockVitals) {
      // Emit immediately then every 5s with fresh mock readings
      _latestVitals = MockVitalsService.latestVitalsMap(babyId);
      notifyListeners();
      _latestVitalsSubscription = Stream.periodic(
        const Duration(seconds: 5),
        (_) => MockVitalsService.latestVitalsMap(babyId),
      ).listen((vitals) {
        _latestVitals = vitals;
        notifyListeners();
      });
      return;
    }
    _latestVitalsSubscription =
        _dataFetchingService.subscribeToLatestVitals(babyId).listen(
      (vitals) {
        _latestVitals = vitals;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error subscribing to latest vitals: $e');
      },
    );
  }

  /// Subscribe to active sleep session (real-time, only if one is active)
  void subscribeToActiveSleepSession(String babyId) {
    _activeSleepSessionSubscription?.cancel();
    _activeSleepSessionSubscription =
        _dataFetchingService.subscribeToActiveSleepSession(babyId).listen(
      (session) {
        // Handle active sleep session updates
        // Could add to state if needed
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error subscribing to active sleep session: $e');
      },
    );
  }

  /// Delete a baby
  Future<void> deleteBaby(String babyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.deleteBaby(babyId);

      // Remove from local list
      _babies.removeWhere((b) => b.id == babyId);

      // If deleted baby was selected, select first baby or null
      if (_selectedBaby?.id == babyId) {
        _selectedBaby = _babies.isNotEmpty ? _babies.first : null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Add a new baby
  Future<String> addBaby({
    required String name,
    required DateTime dateOfBirth,
    required String gender,
    required String parentId,
    String? familyId,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final baby = BabyModel(
        id: '',
        name: name,
        dateOfBirth: dateOfBirth,
        gender: gender,
        parentId: parentId,
        familyId: familyId,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final babyId = await _firestoreService.addBaby(baby);

      // CRITICAL: Link baby to family's babyIds array
      if (familyId != null) {
        await _firestoreService.linkBabyToFamily(familyId, babyId);
      }

      // Reload babies
      await loadBabiesForParent(parentId);

      // Select the new baby
      selectBabyById(babyId);

      return babyId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update baby
  Future<void> updateBaby(String babyId, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.updateBaby(babyId, data);

      // Update local state
      final index = _babies.indexWhere((b) => b.id == babyId);
      if (index >= 0) {
        final updatedBaby = await _firestoreService.getBaby(babyId);
        if (updatedBaby != null) {
          _babies[index] = updatedBaby;
          if (_selectedBaby?.id == babyId) {
            _selectedBaby = updatedBaby;
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get sleep sessions for selected baby (ON-DEMAND)
  /// Only call when user navigates to Sleep Analysis screen
  Future<List<SleepSession>> getSleepSessions({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    if (_selectedBaby == null) return [];

    // Use hybrid data fetching service for on-demand queries
    final sessionsData = await _dataFetchingService.getSleepSessions(
      babyId: _selectedBaby!.id,
      daysBack: 7,
    );

    // Convert to SleepSession models
    return sessionsData
        .map((data) => SleepSession.fromMap(data))
        .toList();
  }

  /// Get vital logs for selected baby (ON-DEMAND)
  /// Only call when user navigates to Trends screen
  /// Cost savings: ~80-90% reduction vs continuous listener
  Future<List<VitalLog>> getVitalLogs({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    if (_selectedBaby == null) return [];

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 7));
    final end = endDate ?? now;

    if (kMockVitals) {
      final days = end.difference(start).inDays.clamp(1, 30);
      return MockVitalsService.generateVitalLogs(
        babyId: _selectedBaby!.id,
        count: limit.clamp(10, 100),
        days: days,
      );
    }

    final vitalLogsData = await _dataFetchingService.getHistoricalVitals(
      babyId: _selectedBaby!.id,
      startDate: start,
      endDate: end,
      limit: limit,
    );

    // Convert to VitalLog models
    return vitalLogsData
        .map((data) => VitalLog.fromMap(data))
        .toList();
  }

  /// Get cry events for selected baby (ON-DEMAND)
  Future<List<CryEvent>> getCryEvents(
      DateTime startDate, DateTime endDate) async {
    if (_selectedBaby == null) return [];

    final cryEventsData = await _dataFetchingService.getCryEvents(
      babyId: _selectedBaby!.id,
      startDate: startDate,
      endDate: endDate,
    );

    // Convert to CryEvent models
    return cryEventsData
        .map((data) => CryEvent.fromMap(data))
        .toList();
  }

  /// Get daily stats for analytics (ON-DEMAND)
  /// Pre-aggregated by Cloud Functions for efficiency
  Future<List<Map<String, dynamic>>> getDailyStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_selectedBaby == null) return [];

    return await _dataFetchingService.getDailyStats(
      babyId: _selectedBaby!.id,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear state (on logout)
  void clear() {
    _babySubscription?.cancel();
    _latestVitalsSubscription?.cancel();
    _activeSleepSessionSubscription?.cancel();
    _babies = [];
    _selectedBaby = null;
    _latestVitals = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _babySubscription?.cancel();
    _latestVitalsSubscription?.cancel();
    _activeSleepSessionSubscription?.cancel();
    super.dispose();
  }
}
