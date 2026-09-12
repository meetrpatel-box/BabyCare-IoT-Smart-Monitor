import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baby_provider.dart';
import '../../models/baby_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';

/// Settings screen
/// Ported from React Native SettingsScreen.tsx
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        leading: const SmartBackButton(),
        title: const Text('Settings'),
      ),
      body: Consumer2<AuthProvider, BabyProvider>(
        builder: (context, authProvider, babyProvider, child) {
          final user = authProvider.firestoreUser;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                _buildProfileCard(context, authProvider),

                const SizedBox(height: AppSpacing.xl),

                // Baby Profiles
                Text(
                  'Baby Profiles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildBabyProfilesSection(context, babyProvider),

                const SizedBox(height: AppSpacing.lg),

                // Family Invitations
                _buildFamilyInviteSection(context, authProvider),

                const SizedBox(height: AppSpacing.xl),

                // App Settings
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildAppSettingsSection(context),

                const SizedBox(height: AppSpacing.xl),

                // Cry Detection
                Text(
                  'Cry Detection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildCryDetectionSection(context, babyProvider),

                const SizedBox(height: AppSpacing.xl),

                // Devices
                Text(
                  'Devices',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDevicesSection(context),

                const SizedBox(height: AppSpacing.xl),

                // Support
                Text(
                  'Support',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildSupportSection(context),

                const SizedBox(height: AppSpacing.xxl),

                // Sign Out
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showSignOutDialog(context, authProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // App version
                Center(
                  child: Text(
                    'BabyTrack v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.firestoreUser;
    final displayName = (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : null) ??
        authProvider.currentUser?.email ??
        'User';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primaryLight,
          backgroundImage:
              user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          child: user?.photoUrl == null
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        title: Text(displayName),
        subtitle: Text(
          user?.email ?? '',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/profile'),
      ),
    );
  }

  Widget _buildBabyProfilesSection(
      BuildContext context, BabyProvider babyProvider) {
    // Show loading state
    if (babyProvider.isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    // Show error state
    if (babyProvider.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 12),
              Text(
                'Error loading baby profiles',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                babyProvider.error!,
                style: TextStyle(fontSize: 12, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  if (authProvider.userId != null) {
                    babyProvider.loadBabiesForParent(authProvider.userId!);
                  }
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // Filter out invalid babies
          ...babyProvider.babies.where((baby) {
            // Only show babies with valid names
            return baby.name.trim().isNotEmpty &&
                baby.name.trim().length > 1 &&
                !baby.dateOfBirth.isAfter(DateTime.now());
          }).map((baby) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: baby.photoUrl != null
                      ? NetworkImage(baby.photoUrl!)
                      : null,
                  child: baby.photoUrl == null
                      ? Text(
                          baby.name.trim().isNotEmpty
                              ? baby.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: AppColors.primary),
                        )
                      : null,
                ),
                title: Text(baby.name.trim()),
                subtitle: Text(baby.ageDisplay),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Delete button for invalid/test babies
                    if (baby.name.trim().length <= 2 ||
                        baby.name.toLowerCase() == 'test baby')
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            _confirmDeleteBaby(context, babyProvider, baby),
                      ),
                    Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _showBabyOptions(context, babyProvider, baby),
              )),

          // Show empty state if no valid babies
          if (babyProvider.babies
              .where(
                  (b) => b.name.trim().isNotEmpty && b.name.trim().length > 1)
              .isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.child_care, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 12),
                  Text(
                    'No baby profiles yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your baby\'s profile to get started',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            ),
            title: const Text('Add Baby'),
            onTap: () => context.push('/settings/add-baby'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyInviteSection(
      BuildContext context, AuthProvider authProvider) {
    final familyId = authProvider.firestoreUser?.familyIds.firstOrNull;

    if (familyId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_add, color: AppColors.primary),
            ),
            title: const Text('Invite Family Member'),
            subtitle: const Text('Share via email, QR code, or invite code'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push(
                '/settings/invite-family',
                extra: {
                  'familyId': familyId,
                  'familyName':
                      authProvider.firestoreUser?.displayName ?? 'Family',
                },
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            ),
            title: const Text('Scan Invitation QR Code'),
            subtitle: const Text('Join another family'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/scan-invite-qr'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBaby(
      BuildContext context, BabyProvider babyProvider, BabyModel baby) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${baby.name}?'),
        content: Text(
            'This will permanently delete this baby profile and all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await babyProvider.deleteBaby(baby.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${baby.name} deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting baby: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAppSettingsSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Security'),
            subtitle: const Text('PIN & Biometrics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/security'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Theme & Display'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/appearance'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCryDetectionSection(BuildContext context, BabyProvider babyProvider) {
    final babyId = babyProvider.selectedBaby?.id ?? '';
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFFE11D48)),
            title: const Text('Cry History'),
            subtitle: const Text('View cry events & classifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: babyId.isEmpty
                ? null
                : () => context.push('/cry-history/$babyId'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF0284C7)),
            title: const Text('Cry Alerts & Data Settings'),
            subtitle: const Text('Manage data sharing consent'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/cry-consent'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.analytics_outlined, color: Color(0xFFF97316)),
            title: const Text('Colic Analytics'),
            subtitle: const Text('Pattern detection & risk analysis'),
            trailing: const Icon(Icons.chevron_right),
            onTap: babyId.isEmpty
                ? null
                : () => context.push('/cry-history/$babyId?tab=colic'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('My Devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add New Device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/wifi-provisioning'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfoDialog(context, 'Help & FAQ',
                'For help and FAQs, visit our website or contact support at support@babytrack.app'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Contact Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfoDialog(context, 'Contact Support',
                'Email us at support@babytrack.app\n\nWe typically respond within 24 hours.'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfoDialog(context, 'Privacy Policy',
                'Your data is stored securely and never shared with third parties without your consent. We collect only the minimum data needed to operate BabyTrack.'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfoDialog(context, 'Terms of Service',
                'By using BabyTrack you agree to use the app for personal, non-commercial purposes. BabyTrack is not a medical device and should not replace professional medical advice.'),
          ),
        ],
      ),
    );
  }

  void _showBabyOptions(BuildContext context, BabyProvider babyProvider, BabyModel baby) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/settings/add-baby');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Profile',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteBaby(context, babyProvider, baby);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: const Text(
            'Additional language support is coming soon.\n\nCurrently only English is supported.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
