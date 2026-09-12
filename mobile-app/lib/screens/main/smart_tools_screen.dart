import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../providers/mqtt_provider.dart';

class SmartToolsScreen extends StatelessWidget {
  const SmartToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.foregroundPrimary,
        title: Text(
          'Smart Tools',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.foregroundPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolTile(
            icon: Icons.mic_rounded,
            title: 'Cry Analyzer',
            subtitle: 'Analyze recorded or uploaded baby cries',
            color: AppColors.warning,
            onTap: () => context.push(AppRoutes.cryAnalyzer),
          ),
          _ToolTile(
            icon: Icons.bedtime_rounded,
            title: 'Sleep Analysis',
            subtitle: 'Review sleep insights',
            color: const Color(0xFF6366F1),
            onTap: () => context.push('/sleep-analysis'),
          ),
          _ToolTile(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Insights',
            subtitle: 'See personalized updates',
            color: AppColors.success,
            onTap: () => context.push('/ai-insights'),
          ),
          _ToolTile(
            icon: Icons.music_note_rounded,
            title: 'Soothing Sounds',
            subtitle: 'Play calming music',
            color: const Color(0xFFF97316),
            onTap: () => context.push('/music-player'),
          ),
          _ToolTile(
            icon: Icons.history_rounded,
            title: 'Cry History',
            subtitle: 'View saved cry activity',
            color: const Color(0xFFE11D48),
            onTap: () => context.push('/cry-consent'),
          ),
          const SizedBox(height: 8),
          // ESP32 device status card
          Consumer<DeviceMqttProvider>(
            builder: (context, mqttProvider, _) {
              final isConnected = mqttProvider.isConnected;
              final devices = mqttProvider.devices;
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
                    child: Icon(
                      Icons.memory,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    'ESP32 Device',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    devices.isEmpty
                        ? 'No device added — tap to discover'
                        : devices.map((d) => '${d.deviceName}: ${d.isOnline ? "online" : "offline"}').join(', '),
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                  onTap: () => context.push('/device-setup'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(color: AppColors.foregroundSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
