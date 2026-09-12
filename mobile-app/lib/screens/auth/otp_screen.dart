import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../providers/auth_provider.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_theme.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/common/smart_back_button.dart';

/// Minimalist OTP Verification Screen
/// Apple-inspired clean UI
class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  String _otp = '';
  bool _isLoading = false;
  String? _error;
  int _resendCountdown = 30;
  Timer? _timer;
  bool _otpReady = false; // true once verificationId is received

  @override
  void initState() {
    super.initState();
    // Check if verificationId is already available (from route params or AuthProvider)
    final alreadyReady = widget.verificationId.isNotEmpty;
    if (alreadyReady) {
      _otpReady = true;
      _startResendTimer();
    }
    // If not ready yet, the Consumer<AuthProvider> in build() will trigger
    // setState when pendingVerificationId arrives via router-driven navigation
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_otpReady) {
      final pending = context.read<AuthProvider>().pendingVerificationId;
      if (pending != null && pending.isNotEmpty) {
        setState(() => _otpReady = true);
        _startResendTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _verificationId =>
      widget.verificationId.isNotEmpty
          ? widget.verificationId
          : context.read<AuthProvider>().pendingVerificationId ?? '';

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6) return;

    final verificationId = _verificationId;
    if (verificationId.isEmpty) {
      setState(() => _error = 'Still waiting for OTP to be sent. Please wait a moment.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      await authProvider.verifyPhoneOTP(
        verificationId: verificationId,
        smsCode: otp,
      );

      // Navigate to PIN creation
      if (mounted) {
        context.goNamed('createPin');
      }
    } on Exception catch (e) {
      try {
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 200);
        }
      } catch (_) {}

      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() {
        _error = msg.isNotEmpty ? msg : 'Invalid verification code. Please try again.';
        _isLoading = false;
        _otp = '';
      });
    } catch (e) {
      try {
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 200);
        }
      } catch (_) {}

      setState(() {
        _error = 'Verification failed. Please try again.';
        _isLoading = false;
        _otp = '';
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      await authProvider.signInWithPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          setState(() => _isLoading = false);
          _startResendTimer();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code resent successfully')),
          );
        },
        onError: (error) {
          setState(() {
            _error = error;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: DesignTokens.backgroundWarm,
        appBar: AppBar(
          backgroundColor: DesignTokens.backgroundWarm,
          elevation: 0,
          leading: const Padding(
            padding: EdgeInsets.only(left: DesignTokens.spaceMd),
            child: SmartBackButton(),
          ),
        ),
        body: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              // Check if verificationId is now available via provider
              if (!_otpReady) {
                final pending = authProvider.pendingVerificationId;
                if (pending != null && pending.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _otpReady = true);
                    _startResendTimer();
                  });
                }
              }

              return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: DesignTokens.spaceLg),

                const Text(
                  'Verification Code',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimary,
                    letterSpacing: -0.5,
                    fontFamily: DesignTokens.fontFamilySecondary,
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceMd),

                Text(
                  'Enter the code sent to ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: DesignTokens.textSecondary,
                  ),
                ),

                const SizedBox(height: DesignTokens.space3xl),

                // OTP Input — shown only after verificationId is ready
                if (!_otpReady) ...[
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(DesignTokens.primaryTeal),
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  const Text(
                    'Sending verification code...',
                    style: TextStyle(
                      fontSize: 14,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ] else ...[
                  OTPInput(
                    length: 6,
                    onCompleted: _verifyOTP,
                    onChanged: (value) => setState(() => _otp = value),
                    hasError: _error != null,
                  ),
                ],

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: DesignTokens.spaceLg),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: DesignTokens.statusCritical,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: DesignTokens.space3xl),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || _otp.length != 6 || !_otpReady
                        ? null
                        : () => _verifyOTP(_otp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                      disabledBackgroundColor:
                          DesignTokens.primaryTeal.withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spaceXl),

                // Resend code
                if (_otpReady)
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'Resend code in ${_resendCountdown}s',
                            style: const TextStyle(
                              color: DesignTokens.textMuted,
                              fontSize: 14,
                            ),
                          )
                        : TextButton(
                            onPressed: _resendOTP,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                color: DesignTokens.primaryTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          );
            },
          ),
        ),
      ),
    );
  }
}
