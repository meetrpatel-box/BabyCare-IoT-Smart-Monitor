import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/photo_model.dart';

/// Service for managing baby photos in Firebase
///
/// Handles:
/// - Photo upload to Firebase Storage
/// - Photo metadata in Firestore
/// - Real-time photo streaming
/// - Search and filtering
/// - Like/comment engagement
class PhotoService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Collection reference for photos subcollection
  CollectionReference<Map<String, dynamic>> _photosCollection(String babyId) {
    return _firestore.collection('babies').doc(babyId).collection('photos');
  }

  // ============================================================
  // UPLOAD OPERATIONS
  // ============================================================

  /// Upload a photo with automatic thumbnail generation
  ///
  /// Returns the created PhotoModel on success
  Future<PhotoModel> uploadPhoto({
    required String babyId,
    required String userId,
    required File photoFile,
    String? caption,
    List<String>? manualTags,
    PhotoDataContext? dataContext,
    DateTime? capturedAt,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(photoFile.path).toLowerCase();
      final fileName = '$timestamp$extension';
      final storagePath = 'photos/$babyId/$fileName';

      // Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        photoFile,
        SettableMetadata(
          contentType: _getContentType(extension),
          customMetadata: {
            'uploadedBy': userId,
            'babyId': babyId,
          },
        ),
      );

      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final photoUrl = await snapshot.ref.getDownloadURL();

      // Generate thumbnail URL (same as photo for now)
      // TODO: Implement Cloud Function for thumbnail generation
      final thumbnailUrl = photoUrl;

      // Create photo document in Firestore
      final photoDoc = _photosCollection(babyId).doc();
      final now = DateTime.now();

      final photo = PhotoModel(
        id: photoDoc.id,
        babyId: babyId,
        uploadedBy: userId,
        photoUrl: photoUrl,
        thumbnailUrl: thumbnailUrl,
        capturedAt: capturedAt ?? now,
        uploadedAt: now,
        aiTags: AIPhotoTags.empty(),
        dataContext: dataContext,
        caption: caption,
        manualTags: manualTags ?? [],
      );

      await photoDoc.set(photo.toFirestore());

      debugPrint('PhotoService: Uploaded photo ${photo.id} for baby $babyId');

      // Trigger AI tagging in background (async)
      _triggerAITagging(babyId, photo.id, photoUrl);

      return photo;
    } catch (e) {
      debugPrint('PhotoService: Upload failed: $e');
      throw PhotoServiceException('Failed to upload photo: $e');
    }
  }

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Trigger AI tagging via Cloud Function (placeholder)
  Future<void> _triggerAITagging(
      String babyId, String photoId, String photoUrl) async {
    // TODO: Call Cloud Function to analyze image with ML
    // This would update the aiTags field with detected:
    // - Mood (happy, calm, crying, sleeping, alert)
    // - Activity (feeding, playing, sleeping, bath, tummy_time)
    // - People (mom, dad, grandma, sibling)
    debugPrint('PhotoService: AI tagging triggered for photo $photoId');
  }

  // ============================================================
  // READ OPERATIONS
  // ============================================================

  /// Stream photos for a baby (real-time updates)
  Stream<List<PhotoModel>> streamPhotos(
    String babyId, {
    int limit = 50,
    bool includeArchived = false,
  }) {
    Query<Map<String, dynamic>> query = _photosCollection(babyId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final photos =
          snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
      // Sort manually to avoid index requirement
      photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return photos;
    });
  }

  /// Get photos with pagination support
  Future<List<PhotoModel>> getPhotos(
    String babyId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool includeArchived = false,
  }) async {
    Query<Map<String, dynamic>> query = _photosCollection(babyId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final photos =
        snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
    // Sort manually to avoid index requirement
    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return photos;
  }

  /// Get a single photo by ID
  Future<PhotoModel?> getPhoto(String babyId, String photoId) async {
    final doc = await _photosCollection(babyId).doc(photoId).get();
    if (!doc.exists) return null;
    return PhotoModel.fromFirestore(doc);
  }

  /// Stream photos by album
  Stream<List<PhotoModel>> streamPhotosByAlbum(String babyId, String albumId) {
    return _photosCollection(babyId)
        .where('albumIds', arrayContains: albumId)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final photos =
          snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();
      // Sort manually to avoid index requirement
      photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return photos;
    });
  }

  // ============================================================
  // SEARCH & FILTER OPERATIONS
  // ============================================================

  /// Search photos with filters
  Future<List<PhotoModel>> searchPhotos(
    String babyId, {
    List<String>? tags,
    String? mood,
    String? activity,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? people,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query =
        _photosCollection(babyId).where('isArchived', isEqualTo: false);

    // Filter by manual tags
    if (tags != null && tags.isNotEmpty) {
      query = query.where('manualTags', arrayContainsAny: tags);
    }

    // Filter by date range
    if (startDate != null) {
      query = query.where('capturedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('capturedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    var photos =
        snapshot.docs.map((doc) => PhotoModel.fromFirestore(doc)).toList();

    // Sort manually to avoid index requirement
    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    // Client-side filtering for AI tags (Firestore limitations with nested fields)
    if (mood != null) {
      photos = photos.where((p) => p.aiTags.mood == mood).toList();
    }

    if (activity != null) {
      photos = photos.where((p) => p.aiTags.activity == activity).toList();
    }

    if (people != null && people.isNotEmpty) {
      photos = photos
          .where(
              (p) => people.any((person) => p.aiTags.people.contains(person)))
          .toList();
    }

    return photos;
  }

  /// Get photos from "On This Day" (same date, previous years)
  Future<List<PhotoModel>> getOnThisDayPhotos(String babyId) async {
    final now = DateTime.now();
    final photos = <PhotoModel>[];

    // Check last 3 years
    for (int yearsAgo = 1; yearsAgo <= 3; yearsAgo++) {
      final targetDate = DateTime(now.year - yearsAgo, now.month, now.day);
      final startOfDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(
          targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final dayPhotos = await searchPhotos(
        babyId,
        startDate: startOfDay,
        endDate: endOfDay,
        limit: 10,
      );
      photos.addAll(dayPhotos);
    }

    return photos;
  }

  /// Get photos by date range for recap generation
  Future<List<PhotoModel>> getPhotosForDateRange(
    String babyId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return searchPhotos(
      babyId,
      startDate: startDate,
      endDate: endDate,
      limit: 100,
    );
  }

  // ============================================================
  // UPDATE OPERATIONS
  // ============================================================

  /// Update photo metadata
  Future<void> updatePhoto(
    String babyId,
    String photoId, {
    String? caption,
    List<String>? manualTags,
    List<String>? albumIds,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};

    if (caption != null) updates['caption'] = caption;
    if (manualTags != null) updates['manualTags'] = manualTags;
    if (albumIds != null) updates['albumIds'] = albumIds;
    if (isPublic != null) updates['isPublic'] = isPublic;

    if (updates.isEmpty) return;

    await _photosCollection(babyId).doc(photoId).update(updates);
    debugPrint('PhotoService: Updated photo $photoId');
  }

  /// Update AI tags (called by Cloud Function after ML processing)
  Future<void> updateAITags(
    String babyId,
    String photoId,
    AIPhotoTags aiTags,
  ) async {
    await _photosCollection(babyId).doc(photoId).update({
      'aiTags': aiTags.toMap(),
    });
    debugPrint('PhotoService: Updated AI tags for photo $photoId');
  }

  /// Add photo to album
  Future<void> addToAlbum(String babyId, String photoId, String albumId) async {
    await _photosCollection(babyId).doc(photoId).update({
      'albumIds': FieldValue.arrayUnion([albumId]),
    });
  }

  /// Remove photo from album
  Future<void> removeFromAlbum(
      String babyId, String photoId, String albumId) async {
    await _photosCollection(babyId).doc(photoId).update({
      'albumIds': FieldValue.arrayRemove([albumId]),
    });
  }

  // ============================================================
  // ENGAGEMENT OPERATIONS
  // ============================================================

  /// Increment view count
  Future<void> incrementViewCount(String babyId, String photoId) async {
    await _photosCollection(babyId).doc(photoId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Toggle like on photo
  Future<bool> toggleLike(String babyId, String photoId, String userId) async {
    final photoRef = _photosCollection(babyId).doc(photoId);
    final doc = await photoRef.get();

    if (!doc.exists) {
      throw PhotoServiceException('Photo not found');
    }

    final photo = PhotoModel.fromFirestore(doc);
    final isLiked = photo.likedBy.contains(userId);

    if (isLiked) {
      await photoRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
      });
      return false;
    } else {
      await photoRef.update({
        'likedBy': FieldValue.arrayUnion([userId]),
      });
      return true;
    }
  }

  /// Share photo with family members
  Future<void> sharePhoto(
    String babyId,
    String photoId,
    List<String> userIds,
  ) async {
    await _photosCollection(babyId).doc(photoId).update({
      'sharedWith': FieldValue.arrayUnion(userIds),
    });
    debugPrint(
        'PhotoService: Shared photo $photoId with ${userIds.length} users');
  }

  /// Unshare photo from users
  Future<void> unsharePhoto(
    String babyId,
    String photoId,
    List<String> userIds,
  ) async {
    await _photosCollection(babyId).doc(photoId).update({
      'sharedWith': FieldValue.arrayRemove(userIds),
    });
  }

  // ============================================================
  // DELETE OPERATIONS
  // ============================================================

  /// Soft delete (archive) photo
  Future<void> archivePhoto(String babyId, String photoId) async {
    await _photosCollection(babyId).doc(photoId).update({
      'isArchived': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('PhotoService: Archived photo $photoId');
  }

  /// Restore archived photo
  Future<void> restorePhoto(String babyId, String photoId) async {
    await _photosCollection(babyId).doc(photoId).update({
      'isArchived': false,
      'deletedAt': null,
    });
    debugPrint('PhotoService: Restored photo $photoId');
  }

  /// Permanently delete photo (also removes from Storage)
  Future<void> deletePhoto(String babyId, String photoId) async {
    try {
      // Get photo to find storage path
      final photo = await getPhoto(babyId, photoId);
      if (photo == null) return;

      // Delete from Storage
      try {
        final ref = _storage.refFromURL(photo.photoUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('PhotoService: Failed to delete from storage: $e');
        // Continue even if storage deletion fails
      }

      // Delete thumbnail if different
      if (photo.thumbnailUrl != photo.photoUrl) {
        try {
          final thumbRef = _storage.refFromURL(photo.thumbnailUrl);
          await thumbRef.delete();
        } catch (e) {
          debugPrint('PhotoService: Failed to delete thumbnail: $e');
        }
      }

      // Delete Firestore document
      await _photosCollection(babyId).doc(photoId).delete();
      debugPrint('PhotoService: Permanently deleted photo $photoId');
    } catch (e) {
      throw PhotoServiceException('Failed to delete photo: $e');
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Get photo count for baby
  Future<int> getPhotoCount(String babyId,
      {bool includeArchived = false}) async {
    Query<Map<String, dynamic>> query = _photosCollection(babyId);

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  /// Get photos stats (for weekly recap)
  Future<Map<String, dynamic>> getPhotosStats(
    String babyId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final photos = await getPhotosForDateRange(
      babyId,
      startDate: startDate,
      endDate: endDate,
    );

    // Count moods
    final moodCounts = <String, int>{};
    final activityCounts = <String, int>{};

    for (final photo in photos) {
      final mood = photo.aiTags.mood;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;

      final activity = photo.aiTags.activity;
      activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
    }

    return {
      'totalPhotos': photos.length,
      'moodCounts': moodCounts,
      'activityCounts': activityCounts,
      'mostCommonMood': moodCounts.entries.isEmpty
          ? null
          : moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key,
      'mostCommonActivity': activityCounts.entries.isEmpty
          ? null
          : activityCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
    };
  }
}

/// Exception for PhotoService errors
class PhotoServiceException implements Exception {
  final String message;
  PhotoServiceException(this.message);

  @override
  String toString() => 'PhotoServiceException: $message';
}
