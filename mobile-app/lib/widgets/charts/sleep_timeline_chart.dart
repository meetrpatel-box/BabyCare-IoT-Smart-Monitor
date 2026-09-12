import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/sleep_data_model.dart';

/// Sleep Timeline Chart
/// Shows sleep stages over time with color-coded bars
class SleepTimelineChart extends StatelessWidget {
  final SleepSession session;
  final double height;

  const SleepTimelineChart({
    super.key,
    required this.session,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (!session.hasDeviceData) {
      return _buildNoDataView();
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep Timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildChart(),
          ),
          const SizedBox(height: 8),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final totalDuration = session.totalDuration;
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < session.stages.length; i++) {
      final stage = session.stages[i];
      final percentage = (stage.duration.inMinutes / totalDuration.inMinutes) * 100;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: percentage,
              color: _getStageColor(stage.stage),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= session.stages.length) return const SizedBox();
                final stage = session.stages[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('HH:mm').format(stage.startTime),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Awake', _getStageColor(SleepStage.awake)),
        _buildLegendItem('Light', _getStageColor(SleepStage.light)),
        _buildLegendItem('Deep', _getStageColor(SleepStage.deep)),
        _buildLegendItem('REM', _getStageColor(SleepStage.rem)),
      ],
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
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNoDataView() {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No device data available',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              'Connect Anavaya device for sleep analysis',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStageColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.awake:
        return Colors.red[300]!;
      case SleepStage.light:
        return Colors.blue[200]!;
      case SleepStage.deep:
        return Colors.indigo[600]!;
      case SleepStage.rem:
        return Colors.purple[400]!;
    }
  }
}
