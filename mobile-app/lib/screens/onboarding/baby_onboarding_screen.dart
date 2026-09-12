import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baby_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_button.dart';

/// Baby Onboarding Flow - First-time user experience
/// Multi-step process to add first baby and setup device
class BabyOnboardingScreen extends StatefulWidget {
  const BabyOnboardingScreen({super.key});

  @override
  State<BabyOnboardingScreen> createState() => _BabyOnboardingScreenState();
}

class _BabyOnboardingScreenState extends State<BabyOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form data
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  String _gender = 'male';
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _completeBabyProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your baby\'s date of birth'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final babyProvider = context.read<BabyProvider>();

      // Ensure firestoreUser is loaded (handles race condition on first login)
      if (authProvider.firestoreUser == null) {
        await authProvider.refreshFirestoreUser();
      }

      // Get user's family ID — auto-create family if missing
      String? familyId = authProvider.firestoreUser?.familyIds.firstOrNull;

      if (familyId == null) {
        // Family missing — create one now (handles edge cases on first login)
        debugPrint('⚠️ No family found — auto-creating for user ${authProvider.userId}');
        final userId = authProvider.userId!;
        final displayName = authProvider.firestoreUser?.displayName;
        await AuthService().createFamilyForExistingUser(userId, displayName);
        await authProvider.refreshFirestoreUser();
        familyId = authProvider.firestoreUser?.familyIds.firstOrNull;
      }

      if (familyId == null) {
        throw Exception('Unable to create family. Please try again or contact support.');
      }

      await babyProvider.addBaby(
        name: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        gender: _gender,
        parentId: authProvider.userId!,
        familyId: familyId,
      );

      if (mounted) {
        _nextStep(); // Go to device setup step
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipToApp() {
    context.go('/dashboard');
  }

  void _setupDevice() {
    context.go('/wifi-provisioning');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _buildWelcomePage(),
                  _buildBabyInfoPage(),
                  _buildDeviceSetupPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '👶',
                style: TextStyle(fontSize: 100),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Heading
          const Text(
            'Welcome to BabyCare',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Subheading
          Text(
            'Let\'s get started by adding your baby\'s profile. This helps us personalize your experience.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.foregroundSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Features list
          _buildFeatureItem(Icons.favorite, 'Monitor vital signs in real-time'),
          const SizedBox(height: AppSpacing.md),
          _buildFeatureItem(Icons.timeline, 'Track milestones and growth'),
          const SizedBox(height: AppSpacing.md),
          _buildFeatureItem(Icons.analytics, 'AI-powered insights'),

          const SizedBox(height: AppSpacing.xxl),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildBabyInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Back button
            IconButton(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.foreground,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Heading
            const Text(
              'Tell us about your baby',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'This information helps us provide personalized care insights.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.foregroundSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Baby's name
            Text(
              'Baby\'s Name',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter baby\'s name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter baby\'s name';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Date of birth
            Text(
              'Date of Birth',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _dateOfBirth != null
                          ? DateFormat('MMMM dd, yyyy').format(_dateOfBirth!)
                          : 'Select date of birth',
                      style: TextStyle(
                        fontSize: 15,
                        color: _dateOfBirth != null
                            ? AppColors.foreground
                            : AppColors.foregroundSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Gender
            Text(
              'Gender',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildGenderButton('male', 'Boy', '👦'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderButton('female', 'Girl', '👧'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed: _completeBabyProfile,
                isLoading: _isLoading,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSetupPage() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Success illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.check_circle_outline,
                size: 100,
                color: AppColors.success,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Success message
          const Text(
            'Profile Complete!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            'Now let\'s connect your BabyCare device to start monitoring your baby\'s well-being.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.foregroundSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Device setup button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _setupDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Connect Device',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Skip button
          TextButton(
            onPressed: _skipToApp,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.foregroundSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String value, String label, String emoji) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
