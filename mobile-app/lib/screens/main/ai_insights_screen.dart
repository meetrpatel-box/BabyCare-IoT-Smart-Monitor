import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/baby_provider.dart';
import '../../models/ai_insight_model.dart';
import '../../services/ai_insights_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// AI Insights screen
/// Ported from React Native AIInsightsScreen.tsx
class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  final AIInsightsService _insightsService = AIInsightsService();
  List<AIInsight> _insights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    final babyProvider = context.read<BabyProvider>();
    if (babyProvider.selectedBaby == null) {
      setState(() => _isLoading = false);
      return;
    }

    final insights =
        await _insightsService.getAIInsights(babyProvider.selectedBaby!.id);

    setState(() {
      _insights = insights;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(AIInsight insight) async {
    if (!insight.isRead) {
      await _insightsService.markInsightAsRead(insight.id);
      setState(() {
        final index = _insights.indexWhere((i) => i.id == insight.id);
        if (index >= 0) {
          _insights[index] = insight.copyWith(isRead: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('AI Insights'),
        leading: const SmartCloseButton(),
        actions: [
          if (_insights.any((i) => !i.isRead))
            TextButton(
              onPressed: () async {
                final babyProvider = context.read<BabyProvider>();
                if (babyProvider.selectedBaby != null) {
                  await _insightsService
                      .markAllInsightsAsRead(babyProvider.selectedBaby!.id);
                  _loadInsights();
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _insights.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadInsights,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _insights.length,
                    itemBuilder: (context, index) {
                      final insight = _insights[index];
                      return _buildInsightCard(insight);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No insights yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'AI insights will appear here as we analyze your baby\'s data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(AIInsight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _markAsRead(insight),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getInsightColor(insight).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      _getInsightIcon(insight),
                      color: _getInsightColor(insight),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                insight.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: insight.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (!insight.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          insight.type.displayName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _getInsightColor(insight),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                insight.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              // Recommendations
              if (insight.recommendations != null &&
                  insight.recommendations!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...insight.recommendations!.map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            rec,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Priority badge
              if (insight.isHighPriority) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(insight.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 14,
                        color: _getPriorityColor(insight.priority),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        insight.priority == InsightPriority.critical
                            ? 'Critical'
                            : 'High Priority',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getPriorityColor(insight.priority),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getInsightIcon(AIInsight insight) {
    switch (insight.type) {
      case InsightType.sleepPattern:
        return Icons.bedtime;
      case InsightType.healthAlert:
        return Icons.warning_amber;
      case InsightType.recommendation:
        return Icons.lightbulb_outline;
      case InsightType.milestone:
        return Icons.emoji_events;
      case InsightType.trend:
        return Icons.trending_up;
    }
  }

  Color _getInsightColor(AIInsight insight) {
    switch (insight.type) {
      case InsightType.sleepPattern:
        return AppColors.sleepDeep;
      case InsightType.healthAlert:
        return AppColors.warning;
      case InsightType.recommendation:
        return AppColors.primary;
      case InsightType.milestone:
        return AppColors.success;
      case InsightType.trend:
        return AppColors.info;
    }
  }

  Color _getPriorityColor(InsightPriority priority) {
    switch (priority) {
      case InsightPriority.critical:
        return AppColors.error;
      case InsightPriority.high:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}
