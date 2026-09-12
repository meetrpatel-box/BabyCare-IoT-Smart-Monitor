import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// Goals tracking screen
/// Ported from React Native GoalsScreen.tsx
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add new goal
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Progress
            Text(
              'Today\'s Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildProgressCard(context),

            const SizedBox(height: AppSpacing.xl),

            // Active Goals
            Text(
              'Active Goals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildGoalsList(context),

            const SizedBox(height: AppSpacing.xl),

            // Completed Goals
            Text(
              'Completed Today',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildCompletedGoals(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '4 of 6 goals completed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text(
                    '67%',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: 0.67,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsList(BuildContext context) {
    final goals = [
      {
        'title': 'Sleep Duration',
        'target': '14 hours',
        'current': '10 hours',
        'progress': 0.71,
        'icon': Icons.bedtime,
        'color': AppColors.sleepDeep,
      },
      {
        'title': 'Tummy Time',
        'target': '30 min',
        'current': '15 min',
        'progress': 0.5,
        'icon': Icons.timer,
        'color': AppColors.primary,
      },
    ];

    return Column(
      children: goals
          .map((goal) => _buildGoalItem(
                context,
                title: goal['title'] as String,
                target: goal['target'] as String,
                current: goal['current'] as String,
                progress: goal['progress'] as double,
                icon: goal['icon'] as IconData,
                color: goal['color'] as Color,
              ))
          .toList(),
    );
  }

  Widget _buildGoalItem(
    BuildContext context, {
    required String title,
    required String target,
    required String current,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$current / $target',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedGoals(BuildContext context) {
    final completed = [
      {'title': 'Feeding', 'times': '8 times', 'icon': Icons.restaurant},
      {'title': 'Diaper Change', 'times': '6 times', 'icon': Icons.child_care},
      {'title': 'Bath Time', 'times': '1 time', 'icon': Icons.bathtub},
      {
        'title': 'Medicine',
        'times': 'Completed',
        'icon': Icons.medical_services
      },
    ];

    return Card(
      child: Column(
        children: completed
            .map((goal) => ListTile(
                  leading: Icon(
                    goal['icon'] as IconData,
                    color: AppColors.success,
                  ),
                  title: Text(goal['title'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        goal['times'] as String,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
