import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/common/smart_back_button.dart';

/// Phone number entry screen
/// Ported from React Native PhoneEntryScreen.tsx
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _countryCode = '+91';
  String? _error;
  Timer? _timeoutTimer;

  // Minimum digits expected per country code (without the country code itself)
  static const Map<String, int> _minDigits = {
    '+1': 10,
    '+44': 10,
    '+91': 10,
    '+61': 9,
    '+81': 10,
  };

  @override
  void dispose() {
    _phoneController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Safety timeout — if Firebase callbacks never fire, unblock the UI
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _error = 'Request timed out. Please check your connection and try again.';
        });
      }
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final router = GoRouter.of(context);
      final phoneNumber = _fullPhoneNumber;
      debugPrint('📱 [PhoneEntry] Sending OTP to $phoneNumber');

      // Navigate to OTP screen immediately — verificationId will arrive via AuthProvider
      router.goNamed(
        'otp',
        extra: {
          'phoneNumber': phoneNumber,
          'verificationId': '',
        },
      );

      await authProvider.signInWithPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          _timeoutTimer?.cancel();
          // verificationId is already stored in AuthProvider.pendingVerificationId
          // OTP screen will pick it up automatically via provider listener
        },
        onError: (error) {
          _timeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _error = _friendlyError(error);
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = _friendlyError(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  /// Convert raw Firebase error strings into user-friendly messages.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid-phone-number') || lower.contains('invalid phone')) {
      return 'Invalid phone number. Please check the number and country code.';
    }
    if (lower.contains('quota') || lower.contains('too-many-requests') || lower.contains('too many')) {
      return 'Too many requests. Please wait a few minutes and try again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    if (lower.contains('invalid_app_id') || lower.contains('app-not-authorized') || lower.contains('app not authorized')) {
      return 'Phone login is not set up correctly. Please contact support.';
    }
    if (lower.contains('blocked') || lower.contains('captcha')) {
      return 'Verification blocked. Please try again later.';
    }
    // Strip "Exception: " prefix that Dart adds
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm, // Global theme consistency
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        leading: const SmartBackButton(fallbackRoute: '/welcome'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your phone number',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'We\'ll send you a verification code',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Phone input with country code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country code dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _countryCode,
                          items: const [
                            DropdownMenuItem(value: '+1', child: Text('+1')),
                            DropdownMenuItem(value: '+44', child: Text('+44')),
                            DropdownMenuItem(value: '+91', child: Text('+91')),
                            DropdownMenuItem(value: '+61', child: Text('+61')),
                            DropdownMenuItem(value: '+81', child: Text('+81')),
                          ],
                          onChanged: (value) {
                            setState(() => _countryCode = value!);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // Phone number field
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Phone number',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final min = _minDigits[_countryCode] ?? 7;
                          if (value.length < min) {
                            return 'Please enter a valid $min-digit phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                ],

                const Spacer(),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: LoadingButton(
                    onPressed: _sendOTP,
                    isLoading: _isLoading,
                    child: const Text('Continue'),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
