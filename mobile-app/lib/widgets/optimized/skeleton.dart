import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../core/constants.dart';

/// Skeleton loading widgets for perceived performance
/// Shows content shape while loading - feels faster than spinner
/// See DESIGN_GUIDELINES.md: Skeleton screens over spinners

class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = Radii.sm,
  });

  /// Circle skeleton for avatars
  const Skeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = Radii.full;

  /// Text line skeleton
  const Skeleton.text({
    super.key,
    this.width = double.infinity,
  })  : height = 16,
        borderRadius = Radii.sm;

  /// Title skeleton
  const Skeleton.title({
    super.key,
    this.width = 200,
  })  : height = 24,
        borderRadius = Radii.sm;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                AppColors.border.withOpacity(0.3),
                AppColors.border.withOpacity(0.5),
                AppColors.border.withOpacity(0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card for dashboard vitals
class SkeletonVitalCard extends StatelessWidget {
  const SkeletonVitalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 36, width: 36, borderRadius: Radii.sm),
              Skeleton(height: 20, width: 50, borderRadius: Radii.sm),
            ],
          ),
          SizedBox(height: Spacing.md),
          Skeleton.text(width: 80),
          SizedBox(height: Spacing.sm),
          Skeleton.title(width: 60),
        ],
      ),
    );
  }
}

/// Skeleton for list items
class SkeletonListItem extends StatelessWidget {
  final bool showAvatar;
  final bool showSubtitle;

  const SkeletonListItem({
    super.key,
    this.showAvatar = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      child: Row(
        children: [
          if (showAvatar) ...[
            const Skeleton.circle(size: 48),
            SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.text(width: 150),
                if (showSubtitle) ...[
                  SizedBox(height: Spacing.sm),
                  Skeleton.text(width: 100),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for dashboard screen
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Skeleton.circle(size: 56),
              SizedBox(width: Spacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.title(width: 120),
                  SizedBox(height: Spacing.sm),
                  Skeleton.text(width: 80),
                ],
              ),
            ],
          ),

          SizedBox(height: Spacing.xl),

          // Vitals section title
          Skeleton.title(width: 100),

          SizedBox(height: Spacing.md),

          // Vitals grid
          Row(
            children: [
              Expanded(child: SkeletonVitalCard()),
              SizedBox(width: Spacing.md),
              Expanded(child: SkeletonVitalCard()),
            ],
          ),
          SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(child: SkeletonVitalCard()),
              SizedBox(width: Spacing.md),
              Expanded(child: SkeletonVitalCard()),
            ],
          ),

          SizedBox(height: Spacing.xl),

          // Sleep card
          Container(
            padding: EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Skeleton.title(width: 100),
                    Skeleton.text(width: 60),
                  ],
                ),
                SizedBox(height: Spacing.lg),
                Skeleton(height: 60, borderRadius: Radii.md),
                SizedBox(height: Spacing.md),
                Skeleton.text(),
                SizedBox(height: Spacing.sm),
                Skeleton.text(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
