import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

/// Provider for managing milestone state
///
/// Handles:
/// - Loading milestones for a baby
/// - Tracking milestone completion
/// - Filtering by category
/// - Calculating completion percentages
class MilestoneProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  MilestoneProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // State
  List<MilestoneModel> _milestones = [];
  List<MilestoneModel> _upcomingMilestones = [];
  bool _isLoading = false;
  String? _error;
  String? _currentBabyId;
  MilestoneCategory? _selectedCategory;

  // Getters
  List<MilestoneModel> get milestones => _milestones;
  List<MilestoneModel> get upcomingMilestones => _upcomingMilestones;
  bool get isLoading => _isLoading;
  String? get error => _error;
  MilestoneCategory? get selectedCategory => _selectedCategory;

  List<MilestoneModel> get completedMilestones => _milestones
      .where((m) => m.achievedDate.isBefore(DateTime.now()))
      .toList();

  List<MilestoneModel> get pendingMilestones =>
      _milestones.where((m) => m.achievedDate.isAfter(DateTime.now())).toList();

  int get completedCount => completedMilestones.length;
  int get totalCount => _milestones.length;

  // ============================================================
  // LOAD OPERATIONS
  // ============================================================

  /// Load all milestones for a baby
  Future<void> loadMilestones(String babyId) async {
    if (_currentBabyId == babyId && _milestones.isNotEmpty) {
      // Already loaded for this baby
      return;
    }

    _currentBabyId = babyId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // For now, we'll use a placeholder query structure
      // This will be replaced with actual MilestoneService implementation
      final snapshot = await _firestoreService.firestore
          .collection('babies')
          .doc(babyId)
          .collection('milestones')
          .orderBy('achievedDate', descending: true)
          .get();

      _milestones = snapshot.docs
          .map((doc) => MilestoneModel.fromFirestore(doc))
          .toList();

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('MilestoneProvider: Error loading milestones: $e');
    }
  }

  /// Load upcoming milestones based on baby's age
  Future<void> loadUpcomingMilestones(String babyId, int ageInMonths) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load milestones expected in next 2 months
      final minAge = ageInMonths;
      final maxAge = ageInMonths + 2;

      final snapshot = await _firestoreService.firestore
          .collection('babies')
          .doc(babyId)
          .collection('milestones')
          .where('ageInMonths', isGreaterThanOrEqualTo: minAge)
          .where('ageInMonths', isLessThanOrEqualTo: maxAge)
          .get();

      _upcomingMilestones = snapshot.docs
          .map((doc) => MilestoneModel.fromFirestore(doc))
          .toList();

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('MilestoneProvider: Error loading upcoming milestones: $e');
    }
  }

  /// Refresh milestones (reload from Firestore)
  Future<void> refresh() async {
    if (_currentBabyId != null) {
      _milestones = [];
      await loadMilestones(_currentBabyId!);
    }
  }

  // ============================================================
  // MILESTONE OPERATIONS
  // ============================================================

  /// Mark a milestone as completed
  Future<void> markMilestoneCompleted(
    String milestoneId,
    DateTime completedAt, {
    String? photoUrl,
    String? notes,
  }) async {
    if (_currentBabyId == null) {
      _error = 'No baby selected';
      notifyListeners();
      return;
    }

    try {
      await _firestoreService.firestore
          .collection('babies')
          .doc(_currentBabyId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
        'achievedDate': completedAt,
        'updatedAt': DateTime.now(),
        if (photoUrl != null) 'photoUrls': [photoUrl],
        if (notes != null) 'notes': notes,
      });

      // Update local state
      final index = _milestones.indexWhere((m) => m.id == milestoneId);
      if (index >= 0) {
        _milestones[index] = _milestones[index].copyWith(
          achievedDate: completedAt,
          photoUrls:
              photoUrl != null ? [photoUrl] : _milestones[index].photoUrls,
          notes: notes ?? _milestones[index].notes,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('MilestoneProvider: Error marking milestone completed: $e');
    }
  }

  /// Add a custom milestone
  Future<void> addCustomMilestone(MilestoneModel milestone) async {
    if (_currentBabyId == null) {
      _error = 'No baby selected';
      notifyListeners();
      return;
    }

    try {
      final docRef = await _firestoreService.firestore
          .collection('babies')
          .doc(_currentBabyId)
          .collection('milestones')
          .add(milestone.toFirestore());

      // Add to local state with the generated ID
      final newMilestone = milestone.copyWith(id: docRef.id);
      _milestones.insert(0, newMilestone);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('MilestoneProvider: Error adding custom milestone: $e');
    }
  }

  /// Delete a milestone
  Future<void> deleteMilestone(String milestoneId) async {
    if (_currentBabyId == null) return;

    try {
      await _firestoreService.firestore
          .collection('babies')
          .doc(_currentBabyId)
          .collection('milestones')
          .doc(milestoneId)
          .delete();

      // Update local state
      _milestones.removeWhere((m) => m.id == milestoneId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('MilestoneProvider: Error deleting milestone: $e');
    }
  }

  // ============================================================
  // FILTERING & ANALYTICS
  // ============================================================

  /// Get milestone by ID
  MilestoneModel? getMilestoneById(String milestoneId) {
    try {
      return _milestones.firstWhere((m) => m.id == milestoneId);
    } catch (e) {
      return null;
    }
  }

  /// Filter milestones by category
  void filterByCategory(MilestoneCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Get milestones by category
  List<MilestoneModel> getMilestonesByCategory(MilestoneCategory category) {
    return _milestones.where((m) => m.category == category).toList();
  }

  /// Get milestones by age range
  List<MilestoneModel> getMilestonesByAge(int minMonths, int maxMonths) {
    return _milestones
        .where((m) => m.ageInMonths >= minMonths && m.ageInMonths <= maxMonths)
        .toList();
  }

  /// Calculate completion percentage for a specific age
  /// Returns percentage of milestones achieved at or before the given age
  double getCompletionPercentage(int ageInMonths) {
    if (_milestones.isEmpty) return 0.0;

    // Count milestones expected at or before this age
    final expectedMilestones =
        _milestones.where((m) => m.ageInMonths <= ageInMonths).toList();

    if (expectedMilestones.isEmpty) return 0.0;

    // Count completed milestones in that range
    final completedCount = expectedMilestones
        .where((m) => m.achievedDate.isBefore(DateTime.now()))
        .length;

    return (completedCount / expectedMilestones.length) * 100;
  }

  /// Get completion percentage by category
  double getCategoryCompletionPercentage(
    MilestoneCategory category,
    int ageInMonths,
  ) {
    final categoryMilestones = getMilestonesByCategory(category)
        .where((m) => m.ageInMonths <= ageInMonths)
        .toList();

    if (categoryMilestones.isEmpty) return 0.0;

    final completedCount = categoryMilestones
        .where((m) => m.achievedDate.isBefore(DateTime.now()))
        .length;

    return (completedCount / categoryMilestones.length) * 100;
  }

  /// Get next milestone to achieve
  MilestoneModel? getNextMilestone(int ageInMonths) {
    final pending = _milestones
        .where((m) =>
            m.ageInMonths <= ageInMonths + 1 &&
            m.achievedDate.isAfter(DateTime.now()))
        .toList();

    if (pending.isEmpty) return null;

    // Sort by age and return first
    pending.sort((a, b) => a.ageInMonths.compareTo(b.ageInMonths));
    return pending.first;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }

  /// Clear all state
  void clear() {
    _milestones = [];
    _upcomingMilestones = [];
    _currentBabyId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
