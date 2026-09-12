import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Smart Back Button - Handles navigation safely
///
/// Prevents "Nothing to pop" error by checking navigation stack
/// Falls back to a safe route if stack is empty
///
/// Usage:
/// ```dart
/// AppBar(
///   leading: SmartBackButton(),
/// )
/// ```
class SmartBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? fallbackRoute;
  final Color? color;

  const SmartBackButton({
    Key? key,
    this.onPressed,
    this.fallbackRoute,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: color),
      onPressed: () => _handleBack(context),
    );
  }

  void _handleBack(BuildContext context) {
    // If custom onPressed provided, use it
    if (onPressed != null) {
      onPressed!();
      return;
    }

    // Check if we can pop
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      // Can't pop - go to fallback route or welcome
      final route = fallbackRoute ?? '/welcome';
      context.go(route);
    }
  }
}

/// Smart Close Button - For modals and overlays
class SmartCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const SmartCloseButton({
    Key? key,
    this.onPressed,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.close, color: color),
      onPressed: () {
        if (onPressed != null) {
          onPressed!();
        } else if (Navigator.of(context).canPop()) {
          context.pop();
        }
      },
    );
  }
}
