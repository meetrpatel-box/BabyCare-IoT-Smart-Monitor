import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/pin_input.dart';
import '../../widgets/common/smart_back_button.dart';

/// PIN creation screen
/// Ported from React Native CreatePINScreen.tsx
class CreatePINScreen extends StatefulWidget {
  const CreatePINScreen({super.key});

  @override
  State<CreatePINScreen> createState() => _CreatePINScreenState();
}

class _CreatePINScreenState extends State<CreatePINScreen> {
  String? _firstPin;
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _onPinEntered(String pin) async {
    if (!_isConfirming) {
      // First entry - store and ask for confirmation
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
        _error = null;
      });
    } else {
      // Confirmation entry - verify match
      if (pin == _firstPin) {
        // PINs match - save and continue
        setState(() => _isLoading = true);

        try {
          final authProvider = context.read<AuthProvider>();
          await authProvider.setupPin(pin);

          if (mounted) {
            context.goNamed('biometricSetup');
          }
        } catch (e) {
          setState(() {
            _error = 'Failed to save PIN. Please try again.';
            _isLoading = false;
            _isConfirming = false;
            _firstPin = null;
          });
        }
      } else {
        // PINs don't match
        setState(() {
          _error = 'PINs don\'t match. Please try again.';
          _isConfirming = false;
          _firstPin = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        leading: SmartBackButton(
          fallbackRoute: '/welcome',
          onPressed: _isConfirming
              ? () {
                  setState(() {
                    _isConfirming = false;
                    _firstPin = null;
                    _error = null;
                  });
                }
              : null,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxl),

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
                _isConfirming ? 'Confirm your PIN' : 'Create a PIN',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                _isConfirming
                    ? 'Re-enter your 6-digit PIN'
                    : 'Create a 6-digit PIN for quick access',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // PIN Input
              PINInput(
                length: 6,
                onCompleted: _onPinEntered,
                hasError: _error != null,
                isLoading: _isLoading,
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

              // Skip button (only on first entry)
              if (!_isConfirming)
                TextButton(
                  onPressed: () => context.goNamed('biometricSetup'),
                  child: const Text('Skip for now'),
                ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
