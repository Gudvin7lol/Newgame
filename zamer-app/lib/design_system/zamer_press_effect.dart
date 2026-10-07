import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared tactile/visual press feedback for ZAMER controls.
///
/// Uses pointer events instead of a gesture recognizer, so it can safely wrap
/// Material/InkWell controls without stealing their tap gesture.
class ZPressEffect extends StatefulWidget {
  const ZPressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = .975,
    this.opacity = .90,
    this.haptic = true,
  });

  final Widget child;
  final bool enabled;
  final double scale;
  final double opacity;
  final bool haptic;

  @override
  State<ZPressEffect> createState() => _ZPressEffectState();
}

class _ZPressEffectState extends State<ZPressEffect> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!widget.enabled) return;
        _setPressed(true);
        if (widget.haptic) HapticFeedback.selectionClick();
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.opacity : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
