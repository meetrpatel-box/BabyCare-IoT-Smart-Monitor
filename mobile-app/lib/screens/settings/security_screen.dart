import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pin_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/smart_back_button.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _hasPinSetup = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    final results = await Future.wait([
      PinService.hasPinSetup(uid),
      BiometricService.isBiometricEnabled(uid),
      BiometricService.isBiometricAvailable(),
    ]);

    setState(() {
      _hasPinSetup = results[0] as bool;
      _biometricEnabled = results[1] as bool;
      _biometricAvailable = (results[2] as BiometricAvailability).isAvailable;
      _loading = false;
    });
  }

  Future<void> _removePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text(
            'You will no longer need a PIN to open the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = context.read<AuthProvider>().userId!;
      await PinService.clearPin(uid);
      await BiometricService.setBiometricEnabled(uid, false);
      setState(() {
        _hasPinSetup = false;
        _biometricEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PIN removed')));
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final uid = context.read<AuthProvider>().userId!;
    if (value) {
      final result = await BiometricService.authenticate();
      if (!result.success) return;
    }
    await BiometricService.setBiometricEnabled(uid, value);
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text('Security'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'App Lock',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.pin_outlined,
                            color: AppColors.primary),
                        title: Text(_hasPinSetup ? 'Change PIN' : 'Set Up PIN'),
                        subtitle: Text(_hasPinSetup
                            ? 'PIN is active'
                            : 'Add a 4-digit PIN for app security'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/auth/create-pin').then((_) => _load()),
                      ),
                      if (_hasPinSetup) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.no_encryption_outlined,
                              color: Colors.red),
                          title: const Text('Remove PIN',
                              style: TextStyle(color: Colors.red)),
                          onTap: _removePin,
                        ),
                      ],
                      if (_biometricAvailable) ...[
                        const Divider(height: 1, indent: 56),
                        SwitchListTile(
                          secondary: const Icon(Icons.fingerprint,
                              color: AppColors.primary),
                          title: const Text('Biometric Login'),
                          subtitle: const Text(
                              'Use fingerprint or face unlock'),
                          value: _biometricEnabled,
                          onChanged: _hasPinSetup ? _toggleBiometric : null,
                          activeColor: AppColors.primary,
                        ),
                        if (!_hasPinSetup)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'Set up a PIN first to enable biometrics',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
