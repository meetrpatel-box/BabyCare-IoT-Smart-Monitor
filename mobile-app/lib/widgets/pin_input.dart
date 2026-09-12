import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// PIN input widget with numeric keypad
/// Ported from React Native PINInput.tsx
class PINInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool isLoading;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;

  const PINInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.hasError = false,
    this.isLoading = false,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  @override
  State<PINInput> createState() => _PINInputState();
}

class _PINInputState extends State<PINInput>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void didUpdateWidget(PINInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward().then((_) {
        _shakeController.reverse();
        setState(() => _pin = '');
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_pin.length >= widget.length || widget.isLoading) return;

    Vibration.vibrate(duration: 30);

    setState(() {
      _pin += digit;
    });

    if (_pin.length == widget.length) {
      widget.onCompleted?.call(_pin);
    }
  }

  void _deleteDigit() {
    if (_pin.isEmpty || widget.isLoading) return;

    Vibration.vibrate(duration: 30);

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _clearAll() {
    if (widget.isLoading) return;

    Vibration.vibrate(duration: 50);

    setState(() {
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PIN dots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final isFilled = index < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? (widget.hasError ? AppColors.error : AppColors.primary)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.hasError
                        ? AppColors.error
                        : (isFilled ? AppColors.primary : AppColors.border),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.xxxl),

        // Keypad
        if (widget.isLoading)
          const CircularProgressIndicator()
        else
          _buildKeypad(),
      ],
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.showBiometric
                ? _buildBiometricKey()
                : const SizedBox(width: 80, height: 80),
            _buildKey('0'),
            _buildDeleteKey(),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String digit) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addDigit(digit),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                digit,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _deleteDigit,
          onLongPress: _clearAll,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricKey() {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onBiometricPressed,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Icon(
              Icons.fingerprint,
              color: AppColors.primary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
