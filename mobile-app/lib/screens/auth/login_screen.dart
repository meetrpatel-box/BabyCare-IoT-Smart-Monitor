import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/smart_back_button.dart';

/// Minimalist Login Screen
/// Apple-inspired UI: Phone First > Google > Email
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginMethod { phone, email }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Default to email on web (phone auth doesn't work on web)
  LoginMethod _loginMethod = kIsWeb ? LoginMethod.email : LoginMethod.phone;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  String _countryCode = '+91';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text}';

  Future<void> _handlePhoneLogin() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final phoneNumber = _fullPhoneNumber;

      // Just trigger the OTP send — the router automatically navigates to
      // the OTP screen when pendingVerificationId is set in AuthProvider.
      await authProvider.signInWithPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          // Router handles navigation automatically
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _error = error;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthProvider's authStateChanges listener will update state.
      // GoRouter's refreshListenable will redirect automatically (to dashboard,
      // /enter-pin for PIN users, or /onboarding for new users).
      // Do NOT navigate manually here — that bypasses PIN / onboarding guards.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        if (errorMessage.contains('user-not-found')) {
          errorMessage = 'No account found with this email.';
        } else if (errorMessage.contains('wrong-password')) {
          errorMessage = 'Incorrect password.';
        } else if (errorMessage.contains('invalid-credential')) {
          errorMessage = 'Invalid email or password.';
        } else if (errorMessage.contains('too-many-requests')) {
          errorMessage = 'Too many attempts. Please try again later.';
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLoginMethod() {
    setState(() {
      _loginMethod = _loginMethod == LoginMethod.phone
          ? LoginMethod.email
          : LoginMethod.phone;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _loginMethod == LoginMethod.phone;

    // Enforce Light Theme for this screen to ensure DesignTokens match widgets
    // This prevents dark mode inputs/dialogs from clashing with the fixed light background
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: DesignTokens.backgroundWarm,
        body: SafeArea(
          child: Stack(
            children: [
              // Smart back button
              Positioned(
                top: DesignTokens.spaceLg,
                left: DesignTokens.spaceLg,
                child: const SmartBackButton(fallbackRoute: '/welcome'),
              ),

              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceXl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Minimalist Header
                        Text(
                          isPhone ? 'Enter Phone Number' : 'Sign in with Email',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: DesignTokens.textPrimary,
                            letterSpacing: -0.5,
                            fontFamily: DesignTokens.fontFamilySecondary,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Text(
                          isPhone
                              ? 'We\'ll send you a verification code'
                              : 'Enter your account details to continue',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: DesignTokens.textSecondary,
                          ),
                        ),

                        const SizedBox(height: DesignTokens.space3xl),

                        // Animated Form Container
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  if (isPhone)
                                    _buildPhoneForm()
                                  else
                                    _buildEmailForm(),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Error Display
                        if (_error != null) ...[
                          const SizedBox(height: DesignTokens.spaceLg),
                          Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceMd),
                            decoration: BoxDecoration(
                              color:
                                  DesignTokens.statusCritical.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusMd),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: DesignTokens.statusCritical,
                                    size: 20),
                                const SizedBox(width: DesignTokens.spaceSm),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: DesignTokens.statusCritical,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: DesignTokens.spaceXl),

                        // Social / Alternative Login Section
                        if (isPhone) ...[
                          _buildDivider(),
                          const SizedBox(height: DesignTokens.spaceLg),
                          _buildGoogleButton(),
                          const SizedBox(height: DesignTokens.spaceMd),
                          _buildEmailButton(),
                        ] else ...[
                          const SizedBox(height: DesignTokens.spaceLg),
                          TextButton(
                            onPressed: _toggleLoginMethod,
                            child: const Text(
                              'Use Phone Number instead',
                              style: TextStyle(
                                color: DesignTokens.primaryTeal,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],

                        // Sign Up Link
                        const SizedBox(height: DesignTokens.spaceXl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: DesignTokens.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/auth/signup'),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: DesignTokens.primaryTeal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: DesignTokens.borderLight),
            boxShadow: [DesignTokens.shadowSm],
          ),
          child: Row(
            children: [
              // Country Code
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: DesignTokens.borderLight),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _countryCode,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    style: const TextStyle(
                      fontSize: 16,
                      color: DesignTokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: DesignTokens.surfaceWhite,
                    onChanged: (value) => setState(() => _countryCode = value!),
                    items: const [
                      DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                      DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                      DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                    ],
                  ),
                ),
              ),
              // Phone Input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: DesignTokens.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Mobile Number',
                    hintStyle: TextStyle(color: DesignTokens.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false, // Important: prevent theme fill color
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMd,
                      vertical: DesignTokens.spaceLg,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.spaceXl),
        SizedBox(
          width: double.infinity,
          height: 52, // Apple-standard touch target
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePhoneLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
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
                    'Get Verification Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        // Email Input
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: DesignTokens.borderLight),
            boxShadow: [DesignTokens.shadowSm],
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(
              fontSize: 16,
              color: DesignTokens.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Email Address',
              hintStyle: TextStyle(color: DesignTokens.textMuted),
              prefixIcon:
                  Icon(Icons.email_outlined, color: DesignTokens.textSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false, // Important
              contentPadding: EdgeInsets.symmetric(
                vertical: DesignTokens.spaceLg,
                horizontal: DesignTokens.spaceMd,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (!value.contains('@')) return 'Invalid email';
              return null;
            },
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMd),

        // Password Input
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: DesignTokens.borderLight),
            boxShadow: [DesignTokens.shadowSm],
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _handleEmailLogin(),
            style: const TextStyle(
              fontSize: 16,
              color: DesignTokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: DesignTokens.textMuted),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: DesignTokens.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: DesignTokens.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false, // Important
              contentPadding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceLg,
                horizontal: DesignTokens.spaceMd,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (value.length < 6) return 'Min 6 chars';
              return null;
            },
          ),
        ),

        const SizedBox(height: DesignTokens.spaceXl),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
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
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: DesignTokens.surfaceWhite,
          side: const BorderSide(color: DesignTokens.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple G logo approximation or asset
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue, // Placeholder for G logo
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithGoogle();
      // Router handles navigation — do NOT navigate manually here.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (msg == 'Google Sign-In cancelled') msg = '';
        setState(() {
          _error = msg.isNotEmpty ? msg : null;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildEmailButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _toggleLoginMethod,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
        ),
        child: const Text(
          'Continue with Email',
          style: TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: DesignTokens.borderLight)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceLg),
          child: Text(
            'or',
            style: TextStyle(
              color: DesignTokens.textMuted,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: DesignTokens.borderLight)),
      ],
    );
  }
}
