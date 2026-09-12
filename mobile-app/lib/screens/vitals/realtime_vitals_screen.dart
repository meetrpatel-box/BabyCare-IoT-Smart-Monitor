import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/vital_sign.dart';
import '../../models/mqtt_device_model.dart';
import '../../providers/mqtt_provider.dart';
import '../../services/vital_signs_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Real-time Vital Signs Screen
/// Displays live sensor data from the device
class RealTimeVitalsScreen extends StatefulWidget {
  final String babyId;

  const RealTimeVitalsScreen({
    super.key,
    required this.babyId,
  });

  @override
  State<RealTimeVitalsScreen> createState() => _RealTimeVitalsScreenState();
}

class _RealTimeVitalsScreenState extends State<RealTimeVitalsScreen> {
  final VitalSignsService _vitalsService = VitalSignsService();
  VitalSign? _latestVital;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _hasData = false;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _isConnected = true;
      _isLoading = true;
    });

    _subscription =
        _vitalsService.streamVitalSigns(widget.babyId, limit: 1).listen(
      (vitals) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (vitals.isNotEmpty) {
              _latestVital = vitals.first;
              _hasData = true;
              _errorMessage = null;
            } else {
              _hasData = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
            _hasData = false;

            // Parse Firestore errors into user-friendly messages
            if (error.toString().contains('requires an index')) {
              _errorMessage =
                  'Database setup required. Please contact support.';
            } else if (error.toString().contains('permission-denied')) {
              _errorMessage =
                  'Permission denied. Please check your account settings.';
            } else if (error.toString().contains('unavailable')) {
              _errorMessage =
                  'Connection lost. Check your internet connection.';
            } else {
              _errorMessage = 'Unable to connect to device.';
            }
          });
        }
      },
    );
  }

  Color _getVitalColor(String type, dynamic value) {
    if (type == 'heartRate') {
      final hr = value as int;
      if (hr < 100 || hr > 180) return Colors.red;
      if (hr < 110 || hr > 170) return Colors.orange;
      return Colors.green;
    } else if (type == 'respiratoryRate') {
      final rr = value as int;
      if (rr < 30 || rr > 60) return Colors.red;
      if (rr < 35 || rr > 55) return Colors.orange;
      return Colors.green;
    } else if (type == 'temperature') {
      final temp = value as double;
      if (temp < 36.5 || temp > 37.5) return Colors.red;
      if (temp < 36.8 || temp > 37.2) return Colors.orange;
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceMqttProvider>(
      builder: (ctx, mqttProvider, _) {
        final mqttVitals = mqttProvider.firstOnlineVitals;

        // If board is live, convert MQTT vitals to VitalSign and show directly.
        if (mqttVitals != null) {
          return _buildWithMqttVitals(mqttVitals, mqttProvider);
        }

        // Fallback: Firestore stream
        return _buildFirestoreScaffold();
      },
    );
  }

  Scaffold _buildFirestoreScaffold() {
    return Scaffold(
      appBar: _buildAppBar(_isConnected, mqttLive: false),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : !_hasData
                  ? _buildNoDeviceState()
                  : _buildVitalsDisplay(),
    );
  }

  Scaffold _buildWithMqttVitals(
      MqttVitals vitals, DeviceMqttProvider provider) {
    // Synthesise a VitalSign from live MQTT data
    final liveVital = VitalSign(
      id: 'mqtt_live',
      babyId: widget.babyId,
      deviceId: provider.devices
          .where((d) => d.isOnline && d.latestVitals != null)
          .map((d) => d.deviceId)
          .firstOrNull ??
          'device001',
      heartRate: vitals.heartRate,
      respiratoryRate: vitals.respiratoryRate,
      bodyTemperature: vitals.bodyTemperature,
      skinTemperature: vitals.skinTemperature,
      ambientTemperature: vitals.ambientTemperature,
      humidity: vitals.humidity,
      timestamp: vitals.timestamp,
      quality: 'good',
      movement: vitals.movementDetected ? 'detected' : 'none',
    );

    return Scaffold(
      appBar: _buildAppBar(true, mqttLive: true),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _buildVitalsBody(liveVital),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isConnected, {required bool mqttLive}) {
    return AppBar(
      title: const Text('Real-time Vitals'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                mqttLive ? 'BOARD LIVE' : (isConnected ? 'LIVE' : 'OFFLINE'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Connecting to device...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to connect',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _startListening();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDeviceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Device Connected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To start monitoring vitals, you need to:\n\n'
              '1. Turn on your Anvaya Pod device\n'
              '2. Connect it to WiFi using the app\n'
              '3. Place it near your baby\n\n'
              'The device will automatically start sending data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to device provisioning screen
                context.push('/device-setup');
              },
              icon: const Icon(Icons.add),
              label: const Text('Set Up Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Waiting for sensor data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure the device is connected',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsDisplay() {
    final vital = _latestVital!;

    return RefreshIndicator(
      onRefresh: () async =>
          await Future.delayed(const Duration(milliseconds: 500)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _buildVitalsBody(vital),
      ),
    );
  }

  Widget _buildVitalsBody(VitalSign vital) {
    final lastUpdate = DateTime.now().difference(vital.timestamp);

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: vital.isHealthy ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      vital.isHealthy ? Icons.check_circle : Icons.warning,
                      color: vital.isHealthy ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vital.healthStatus,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: vital.isHealthy
                                  ? Colors.green[900]
                                  : Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last update: ${lastUpdate.inSeconds}s ago',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Vital Signs Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildVitalCard(
                  icon: Icons.favorite,
                  title: 'Heart Rate',
                  value: '${vital.heartRate}',
                  unit: 'BPM',
                  color: _getVitalColor('heartRate', vital.heartRate),
                  normalRange: '100-180',
                ),
                _buildVitalCard(
                  icon: Icons.air,
                  title: 'Respiratory',
                  value: '${vital.respiratoryRate}',
                  unit: 'BPM',
                  color:
                      _getVitalColor('respiratoryRate', vital.respiratoryRate),
                  normalRange: '30-60',
                ),
                _buildVitalCard(
                  icon: Icons.thermostat,
                  title: 'Body Temp',
                  value: vital.bodyTemperature.toStringAsFixed(1),
                  unit: '°C',
                  color: _getVitalColor('temperature', vital.bodyTemperature),
                  normalRange: '36.5-37.5',
                ),
                _buildVitalCard(
                  icon: Icons.water_drop,
                  title: 'Humidity',
                  value: '${vital.humidity}',
                  unit: '%',
                  color: Colors.blue,
                  normalRange: '40-60',
                ),
                _buildVitalCard(
                  icon: Icons.home_outlined,
                  title: 'Room Temp',
                  value: vital.ambientTemperature.toStringAsFixed(1),
                  unit: '°C',
                  color: Colors.purple,
                  normalRange: '20-24',
                ),
                _buildVitalCard(
                  icon: Icons.directions_run,
                  title: 'Movement',
                  value: vital.movement == 'detected' ? 'Active' : 'Resting',
                  unit: '',
                  color: vital.movement == 'detected'
                      ? Colors.orange
                      : Colors.green,
                  normalRange: null,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Device Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Device ID', vital.deviceId),
                    _buildInfoRow(
                        'Signal Quality', vital.quality.toUpperCase()),
                    _buildInfoRow('Skin Temperature',
                        '${vital.skinTemperature.toStringAsFixed(1)}°C'),
                    _buildInfoRow(
                        'Last Reading', _formatTimestamp(vital.timestamp)),
                  ],
                ),
              ),
            ),
          ],
        );
  }

  Widget _buildVitalCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    String? normalRange,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (normalRange != null) ...[
              const SizedBox(height: 4),
              Text(
                'Normal: $normalRange',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
