import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cry_event_model.dart';
import '../../services/cry_alert_service.dart';
import '../../services/cry_detection_service.dart';
import '../../services/cry_feedback_service.dart';
import '../../theme/design_tokens.dart';

/// Full-screen cry alert overlay.
///
/// Listens to [CryAlertService.alertStream] and shows progressive alerts:
/// - Tier 1: Red pulsing "Baby is crying!" with intensity
/// - Tier 2: Classification label with confidence
/// - Tier 3: Confirmed classification + actionable suggestion
/// - Resolved: Green "Crying stopped" with feedback prompt
class CryAlertScreen extends StatefulWidget {
  final String babyId;
  final String babyName;

  const CryAlertScreen({
    super.key,
    required this.babyId,
    required this.babyName,
  });

  @override
  State<CryAlertScreen> createState() => _CryAlertScreenState();
}

class _CryAlertScreenState extends State<CryAlertScreen>
    with SingleTickerProviderStateMixin {
  late final CryAlertService _alertService;
  late final CryFeedbackService _feedbackService;
  StreamSubscription<CryAlert>? _alertSub;

  CryAlert? _currentAlert;
  bool _showFeedback = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    final detectionService = CryDetectionService(firestore: firestore);
    _alertService = CryAlertService(
      detectionService: detectionService,
      firestore: firestore,
    );
    _feedbackService = CryFeedbackService(firestore: firestore);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _alertSub = _alertService.alertStream.listen((alert) {
      if (alert.babyId != widget.babyId) return;
      if (!mounted) return;
      setState(() {
        _currentAlert = alert;
        _showFeedback = alert.tier == AlertTier.resolved;
        if (alert.tier == AlertTier.resolved) {
          _pulseController.stop();
        } else {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _pulseController.dispose();
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = _currentAlert;

    if (alert == null) {
      return _buildNoActiveAlert();
    }

    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _showFeedback
                  ? _buildFeedbackPanel(alert)
                  : _buildAlertContent(alert),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.babyName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXl,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildNoActiveAlert() {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: DesignTokens.statusHealthy,
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    const Text(
                      'No active cry detected',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSize2xl,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                        color: DesignTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    const Text(
                      'Monitoring in background...',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeMd,
                        color: DesignTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertContent(CryAlert alert) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated alert icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              return Transform.scale(
                scale: alert.tier == AlertTier.resolved ? 1.0 : scale,
                child: _buildAlertIcon(alert),
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceXl),

          // Title
          Text(
            alert.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: DesignTokens.fontSize3xl,
              fontWeight: DesignTokens.fontWeightBold,
              color: _titleColor(alert.tier),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          // Subtitle
          if (alert.subtitle != null)
            Text(
              alert.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                color: DesignTokens.textSecondary,
              ),
            ),

          // Tier badge
          const SizedBox(height: DesignTokens.spaceLg),
          _buildTierBadge(alert.tier),

          // Confidence bar
          if (alert.confidence != null) ...[
            const SizedBox(height: DesignTokens.spaceXl),
            _buildConfidenceBar(alert.confidence!),
          ],

          // Suggestion
          if (alert.suggestion != null) ...[
            const SizedBox(height: DesignTokens.spaceXl),
            _buildSuggestionCard(alert.suggestion!),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertIcon(CryAlert alert) {
    final iconData = _alertIcon(alert);
    final color = _alertColor(alert.tier);
    final bgColor = _alertBgColor(alert.tier);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 56, color: color),
    );
  }

  IconData _alertIcon(CryAlert alert) {
    if (alert.tier == AlertTier.resolved) return Icons.check_circle;
    if (alert.classification == null) return Icons.warning_rounded;
    switch (alert.classification!) {
      case CryClassification.hungry:
        return Icons.restaurant;
      case CryClassification.tired:
        return Icons.bedtime;
      case CryClassification.pain:
        return Icons.healing;
      case CryClassification.discomfort:
        return Icons.thermostat;
      case CryClassification.gassy:
        return Icons.air;
      case CryClassification.attention:
        return Icons.favorite;
      case CryClassification.overstimulated:
        return Icons.volume_off;
      case CryClassification.colic:
        return Icons.waves;
      case CryClassification.unknown:
        return Icons.help_outline;
    }
  }

  Color _alertColor(AlertTier tier) {
    switch (tier) {
      case AlertTier.detection:
        return DesignTokens.statusCritical;
      case AlertTier.preliminary:
        return DesignTokens.statusWarning;
      case AlertTier.confirmed:
        return DesignTokens.primaryTeal;
      case AlertTier.resolved:
        return DesignTokens.statusHealthy;
    }
  }

  Color _alertBgColor(AlertTier tier) {
    switch (tier) {
      case AlertTier.detection:
        return DesignTokens.bgCritical;
      case AlertTier.preliminary:
        return DesignTokens.bgWarning;
      case AlertTier.confirmed:
        return DesignTokens.primaryLight.withOpacity(0.3);
      case AlertTier.resolved:
        return DesignTokens.bgHealthy;
    }
  }

  Color _titleColor(AlertTier tier) {
    switch (tier) {
      case AlertTier.detection:
        return DesignTokens.statusCritical;
      case AlertTier.preliminary:
        return DesignTokens.textPrimary;
      case AlertTier.confirmed:
        return DesignTokens.primaryDark;
      case AlertTier.resolved:
        return DesignTokens.statusHealthy;
    }
  }

  Widget _buildTierBadge(AlertTier tier) {
    final labels = {
      AlertTier.detection: 'Detecting...',
      AlertTier.preliminary: 'Analyzing...',
      AlertTier.confirmed: 'Confirmed',
      AlertTier.resolved: 'Resolved',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLg,
        vertical: DesignTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: _alertBgColor(tier),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Text(
        labels[tier]!,
        style: TextStyle(
          fontSize: DesignTokens.fontSizeSm,
          fontWeight: DesignTokens.fontWeightSemiBold,
          color: _alertColor(tier),
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Confidence',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textMuted,
              ),
            ),
            Text(
              '${(confidence * 100).round()}%',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 8,
            backgroundColor: DesignTokens.neutralGray200,
            valueColor: AlwaysStoppedAnimation<Color>(
              confidence > 0.8
                  ? DesignTokens.statusHealthy
                  : confidence > 0.6
                      ? DesignTokens.statusWarning
                      : DesignTokens.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(String suggestion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: DesignTokens.bgInfo,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: DesignTokens.accentBlue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: DesignTokens.accentBlue,
            size: DesignTokens.iconSizeLg,
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Text(
              suggestion,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeMd,
                color: DesignTokens.textPrimary,
                height: DesignTokens.lineHeightNormal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Feedback Panel ====================

  Widget _buildFeedbackPanel(CryAlert alert) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceXl),
      child: Column(
        children: [
          const SizedBox(height: DesignTokens.spaceXl),
          // Resolved icon
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: DesignTokens.bgHealthy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 40,
              color: DesignTokens.statusHealthy,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          const Text(
            'Crying stopped',
            style: TextStyle(
              fontSize: DesignTokens.fontSize2xl,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: DesignTokens.statusHealthy,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXxl),

          // Was the classification correct?
          const Text(
            'Was the classification correct?',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeLg,
              fontWeight: DesignTokens.fontWeightMedium,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),

          // Confirm / Correct buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmClassification(alert),
                  icon: const Icon(Icons.check, color: DesignTokens.statusHealthy),
                  label: const Text('Correct'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
                    side: const BorderSide(color: DesignTokens.statusHealthy),
                    foregroundColor: DesignTokens.statusHealthy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceMd),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCorrectionPicker(alert),
                  icon: const Icon(Icons.edit, color: DesignTokens.statusWarning),
                  label: const Text('Wrong'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
                    side: const BorderSide(color: DesignTokens.statusWarning),
                    foregroundColor: DesignTokens.statusWarning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spaceXxl),

          // Resolution picker
          const Text(
            'What resolved the cry?',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeLg,
              fontWeight: DesignTokens.fontWeightMedium,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          _buildResolutionGrid(alert),

          const SizedBox(height: DesignTokens.spaceXl),

          // Skip button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Skip',
              style: TextStyle(color: DesignTokens.textMuted),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXl),
        ],
      ),
    );
  }

  Widget _buildResolutionGrid(CryAlert alert) {
    final resolutions = [
      (CryResolution.fed, Icons.restaurant, 'Fed'),
      (CryResolution.diaperChange, Icons.baby_changing_station, 'Diaper'),
      (CryResolution.rocked, Icons.airline_seat_recline_normal, 'Rocked'),
      (CryResolution.held, Icons.back_hand, 'Held'),
      (CryResolution.pacifier, Icons.child_care, 'Pacifier'),
      (CryResolution.sleep, Icons.bedtime, 'Fell Asleep'),
      (CryResolution.selfResolved, Icons.auto_fix_high, 'Self-Resolved'),
      (CryResolution.other, Icons.more_horiz, 'Other'),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: DesignTokens.spaceSm,
      crossAxisSpacing: DesignTokens.spaceSm,
      children: resolutions.map((r) {
        return _buildResolutionChip(alert, r.$1, r.$2, r.$3);
      }).toList(),
    );
  }

  Widget _buildResolutionChip(
    CryAlert alert,
    CryResolution resolution,
    IconData icon,
    String label,
  ) {
    return InkWell(
      onTap: () => _logResolution(alert, resolution),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(color: DesignTokens.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: DesignTokens.primaryTeal),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Feedback Actions ====================

  Future<void> _confirmClassification(CryAlert alert) async {
    await _feedbackService.confirmClassification(
      babyId: widget.babyId,
      eventId: alert.eventId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for confirming!'),
          backgroundColor: DesignTokens.statusHealthy,
        ),
      );
    }
  }

  Future<void> _showCorrectionPicker(CryAlert alert) async {
    final correctedType = await showModalBottomSheet<CryClassification>(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXl),
        ),
      ),
      builder: (ctx) => _CorrectionPicker(),
    );

    if (correctedType != null) {
      await _feedbackService.correctClassification(
        babyId: widget.babyId,
        eventId: alert.eventId,
        correctedType: correctedType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated to ${correctedType.label}'),
            backgroundColor: DesignTokens.primaryTeal,
          ),
        );
      }
    }
  }

  Future<void> _logResolution(CryAlert alert, CryResolution resolution) async {
    await _feedbackService.logResolution(
      babyId: widget.babyId,
      eventId: alert.eventId,
      resolution: resolution,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged: ${resolution.label}'),
          backgroundColor: DesignTokens.primaryTeal,
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

/// Bottom sheet for selecting the correct classification
class _CorrectionPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final types = CryClassification.values
        .where((t) => t != CryClassification.unknown)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What was the real reason?',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeXl,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ...types.map((type) => ListTile(
                leading: Icon(
                  _classificationIcon(type),
                  color: DesignTokens.primaryTeal,
                ),
                title: Text(type.label),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                onTap: () => Navigator.of(context).pop(type),
              )),
          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }

  IconData _classificationIcon(CryClassification type) {
    switch (type) {
      case CryClassification.hungry:
        return Icons.restaurant;
      case CryClassification.tired:
        return Icons.bedtime;
      case CryClassification.pain:
        return Icons.healing;
      case CryClassification.discomfort:
        return Icons.thermostat;
      case CryClassification.gassy:
        return Icons.air;
      case CryClassification.attention:
        return Icons.favorite;
      case CryClassification.overstimulated:
        return Icons.volume_off;
      case CryClassification.colic:
        return Icons.waves;
      case CryClassification.unknown:
        return Icons.help_outline;
    }
  }
}
