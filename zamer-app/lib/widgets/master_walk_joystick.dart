import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../services/walk_input_service.dart';

class MasterWalkJoystick extends StatefulWidget {
  const MasterWalkJoystick({super.key, required this.onStep});

  final void Function(double forward, double sideways, double deltaSeconds)
      onStep;

  @override
  State<MasterWalkJoystick> createState() => _MasterWalkJoystickState();
}

class _MasterWalkJoystickState extends State<MasterWalkJoystick> {
  static const double _radius = 54;
  static const Duration _frameInterval = Duration(milliseconds: 16);

  Timer? _timer;
  Offset _vector = Offset.zero;
  final Stopwatch _clock = Stopwatch();
  int? _lastMicros;

  void _update(Offset local) {
    final delta = local - const Offset(64, 64);
    final distance = delta.distance;
    final clamped = distance > _radius && distance > 0
        ? delta * (_radius / distance)
        : delta;
    if (mounted) setState(() => _vector = clamped / _radius);
  }

  void _emit() {
    final now = _clock.elapsedMicroseconds;
    final previous = _lastMicros;
    _lastMicros = now;
    final elapsed = previous == null
        ? _frameInterval.inMicroseconds
        : now - previous;
    final dt = (elapsed / Duration.microsecondsPerSecond)
        .clamp(1 / 240, .05)
        .toDouble();
    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);
    if (input.forward == 0 && input.sideways == 0) return;
    widget.onStep(input.forward, input.sideways, dt);
  }

  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    _clock
      ..reset()
      ..start();
    _lastMicros = null;
    _emit();
    _timer = Timer.periodic(_frameInterval, (_) => _emit());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _lastMicros = null;
    if (mounted) setState(() => _vector = Offset.zero);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 128,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _start(event.localPosition),
          onPointerMove: (event) => _update(event.localPosition),
          onPointerUp: (_) => _stop(),
          onPointerCancel: (_) => _stop(),
          child: CustomPaint(painter: _MasterJoystickPainter(vector: _vector)),
        ),
      );
}

class _MasterJoystickPainter extends CustomPainter {
  const _MasterJoystickPainter({required this.vector});
  final Offset vector;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * .42;
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()..color = ZamerColors.surface.withValues(alpha: .90),
    );
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = ZamerColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final knob = center + vector * baseRadius;
    canvas.drawCircle(knob, 22, Paint()..color = ZamerColors.accent);
    canvas.drawCircle(
      knob,
      22,
      Paint()
        ..color = ZamerColors.textPrimary.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MasterJoystickPainter oldDelegate) =>
      oldDelegate.vector != vector;
}
