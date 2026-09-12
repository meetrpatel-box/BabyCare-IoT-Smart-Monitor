import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/pin_input.dart';
import '../../widgets/common/smart_back_button.dart';

/// PIN entry screen (after login)
/// Ported from React Native EnterPINScreen.tsx
class EnterPINScreen extends StatefulWidget {
  const EnterPINScreen({super.key});

  @override
  State<EnterPINScreen> createState() => _EnterPINScreenState();
}

class _EnterPINScreenState extends State<EnterPINScreen> {
  bool _isLoading = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final authProvider = context.read<AuthProvider>();
    final availability = await BiometricService.isBiometricAvailable();
    final enabled = await authProvider.isBiometricEnabled();

    setState(() {
      _biometricAvailable = availability.isAvailable;
      _biometricEnabled = enabled;
    });

    // Auto-trigger biometric if available and enabled
    if (_biometricAvailable && _biometricEnabled) {
      _authenticateWithBiometric();
    }
  }

  Future<void> _onPinEntered(String pin) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final result = await authProvider.verifyPin(pin);

      if (!result.success) {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
      }
      // If success, auth provider will update state and router will redirect
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.authenticateWithBiometrics();

      if (!success) {
        setState(() {
          _error = 'Biometric authentication failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        leading: const SmartBackButton(fallbackRoute: '/welcome'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxxl),

              // Lock icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Enter your PIN to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // PIN Input
              PINInput(
                length: 6,
                onCompleted: _onPinEntered,
                hasError: _error != null,
                isLoading: _isLoading,
                showBiometric: _biometricAvailable && _biometricEnabled,
                onBiometricPressed: _authenticateWithBiometric,
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              // Biometric button (if available but not in input)
              if (_biometricAvailable && _biometricEnabled)
                TextButton.icon(
                  onPressed: _authenticateWithBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use biometrics'),
                ),

              const SizedBox(height: AppSpacing.md),

              // Logout link
              TextButton(
                onPressed: _logout,
                child: Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
