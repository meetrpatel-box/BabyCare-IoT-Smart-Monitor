import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/photo_model.dart';
import '../services/photo_service.dart';

/// Provider for managing photo state across the app
///
/// Handles:
/// - Photo list state and pagination
/// - Upload progress tracking
/// - Search and filtering
/// - Real-time updates
class PhotoProvider with ChangeNotifier {
  final PhotoService _photoService;

  // State
  List<PhotoModel> _photos = [];
  List<PhotoModel> _searchResults = [];
  List<PhotoModel> _onThisDayPhotos = [];

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isUploading = false;
  bool _hasMore = true;

  double _uploadProgress = 0.0;
  String? _error;
  String? _currentBabyId;

  DocumentSnapshot? _lastDocument;
  StreamSubscription? _photosSubscription;

  // Getters
  List<PhotoModel> get photos => _photos;
  List<PhotoModel> get searchResults => _searchResults;
  List<PhotoModel> get onThisDayPhotos => _onThisDayPhotos;

  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isUploading => _isUploading;
  bool get hasMore => _hasMore;

  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  String? get currentBabyId => _currentBabyId;

  PhotoProvider({PhotoService? photoService})
      : _photoService = photoService ?? PhotoService();

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize provider for a specific baby
  void initialize(String babyId) {
    if (_currentBabyId == babyId) return;

    _currentBabyId = babyId;
    _photos = [];
    _searchResults = [];
    _onThisDayPhotos = [];
    _lastDocument = null;
    _hasMore = true;
    _error = null;

    loadPhotos();
    loadOnThisDayPhotos();
  }

  /// Subscribe to real-time photo updates
  void subscribeToPhotos(String babyId) {
    _photosSubscription?.cancel();

    _photosSubscription = _photoService.streamPhotos(babyId, limit: 50).listen(
      (photos) {
        _photos = photos;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
        debugPrint('PhotoProvider: Stream error: $error');
      },
    );
  }

  // ============================================================
  // LOAD OPERATIONS
  // ============================================================

  /// Load initial photos
  Future<void> loadPhotos() async {
    if (_currentBabyId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _photos = await _photoService.getPhotos(
        _currentBabyId!,
        limit: 20,
      );
      _hasMore = _photos.length >= 20;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('PhotoProvider: Failed to load photos: $e');
    }
  }

  /// Load more photos (pagination)
  Future<void> loadMorePhotos() async {
    if (_currentBabyId == null || _isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final morePhotos = await _photoService.getPhotos(
        _currentBabyId!,
        limit: 20,
        startAfter: _lastDocument,
      );

      _photos.addAll(morePhotos);
      _hasMore = morePhotos.length >= 20;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load "On This Day" photos
  Future<void> loadOnThisDayPhotos() async {
    if (_currentBabyId == null) return;

    try {
      _onThisDayPhotos =
          await _photoService.getOnThisDayPhotos(_currentBabyId!);
      notifyListeners();
    } catch (e) {
      debugPrint('PhotoProvider: Failed to load On This Day photos: $e');
    }
  }

  /// Refresh all photos
  Future<void> refresh() async {
    _photos = [];
    _lastDocument = null;
    _hasMore = true;
    await loadPhotos();
    await loadOnThisDayPhotos();
  }

  // ============================================================
  // UPLOAD OPERATIONS
  // ============================================================

  /// Upload a new photo
  Future<PhotoModel?> uploadPhoto({
    required String babyId,
    required String userId,
    required File photoFile,
    String? caption,
    List<String>? tags,
    PhotoDataContext? dataContext,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final photo = await _photoService.uploadPhoto(
        babyId: babyId,
        userId: userId,
        photoFile: photoFile,
        caption: caption,
        manualTags: tags,
        dataContext: dataContext,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      // Add to local list immediately
      _photos.insert(0, photo);

      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();

      return photo;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('PhotoProvider: Upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // SEARCH OPERATIONS
  // ============================================================

  /// Search photos with filters
  Future<void> searchPhotos({
    List<String>? tags,
    String? mood,
    String? activity,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? people,
  }) async {
    if (_currentBabyId == null) return;

    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _photoService.searchPhotos(
        _currentBabyId!,
        tags: tags,
        mood: mood,
        activity: activity,
        startDate: startDate,
        endDate: endDate,
        people: people,
      );
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // ============================================================
  // UPDATE OPERATIONS
  // ============================================================

  /// Update photo caption and tags
  Future<void> updatePhoto(
    String photoId, {
    String? caption,
    List<String>? tags,
  }) async {
    if (_currentBabyId == null) return;

    try {
      await _photoService.updatePhoto(
        _currentBabyId!,
        photoId,
        caption: caption,
        manualTags: tags,
      );

      // Update local state
      final index = _photos.indexWhere((p) => p.id == photoId);
      if (index != -1) {
        _photos[index] = _photos[index].copyWith(
          caption: caption,
          manualTags: tags,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Toggle like on photo
  Future<void> toggleLike(String photoId, String userId) async {
    if (_currentBabyId == null) return;

    try {
      final isLiked = await _photoService.toggleLike(
        _currentBabyId!,
        photoId,
        userId,
      );

      // Update local state optimistically
      final index = _photos.indexWhere((p) => p.id == photoId);
      if (index != -1) {
        final photo = _photos[index];
        final updatedLikedBy = isLiked
            ? [...photo.likedBy, userId]
            : photo.likedBy.where((id) => id != userId).toList();

        _photos[index] = photo.copyWith(likedBy: updatedLikedBy);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PhotoProvider: Failed to toggle like: $e');
    }
  }

  /// Increment view count when photo is viewed
  Future<void> incrementViewCount(String photoId) async {
    if (_currentBabyId == null) return;

    try {
      await _photoService.incrementViewCount(_currentBabyId!, photoId);
    } catch (e) {
      debugPrint('PhotoProvider: Failed to increment view count: $e');
    }
  }

  // ============================================================
  // DELETE OPERATIONS
  // ============================================================

  /// Archive (soft delete) photo
  Future<void> archivePhoto(String photoId) async {
    if (_currentBabyId == null) return;

    try {
      await _photoService.archivePhoto(_currentBabyId!, photoId);

      // Remove from local list
      _photos.removeWhere((p) => p.id == photoId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Restore archived photo
  Future<void> restorePhoto(String photoId) async {
    if (_currentBabyId == null) return;

    try {
      await _photoService.restorePhoto(_currentBabyId!, photoId);
      // Refresh to get the restored photo
      await loadPhotos();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Permanently delete photo
  Future<void> deletePhoto(String photoId) async {
    if (_currentBabyId == null) return;

    try {
      await _photoService.deletePhoto(_currentBabyId!, photoId);

      // Remove from local list
      _photos.removeWhere((p) => p.id == photoId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get photo by ID from local cache
  PhotoModel? getPhotoById(String photoId) {
    try {
      return _photos.firstWhere((p) => p.id == photoId);
    } catch (e) {
      return null;
    }
  }

  /// Get photos grouped by date
  Map<DateTime, List<PhotoModel>> get photosGroupedByDate {
    final grouped = <DateTime, List<PhotoModel>>{};

    for (final photo in _photos) {
      final date = DateTime(
        photo.capturedAt.year,
        photo.capturedAt.month,
        photo.capturedAt.day,
      );

      grouped.putIfAbsent(date, () => []).add(photo);
    }

    return grouped;
  }

  /// Get photos grouped by month
  Map<String, List<PhotoModel>> get photosGroupedByMonth {
    final grouped = <String, List<PhotoModel>>{};

    for (final photo in _photos) {
      final key =
          '${photo.capturedAt.year}-${photo.capturedAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(photo);
    }

    return grouped;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _photosSubscription?.cancel();
    super.dispose();
  }
}
