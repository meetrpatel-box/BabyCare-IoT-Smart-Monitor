import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/milestone_model.dart';
import '../../theme/design_tokens.dart';

/// Card widget for displaying a milestone
/// Shows milestone achievement with photo, category, and details
class MilestoneCard extends StatelessWidget {
  final MilestoneModel milestone;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MilestoneCard({
    super.key,
    required this.milestone,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      elevation: 0,
      color: DesignTokens.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(
          color: DesignTokens.neutralGray200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with category and date
              Row(
                children: [
                  // Category icon and badge
                  _buildCategoryBadge(),
                  const Spacer(),
                  // Age indicator
                  _buildAgeIndicator(),
                  // More menu
                  if (onEdit != null || onDelete != null)
                    _buildMoreMenu(context),
                ],
              ),

              const SizedBox(height: DesignTokens.spaceSm),

              // Title
              Text(
                milestone.title,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeLg,
                  fontWeight: DesignTokens.fontWeightSemiBold,
                  color: DesignTokens.textPrimary,
                ),
              ),

              // Description
              if (milestone.description != null &&
                  milestone.description!.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceXs),
                Text(
                  milestone.description!,
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: DesignTokens.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: DesignTokens.spaceMd),

              // Photo preview (if available)
              if (milestone.photoUrls.isNotEmpty) _buildPhotoPreview(),

              // Notes (if available)
              if (milestone.notes != null && milestone.notes!.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                _buildNotesSection(),
              ],

              const SizedBox(height: DesignTokens.spaceSm),

              // Footer with achievement date
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: _getCategoryColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getCategoryIcon(),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          Text(
            milestone.category.displayName,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              fontWeight: DesignTokens.fontWeightMedium,
              color: _getCategoryColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeIndicator() {
    final ageText = milestone.ageInMonths == 0
        ? 'Newborn'
        : milestone.ageInMonths == 1
            ? '1 month'
            : '${milestone.ageInMonths} months';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.neutralGray100,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        ageText,
        style: const TextStyle(
          fontSize: DesignTokens.fontSizeXs,
          fontWeight: DesignTokens.fontWeightMedium,
          color: DesignTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: DesignTokens.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) {
          onEdit!();
        } else if (value == 'delete' && onDelete != null) {
          onDelete!();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18, color: DesignTokens.textSecondary),
                SizedBox(width: DesignTokens.spaceXs),
                Text('Edit'),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete,
                    size: 18, color: DesignTokens.statusCritical),
                SizedBox(width: DesignTokens.spaceXs),
                Text('Delete',
                    style: TextStyle(color: DesignTokens.statusCritical)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    final photoUrl = milestone.photoUrls.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: DesignTokens.neutralGray100,
            child: const Icon(
              Icons.photo,
              size: 48,
              color: DesignTokens.neutralGray400,
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: DesignTokens.neutralGray100,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    DesignTokens.primaryTeal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.accentYellow.withOpacity(0.05),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(
          color: DesignTokens.accentYellow.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: DesignTokens.accentYellow.withOpacity(0.8),
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          Expanded(
            child: Text(
              milestone.notes!,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: DesignTokens.textPrimary.withOpacity(0.8),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Row(
      children: [
        Icon(
          Icons.check_circle,
          size: 16,
          color: DesignTokens.statusHealthy.withOpacity(0.6),
        ),
        const SizedBox(width: DesignTokens.spaceXs),
        Text(
          'Achieved on ${dateFormat.format(milestone.achievedDate)}',
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXs,
            color: DesignTokens.textTertiary,
          ),
        ),
        if (milestone.photoUrls.length > 1) ...[
          const Spacer(),
          Icon(
            Icons.photo_library,
            size: 14,
            color: DesignTokens.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            '${milestone.photoUrls.length}',
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              color: DesignTokens.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Color _getCategoryColor() {
    switch (milestone.category) {
      case MilestoneCategory.physical:
        return DesignTokens.accentBlue;
      case MilestoneCategory.cognitive:
        return DesignTokens.accentPurple;
      case MilestoneCategory.language:
        return DesignTokens.primaryTeal;
      case MilestoneCategory.social:
        return DesignTokens.accentPink;
      case MilestoneCategory.emotional:
        return DesignTokens.accentYellow;
      case MilestoneCategory.feeding:
        return DesignTokens.accentGreen;
      case MilestoneCategory.sleep:
        return DesignTokens.statusSleeping;
      case MilestoneCategory.other:
        return DesignTokens.neutralGray400;
    }
  }

  String _getCategoryIcon() {
    switch (milestone.category) {
      case MilestoneCategory.physical:
        return '💪';
      case MilestoneCategory.cognitive:
        return '🧠';
      case MilestoneCategory.language:
        return '💬';
      case MilestoneCategory.social:
        return '👥';
      case MilestoneCategory.emotional:
        return '❤️';
      case MilestoneCategory.feeding:
        return '🍼';
      case MilestoneCategory.sleep:
        return '😴';
      case MilestoneCategory.other:
        return '⭐';
    }
  }
}
