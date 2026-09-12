import 'package:flutter/material.dart';
import '../models/connection_status.dart' as models;
import '../services/connection_monitoring_service.dart';

/// Connection status indicator widget
/// Shows WiFi signal strength, online/offline status, and connection quality
class ConnectionStatusIndicator extends StatelessWidget {
  final String deviceId;
  final ConnectionMonitoringService monitoringService;
  final bool showDetails;

  const ConnectionStatusIndicator({
    Key? key,
    required this.deviceId,
    required this.monitoringService,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<models.ConnectionStatus>(
      stream: monitoringService.monitorDevice(deviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status),
                size: 16,
                color: _getStatusColor(status),
              ),
              if (showDetails) ...[
                const SizedBox(width: 8),
                Text(
                  status.getDisplayText(showSignal: true),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (status.signalStrength != null) ...[
                const SizedBox(width: 8),
                Icon(
                  _getSignalIcon(status.signalStrength!),
                  size: 16,
                  color: _getStatusColor(status),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(models.ConnectionStatus status) {
    switch (status.state) {
      case models.ConnectionState.online:
        if (status.signalStrength != null && status.signalStrength! < -80) {
          return Colors.orange; // Weak signal warning
        }
        return Colors.green;
      case models.ConnectionState.degraded:
        return Colors.orange;
      case models.ConnectionState.offline:
      case models.ConnectionState.reconnecting:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(models.ConnectionStatus status) {
    switch (status.state) {
      case models.ConnectionState.online:
        return Icons.check_circle;
      case models.ConnectionState.degraded:
        return Icons.warning_amber;
      case models.ConnectionState.offline:
        return Icons.cloud_off;
      case models.ConnectionState.reconnecting:
        return Icons.sync;
    }
  }

  IconData _getSignalIcon(int rssi) {
    // WiFi signal strength icons based on RSSI
    if (rssi > -50) return Icons.wifi; // Excellent
    if (rssi > -70) return Icons.wifi_2_bar; // Good/Fair
    return Icons.wifi_1_bar; // Weak
  }
}

/// Compact connection status dot (for small spaces)
class ConnectionStatusDot extends StatelessWidget {
  final String deviceId;
  final ConnectionMonitoringService monitoringService;

  const ConnectionStatusDot({
    Key? key,
    required this.deviceId,
    required this.monitoringService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<models.ConnectionStatus>(
      stream: monitoringService.monitorDevice(deviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;

        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(status),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(status).withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(models.ConnectionStatus status) {
    switch (status.state) {
      case models.ConnectionState.online:
        return Colors.green;
      case models.ConnectionState.degraded:
        return Colors.orange;
      case models.ConnectionState.offline:
        return Colors.red;
      case models.ConnectionState.reconnecting:
        return Colors.blue;
    }
  }
}

/// Detailed connection info card (for device settings screen)
class ConnectionInfoCard extends StatelessWidget {
  final String deviceId;
  final ConnectionMonitoringService monitoringService;

  const ConnectionInfoCard({
    Key? key,
    required this.deviceId,
    required this.monitoringService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<models.ConnectionStatus>(
      stream: monitoringService.monitorDevice(deviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Checking connection...'),
            ),
          );
        }

        final status = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(status.state),
                      color: _getStatusColor(status.state),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.getDisplayText(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (status.userFriendlyMessage != null)
                            Text(
                              status.userFriendlyMessage!,
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
                if (status.signalStrength != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Signal Strength:'),
                      const Spacer(),
                      Text(
                        status.signalQuality,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _getSignalColor(status.signalStrength!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${status.signalStrength} dBm',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (status.lastConnected != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Last Seen:'),
                      const Spacer(),
                      Text(
                        _formatLastSeen(status.lastConnected!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(models.ConnectionState state) {
    switch (state) {
      case models.ConnectionState.online:
        return Colors.green;
      case models.ConnectionState.degraded:
        return Colors.orange;
      case models.ConnectionState.offline:
        return Colors.red;
      case models.ConnectionState.reconnecting:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(models.ConnectionState state) {
    switch (state) {
      case models.ConnectionState.online:
        return Icons.check_circle_outline;
      case models.ConnectionState.degraded:
        return Icons.warning_amber_outlined;
      case models.ConnectionState.offline:
        return Icons.cloud_off_outlined;
      case models.ConnectionState.reconnecting:
        return Icons.sync_outlined;
    }
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
