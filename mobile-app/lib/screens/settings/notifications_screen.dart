import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/smart_back_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _cryAlerts = true;
  bool _feedingReminders = true;
  bool _sleepReminders = false;
  bool _milestoneAlerts = true;
  bool _deviceAlerts = true;

  static const _keyPrefix = 'notif_';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cryAlerts = prefs.getBool('${_keyPrefix}cry') ?? true;
      _feedingReminders = prefs.getBool('${_keyPrefix}feeding') ?? true;
      _sleepReminders = prefs.getBool('${_keyPrefix}sleep') ?? false;
      _milestoneAlerts = prefs.getBool('${_keyPrefix}milestone') ?? true;
      _deviceAlerts = prefs.getBool('${_keyPrefix}device') ?? true;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}$key', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _section(context, 'Baby Monitoring', [
            _toggle(
              context,
              title: 'Cry Alerts',
              subtitle: 'Get notified when crying is detected',
              icon: Icons.record_voice_over_outlined,
              value: _cryAlerts,
              onChanged: (v) {
                setState(() => _cryAlerts = v);
                _set('cry', v);
              },
            ),
            _toggle(
              context,
              title: 'Device Alerts',
              subtitle: 'Connection and battery notifications',
              icon: Icons.devices_outlined,
              value: _deviceAlerts,
              onChanged: (v) {
                setState(() => _deviceAlerts = v);
                _set('device', v);
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _section(context, 'Reminders', [
            _toggle(
              context,
              title: 'Feeding Reminders',
              subtitle: 'Based on your feeding schedule',
              icon: Icons.restaurant_outlined,
              value: _feedingReminders,
              onChanged: (v) {
                setState(() => _feedingReminders = v);
                _set('feeding', v);
              },
            ),
            _toggle(
              context,
              title: 'Sleep Reminders',
              subtitle: 'Nap time and bedtime alerts',
              icon: Icons.bedtime_outlined,
              value: _sleepReminders,
              onChanged: (v) {
                setState(() => _sleepReminders = v);
                _set('sleep', v);
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _section(context, 'Growth & Milestones', [
            _toggle(
              context,
              title: 'Milestone Alerts',
              subtitle: 'When a new milestone is expected',
              icon: Icons.star_outline,
              value: _milestoneAlerts,
              onChanged: (v) {
                setState(() => _milestoneAlerts = v);
                _set('milestone', v);
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _toggle(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
