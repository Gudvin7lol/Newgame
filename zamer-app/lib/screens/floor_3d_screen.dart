import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_graphics_selector.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../renderer3d/zamer_gpu_viewport.dart';
import '../services/walk_input_service.dart';
import '../services/walk_navigation_service.dart';
import 'photo_studio_screen.dart';

class Floor3DScreen extends StatefulWidget {
  const Floor3DScreen({super.key, required this.floor});
  final FloorPlan floor;

  @override
  State<Floor3DScreen> createState() => _Floor3DScreenState();
}

class _Floor3DScreenState extends State<Floor3DScreen> {
  double _rotation = -0.65;
  double _tilt = 0.82;
  double _zoom = 0.92;
  bool _cutaway = true;
  bool _walkMode = false;
  bool _noclip = false;
  double _walkStepMm = 120;
  double _lookSensitivity = 0.010;
  double _walkX = 0, _walkY = 0;
  double _overviewRotation = -0.65, _overviewTilt = 0.82;
  double _overviewZoom = 0.92;
  Offset _overviewPan = Offset.zero;
  Offset _pan = Offset.zero;
  double _gestureZoom = 1;
  Offset _gesturePan = Offset.zero;
  Offset _gestureFocal = Offset.zero;
  int _gesturePointers = 0;
  ZGraphicsMode _graphicsMode = ZGraphicsMode.quality;
  final GlobalKey<ZamerGpuViewportState> _gpuKey =
      GlobalKey<ZamerGpuViewportState>();

  void _reset() => setState(() {
    if (_walkMode) _centerWalk();
    _rotation = _walkMode
        ? WalkNavigationService.startingRotation(
            widget.floor,
            math.Point(_walkX, _walkY),
          )
        : -0.65;
    _tilt = _walkMode ? 0 : 0.82;
    _zoom = _walkMode ? 1 : 0.92;
    _pan = Offset.zero;
  });

  void _topView() => setState(() {
    _walkMode = false;
    _rotation = 0;
    _tilt = 1.42;
    _zoom = 0.9;
    _pan = Offset.zero;
  });

  void _centerWalk() {
    final start = WalkNavigationService.startingPoint(widget.floor);
    _walkX = start.x;
    _walkY = start.y;
  }

  void _toggleWalk() => setState(() {
    if (!_walkMode) {
      _overviewRotation = _rotation;
      _overviewTilt = _tilt;
      _overviewZoom = _zoom;
      _overviewPan = _pan;
      _centerWalk();
      _rotation = WalkNavigationService.startingRotation(
        widget.floor,
        math.Point(_walkX, _walkY),
      );
      _tilt = 0;
      _zoom = 1;
      _pan = Offset.zero;
    } else {
      _rotation = _overviewRotation;
      _tilt = _overviewTilt;
      _zoom = _overviewZoom;
      _pan = _overviewPan;
    }
    _walkMode = !_walkMode;
  });

  void _walk(double forward, double sideways) {
    final next = WalkNavigationService.advance(
      widget.floor,
      math.Point(_walkX, _walkY),
      _rotation,
      forward,
      sideways,
      ignoreCollisions: _noclip,
    );
    if (next.x != _walkX || next.y != _walkY) {
      setState(() {
        _walkX = next.x;
        _walkY = next.y;
      });
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureZoom = _zoom;
    _gesturePan = _pan;
    _gestureFocal = d.focalPoint;
    _gesturePointers = d.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      return;
    }
    setState(() {
      if (d.pointerCount >= 2) {
        _zoom = (_gestureZoom * d.scale)
            .clamp(_walkMode ? 0.7 : 0.15, _walkMode ? 1.4 : 10.0)
            .toDouble();
        if (!_walkMode) {
          _pan = _gesturePan + (d.focalPoint - _gestureFocal);
        }
      } else {
        final lookSensitivity = _walkMode ? _lookSensitivity : 0.010;
        final angle = _rotation + d.focalPointDelta.dx * lookSensitivity;
        _rotation = math.atan2(math.sin(angle), math.cos(angle));
        _tilt = (_tilt - d.focalPointDelta.dy * lookSensitivity * 0.6)
            .clamp(_walkMode ? -0.7 : 0.22, _walkMode ? 0.7 : 1.48)
            .toDouble();
      }
    });
  }

  Future<void> _showRenderSheet() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => PhotoStudioScreen(
          floor: widget.floor,
          rotation: _rotation,
          tilt: _tilt,
          zoom: _zoom,
          pan: _pan,
        ),
      ),
    );
  }

  Future<void> _selectGraphicsMode(ZGraphicsMode value) async {
    setState(() => _graphicsMode = value);
    if (value == ZGraphicsMode.photo) {
      await _showRenderSheet();
      if (mounted) setState(() => _graphicsMode = ZGraphicsMode.quality);
    }
  }

  Future<void> _showWalkSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => ZSheetFrame(
          title: 'Настройки прогулки',
          description:
              'Левый стик отвечает за движение. Осмотр выполняется одним пальцем прямо по сцене.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, size: 19),
                  const SizedBox(width: ZamerSpace.sm),
                  const SizedBox(width: 96, child: Text('Скорость')),
                  Expanded(
                    child: Slider(
                      value: _walkStepMm,
                      min: 55,
                      max: 220,
                      divisions: 11,
                      label: '${_walkStepMm.round()} мм',
                      onChanged: (value) {
                        setState(() => _walkStepMm = value);
                        setSheet(() {});
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 19),
                  const SizedBox(width: ZamerSpace.sm),
                  const SizedBox(width: 96, child: Text('Осмотр')),
                  Expanded(
                    child: Slider(
                      value: _lookSensitivity,
                      min: 0.005,
                      max: 0.018,
                      divisions: 13,
                      label: '${(_lookSensitivity * 1000).round()}',
                      onChanged: (value) {
                        setState(() => _lookSensitivity = value);
                        setSheet(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.floor.walls.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_in_ar_outlined,
        title: '3D пока пуст',
        subtitle: 'Построй стены в разделе «Замер», и сцена появится здесь.',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ZamerGpuViewport(
                  key: _gpuKey,
                  floor: widget.floor,
                  rotation: _rotation,
                  tilt: _tilt,
                  zoom: _zoom,
                  cutaway: !_walkMode && _cutaway,
                  pan: _pan,
                  walkMode: _walkMode,
                  walkX: _walkX,
                  walkY: _walkY,
                ),
                if (_walkMode)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: ZamerColors.accent,
                                width: 1.4,
                              ),
                            ),
                          ),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ZamerColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_walkMode)
          Positioned(
            left: ZamerSpace.md,
            top: ZamerSpace.md,
            child: SafeArea(
              bottom: false,
              child: ZGraphicsModeSelector(
                value: _graphicsMode,
                onChanged: _selectGraphicsMode,
              ),
            ),
          ),
        Positioned(
          top: ZamerSpace.md,
          right: ZamerSpace.md,
          child: SafeArea(
            bottom: false,
            child: ZPanel(
              padding: EdgeInsets.zero,
              color: ZamerColors.surface.withValues(alpha: .92),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _walkMode ? 'В центр комнаты' : 'Сбросить вид',
                    onPressed: _reset,
                    icon: const Icon(Icons.my_location_outlined),
                  ),
                  if (!_walkMode)
                    IconButton(
                      tooltip: 'Вид сверху',
                      onPressed: _topView,
                      icon: const Icon(Icons.vertical_align_top),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_walkMode)
          Positioned(
            left: 10,
            bottom: 78,
            child: SafeArea(
              top: false,
              right: false,
              child: _WalkJoystick(
                onStep: (forward, sideways) =>
                    _walk(forward * _walkStepMm, sideways * _walkStepMm),
              ),
            ),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: ZamerSpace.sm,
          child: SafeArea(
            top: false,
            child: ZPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: ZamerSpace.xxs,
                vertical: ZamerSpace.xs,
              ),
              color: ZamerColors.surface.withValues(alpha: .96),
              child: Row(
                children: _walkMode
                    ? [
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.home_outlined,
                            label: 'Обзор',
                            onTap: _toggleWalk,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.blur_on,
                            label: 'Сквозь',
                            selected: _noclip,
                            onTap: () => setState(() => _noclip = !_noclip),
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.tune_rounded,
                            label: 'Настройки',
                            onTap: _showWalkSettingsSheet,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.my_location_outlined,
                            label: 'Центр',
                            onTap: _reset,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.photo_camera_outlined,
                            label: 'Фото',
                            onTap: _showRenderSheet,
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.view_in_ar_outlined,
                            label: 'Обзор',
                            selected: true,
                            onTap: _reset,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.directions_walk,
                            label: 'Прогулка',
                            onTap: _toggleWalk,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.layers_clear_outlined,
                            label: 'Разрез',
                            selected: _cutaway,
                            onTap: () => setState(() => _cutaway = !_cutaway),
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.vertical_align_top,
                            label: 'Сверху',
                            onTap: _topView,
                          ),
                        ),
                        Expanded(
                          child: ZToolAction(
                            icon: Icons.photo_camera_outlined,
                            label: 'Фото',
                            onTap: _showRenderSheet,
                          ),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalkJoystick extends StatefulWidget {
  const _WalkJoystick({required this.onStep});

  final void Function(double forward, double sideways) onStep;

  @override
  State<_WalkJoystick> createState() => _WalkJoystickState();
}

class _WalkJoystickState extends State<_WalkJoystick> {
  Timer? _timer;
  Offset _vector = Offset.zero;
  static const double _radius = 58;

  void _update(Offset local) {
    final delta = local - const Offset(70, 70);
    final distance = delta.distance;
    final clamped = distance > _radius && distance > 0
        ? delta * (_radius / distance)
        : delta;
    setState(() => _vector = clamped / _radius);
  }

  void _emitStep() {
    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);
    if (input.forward == 0 && input.sideways == 0) return;
    widget.onStep(input.forward, input.sideways);
  }

  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    _emitStep();
    _timer = Timer.periodic(
      const Duration(milliseconds: 48),
      (_) => _emitStep(),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _vector = Offset.zero);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 140,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _start(event.localPosition),
        onPointerMove: (event) => _update(event.localPosition),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: CustomPaint(
          painter: _JoystickPainter(
            vector: _vector,
            baseColor: ZamerColors.surfaceHighest.withValues(alpha: .88),
            ringColor: ZamerColors.outline,
            knobColor: ZamerColors.accent,
            iconColor: ZamerColors.accentInk,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({
    required this.vector,
    required this.baseColor,
    required this.ringColor,
    required this.knobColor,
    required this.iconColor,
  });

  final Offset vector;
  final Color baseColor, ringColor, knobColor, iconColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * .42;
    canvas.drawCircle(center, baseRadius, Paint()..color = baseColor);
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      baseRadius * 0.18,
      Paint()
        ..color = ringColor.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final knob = center + vector * baseRadius;
    canvas.drawCircle(knob, 25, Paint()..color = knobColor);
    final arrow = Paint()
      ..color = iconColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      knob + const Offset(0, 8),
      knob - const Offset(0, 8),
      arrow,
    );
    canvas.drawLine(
      knob - const Offset(0, 8),
      knob + const Offset(-5, -2),
      arrow,
    );
    canvas.drawLine(
      knob - const Offset(0, 8),
      knob + const Offset(5, -2),
      arrow,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.vector != vector ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.knobColor != knobColor ||
      oldDelegate.iconColor != iconColor;
}

class _HoldMoveButton extends StatefulWidget {
  const _HoldMoveButton({
    required this.icon,
    required this.tooltip,
    required this.onStep,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onStep;
  final bool primary;

  @override
  State<_HoldMoveButton> createState() => _HoldMoveButtonState();
}

class _HoldMoveButtonState extends State<_HoldMoveButton> {
  Timer? _timer;

  void _start() {
    _timer?.cancel();
    widget.onStep();
    _timer = Timer.periodic(
      const Duration(milliseconds: 72),
      (_) => widget.onStep(),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: widget.primary
                ? ZamerColors.accent
                : ZamerColors.surfaceHighest,
            borderRadius: BorderRadius.circular(ZamerRadius.lg),
            border: Border.all(
              color: widget.primary ? ZamerColors.accent : ZamerColors.outline,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            color: widget.primary
                ? ZamerColors.accentInk
                : ZamerColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
