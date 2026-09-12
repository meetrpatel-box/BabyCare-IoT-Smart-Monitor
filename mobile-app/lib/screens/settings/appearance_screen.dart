import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/smart_back_button.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text('Appearance'),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    _ThemeTile(
                      title: 'System Default',
                      subtitle: 'Follows your device setting',
                      icon: Icons.brightness_auto_outlined,
                      value: ThemeMode.system,
                      groupValue: themeProvider.themeMode,
                      onChanged: themeProvider.setThemeMode,
                    ),
                    const Divider(height: 1, indent: 56),
                    _ThemeTile(
                      title: 'Light',
                      subtitle: 'Always use light theme',
                      icon: Icons.light_mode_outlined,
                      value: ThemeMode.light,
                      groupValue: themeProvider.themeMode,
                      onChanged: themeProvider.setThemeMode,
                    ),
                    const Divider(height: 1, indent: 56),
                    _ThemeTile(
                      title: 'Dark',
                      subtitle: 'Always use dark theme',
                      icon: Icons.dark_mode_outlined,
                      value: ThemeMode.dark,
                      groupValue: themeProvider.themeMode,
                      onChanged: themeProvider.setThemeMode,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppColors.primary : AppColors.textSecondary),
      title: Text(title,
          style: TextStyle(
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: Text(subtitle),
      trailing: Radio<ThemeMode>(
        value: value,
        groupValue: groupValue,
        onChanged: (v) => onChanged(v!),
        activeColor: AppColors.primary,
      ),
      onTap: () => onChanged(value),
    );
  }
}
