/// Connection state for devices
enum ConnectionState {
  online,      // Device is connected and responsive
  offline,     // Device hasn't been seen for >5 minutes
  reconnecting, // Attempting to reconnect
  degraded,    // Connection is slow or unstable
}

/// Detailed connection status information
class ConnectionStatus {
  final ConnectionState state;
  final DateTime? lastConnected;
  final int? signalStrength; // WiFi RSSI: -30 (excellent) to -90 (poor) dBm
  final String? errorCode;
  final String? userFriendlyMessage;

  ConnectionStatus({
    required this.state,
    this.lastConnected,
    this.signalStrength,
    this.errorCode,
    this.userFriendlyMessage,
  });

  bool get isOnline => state == ConnectionState.online;
  bool get isOffline => state == ConnectionState.offline;
  bool get isReconnecting => state == ConnectionState.reconnecting;
  bool get isDegraded => state == ConnectionState.degraded;

  /// Get human-readable signal quality
  String get signalQuality {
    if (signalStrength == null) return 'Unknown';
    if (signalStrength! > -50) return 'Excellent';
    if (signalStrength! > -60) return 'Good';
    if (signalStrength! > -70) return 'Fair';
    if (signalStrength! > -80) return 'Weak';
    return 'Very Weak';
  }

  /// Get color code for UI indicators
  String get statusColor {
    switch (state) {
      case ConnectionState.online:
        return signalStrength != null && signalStrength! < -80 ? 'warning' : 'success';
      case ConnectionState.degraded:
        return 'warning';
      case ConnectionState.offline:
      case ConnectionState.reconnecting:
        return 'error';
    }
  }

  /// Get icon name for status
  String get iconName {
    switch (state) {
      case ConnectionState.online:
        return 'check_circle';
      case ConnectionState.degraded:
        return 'warning';
      case ConnectionState.offline:
        return 'cloud_off';
      case ConnectionState.reconnecting:
        return 'sync';
    }
  }

  /// Get display text for status
  String getDisplayText({bool showSignal = true}) {
    switch (state) {
      case ConnectionState.online:
        if (showSignal && signalStrength != null) {
          return 'Connected • $signalQuality';
        }
        return 'Connected';
      case ConnectionState.degraded:
        return userFriendlyMessage ?? 'Weak Connection';
      case ConnectionState.offline:
        if (lastConnected != null) {
          final diff = DateTime.now().difference(lastConnected!);
          return 'Offline ${_formatTimeSince(diff)}';
        }
        return 'Offline';
      case ConnectionState.reconnecting:
        return 'Reconnecting...';
    }
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    if (duration.inHours < 24) return '${duration.inHours}h';
    return '${duration.inDays}d';
  }

  ConnectionStatus copyWith({
    ConnectionState? state,
    DateTime? lastConnected,
    int? signalStrength,
    String? errorCode,
    String? userFriendlyMessage,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      lastConnected: lastConnected ?? this.lastConnected,
      signalStrength: signalStrength ?? this.signalStrength,
      errorCode: errorCode ?? this.errorCode,
      userFriendlyMessage: userFriendlyMessage ?? this.userFriendlyMessage,
    );
  }
}
