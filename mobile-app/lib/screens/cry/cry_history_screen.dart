import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cry_event_model.dart';
import '../../services/cry_detection_service.dart';
import '../../theme/design_tokens.dart';

/// Cry history timeline screen.
///
/// Shows past cry events with classification, duration, resolution,
/// and analytics summary (total cries, avg duration, peak hours).
class CryHistoryScreen extends StatefulWidget {
  final String babyId;
  final String babyName;

  const CryHistoryScreen({
    super.key,
    required this.babyId,
    required this.babyName,
  });

  @override
  State<CryHistoryScreen> createState() => _CryHistoryScreenState();
}

class _CryHistoryScreenState extends State<CryHistoryScreen> {
  late final CryDetectionService _service;
  int _selectedDays = 7;
  CryAnalytics? _analytics;
  List<CryEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = CryDetectionService(firestore: FirebaseFirestore.instance);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: _selectedDays));

      final results = await Future.wait([
        _service.getCryEventsInRange(widget.babyId, start, now),
        _service.getCryAnalytics(widget.babyId, _selectedDays),
      ]);

      if (mounted) {
        setState(() {
          _events = results[0] as List<CryEvent>;
          _analytics = results[1] as CryAnalytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: Text('${widget.babyName} — Cry History'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Period selector
                  SliverToBoxAdapter(child: _buildPeriodSelector()),
                  // Analytics summary
                  if (_analytics != null)
                    SliverToBoxAdapter(child: _buildAnalyticsSummary()),
                  // Insights
                  if (_analytics != null && _analytics!.insights.isNotEmpty)
                    SliverToBoxAdapter(child: _buildInsights()),
                  // Event list header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignTokens.spaceLg,
                        DesignTokens.spaceXl,
                        DesignTokens.spaceLg,
                        DesignTokens.spaceSm,
                      ),
                      child: Text(
                        '${_events.length} events',
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeSm,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                          color: DesignTokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                  // Event list
                  _events.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildEventCard(_events[index]),
                            childCount: _events.length,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      child: Row(
        children: [1, 7, 14, 30].map((days) {
          final isSelected = _selectedDays == days;
          return Padding(
            padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
            child: ChoiceChip(
              label: Text(days == 1 ? 'Today' : '${days}d'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedDays = days);
                  _loadData();
                }
              },
              selectedColor: DesignTokens.primaryLight,
              labelStyle: TextStyle(
                color: isSelected
                    ? DesignTokens.primaryDark
                    : DesignTokens.textSecondary,
                fontWeight: isSelected
                    ? DesignTokens.fontWeightSemiBold
                    : DesignTokens.fontWeightRegular,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    final a = _analytics!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLg),
      child: Row(
        children: [
          _buildStatCard('Total', '${a.totalCries}', Icons.timeline),
          const SizedBox(width: DesignTokens.spaceSm),
          _buildStatCard(
            'Avg Duration',
            _formatDuration(a.avgDuration),
            Icons.timer,
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          _buildStatCard(
            'Peak Hour',
            a.peakHours.isNotEmpty ? '${a.peakHours.first}:00' : '-',
            Icons.schedule,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          boxShadow: [DesignTokens.shadowSm],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: DesignTokens.primaryTeal),
            const SizedBox(height: DesignTokens.spaceXs),
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
                color: DesignTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        decoration: BoxDecoration(
          color: DesignTokens.bgInfo,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, size: 18, color: DesignTokens.accentBlue),
                SizedBox(width: DesignTokens.spaceSm),
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeMd,
                    fontWeight: DesignTokens.fontWeightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            ..._analytics!.insights.map((insight) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: DesignTokens.spaceXs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('  •  ',
                          style: TextStyle(color: DesignTokens.textSecondary)),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
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
      ),
    );
  }

  Widget _buildEventCard(CryEvent event) {
    final classification = event.classification;
    final source = event.classificationSource;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLg,
        vertical: DesignTokens.spaceXs,
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          boxShadow: [DesignTokens.shadowSm],
        ),
        child: Row(
          children: [
            // Classification icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _classificationBgColor(classification),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Icon(
                _classificationIcon(classification),
                size: 22,
                color: _classificationColor(classification),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        classification.label,
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeMd,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      Text(
                        _formatTime(event.startTime),
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: DesignTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (event.durationSeconds != null)
                        _buildMiniTag(
                          _formatDuration(event.durationSeconds!),
                          Icons.timer,
                        ),
                      if (event.intensity != null)
                        _buildMiniTag(
                          '${(event.intensity! * 100).round()}%',
                          Icons.graphic_eq,
                        ),
                      _buildMiniTag(
                        source.name,
                        source == ClassificationSource.parentCorrected
                            ? Icons.person
                            : source == ClassificationSource.cloud
                                ? Icons.cloud
                                : Icons.bluetooth,
                      ),
                      if (event.resolution != null)
                        _buildMiniTag(
                          event.resolution!.label,
                          Icons.check_circle_outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: DesignTokens.spaceXs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceGray,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: DesignTokens.textMuted),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: DesignTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sentiment_satisfied,
              size: 48, color: DesignTokens.textMuted),
          const SizedBox(height: DesignTokens.spaceLg),
          const Text(
            'No cry events in this period',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeLg,
              color: DesignTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Helpers ----

  IconData _classificationIcon(CryClassification c) {
    switch (c) {
      case CryClassification.hungry: return Icons.restaurant;
      case CryClassification.tired: return Icons.bedtime;
      case CryClassification.pain: return Icons.healing;
      case CryClassification.discomfort: return Icons.thermostat;
      case CryClassification.gassy: return Icons.air;
      case CryClassification.attention: return Icons.favorite;
      case CryClassification.overstimulated: return Icons.volume_off;
      case CryClassification.colic: return Icons.waves;
      case CryClassification.unknown: return Icons.help_outline;
    }
  }

  Color _classificationColor(CryClassification c) {
    switch (c) {
      case CryClassification.pain: return DesignTokens.statusCritical;
      case CryClassification.colic: return DesignTokens.statusWarning;
      case CryClassification.unknown: return DesignTokens.textMuted;
      default: return DesignTokens.primaryTeal;
    }
  }

  Color _classificationBgColor(CryClassification c) {
    switch (c) {
      case CryClassification.pain: return DesignTokens.bgCritical;
      case CryClassification.colic: return DesignTokens.bgWarning;
      case CryClassification.unknown: return DesignTokens.surfaceGray;
      default: return DesignTokens.primaryLight.withOpacity(0.2);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return sec > 0 ? '${min}m ${sec}s' : '${min}m';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);

    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (eventDay == today) return time;
    if (eventDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    }
    return '${dt.month}/${dt.day} $time';
  }
}
