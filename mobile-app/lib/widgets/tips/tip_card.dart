import 'package:flutter/material.dart';
import '../../models/tip_model.dart';
import '../../theme/design_tokens.dart';

/// Card widget for displaying a parenting tip
/// Shows tip content with category, priority, and user feedback options
class TipCard extends StatelessWidget {
  final TipModel tip;
  final bool isDismissed;
  final bool? isHelpful;
  final VoidCallback? onMarkHelpful;
  final VoidCallback? onMarkNotHelpful;
  final VoidCallback? onDismiss;
  final VoidCallback? onUndismiss;
  final VoidCallback? onTap;

  const TipCard({
    super.key,
    required this.tip,
    this.isDismissed = false,
    this.isHelpful,
    this.onMarkHelpful,
    this.onMarkNotHelpful,
    this.onDismiss,
    this.onUndismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      elevation: 0,
      color: isDismissed
          ? DesignTokens.neutralGray50.withOpacity(0.5)
          : DesignTokens.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(
          color: isDismissed
              ? DesignTokens.neutralGray200
              : _getPriorityBorderColor(),
          width: isDismissed ? 1 : 2,
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
              // Header row with category, priority, and dismiss button
              Row(
                children: [
                  // Category badge
                  _buildCategoryBadge(),
                  const SizedBox(width: DesignTokens.spaceXs),
                  // Priority indicator (only for high/urgent)
                  if (tip.priority == TipPriority.high ||
                      tip.priority == TipPriority.urgent)
                    _buildPriorityBadge(),
                  const Spacer(),
                  // Dismiss/Undismiss button
                  if (!isDismissed && onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: DesignTokens.textSecondary,
                      onPressed: onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Dismiss',
                    )
                  else if (isDismissed && onUndismiss != null)
                    TextButton.icon(
                      onPressed: onUndismiss,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Restore'),
                      style: TextButton.styleFrom(
                        foregroundColor: DesignTokens.primaryTeal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceXs,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: DesignTokens.spaceSm),

              // Title
              Text(
                tip.title,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeLg,
                  fontWeight: DesignTokens.fontWeightSemiBold,
                  color: isDismissed
                      ? DesignTokens.textSecondary
                      : DesignTokens.textPrimary,
                  decoration: isDismissed ? TextDecoration.lineThrough : null,
                ),
              ),

              const SizedBox(height: DesignTokens.spaceXs),

              // Content
              Text(
                tip.content,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: isDismissed
                      ? DesignTokens.textTertiary
                      : DesignTokens.textSecondary,
                  height: 1.5,
                ),
              ),

              // Tags
              if (tip.tags.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Wrap(
                  spacing: DesignTokens.spaceXs,
                  runSpacing: DesignTokens.spaceXs,
                  children: tip.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.neutralGray100,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm),
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
                ),
              ],

              // Source URL
              if (tip.sourceUrl != null) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 14,
                      color: DesignTokens.primaryTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Learn more',
                      style: const TextStyle(
                        fontSize: DesignTokens.fontSizeXs,
                        color: DesignTokens.primaryTeal,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],

              // Feedback buttons (if not dismissed)
              if (!isDismissed &&
                  (onMarkHelpful != null || onMarkNotHelpful != null)) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                const Divider(height: 1),
                const SizedBox(height: DesignTokens.spaceXs),
                _buildFeedbackSection(),
              ],

              // AI Generated indicator
              if (tip.isAiGenerated) ...[
                const SizedBox(height: DesignTokens.spaceXs),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: DesignTokens.accentPurple.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Generated',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXs,
                        color: DesignTokens.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceXs,
        vertical: 2,
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
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            tip.category.displayName,
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

  Widget _buildPriorityBadge() {
    final color = tip.priority == TipPriority.urgent
        ? DesignTokens.statusCritical
        : DesignTokens.statusWarning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tip.priority == TipPriority.urgent
                ? Icons.priority_high
                : Icons.info_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            tip.priority.displayName,
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

  Widget _buildFeedbackSection() {
    return Row(
      children: [
        Text(
          'Was this helpful?',
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeSm,
            color: DesignTokens.textSecondary,
          ),
        ),
        const Spacer(),
        // Thumbs up
        IconButton(
          icon: Icon(
            isHelpful == true ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 20,
          ),
          color: isHelpful == true
              ? DesignTokens.statusHealthy
              : DesignTokens.textSecondary,
          onPressed: onMarkHelpful,
          tooltip: 'Helpful',
        ),
        // Thumbs down
        IconButton(
          icon: Icon(
            isHelpful == false ? Icons.thumb_down : Icons.thumb_down_outlined,
            size: 20,
          ),
          color: isHelpful == false
              ? DesignTokens.statusCritical
              : DesignTokens.textSecondary,
          onPressed: onMarkNotHelpful,
          tooltip: 'Not helpful',
        ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (tip.category) {
      case TipCategory.sleep:
        return DesignTokens.statusSleeping;
      case TipCategory.feeding:
        return DesignTokens.accentGreen;
      case TipCategory.health:
        return DesignTokens.statusCritical;
      case TipCategory.safety:
        return DesignTokens.statusWarning;
      case TipCategory.development:
        return DesignTokens.accentPurple;
      case TipCategory.behavior:
        return DesignTokens.accentBlue;
      case TipCategory.care:
        return DesignTokens.accentPink;
      case TipCategory.bonding:
        return DesignTokens.accentYellow;
      case TipCategory.general:
        return DesignTokens.neutralGray400;
    }
  }

  String _getCategoryIcon() {
    return tip.category.icon;
  }

  Color _getPriorityBorderColor() {
    switch (tip.priority) {
      case TipPriority.urgent:
        return DesignTokens.statusCritical;
      case TipPriority.high:
        return DesignTokens.statusWarning;
      case TipPriority.normal:
      case TipPriority.low:
        return DesignTokens.neutralGray200;
    }
  }
}
