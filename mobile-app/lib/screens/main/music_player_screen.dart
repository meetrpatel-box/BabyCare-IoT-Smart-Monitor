import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../providers/baby_provider.dart';
import '../../widgets/device_controls/music_player_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

/// Music Player Screen - Soothing sounds for baby
class MusicPlayerScreen extends StatelessWidget {
  const MusicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Prefer first online MQTT device; fall back to baby's assigned device ID.
    final mqttProvider =
        Provider.of<DeviceMqttProvider>(context, listen: false);
    final onlineDevices = mqttProvider.devices.where((d) => d.isOnline);
    final deviceId = onlineDevices.isNotEmpty
        ? onlineDevices.first.deviceId
        : (Provider.of<BabyProvider>(context, listen: false)
                .selectedBaby
                ?.assignedDeviceId ??
            '');

    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Soothing Sounds'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MusicPlayerWidget(deviceId: deviceId),
        ),
      ),
    );
  }
}
