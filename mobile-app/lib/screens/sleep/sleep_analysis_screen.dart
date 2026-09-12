import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/sleep_analysis_service.dart';
import '../../models/sleep_data_model.dart';
import '../../widgets/charts/sleep_timeline_chart.dart';
import '../../widgets/charts/sleep_quality_chart.dart';
import '../../widgets/feature_gate.dart';
import '../../theme/app_colors.dart';

/// Sleep Analysis Dashboard
/// Shows detailed sleep analytics from device data
class SleepAnalysisScreen extends StatefulWidget {
  final String babyId;

  const SleepAnalysisScreen({
    super.key,
    required this.babyId,
  });

  @override
  State<SleepAnalysisScreen> createState() => _SleepAnalysisScreenState();
}

class _SleepAnalysisScreenState extends State<SleepAnalysisScreen> {
  final SleepAnalysisService _sleepService = SleepAnalysisService();
  
  DateTime _selectedDate = DateTime.now();
  SleepSession? _selectedSession;
  List<SleepSession> _recentSessions = [];
  SleepStatistics? _weeklyStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load recent sessions (last 7 days)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));
      
      final sessions = await _sleepService.getSleepSessions(
        widget.babyId,
        startDate: startDate,
        endDate: endDate,
      );

      // Load weekly statistics
      final stats = await _sleepService.getStatistics(
        widget.babyId,
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _recentSessions = sessions;
        _weeklyStats = stats;
        if (sessions.isNotEmpty) {
          _selectedSession = sessions.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sleep data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: 'sleep_analysis',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sleep Analysis'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Weekly Summary Card
                      _buildWeeklySummaryCard(),
                      
                      const SizedBox(height: 16),
                      
                      // Quality Trend Chart
                      if (_recentSessions.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: SleepQualityChart(sessions: _recentSessions),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Session List
                      _buildSessionList(),
                      
                      const SizedBox(height: 16),
                      
                      // Selected Session Details
                      if (_selectedSession != null)
                        _buildSessionDetails(_selectedSession!),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    if (_weeklyStats == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Last 7 Days Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Sleep',
                    _formatDuration(_weeklyStats!.avgSleepDuration),
                    Icons.bedtime,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Quality',
                    '${_weeklyStats!.avgQualityScore.toInt()}/100',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Awakenings',
                    '${_weeklyStats!.totalAwakenings}',
                    Icons.notifications_active,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Sessions',
                    '${_weeklyStats!.totalSessions}',
                    Icons.nightlight_round,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Sleep Stage Distribution',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStageDistribution(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageDistribution() {
    if (_weeklyStats == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildStageBar(
          'Light Sleep',
          _weeklyStats!.lightSleepPercentage,
          Colors.blue[200]!,
        ),
        const SizedBox(height: 8),
        _buildStageBar(
          'Deep Sleep',
          _weeklyStats!.deepSleepPercentage,
          Colors.indigo[600]!,
        ),
        const SizedBox(height: 8),
        _buildStageBar(
          'REM Sleep',
          _weeklyStats!.remSleepPercentage,
          Colors.purple[400]!,
        ),
      ],
    );
  }

  Widget _buildStageBar(String label, double percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${percentage.toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionList() {
    if (_recentSessions.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.bedtime_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No sleep sessions yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sleep data will appear here once your Anavaya device starts monitoring',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent Sleep Sessions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentSessions.length,
          itemBuilder: (context, index) {
            final session = _recentSessions[index];
            final isSelected = _selectedSession?.id == session.id;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: session.qualityScore != null
                      ? Color(int.parse(session.getQualityColor().substring(1), radix: 16) + 0xFF000000)
                      : Colors.grey,
                  child: Text(
                    session.qualityScore?.toInt().toString() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(session.startTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Duration: ${_formatDuration(session.totalDuration)}'),
                    if (session.qualityScore != null)
                      Text('Quality: ${session.getQualityRating()}'),
                    if (!session.hasDeviceData)
                      const Text(
                        'Manual entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedSession = session;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionDetails(SleepSession session) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nights_stay, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (session.qualityScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(int.parse(session.getQualityColor().substring(1), radix: 16) + 0xFF000000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      session.getQualityRating(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Session info
            _buildDetailRow('Start Time', DateFormat('MMM d, h:mm a').format(session.startTime)),
            if (session.endTime != null)
              _buildDetailRow('End Time', DateFormat('MMM d, h:mm a').format(session.endTime!)),
            _buildDetailRow('Duration', _formatDuration(session.totalDuration)),
            
            if (session.hasDeviceData) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              _buildDetailRow('Time to Sleep', _formatDuration(session.timeToSleep ?? Duration.zero)),
              _buildDetailRow('Awakenings', '${session.awakenings ?? 0} times'),
              _buildDetailRow('Sleep Efficiency', '${session.sleepEfficiency?.toInt() ?? 0}%'),
              
              const SizedBox(height: 16),
              
              // Sleep timeline chart
              SleepTimelineChart(session: session),
            ],
            
            if (!session.hasDeviceData)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Connect your Anavaya device for detailed sleep analysis',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
