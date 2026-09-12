import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Status of a provisioning step
enum StepStatus { pending, active, complete, error }

/// Single provisioning step data
class ProvisioningStepData {
  final String label;
  final StepStatus status;

  const ProvisioningStepData({
    required this.label,
    required this.status,
  });
}

/// Visual progress indicator for WiFi provisioning
/// Shows a 4-step progress with status (pending/active/complete/error)
class ProvisioningProgress extends StatelessWidget {
  final List<ProvisioningStepData> steps;

  const ProvisioningProgress({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStep(context, steps[i], i + 1),
            if (i < steps.length - 1)
              Expanded(
                child: _buildConnector(steps[i].status),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(
      BuildContext context, ProvisioningStepData step, int number) {
    Color circleColor;
    Widget circleContent;

    switch (step.status) {
      case StepStatus.complete:
        circleColor = AppColors.success;
        circleContent = const Icon(Icons.check, color: Colors.white, size: 20);
        break;
      case StepStatus.active:
        circleColor = AppColors.primary;
        circleContent = Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
      case StepStatus.error:
        circleColor = AppColors.error;
        circleContent = const Icon(Icons.close, color: Colors.white, size: 20);
        break;
      case StepStatus.pending:
        circleColor = AppColors.textMuted.withValues(alpha: 0.3);
        circleContent = Text(
          '$number',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: circleContent),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 80,
          child: Text(
            step.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: step.status == StepStatus.active
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: step.status == StepStatus.active
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(StepStatus status) {
    Color color;
    switch (status) {
      case StepStatus.complete:
        color = AppColors.success;
        break;
      case StepStatus.active:
      case StepStatus.error:
      case StepStatus.pending:
        color = AppColors.textMuted.withValues(alpha: 0.3);
        break;
    }

    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 48),
      color: color,
    );
  }
}
