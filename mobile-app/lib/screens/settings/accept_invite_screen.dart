import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/family_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/smart_back_button.dart';

/// Screen for accepting or declining family invitations
///
/// Flow:
/// 1. User scans QR code or clicks invite link
/// 2. URL contains inviteId: /accept-invite/{inviteId}
/// 3. Screen fetches invitation details
/// 4. Shows family name, inviter, expiry
/// 5. User accepts or declines
/// 6. Updates Firestore and navigates to dashboard
class AcceptInviteScreen extends StatefulWidget {
  final String inviteId;

  const AcceptInviteScreen({
    super.key,
    required this.inviteId,
  });

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final FamilyService _familyService = FamilyService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  Map<String, dynamic>? _inviteData;
  Map<String, dynamic>? _familyData;
  Map<String, dynamic>? _inviterData;

  @override
  void initState() {
    super.initState();
    _loadInviteDetails();
  }

  Future<void> _loadInviteDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch invite document
      final inviteDoc = await FirebaseFirestore.instance
          .collection('familyInvites')
          .doc(widget.inviteId)
          .get();

      if (!inviteDoc.exists) {
        setState(() {
          _error = 'Invitation not found or has expired';
          _isLoading = false;
        });
        return;
      }

      final inviteData = inviteDoc.data()!;

      // Check if expired
      final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();
      if (expiresAt.isBefore(DateTime.now())) {
        setState(() {
          _error = 'This invitation has expired';
          _isLoading = false;
        });
        return;
      }

      // Check if already accepted/declined
      if (inviteData['status'] != 'pending') {
        setState(() {
          _error = 'This invitation has already been ${inviteData['status']}';
          _isLoading = false;
        });
        return;
      }

      // Fetch family details
      final familyDoc = await FirebaseFirestore.instance
          .collection('families')
          .doc(inviteData['familyId'])
          .get();

      Map<String, dynamic>? familyData;
      if (familyDoc.exists) {
        familyData = familyDoc.data();
      }

      // Fetch inviter details
      final inviterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(inviteData['invitedBy'])
          .get();

      Map<String, dynamic>? inviterData;
      if (inviterDoc.exists) {
        inviterData = inviterDoc.data();
      }

      setState(() {
        _inviteData = inviteData;
        _familyData = familyData;
        _inviterData = inviterData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invitation: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    final userEmail = authProvider.firestoreUser?.email;

    if (userId == null || userEmail == null) {
      _showError('You must be logged in to accept invitations');
      return;
    }

    // Check if invite email matches logged-in user
    if (_inviteData!['email'] != userEmail) {
      _showError(
          'This invitation was sent to ${_inviteData!['email']}. Please log in with that account.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _familyService.acceptInvite(
        inviteId: widget.inviteId,
        userId: userId,
        email: userEmail,
        displayName: authProvider.firestoreUser?.displayName,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully joined ${_familyData?['name'] ?? 'the family'}!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to dashboard
      context.go('/dashboard');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Failed to accept invitation: ${e.toString()}');
    }
  }

  Future<void> _declineInvite() async {
    setState(() => _isProcessing = true);

    try {
      await _familyService.declineInvite(widget.inviteId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation declined'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back to previous screen
      context.go('/dashboard');
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Failed to decline invitation: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        leading: const SmartBackButton(fallbackRoute: '/dashboard'),
        title: const Text('Family Invitation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildInviteContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteContent() {
    final familyName = _familyData?['name'] ?? 'Unknown Family';
    final inviterName = _inviterData?['displayName'] ?? 'Someone';
    final inviterEmail = _inviteData?['email'] ?? '';
    final role = _inviteData?['role'] ?? 'member';
    final expiresAt = (_inviteData?['expiresAt'] as Timestamp).toDate();
    final daysUntilExpiry = expiresAt.difference(DateTime.now()).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invitation Icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom,
                size: 48,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Invitation Title
          Text(
            'You\'re Invited!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Join $familyName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    icon: Icons.person,
                    label: 'Invited by',
                    value: inviterName,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.email,
                    label: 'Sent to',
                    value: inviterEmail,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.badge,
                    label: 'Role',
                    value: _formatRole(role),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: 'Expires in',
                    value:
                        '$daysUntilExpiry day${daysUntilExpiry != 1 ? 's' : ''}',
                    valueColor: daysUntilExpiry <= 1 ? AppColors.error : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(
                color: AppColors.primaryLight.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'ll be able to view baby profiles, vitals, and photos shared by the family.',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Accept Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _acceptInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Accept Invitation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Decline Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _declineInvite,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeMd,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'parent':
        return 'Parent';
      case 'caregiver':
        return 'Caregiver';
      case 'viewer':
        return 'Viewer';
      default:
        return 'Member';
    }
  }
}
