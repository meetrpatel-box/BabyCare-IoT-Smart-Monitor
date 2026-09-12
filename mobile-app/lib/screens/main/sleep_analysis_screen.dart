import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/baby_provider.dart';
import '../../models/sleep_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// Sleep Analysis screen
/// Ported from React Native SleepAnalysisScreen.tsx
class SleepAnalysisScreen extends StatefulWidget {
  const SleepAnalysisScreen({super.key});

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen> {
  List<SleepSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final babyProvider = context.read<BabyProvider>();
    final sessions = await babyProvider.getSleepSessions(
      startDate: DateTime.now().subtract(const Duration(days: 7)),
    );

    setState(() {
      // If no data, show sample data for demonstration
      _sessions = sessions.isEmpty ? _generateSampleData() : sessions;
      _isLoading = false;
    });
  }

  /// Generate sample sleep data for demonstration when database is empty
  List<SleepSession> _generateSampleData() {
    final now = DateTime.now();
    final sessions = <SleepSession>[];

    for (int i = 0; i < 7; i++) {
      // Night sleep
      final nightStart = DateTime(
        now.year,
        now.month,
        now.day - i,
        22,
        0,
      );
      final nightEnd = nightStart.add(const Duration(hours: 8));

      sessions.add(SleepSession(
        id: 'sample_night_$i',
        babyId: 'sample',
        startTime: nightStart,
        endTime: nightEnd,
        totalMinutes: 480,
        stages: [
          SleepStage(
            stage: SleepStageType.light,
            durationMinutes: 120,
            startTime: nightStart,
            endTime: nightStart.add(const Duration(minutes: 120)),
          ),
          SleepStage(
            stage: SleepStageType.deep,
            durationMinutes: 200,
            startTime: nightStart.add(const Duration(minutes: 120)),
            endTime: nightStart.add(const Duration(minutes: 320)),
          ),
          SleepStage(
            stage: SleepStageType.rem,
            durationMinutes: 120,
            startTime: nightStart.add(const Duration(minutes: 320)),
            endTime: nightStart.add(const Duration(minutes: 440)),
          ),
          SleepStage(
            stage: SleepStageType.awake,
            durationMinutes: 40,
            startTime: nightStart.add(const Duration(minutes: 440)),
            endTime: nightEnd,
          ),
        ],
        quality: i % 2 == 0 ? SleepQuality.excellent : SleepQuality.good,
        wakeCount: i % 3,
        createdAt: nightEnd,
      ));

      // Morning nap
      final napStart = DateTime(
        now.year,
        now.month,
        now.day - i,
        10,
        0,
      );
      final napEnd = napStart.add(const Duration(minutes: 90));

      sessions.add(SleepSession(
        id: 'sample_nap_$i',
        babyId: 'sample',
        startTime: napStart,
        endTime: napEnd,
        totalMinutes: 90,
        stages: [
          SleepStage(
            stage: SleepStageType.light,
            durationMinutes: 50,
            startTime: napStart,
            endTime: napStart.add(const Duration(minutes: 50)),
          ),
          SleepStage(
            stage: SleepStageType.deep,
            durationMinutes: 40,
            startTime: napStart.add(const Duration(minutes: 50)),
            endTime: napEnd,
          ),
        ],
        quality: SleepQuality.good,
        wakeCount: 0,
        createdAt: napEnd,
      ));
    }

    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Sleep Analysis'),
        leading: const SmartCloseButton(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sleep Score Card (NEW)
                    _buildSleepScoreCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // Summary Card
                    _buildSummaryCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // Sleep Stages Chart
                    Text(
                      'Sleep Stages Distribution',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSleepStagesChart(),

                    const SizedBox(height: AppSpacing.xl),

                    // Recent Sessions
                    Text(
                      'Recent Sleep Sessions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSessionsList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build sleep score card with prominent score display
  Widget _buildSleepScoreCard() {
    if (_sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate average sleep score from sessions
    // Score factors: duration (40%), wake count (30%), stages (30%)
    double totalScore = 0;
    for (var session in _sessions) {
      double score = 0;

      // Duration score (40 points) - 7-8 hours is optimal
      final hours = session.duration.inMinutes / 60;
      if (hours >= 7 && hours <= 9) {
        score += 40;
      } else if (hours >= 6 && hours < 7) {
        score += 30;
      } else if (hours >= 5 && hours < 6) {
        score += 20;
      } else {
        score += 10;
      }

      // Wake count score (30 points) - 0-1 wakes is optimal
      final wakes = session.wakeCount ?? 0;
      if (wakes == 0) {
        score += 30;
      } else if (wakes == 1) {
        score += 25;
      } else if (wakes == 2) {
        score += 15;
      } else {
        score += 5;
      }

      // Stage quality score (30 points) - balanced stages
      if (session.quality == SleepQuality.excellent) {
        score += 30;
      } else if (session.quality == SleepQuality.good) {
        score += 20;
      } else if (session.quality == SleepQuality.fair) {
        score += 10;
      }

      totalScore += score;
    }

    final avgScore = (totalScore / _sessions.length).round();

    // Determine color and status
    Color scoreColor;
    String scoreLabel;
    if (avgScore >= 80) {
      scoreColor = DesignTokens.statusHealthy;
      scoreLabel = 'Excellent';
    } else if (avgScore >= 60) {
      scoreColor = DesignTokens.statusWarning;
      scoreLabel = 'Good';
    } else {
      scoreColor = DesignTokens.statusCritical;
      scoreLabel = 'Needs Attention';
    }

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scoreColor.withOpacity(0.1),
              scoreColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep Quality Score',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Based on ${_sessions.length} sessions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Circular score display
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scoreColor,
                        width: 4,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$avgScore',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/100',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DesignTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      avgScore >= 80 ? Icons.check_circle : Icons.info_outline,
                      color: scoreColor,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Calculate averages
    final totalMinutes = _sessions.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMinutes,
    );
    final avgHours = _sessions.isNotEmpty
        ? (totalMinutes / _sessions.length / 60).toStringAsFixed(1)
        : '0';

    final totalWakes = _sessions.fold<int>(
      0,
      (sum, s) => sum + (s.wakeCount ?? 0),
    );
    final avgWakes = _sessions.isNotEmpty
        ? (totalWakes / _sessions.length).toStringAsFixed(1)
        : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 Days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Duration',
                    '${avgHours}h',
                    Icons.bedtime,
                    AppColors.sleepDeep,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Sessions',
                    '${_sessions.length}',
                    Icons.nights_stay,
                    AppColors.sleepLight,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Wake-ups',
                    avgWakes,
                    Icons.wb_sunny,
                    AppColors.sleepAwake,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSleepStagesChart() {
    // Aggregate all stages
    int deepMinutes = 0;
    int lightMinutes = 0;
    int remMinutes = 0;
    int awakeMinutes = 0;

    for (final session in _sessions) {
      for (final stage in session.stages) {
        switch (stage.stage) {
          case SleepStageType.deep:
            deepMinutes += stage.durationMinutes;
            break;
          case SleepStageType.light:
            lightMinutes += stage.durationMinutes;
            break;
          case SleepStageType.rem:
            remMinutes += stage.durationMinutes;
            break;
          case SleepStageType.awake:
            awakeMinutes += stage.durationMinutes;
            break;
        }
      }
    }

    final total = deepMinutes + lightMinutes + remMinutes + awakeMinutes;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'No sleep stage data available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: deepMinutes.toDouble(),
                      color: AppColors.sleepDeep,
                      title: '${(deepMinutes / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: lightMinutes.toDouble(),
                      color: AppColors.sleepLight,
                      title: '${(lightMinutes / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: remMinutes.toDouble(),
                      color: AppColors.sleepREM,
                      title: '${(remMinutes / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    PieChartSectionData(
                      value: awakeMinutes.toDouble(),
                      color: AppColors.sleepAwake,
                      title: '${(awakeMinutes / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Deep', AppColors.sleepDeep),
                _buildLegendItem('Light', AppColors.sleepLight),
                _buildLegendItem('REM', AppColors.sleepREM),
                _buildLegendItem('Awake', AppColors.sleepAwake),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSessionsList() {
    if (_sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Text(
              'No sleep sessions recorded',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _sessions.take(5).map((session) {
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.sleepDeep.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.bedtime, color: AppColors.sleepDeep),
            ),
            title: Text(session.durationDisplay),
            subtitle: Text(
              _formatDateTime(session.startTime),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: session.quality != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _getQualityColor(session.quality!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      session.quality!.value,
                      style: TextStyle(
                        color: _getQualityColor(session.quality!),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getQualityColor(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.excellent:
        return AppColors.success;
      case SleepQuality.good:
        return AppColors.primary;
      case SleepQuality.fair:
        return AppColors.warning;
      case SleepQuality.poor:
        return AppColors.error;
    }
  }
}
