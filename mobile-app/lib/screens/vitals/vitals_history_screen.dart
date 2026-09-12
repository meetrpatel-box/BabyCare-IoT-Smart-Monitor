import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vital_sign.dart';
import '../../providers/baby_provider.dart';
import '../../services/vital_signs_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charts/vital_charts.dart';

/// Vitals History Screen
/// Shows historical charts for heart rate, respiratory rate, and temperature
class VitalsHistoryScreen extends StatefulWidget {
  const VitalsHistoryScreen({super.key});

  @override
  State<VitalsHistoryScreen> createState() => _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends State<VitalsHistoryScreen> {
  final VitalSignsService _vitalSignsService = VitalSignsService();
  List<VitalSign> _vitals = [];
  bool _isLoading = true;
  String _selectedTimeRange = '24h'; // '24h', '7d', '30d'

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    final baby = context.read<BabyProvider>().selectedBaby;
    if (baby == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime endDate = DateTime.now();
      DateTime startDate;

      switch (_selectedTimeRange) {
        case '24h':
          startDate = endDate.subtract(const Duration(hours: 24));
          break;
        case '7d':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '30d':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        default:
          startDate = endDate.subtract(const Duration(hours: 24));
      }

      final vitals = await _vitalSignsService.getVitalSignsInRange(
          baby.id, startDate, endDate);

      setState(() {
        _vitals = vitals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vitals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        title: const Text('Vitals History'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.foregroundPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.borderLight,
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadVitals,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildTimeRangeSelector(),
                    const SizedBox(height: 24),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildChartCard(
                      child: HeartRateChart(
                        vitals: _vitals,
                        timeRange: _selectedTimeRange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(
                      child: RespiratoryRateChart(
                        vitals: _vitals,
                        timeRange: _selectedTimeRange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(
                      child: TemperatureChart(
                        vitals: _vitals,
                        timeRange: _selectedTimeRange,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildTimeRangeButton('24h', '24 Hours'),
          const SizedBox(width: 12),
          _buildTimeRangeButton('7d', '7 Days'),
          const SizedBox(width: 12),
          _buildTimeRangeButton('30d', '30 Days'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String value, String label) {
    final isSelected = _selectedTimeRange == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTimeRange = value;
          });
          _loadVitals();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.foregroundSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_vitals.isEmpty) {
      return const SizedBox();
    }

    final avgHeartRate =
        _vitals.fold<int>(0, (sum, v) => sum + v.heartRate) / _vitals.length;
    final avgRespRate =
        _vitals.fold<int>(0, (sum, v) => sum + v.respiratoryRate) /
            _vitals.length;
    final avgTemp =
        _vitals.fold<double>(0, (sum, v) => sum + v.bodyTemperature) /
            _vitals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Avg Heart Rate',
              '${avgHeartRate.round()}',
              'bpm',
              AppColors.heartRate,
              Icons.favorite,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Avg Respiratory',
              '${avgRespRate.round()}',
              'bpm',
              AppColors.info,
              Icons.air,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Avg Temperature',
              avgTemp.toStringAsFixed(1),
              '°C',
              AppColors.temperature,
              Icons.thermostat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.foregroundSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.foregroundSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
