import 'package:flutter/material.dart';
import '../../models/colic_pattern_model.dart';
import '../../services/colic_pattern_service.dart';
import '../../theme/design_tokens.dart';

/// Colic analytics screen showing pattern detection results and trends.
///
/// Displays Wessel's criteria tracking, daily crying duration chart,
/// weekly summaries, risk level, and actionable suggestions.
class ColicAnalyticsScreen extends StatefulWidget {
  final String babyId;
  final String babyName;

  const ColicAnalyticsScreen({
    super.key,
    required this.babyId,
    required this.babyName,
  });

  @override
  State<ColicAnalyticsScreen> createState() => _ColicAnalyticsScreenState();
}

class _ColicAnalyticsScreenState extends State<ColicAnalyticsScreen> {
  late final ColicPatternService _service;
  ColicPatternResult? _result;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ColicPatternService();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    setState(() => _isLoading = true);

    try {
      final result = await _service.getLatestAnalysis(widget.babyId);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isAnalyzing = true);

    try {
      final result = await _service.runAnalysis(widget.babyId);
      if (mounted) {
        setState(() {
          _result = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: Text('${widget.babyName} — Colic Analysis'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLatest,
              child: _result == null ? _buildNoDataState() : _buildContent(),
            ),
    );
  }

  Widget _buildNoDataState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.query_stats,
                  size: 48, color: DesignTokens.textMuted),
              const SizedBox(height: DesignTokens.spaceLg),
              const Text(
                'No colic analysis yet',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeLg,
                  color: DesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              const Text(
                'Run an analysis to check for colic patterns',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: DesignTokens.textMuted,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXl),
              _buildAnalyzeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final r = _result!;
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      children: [
        _buildRiskCard(r),
        const SizedBox(height: DesignTokens.spaceLg),
        _buildWesselTracker(r),
        const SizedBox(height: DesignTokens.spaceLg),
        _buildDailyChart(r),
        const SizedBox(height: DesignTokens.spaceLg),
        _buildWeeklySummaries(r),
        const SizedBox(height: DesignTokens.spaceLg),
        _buildSuggestions(r),
        const SizedBox(height: DesignTokens.spaceLg),
        Center(child: _buildAnalyzeButton()),
        const SizedBox(height: DesignTokens.spaceXl),
      ],
    );
  }

  // ========== Risk Level Card ==========

  Widget _buildRiskCard(ColicPatternResult r) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXl),
      decoration: BoxDecoration(
        color: _riskBgColor(r.riskLevel),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: [DesignTokens.shadowMd],
      ),
      child: Column(
        children: [
          Icon(
            _riskIcon(r.riskLevel),
            size: 40,
            color: _riskColor(r.riskLevel),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            r.riskLevel.label,
            style: TextStyle(
              fontSize: DesignTokens.fontSize2xl,
              fontWeight: DesignTokens.fontWeightBold,
              color: _riskColor(r.riskLevel),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            'Risk Score: ${r.riskScore}/100',
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeMd,
              color: DesignTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          // Risk score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
            child: LinearProgressIndicator(
              value: r.riskScore / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                  _riskColor(r.riskLevel)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRiskStat('Streak', '${r.currentStreak}d'),
              _buildRiskStat('Longest', '${r.longestStreak}d'),
              _buildRiskStat('Wessel Weeks', '${r.wesselWeeksCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXl,
            fontWeight: DesignTokens.fontWeightBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXs,
            color: DesignTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  // ========== Wessel's Criteria Tracker ==========

  Widget _buildWesselTracker(ColicPatternResult r) {
    final last7 = r.dailyAnalysis.length >= 7
        ? r.dailyAnalysis.sublist(r.dailyAnalysis.length - 7)
        : r.dailyAnalysis;
    final daysOverThreshold = last7.where((d) => d.meetsThreshold).length;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        boxShadow: [DesignTokens.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist, size: 20, color: DesignTokens.accentPurple),
              SizedBox(width: DesignTokens.spaceSm),
              Text(
                "Wessel's Criteria",
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          const Text(
            'Crying 3+ hours/day, 3+ days/week, for 3+ weeks',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              color: DesignTokens.textMuted,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          _buildCriteriaRow(
            '3+ hours/day',
            daysOverThreshold > 0,
            '$daysOverThreshold of last 7 days',
          ),
          _buildCriteriaRow(
            '3+ days/week',
            daysOverThreshold >= 3,
            daysOverThreshold >= 3 ? 'Met' : 'Not met',
          ),
          _buildCriteriaRow(
            '3+ weeks',
            r.wesselWeeksCount >= 3,
            '${r.wesselWeeksCount} week(s)',
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaRow(String label, bool met, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: met ? DesignTokens.statusWarning : DesignTokens.textMuted,
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeMd,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              color: met ? DesignTokens.statusWarning : DesignTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Daily Chart ==========

  Widget _buildDailyChart(ColicPatternResult r) {
    final days = r.dailyAnalysis;
    if (days.isEmpty) return const SizedBox.shrink();

    final maxMinutes = days
        .map((d) => d.totalCryingMinutes)
        .reduce((a, b) => a > b ? a : b);
    final chartMax = (maxMinutes > 180 ? maxMinutes : 180).toDouble();

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        boxShadow: [DesignTokens.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: DesignTokens.accentBlue),
              SizedBox(width: DesignTokens.spaceSm),
              Text(
                'Daily Crying Duration',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${chartMax.round()}m',
                          style: _axisLabelStyle),
                      Text('${(chartMax / 2).round()}m',
                          style: _axisLabelStyle),
                      Text('0', style: _axisLabelStyle),
                    ],
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceXs),
                // Bars
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((day) {
                      final ratio = chartMax > 0
                          ? day.totalCryingMinutes / chartMax
                          : 0.0;
                      final isOverThreshold = day.meetsThreshold;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: ratio.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isOverThreshold
                                          ? DesignTokens.statusWarning
                                          : DesignTokens.primaryTeal,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          // Threshold line label
          Row(
            children: [
              const SizedBox(width: 34),
              Container(
                width: 12,
                height: 3,
                color: DesignTokens.statusWarning,
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              const Text(
                '3-hour threshold',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  color: DesignTokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle get _axisLabelStyle => const TextStyle(
        fontSize: 9,
        color: DesignTokens.textMuted,
      );

  // ========== Weekly Summaries ==========

  Widget _buildWeeklySummaries(ColicPatternResult r) {
    if (r.weeklySummaries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        boxShadow: [DesignTokens.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_view_week,
                  size: 20, color: DesignTokens.accentGreen),
              SizedBox(width: DesignTokens.spaceSm),
              Text(
                'Weekly Summary',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ...r.weeklySummaries.map((week) => _buildWeekRow(week)),
        ],
      ),
    );
  }

  Widget _buildWeekRow(ColicWeekSummary week) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: week.meetsWessel
              ? DesignTokens.bgWarning
              : DesignTokens.surfaceGray,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: Row(
          children: [
            Icon(
              week.meetsWessel ? Icons.warning_amber : Icons.check,
              size: 18,
              color: week.meetsWessel
                  ? DesignTokens.statusWarning
                  : DesignTokens.statusHealthy,
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week of ${week.weekStart}',
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeMd,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  Text(
                    '${week.daysOverThreshold} days over threshold  |  '
                    'Avg: ${week.avgDailyCryingMinutes}m/day',
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Suggestions ==========

  Widget _buildSuggestions(ColicPatternResult r) {
    if (r.suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: r.riskLevel == ColicRiskLevel.none
            ? DesignTokens.bgHealthy
            : DesignTokens.bgWarning,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: r.riskLevel == ColicRiskLevel.none
                    ? DesignTokens.statusHealthy
                    : DesignTokens.statusWarning,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              const Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          ...r.suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('  •  ',
                        style: TextStyle(color: DesignTokens.textSecondary)),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeMd,
                          color: DesignTokens.textSecondary,
                          height: DesignTokens.lineHeightNormal,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ========== Analyze Button ==========

  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: _isAnalyzing ? null : _runAnalysis,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.analytics, size: 20),
      label: Text(_isAnalyzing ? 'Analyzing...' : 'Run Analysis'),
      style: ElevatedButton.styleFrom(
        backgroundColor: DesignTokens.primaryTeal,
        foregroundColor: DesignTokens.textOnPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceXl,
          vertical: DesignTokens.spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
      ),
    );
  }

  // ========== Risk Level Helpers ==========

  Color _riskColor(ColicRiskLevel level) {
    switch (level) {
      case ColicRiskLevel.none:
        return DesignTokens.statusHealthy;
      case ColicRiskLevel.mild:
        return DesignTokens.accentYellow;
      case ColicRiskLevel.moderate:
        return DesignTokens.statusWarning;
      case ColicRiskLevel.severe:
        return DesignTokens.statusCritical;
    }
  }

  Color _riskBgColor(ColicRiskLevel level) {
    switch (level) {
      case ColicRiskLevel.none:
        return DesignTokens.bgHealthy;
      case ColicRiskLevel.mild:
        return DesignTokens.bgAwake;
      case ColicRiskLevel.moderate:
        return DesignTokens.bgWarning;
      case ColicRiskLevel.severe:
        return DesignTokens.bgCritical;
    }
  }

  IconData _riskIcon(ColicRiskLevel level) {
    switch (level) {
      case ColicRiskLevel.none:
        return Icons.sentiment_satisfied;
      case ColicRiskLevel.mild:
        return Icons.sentiment_neutral;
      case ColicRiskLevel.moderate:
        return Icons.sentiment_dissatisfied;
      case ColicRiskLevel.severe:
        return Icons.warning_amber;
    }
  }
}
