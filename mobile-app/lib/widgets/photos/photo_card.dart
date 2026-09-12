import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/photo_model.dart';
import '../../theme/design_tokens.dart';

/// Photo card widget with data context overlay
///
/// Displays a photo with:
/// - Thumbnail image
/// - Caption (if available)
/// - Data context card (vitals at time of capture)
/// - AI tags (mood, activity)
/// - Engagement stats (likes, comments)
class PhotoCard extends StatelessWidget {
  final PhotoModel photo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String userId)? onLike;
  final String? currentUserId;
  final bool showDataContext;
  final bool showEngagement;
  final bool compact;

  const PhotoCard({
    super.key,
    required this.photo,
    this.onTap,
    this.onLongPress,
    this.onLike,
    this.currentUserId,
    this.showDataContext = true,
    this.showEngagement = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          boxShadow: [DesignTokens.shadowSm],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo image
            _buildImage(),

            // Caption and data context
            if (!compact) ...[
              if (photo.caption != null && photo.caption!.isNotEmpty)
                _buildCaption(),

              if (showDataContext &&
                  photo.dataContext != null &&
                  photo.dataContext!.hasData)
                _buildDataContext(),

              // Tags and engagement
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTags(),
                    if (showEngagement) ...[
                      const SizedBox(height: DesignTokens.spaceSm),
                      _buildEngagement(),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the photo image with loading/error states
  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: compact ? 1.0 : 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          CachedNetworkImage(
            imageUrl: photo.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: DesignTokens.neutralGray100,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.primaryTeal,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: DesignTokens.neutralGray100,
              child: const Icon(
                Icons.broken_image_outlined,
                color: DesignTokens.neutralGray400,
                size: 40,
              ),
            ),
          ),

          // Mood emoji overlay (top right)
          if (photo.aiTags.isProcessed)
            Positioned(
              top: DesignTokens.spaceSm,
              right: DesignTokens.spaceSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                  vertical: DesignTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Text(
                  photo.aiTags.moodEmoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

          // Time ago (bottom left)
          Positioned(
            bottom: DesignTokens.spaceSm,
            left: DesignTokens.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceSm,
                vertical: DesignTokens.spaceXs,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Text(
                photo.timeSinceCapture,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: DesignTokens.fontSizeXs,
                  fontWeight: DesignTokens.fontWeightMedium,
                ),
              ),
            ),
          ),

          // Sleeping indicator (if sleeping)
          if (photo.dataContext?.isSleeping == true)
            Positioned(
              bottom: DesignTokens.spaceSm,
              right: DesignTokens.spaceSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                  vertical: DesignTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.statusSleeping.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('😴', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      photo.dataContext!.sleepDurationFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: DesignTokens.fontSizeXs,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build caption text
  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        0,
      ),
      child: Text(
        photo.caption!,
        style: const TextStyle(
          fontSize: DesignTokens.fontSizeMd,
          fontWeight: DesignTokens.fontWeightMedium,
          color: DesignTokens.textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Build data context card showing vitals at time of capture
  Widget _buildDataContext() {
    final context = photo.dataContext!;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        0,
      ),
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: DesignTokens.backgroundWarm,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: DesignTokens.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 16,
                color: DesignTokens.primaryTeal,
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              Text(
                'Vitals at Capture',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  fontWeight: DesignTokens.fontWeightSemiBold,
                  color: DesignTokens.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          // Vitals row
          Wrap(
            spacing: DesignTokens.spaceMd,
            runSpacing: DesignTokens.spaceSm,
            children: [
              if (context.heartRate != null)
                _buildVitalChip(
                  icon: Icons.favorite,
                  value: '${context.heartRate} bpm',
                  status: context.heartRateStatus,
                  color: _getHeartRateColor(context.heartRate!),
                ),
              if (context.temperature != null)
                _buildVitalChip(
                  icon: Icons.thermostat,
                  value: '${context.temperature!.toStringAsFixed(1)}°F',
                  status: context.temperatureStatus,
                  color: _getTemperatureColor(context.temperature!),
                ),
              if (context.spO2 != null)
                _buildVitalChip(
                  icon: Icons.air,
                  value: '${context.spO2}%',
                  status: context.spO2Status,
                  color: _getSpO2Color(context.spO2!),
                ),
              if (context.sleepScore != null)
                _buildVitalChip(
                  icon: Icons.bedtime,
                  value: '${context.sleepScore}/100',
                  status: context.sleepScoreRating,
                  color: _getSleepScoreColor(context.sleepScore!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a single vital chip
  Widget _buildVitalChip({
    required IconData icon,
    required String value,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build tags display
  Widget _buildTags() {
    final allTags = <String>[
      if (photo.aiTags.isProcessed) ...[
        photo.aiTags.mood,
        photo.aiTags.activity,
      ],
      ...photo.manualTags,
    ];

    if (allTags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DesignTokens.spaceXs,
      runSpacing: DesignTokens.spaceXs,
      children: allTags.take(5).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSm,
            vertical: DesignTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.neutralGray100,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          child: Text(
            '#$tag',
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              color: DesignTokens.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build engagement section (likes, comments)
  Widget _buildEngagement() {
    final isLiked = currentUserId != null && photo.isLikedBy(currentUserId!);

    return Row(
      children: [
        // Like button
        GestureDetector(
          onTap: () {
            if (onLike != null && currentUserId != null) {
              onLike!(currentUserId!);
            }
          },
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isLiked
                    ? DesignTokens.statusCritical
                    : DesignTokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${photo.likedBy.length}',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: isLiked
                      ? DesignTokens.statusCritical
                      : DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: DesignTokens.spaceMd),

        // Comments
        Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: DesignTokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '${photo.commentsCount}',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Views
        Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              '${photo.viewCount}',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: DesignTokens.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // COLOR HELPERS
  // ============================================================

  Color _getHeartRateColor(int heartRate) {
    if (heartRate < 100) return DesignTokens.statusHealthy;
    if (heartRate < 140) return DesignTokens.statusHealthy;
    if (heartRate < 160) return DesignTokens.statusAwake;
    return DesignTokens.statusWarning;
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 97.0) return DesignTokens.statusWarning;
    if (temp <= 99.5) return DesignTokens.statusHealthy;
    if (temp <= 100.4) return DesignTokens.statusWarning;
    return DesignTokens.statusCritical;
  }

  Color _getSpO2Color(int spO2) {
    if (spO2 >= 95) return DesignTokens.statusHealthy;
    if (spO2 >= 90) return DesignTokens.statusWarning;
    return DesignTokens.statusCritical;
  }

  Color _getSleepScoreColor(int score) {
    if (score >= 90) return DesignTokens.statusHealthy;
    if (score >= 75) return DesignTokens.statusHealthy;
    if (score >= 60) return DesignTokens.statusWarning;
    return DesignTokens.statusCritical;
  }
}

/// Compact photo grid item for album views
class PhotoGridItem extends StatelessWidget {
  final PhotoModel photo;
  final VoidCallback? onTap;

  const PhotoGridItem({
    super.key,
    required this.photo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: photo.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: DesignTokens.neutralGray100,
            ),
            errorWidget: (context, url, error) => Container(
              color: DesignTokens.neutralGray100,
              child: const Icon(
                Icons.broken_image_outlined,
                color: DesignTokens.neutralGray400,
              ),
            ),
          ),

          // Mood indicator
          if (photo.aiTags.isProcessed)
            Positioned(
              top: 4,
              right: 4,
              child: Text(
                photo.aiTags.moodEmoji,
                style: const TextStyle(fontSize: 14),
              ),
            ),

          // Multiple photos indicator (for albums)
          if (photo.albumIds.isNotEmpty)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.collections,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
