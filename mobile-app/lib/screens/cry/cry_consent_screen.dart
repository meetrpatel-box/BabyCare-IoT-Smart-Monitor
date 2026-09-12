import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cry_event_model.dart';
import '../../services/cry_data_consent_service.dart';
import '../../theme/design_tokens.dart';

/// Consent onboarding screen shown once before cry detection data collection.
///
/// Explains 3 consent tiers and lets the user choose.
/// Stores choice via [CryDataConsentService].
class CryConsentScreen extends StatefulWidget {
  final String userId;

  const CryConsentScreen({super.key, required this.userId});

  @override
  State<CryConsentScreen> createState() => _CryConsentScreenState();
}

class _CryConsentScreenState extends State<CryConsentScreen> {
  late final CryDataConsentService _consentService;
  CryDataConsent _selected = CryDataConsent.featuresOnly;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _consentService = CryDataConsentService(
      firestore: FirebaseFirestore.instance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DesignTokens.spaceXl),

              // Header
              const Text(
                'Cry Detection Data',
                style: TextStyle(
                  fontSize: DesignTokens.fontSize3xl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              const Text(
                'Help improve cry detection accuracy for all families. '
                'Choose what data you\'re comfortable sharing.',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeMd,
                  color: DesignTokens.textSecondary,
                  height: DesignTokens.lineHeightNormal,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceXxl),

              // Consent options
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildConsentOption(
                        consent: CryDataConsent.featuresOnly,
                        icon: Icons.equalizer,
                        title: 'Audio Features Only',
                        subtitle: 'Recommended',
                        description:
                            'Share extracted audio features (frequency patterns, '
                            'energy levels) but never raw audio recordings. '
                            'This is the best balance of privacy and accuracy.',
                        isRecommended: true,
                      ),
                      const SizedBox(height: DesignTokens.spaceLg),
                      _buildConsentOption(
                        consent: CryDataConsent.fullAudio,
                        icon: Icons.mic,
                        title: 'Full Audio',
                        subtitle: 'Maximum improvement',
                        description:
                            'Share audio features plus short audio clips (~5s) '
                            'around cry events. Helps train more accurate models. '
                            'Audio is encrypted and anonymized.',
                      ),
                      const SizedBox(height: DesignTokens.spaceLg),
                      _buildConsentOption(
                        consent: CryDataConsent.none,
                        icon: Icons.shield,
                        title: 'No Data Sharing',
                        subtitle: 'Detection still works',
                        description:
                            'Cry detection works locally on your device. '
                            'No data is sent to the cloud for training. '
                            'You can change this anytime in Settings.',
                      ),
                    ],
                  ),
                ),
              ),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                decoration: BoxDecoration(
                  color: DesignTokens.bgInfo,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: DesignTokens.accentBlue),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Text(
                        'You can change your preference anytime in Settings. '
                        'Data deletion is available on request.',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),

              // Save button
              SizedBox(
                width: double.infinity,
                height: DesignTokens.touchTargetComfortable,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveConsent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primaryTeal,
                    foregroundColor: DesignTokens.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DesignTokens.textOnPrimary,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeLg,
                            fontWeight: DesignTokens.fontWeightSemiBold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentOption({
    required CryDataConsent consent,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    bool isRecommended = false,
  }) {
    final isSelected = _selected == consent;

    return GestureDetector(
      onTap: () => setState(() => _selected = consent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.primaryLight.withOpacity(0.15)
              : DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(
            color: isSelected
                ? DesignTokens.primaryTeal
                : DesignTokens.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio + Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? DesignTokens.primaryTeal.withOpacity(0.1)
                    : DesignTokens.surfaceGray,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? DesignTokens.primaryTeal
                    : DesignTokens.textMuted,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeLg,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                          color: isSelected
                              ? DesignTokens.primaryDark
                              : DesignTokens.textPrimary,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: DesignTokens.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceSm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DesignTokens.primaryTeal,
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusFull),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: DesignTokens.fontWeightSemiBold,
                              color: DesignTokens.textOnPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: DesignTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: DesignTokens.textSecondary,
                      height: DesignTokens.lineHeightNormal,
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            Radio<CryDataConsent>(
              value: consent,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              activeColor: DesignTokens.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConsent() async {
    setState(() => _isSaving = true);
    try {
      await _consentService.updateConsent(
        userId: widget.userId,
        consent: _selected,
      );
      if (mounted) {
        Navigator.of(context).pop(_selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: DesignTokens.statusCritical,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
