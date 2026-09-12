import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/connection_status.dart';

/// Service for monitoring device connection status
/// Polls device status every 30 seconds and emits connection updates
class ConnectionMonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _pingTimer;
  final Map<String, StreamController<ConnectionStatus>> _controllers = {};

  /// Start monitoring a specific device
  /// Returns a stream of connection status updates
  Stream<ConnectionStatus> monitorDevice(String deviceId) {
    // Create or reuse controller for this device
    if (!_controllers.containsKey(deviceId)) {
      _controllers[deviceId] = StreamController<ConnectionStatus>.broadcast(
        onCancel: () => _stopMonitoring(deviceId),
      );

      // Initial check
      _checkDeviceStatus(deviceId);

      // Start 30-second polling
      Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkDeviceStatus(deviceId);
      });
    }

    return _controllers[deviceId]!.stream;
  }

  /// Check device status and emit update
  Future<void> _checkDeviceStatus(String deviceId) async {
    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();

      if (!doc.exists) {
        _emitStatus(
          deviceId,
          ConnectionStatus(
            state: ConnectionState.offline,
            errorCode: 'DEVICE_NOT_FOUND',
            userFriendlyMessage: 'Device not found',
          ),
        );
        return;
      }

      final data = doc.data()!;
      final lastSeenAt = (data['lastSeenAt'] as Timestamp?)?.toDate();
      final signalStrength = data['wifiInfo']?['signalStrength'] as int?;
      final deviceStatus = data['status'] as String?;

      // Determine connection state
      ConnectionState state;
      String? errorCode;
      String? message;

      if (lastSeenAt == null) {
        state = ConnectionState.offline;
        errorCode = 'NEVER_CONNECTED';
        message = 'Device has never connected';
      } else {
        final timeSinceLastSeen = DateTime.now().difference(lastSeenAt);

        if (deviceStatus == 'provisioning') {
          state = ConnectionState.reconnecting;
          errorCode = 'DEVICE_PROVISIONING';
          message = 'Device is being set up';
        } else if (timeSinceLastSeen.inMinutes > 5) {
          state = ConnectionState.offline;
          errorCode = 'DEVICE_OFFLINE';
          message = 'Device offline for ${timeSinceLastSeen.inMinutes} minutes';
        } else if (timeSinceLastSeen.inSeconds > 60) {
          state = ConnectionState.degraded;
          errorCode = 'DELAYED_UPDATES';
          message = 'Connection delayed';
        } else if (signalStrength != null && signalStrength < -80) {
          state = ConnectionState.degraded;
          errorCode: 'WEAK_SIGNAL';
          message = 'Weak WiFi signal';
        } else {
          state = ConnectionState.online;
        }
      }

      _emitStatus(
        deviceId,
        ConnectionStatus(
          state: state,
          lastConnected: lastSeenAt,
          signalStrength: signalStrength,
          errorCode: errorCode,
          userFriendlyMessage: message,
        ),
      );
    } catch (e) {
      print('[ConnectionMonitoringService] Error checking device $deviceId: $e');
      _emitStatus(
        deviceId,
        ConnectionStatus(
          state: ConnectionState.offline,
          errorCode: 'MONITORING_ERROR',
          userFriendlyMessage: 'Unable to check device status',
        ),
      );
    }
  }

  /// Emit status update to stream
  void _emitStatus(String deviceId, ConnectionStatus status) {
    final controller = _controllers[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(status);
    }
  }

  /// Stop monitoring a specific device
  void _stopMonitoring(String deviceId) {
    final controller = _controllers.remove(deviceId);
    controller?.close();
  }

  /// Stop monitoring all devices and cleanup
  void dispose() {
    _pingTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
