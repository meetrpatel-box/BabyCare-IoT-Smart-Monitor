import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/baby_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// Analysis and statistics screen
/// Ported from React Native AnalysisScreen.tsx
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Analysis'),
      ),
      body: Consumer<BabyProvider>(
        builder: (context, babyProvider, child) {
          if (babyProvider.selectedBaby == null) {
            return const Center(
              child: Text('No baby selected'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health Score
                _buildHealthScoreCard(context),

                const SizedBox(height: AppSpacing.lg),

                // Daily Insights
                Text(
                  'Daily Insights',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInsightsList(context),

                const SizedBox(height: AppSpacing.lg),

                // Patterns Detected
                Text(
                  'Patterns Detected',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildPatternsList(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthScoreCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              'Health Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: 0.85,
                    strokeWidth: 12,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '85',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                    ),
                    Text(
                      'Excellent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Based on sleep quality, vital signs, and activity patterns',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsList(BuildContext context) {
    final insights = [
      {
        'icon': Icons.bedtime,
        'title': 'Sleep Pattern',
        'description': 'Baby is sleeping 2 hours more than last week',
        'color': AppColors.sleepDeep,
      },
      {
        'icon': Icons.favorite,
        'title': 'Heart Rate',
        'description': 'Consistent and within normal range',
        'color': AppColors.error,
      },
      {
        'icon': Icons.air,
        'title': 'Oxygen Levels',
        'description': 'SpO2 has been stable at 98%',
        'color': AppColors.info,
      },
    ];

    return Column(
      children: insights
          .map((insight) => _buildInsightItem(
                context,
                icon: insight['icon'] as IconData,
                title: insight['title'] as String,
                description: insight['description'] as String,
                color: insight['color'] as Color,
              ))
          .toList(),
    );
  }

  Widget _buildInsightItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildPatternsList(BuildContext context) {
    final patterns = [
      {
        'title': 'Longest sleep at night',
        'value': '6-8 hours',
        'trend': 'up',
      },
      {
        'title': 'Most active time',
        'value': '9-11 AM',
        'trend': 'stable',
      },
      {
        'title': 'Feeding correlation',
        'value': 'Strong',
        'trend': 'up',
      },
    ];

    return Card(
      child: Column(
        children: patterns
            .map((pattern) => ListTile(
                  title: Text(pattern['title'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pattern['value'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        pattern['trend'] == 'up'
                            ? Icons.trending_up
                            : (pattern['trend'] == 'down'
                                ? Icons.trending_down
                                : Icons.trending_flat),
                        color: pattern['trend'] == 'up'
                            ? AppColors.success
                            : (pattern['trend'] == 'down'
                                ? AppColors.error
                                : AppColors.textMuted),
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
