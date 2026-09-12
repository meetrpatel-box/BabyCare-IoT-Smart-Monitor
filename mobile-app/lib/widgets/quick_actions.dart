import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Quick action buttons for dashboard
class QuickActions extends StatelessWidget {
  final VoidCallback? onAIInsights;
  final VoidCallback? onSleepAnalysis;
  final VoidCallback? onAddDevice;
  final VoidCallback? onVideoCall;

  const QuickActions({
    super.key,
    this.onAIInsights,
    this.onSleepAnalysis,
    this.onAddDevice,
    this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.lightbulb_outline,
            label: 'AI Insights',
            color: AppColors.primary,
            onTap: onAIInsights,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.bedtime_outlined,
            label: 'Sleep',
            color: AppColors.sleepDeep,
            onTap: onSleepAnalysis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.add_circle_outline,
            label: 'Device',
            color: AppColors.info,
            onTap: onAddDevice,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
