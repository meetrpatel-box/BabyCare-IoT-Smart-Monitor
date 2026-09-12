import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

/// Provider for managing parenting tips state
///
/// Handles:
/// - Loading age-appropriate tips
/// - Tip of the day rotation
/// - Dismissed tips tracking
/// - Helpfulness feedback
class TipProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  TipProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // State
  List<TipModel> _tips = [];
  TipModel? _tipOfTheDay;
  Set<String> _dismissedTipIds = {};
  Map<String, bool> _helpfulnessRatings = {}; // tipId -> isHelpful
  bool _isLoading = false;
  String? _error;
  int? _currentAgeMonths;
  DateTime? _lastTipOfDayDate;

  // Getters
  List<TipModel> get tips => _tips;
  TipModel? get tipOfTheDay => _tipOfTheDay;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get dismissedTipIds => _dismissedTipIds;
  Map<String, bool> get helpfulnessRatings => _helpfulnessRatings;

  /// Get active tips (not dismissed)
  List<TipModel> get activeTips =>
      _tips.where((t) => !_dismissedTipIds.contains(t.id)).toList();

  /// Get dismissed tips
  List<TipModel> get dismissedTips =>
      _tips.where((t) => _dismissedTipIds.contains(t.id)).toList();

  // ============================================================
  // LOAD OPERATIONS
  // ============================================================

  /// Load tips for a specific baby age
  Future<void> loadTips(String babyId, int ageInMonths) async {
    if (_currentAgeMonths == ageInMonths && _tips.isNotEmpty) {
      // Already loaded for this age
      return;
    }

    _currentAgeMonths = ageInMonths;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Query tips relevant for this age range
      // Tips where minAgeMonths <= ageInMonths <= maxAgeMonths
      final snapshot = await _firestoreService.firestore
          .collection('tips')
          .where('minAgeMonths', isLessThanOrEqualTo: ageInMonths)
          .orderBy('minAgeMonths')
          .orderBy('priority', descending: true)
          .limit(50)
          .get();

      final allTips =
          snapshot.docs.map((doc) => TipModel.fromFirestore(doc)).toList();

      // Filter tips that are relevant for the current age
      _tips =
          allTips.where((tip) => tip.isRelevantForAge(ageInMonths)).toList();

      _isLoading = false;
      _error = null;
      notifyListeners();

      // Load dismissed tips from user preferences
      await _loadDismissedTips(babyId);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('TipProvider: Error loading tips: $e');
    }
  }

  /// Load tip of the day
  Future<void> loadTipOfTheDay(String babyId, int ageInMonths) async {
    // Check if we need to refresh (new day)
    final today = DateTime.now();
    if (_lastTipOfDayDate != null &&
        _lastTipOfDayDate!.day == today.day &&
        _lastTipOfDayDate!.month == today.month &&
        _lastTipOfDayDate!.year == today.year &&
        _tipOfTheDay != null) {
      // Already have today's tip
      return;
    }

    try {
      // Load age-appropriate tips
      if (_tips.isEmpty) {
        await loadTips(babyId, ageInMonths);
      }

      // Select tip of the day based on date seed
      // This ensures same tip for the whole day
      if (_tips.isNotEmpty) {
        final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
        final tipIndex = dayOfYear % _tips.length;
        _tipOfTheDay = _tips[tipIndex];
        _lastTipOfDayDate = today;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('TipProvider: Error loading tip of the day: $e');
    }
  }

  /// Refresh tip of the day (force reload)
  Future<void> refreshTipOfTheDay() async {
    _lastTipOfDayDate = null;
    _tipOfTheDay = null;
    notifyListeners();
  }

  /// Refresh all tips (reload from Firestore)
  Future<void> refresh(String babyId, int ageInMonths) async {
    _tips = [];
    await loadTips(babyId, ageInMonths);
    await loadTipOfTheDay(babyId, ageInMonths);
  }

  // ============================================================
  // TIP INTERACTIONS
  // ============================================================

  /// Dismiss a tip (hide from active list)
  Future<void> dismissTip(String tipId) async {
    _dismissedTipIds.add(tipId);
    notifyListeners();

    // Persist to Firestore
    try {
      // Store in user preferences
      // For now, we'll use a simple structure
      // This should be moved to a proper UserPreferencesService later
      await _firestoreService.firestore
          .collection('userPreferences')
          .doc('dismissed_tips')
          .set({
        'tipIds': _dismissedTipIds.toList(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TipProvider: Error persisting dismissed tip: $e');
    }
  }

  /// Un-dismiss a tip (show again)
  Future<void> undismissTip(String tipId) async {
    _dismissedTipIds.remove(tipId);
    notifyListeners();

    try {
      await _firestoreService.firestore
          .collection('userPreferences')
          .doc('dismissed_tips')
          .set({
        'tipIds': _dismissedTipIds.toList(),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TipProvider: Error persisting undismissed tip: $e');
    }
  }

  /// Mark tip as helpful or not helpful
  Future<void> markTipHelpful(String tipId, bool isHelpful) async {
    _helpfulnessRatings[tipId] = isHelpful;
    notifyListeners();

    try {
      // Store feedback
      await _firestoreService.firestore
          .collection('tips')
          .doc(tipId)
          .collection('feedback')
          .add({
        'isHelpful': isHelpful,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('TipProvider: Error recording tip feedback: $e');
    }
  }

  /// Get helpfulness rating for a tip
  bool? getTipHelpfulness(String tipId) {
    return _helpfulnessRatings[tipId];
  }

  // ============================================================
  // FILTERING
  // ============================================================

  /// Get tip by ID
  TipModel? getTipById(String tipId) {
    try {
      return _tips.firstWhere((t) => t.id == tipId);
    } catch (e) {
      return null;
    }
  }

  /// Check if tip is dismissed
  bool isTipDismissed(String tipId) {
    return _dismissedTipIds.contains(tipId);
  }

  /// Get helpfulness rating for a tip
  bool? getHelpfulnessRating(String tipId) {
    return _helpfulnessRatings[tipId];
  }

  /// Get tips by category
  List<TipModel> getTipsByCategory(TipCategory category) {
    return activeTips.where((t) => t.category == category).toList();
  }

  /// Get tips by priority
  List<TipModel> getTipsByPriority(TipPriority priority) {
    return activeTips.where((t) => t.priority == priority).toList();
  }

  /// Get urgent tips
  List<TipModel> getUrgentTips() {
    return getTipsByPriority(TipPriority.urgent);
  }

  /// Get tips by tags
  List<TipModel> getTipsByTags(List<String> tags) {
    return activeTips.where((tip) {
      return tags.any((tag) => tip.tags.contains(tag));
    }).toList();
  }

  /// Search tips by query
  List<TipModel> searchTips(String query) {
    final lowerQuery = query.toLowerCase();
    return activeTips.where((tip) {
      return tip.title.toLowerCase().contains(lowerQuery) ||
          tip.content.toLowerCase().contains(lowerQuery) ||
          tip.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  /// Load dismissed tips from user preferences
  Future<void> _loadDismissedTips(String babyId) async {
    try {
      final doc = await _firestoreService.firestore
          .collection('userPreferences')
          .doc('dismissed_tips')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['tipIds'] is List) {
          _dismissedTipIds = Set<String>.from(data['tipIds']);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('TipProvider: Error loading dismissed tips: $e');
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    super.dispose();
  }

  /// Clear all state
  void clear() {
    _tips = [];
    _tipOfTheDay = null;
    _dismissedTipIds = {};
    _helpfulnessRatings = {};
    _currentAgeMonths = null;
    _lastTipOfDayDate = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
