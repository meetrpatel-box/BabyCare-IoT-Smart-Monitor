import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/common/smart_back_button.dart';

/// Biometric setup screen
/// Ported from React Native BiometricSetupScreen.tsx
class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isLoading = false;
  BiometricAvailability? _availability;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final availability = await BiometricService.isBiometricAvailable();
    setState(() => _availability = availability);
  }

  Future<void> _enableBiometric() async {
    final authProvider = context.read<AuthProvider>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (result.success) {
        await authProvider.setBiometricEnabled(true);

        if (mounted) {
          context.go('/dashboard');
        }
      } else {
        setState(() {
          _error = result.error ?? 'Biometric authentication failed';
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

  void _skip() {
    context.go('/dashboard');
  }

  IconData _getBiometricIcon() {
    switch (_availability?.biometricType) {
      case BiometricType.faceId:
        return Icons.face;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.remove_red_eye;
      default:
        return Icons.security;
    }
  }

  String _getBiometricName() {
    return BiometricService.getBiometricTypeName(
      _availability?.biometricType ?? BiometricType.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = _availability?.isAvailable ?? false;

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
              const Spacer(),

              // Biometric icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getBiometricIcon(),
                  size: 50,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                isAvailable
                    ? 'Enable ${_getBiometricName()}'
                    : 'Biometric Not Available',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                isAvailable
                    ? 'Use ${_getBiometricName()} for quick and secure access to BabyTrack'
                    : _availability?.reason ??
                        'Biometric authentication is not available on this device',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
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

              // Enable button
              if (isAvailable)
                SizedBox(
                  width: double.infinity,
                  child: LoadingButton(
                    onPressed: _enableBiometric,
                    isLoading: _isLoading,
                    child: Text('Enable ${_getBiometricName()}'),
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Skip button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _skip,
                  child: Text(isAvailable ? 'Skip for now' : 'Continue'),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
