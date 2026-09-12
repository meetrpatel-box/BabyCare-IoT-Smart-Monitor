import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vital_sign.dart';
import '../../theme/app_colors.dart';

/// Heart Rate History Chart
class HeartRateChart extends StatelessWidget {
  final List<VitalSign> vitals;
  final String timeRange; // '24h', '7d', '30d'

  const HeartRateChart({
    super.key,
    required this.vitals,
    this.timeRange = '24h',
  });

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return _buildEmptyState('No heart rate data available');
    }

    final spots = _createHeartRateSpots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Heart Rate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foregroundPrimary,
                ),
              ),
              _buildLegend('Normal: 100-180 bpm', AppColors.success),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.borderLight.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          _buildBottomTitle(value),
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.foregroundSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 80,
                maxY: 200,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.heartRate,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: spots.length < 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.heartRate,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.heartRate.withOpacity(0.1),
                    ),
                  ),
                  // Reference range bands
                  _buildReferenceRange(100, 180, spots.length),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createHeartRateSpots() {
    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return List.generate(sortedVitals.length, (index) {
      return FlSpot(
        index.toDouble(),
        sortedVitals[index].heartRate.toDouble(),
      );
    });
  }

  LineChartBarData _buildReferenceRange(double min, double max, int length) {
    return LineChartBarData(
      spots: [
        FlSpot(0, (min + max) / 2),
        FlSpot(length.toDouble(), (min + max) / 2),
      ],
      isCurved: false,
      color: AppColors.success.withOpacity(0.2),
      barWidth: 40,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildBottomTitle(double value) {
    final index = value.toInt();
    if (index < 0 || index >= vitals.length) return const SizedBox();

    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Show labels at intervals
    if (timeRange == '24h') {
      if (index % (vitals.length ~/ 6) == 0) {
        return Text(
          DateFormat.Hm().format(sortedVitals[index].timestamp),
          style: TextStyle(fontSize: 10, color: AppColors.foregroundSecondary),
        );
      }
    } else if (timeRange == '7d') {
      if (index % (vitals.length ~/ 7) == 0) {
        return Text(
          DateFormat.MMMd().format(sortedVitals[index].timestamp),
          style: TextStyle(fontSize: 10, color: AppColors.foregroundSecondary),
        );
      }
    }

    return const SizedBox();
  }

  Widget _buildLegend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: AppColors.foregroundSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(color: AppColors.foregroundSecondary),
      ),
    );
  }
}

/// Respiratory Rate History Chart
class RespiratoryRateChart extends StatelessWidget {
  final List<VitalSign> vitals;
  final String timeRange;

  const RespiratoryRateChart({
    super.key,
    required this.vitals,
    this.timeRange = '24h',
  });

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return _buildEmptyState('No respiratory data available');
    }

    final spots = _createRespiratorySpots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Respiratory Rate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foregroundPrimary,
                ),
              ),
              _buildLegend('Normal: 30-60 bpm', AppColors.info),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.borderLight.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          _buildBottomTitle(value),
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.foregroundSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 20,
                maxY: 80,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.info,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: spots.length < 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.info,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.info.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createRespiratorySpots() {
    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return List.generate(sortedVitals.length, (index) {
      return FlSpot(
        index.toDouble(),
        sortedVitals[index].respiratoryRate.toDouble(),
      );
    });
  }

  Widget _buildBottomTitle(double value) {
    final index = value.toInt();
    if (index < 0 || index >= vitals.length) return const SizedBox();

    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (timeRange == '24h') {
      if (index % (vitals.length ~/ 6) == 0) {
        return Text(
          DateFormat.Hm().format(sortedVitals[index].timestamp),
          style: TextStyle(fontSize: 10, color: AppColors.foregroundSecondary),
        );
      }
    }

    return const SizedBox();
  }

  Widget _buildLegend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: AppColors.foregroundSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(color: AppColors.foregroundSecondary),
      ),
    );
  }
}

/// Temperature History Chart
class TemperatureChart extends StatelessWidget {
  final List<VitalSign> vitals;
  final String timeRange;

  const TemperatureChart({
    super.key,
    required this.vitals,
    this.timeRange = '24h',
  });

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return _buildEmptyState('No temperature data available');
    }

    final bodyTempSpots = _createBodyTempSpots();
    final skinTempSpots = _createSkinTempSpots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temperature',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foregroundPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegend('Body', AppColors.temperature),
                  const SizedBox(width: 12),
                  _buildLegend('Skin', AppColors.warning),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.borderLight.withOpacity(0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) =>
                          _buildBottomTitle(value),
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.foregroundSecondary,
                        ),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 34,
                maxY: 39,
                lineBarsData: [
                  // Body temperature line
                  LineChartBarData(
                    spots: bodyTempSpots,
                    isCurved: true,
                    color: AppColors.temperature,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: bodyTempSpots.length < 20,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.temperature,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.temperature.withOpacity(0.1),
                    ),
                  ),
                  // Skin temperature line
                  LineChartBarData(
                    spots: skinTempSpots,
                    isCurved: true,
                    color: AppColors.warning,
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createBodyTempSpots() {
    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return List.generate(sortedVitals.length, (index) {
      return FlSpot(
        index.toDouble(),
        sortedVitals[index].bodyTemperature,
      );
    });
  }

  List<FlSpot> _createSkinTempSpots() {
    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return List.generate(sortedVitals.length, (index) {
      return FlSpot(
        index.toDouble(),
        sortedVitals[index].skinTemperature,
      );
    });
  }

  Widget _buildBottomTitle(double value) {
    final index = value.toInt();
    if (index < 0 || index >= vitals.length) return const SizedBox();

    final sortedVitals = List<VitalSign>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (timeRange == '24h') {
      if (index % (vitals.length ~/ 6) == 0) {
        return Text(
          DateFormat.Hm().format(sortedVitals[index].timestamp),
          style: TextStyle(fontSize: 10, color: AppColors.foregroundSecondary),
        );
      }
    }

    return const SizedBox();
  }

  Widget _buildLegend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: AppColors.foregroundSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(color: AppColors.foregroundSecondary),
      ),
    );
  }
}
