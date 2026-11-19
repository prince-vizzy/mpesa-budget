import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'app_lock.dart';

/// The full-screen PIN layout: icon, title, message line, a row of dots, and
/// a number pad. Holds the digits typed so far and hands over the whole PIN
/// once [AppLock.pinLength] have been entered.
///
/// Call [PinPadState.reject] (through a GlobalKey) to shake the dots and clear
/// them after a wrong PIN, or [PinPadState.clear] to just clear them.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.message,
    this.isError = false,
    this.enabled = true,
    this.onBiometric,
    this.footer,
  });

  final String title;
  final String? message;
  final bool isError;

  /// False while a PIN is being checked or during a lockout.
  final bool enabled;
  final ValueChanged<String> onCompleted;

  /// Shows a fingerprint key in the bottom-left corner when non-null.
  final VoidCallback? onBiometric;

  /// Shown under the keypad, such as a "Forgot PIN?" link.
  final Widget? footer;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void clear() {
    if (mounted) setState(() => _pin = '');
  }

  void reject() {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    clear();
  }

  void _tapDigit(String digit) {
    if (!widget.enabled || _pin.length >= AppLock.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length == AppLock.pinLength) {
      final pin = _pin;
      // Let the last dot fill in before the check takes over.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keys shrink on short screens so the pad never overflows.
          final keySize = min(76.0, (constraints.maxHeight - 320) / 4.6)
              .clamp(52.0, 76.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.lock_outline,
                          color: AppColors.accent, size: 30),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: Text(
                        widget.message ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.isError
                              ? const Color(0xFFF87171)
                              : AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                            sin(_shake.value * pi * 6) * 12 * (1 - _shake.value),
                            0),
                        child: child,
                      ),
                      child: _Dots(filled: _pin.length),
                    ),
                    const SizedBox(height: 36),
                    _Keypad(
                      keySize: keySize,
                      enabled: widget.enabled,
                      onDigit: _tapDigit,
                      onBackspace: _backspace,
                      onBiometric: widget.onBiometric,
                    ),
                    if (widget.footer != null) ...[
                      const SizedBox(height: 12),
                      widget.footer!,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(AppLock.pinLength, (i) {
        final on = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: on ? AppColors.accent : AppColors.secondaryText,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.keySize,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  final double keySize;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
          size: keySize,
          enabled: enabled,
          onTap: () => onDigit(d),
          semanticLabel: d,
          child: Text(
            d,
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: keySize * 0.36,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

    Widget row(List<Widget> keys) => Padding(
          padding: EdgeInsets.symmetric(vertical: keySize * 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: keys,
          ),
        );

    final spacer = SizedBox(width: keySize, height: keySize);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            onBiometric == null
                ? spacer
                : _Key(
                    size: keySize,
                    enabled: true,
                    filled: false,
                    onTap: onBiometric!,
                    semanticLabel: 'Unlock with fingerprint',
                    child: Icon(Icons.fingerprint,
                        color: AppColors.accent, size: keySize * 0.5),
                  ),
            digit('0'),
            _Key(
              size: keySize,
              enabled: enabled,
              filled: false,
              onTap: onBackspace,
              semanticLabel: 'Delete',
              child: Icon(Icons.backspace_outlined,
                  color: AppColors.secondaryText, size: keySize * 0.32),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.size,
    required this.enabled,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.filled = true,
  });

  final double size;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: filled
              ? AppColors.componentBase.withValues(alpha: 0.85)
              : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
