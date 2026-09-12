import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/baby_provider.dart';
import '../../models/sleep_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// Trends and analytics screen
/// Ported from React Native TrendsScreen.tsx
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String _selectedPeriod = '7d';
  List<VitalLog> _vitalLogs = [];
  List<SleepSession> _sleepSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final babyProvider = context.read<BabyProvider>();
    if (babyProvider.selectedBaby == null) {
      setState(() => _isLoading = false);
      return;
    }

    final days =
        _selectedPeriod == '7d' ? 7 : (_selectedPeriod == '30d' ? 30 : 90);
    final startDate = DateTime.now().subtract(Duration(days: days));

    final vitals = await babyProvider.getVitalLogs(startDate: startDate);
    final sleep = await babyProvider.getSleepSessions(startDate: startDate);

    setState(() {
      _vitalLogs = vitals;
      _sleepSessions = sleep;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Trends'),
        actions: [
          // Period selector
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7d', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90d', child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    _selectedPeriod == '7d'
                        ? '7 days'
                        : (_selectedPeriod == '30d' ? '30 days' : '90 days'),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
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
                    // Heart Rate Chart
                    _buildChartCard(
                      title: 'Heart Rate',
                      subtitle: 'Average over time',
                      chart: _buildHeartRateChart(),
                      icon: Icons.favorite,
                      color: AppColors.error,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // SpO2 Chart
                    _buildChartCard(
                      title: 'Blood Oxygen (SpO2)',
                      subtitle: 'Saturation levels',
                      chart: _buildSpO2Chart(),
                      icon: Icons.air,
                      color: AppColors.info,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Sleep Duration Chart
                    _buildChartCard(
                      title: 'Sleep Duration',
                      subtitle: 'Hours per day',
                      chart: _buildSleepChart(),
                      icon: Icons.bedtime,
                      color: AppColors.sleepDeep,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Statistics summary
                    _buildStatsSummary(),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget chart,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateChart() {
    if (_vitalLogs.isEmpty) {
      return _buildEmptyChart('No heart rate data');
    }

    final spots = _vitalLogs
        .where((v) => v.heartRate != null)
        .map((v) => FlSpot(
              v.timestamp.millisecondsSinceEpoch.toDouble(),
              v.heartRate!.toDouble(),
            ))
        .toList();

    if (spots.isEmpty) {
      return _buildEmptyChart('No heart rate data');
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.error,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.error.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpO2Chart() {
    if (_vitalLogs.isEmpty) {
      return _buildEmptyChart('No SpO2 data');
    }

    final spots = _vitalLogs
        .where((v) => v.spO2 != null)
        .map((v) => FlSpot(
              v.timestamp.millisecondsSinceEpoch.toDouble(),
              v.spO2!.toDouble(),
            ))
        .toList();

    if (spots.isEmpty) {
      return _buildEmptyChart('No SpO2 data');
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 90,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.info,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.info.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepChart() {
    if (_sleepSessions.isEmpty) {
      return _buildEmptyChart('No sleep data');
    }

    // Group by day and sum hours
    final dailySleep = <DateTime, double>{};
    for (final session in _sleepSessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      final hours = session.duration.inMinutes / 60.0;
      dailySleep[day] = (dailySleep[day] ?? 0) + hours;
    }

    final sortedDays = dailySleep.keys.toList()..sort();
    final bars = sortedDays.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: dailySleep[entry.value]!,
            color: AppColors.sleepDeep,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    if (bars.isEmpty) {
      return _buildEmptyChart('No sleep data');
    }

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: bars,
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildStatsSummary() {
    // Calculate averages
    final heartRates =
        _vitalLogs.where((v) => v.heartRate != null).map((v) => v.heartRate!);
    final avgHeartRate = heartRates.isNotEmpty
        ? (heartRates.reduce((a, b) => a + b) / heartRates.length).round()
        : null;

    final spO2Values =
        _vitalLogs.where((v) => v.spO2 != null).map((v) => v.spO2!);
    final avgSpO2 = spO2Values.isNotEmpty
        ? (spO2Values.reduce((a, b) => a + b) / spO2Values.length).round()
        : null;

    final totalSleepMinutes = _sleepSessions.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMinutes,
    );
    final avgSleepHours = _sleepSessions.isNotEmpty
        ? (totalSleepMinutes / _sleepSessions.length / 60).toStringAsFixed(1)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _buildStatItem(
                  'Avg Heart Rate',
                  avgHeartRate != null ? '$avgHeartRate BPM' : '--',
                  Icons.favorite,
                  AppColors.error,
                ),
                _buildStatItem(
                  'Avg SpO2',
                  avgSpO2 != null ? '$avgSpO2%' : '--',
                  Icons.air,
                  AppColors.info,
                ),
                _buildStatItem(
                  'Avg Sleep',
                  avgSleepHours != null ? '${avgSleepHours}h' : '--',
                  Icons.bedtime,
                  AppColors.sleepDeep,
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
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
      ),
    );
  }
}
