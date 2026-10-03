import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../renderer3d/zamer_gpu_viewport.dart';
import '../services/walk_input_service.dart';
import '../services/walk_navigation_service.dart';
import 'photo_studio_screen.dart';

class Master3DScreen extends StatefulWidget {
  const Master3DScreen({
    super.key,
    required this.floor,
    required this.projectTitle,
    required this.onOpen2D,
    this.onOpenAr,
    this.onBack,
  });

  final FloorPlan floor;
  final String projectTitle;
  final VoidCallback onOpen2D;
  final VoidCallback? onOpenAr;
  final VoidCallback? onBack;

  @override
  State<Master3DScreen> createState() => _Master3DScreenState();
}

class _Master3DScreenState extends State<Master3DScreen> {
  double _rotation = -.65;
  double _tilt = .82;
  double _zoom = .92;
  Offset _pan = Offset.zero;
  double _gestureZoom = .92;
  Offset _gesturePan = Offset.zero;
  Offset _gestureFocal = Offset.zero;
  int _gesturePointers = 0;

  bool _walk = false;
  bool _noclip = false;
  bool _cutaway = true;
  bool _hideWalls = false;
  bool _perspective = true;
  int _lightMode = 0;
  int _qualityMode = 1;
  double _walkX = 0;
  double _walkY = 0;
  double _walkSpeedMmPerSecond = 2500;
  double _overviewRotation = -.65;
  double _overviewTilt = .82;
  double _overviewZoom = .92;
  Offset _overviewPan = Offset.zero;

  @override
  void initState() {
    super.initState();
    final start = WalkNavigationService.startingPoint(widget.floor);
    _walkX = start.x;
    _walkY = start.y;
  }

  void _resetOverview() => setState(() {
        _walk = false;
        _rotation = -.65;
        _tilt = .82;
        _zoom = .92;
        _pan = Offset.zero;
      });

  void _toggleWalk() => setState(() {
        if (!_walk) {
          _overviewRotation = _rotation;
          _overviewTilt = _tilt;
          _overviewZoom = _zoom;
          _overviewPan = _pan;
          final start = WalkNavigationService.startingPoint(widget.floor);
          _walkX = start.x;
          _walkY = start.y;
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
        _walk = !_walk;
      });

  void _centerWalk() => setState(() {
        final start = WalkNavigationService.startingPoint(widget.floor);
        _walkX = start.x;
        _walkY = start.y;
        _rotation = WalkNavigationService.startingRotation(
          widget.floor,
          math.Point(_walkX, _walkY),
        );
        _tilt = 0;
      });

  void _walkStep(double forward, double sideways) {
    final next = WalkNavigationService.advance(
      widget.floor,
      math.Point(_walkX, _walkY),
      _rotation,
      forward,
      sideways,
      ignoreCollisions: _noclip,
    );
    if (next.x == _walkX && next.y == _walkY) return;
    setState(() {
      _walkX = next.x;
      _walkY = next.y;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureZoom = _zoom;
    _gesturePan = _pan;
    _gestureFocal = details.focalPoint;
    _gesturePointers = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != _gesturePointers) {
      _gesturePointers = details.pointerCount;
      _gestureZoom = _zoom / math.max(.001, details.scale);
      _gesturePan = _pan;
      _gestureFocal = details.focalPoint;
      return;
    }
    setState(() {
      if (details.pointerCount >= 2) {
        _zoom = (_gestureZoom * details.scale)
            .clamp(_walk ? .7 : .2, _walk ? 1.4 : 8.0)
            .toDouble();
        if (!_walk) _pan = _gesturePan + (details.focalPoint - _gestureFocal);
      } else {
        _rotation += details.focalPointDelta.dx * .010;
        _tilt = (_tilt - details.focalPointDelta.dy * .006)
            .clamp(_walk ? -.7 : .22, _walk ? .7 : 1.48)
            .toDouble();
      }
    });
  }

  ZamerPhotoTime get _photoTime => switch (_lightMode) {
        1 => ZamerPhotoTime.evening,
        2 => ZamerPhotoTime.night,
        _ => ZamerPhotoTime.day,
      };

  Future<void> _openRender() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoStudioScreen(
          floor: widget.floor,
          rotation: _rotation,
          tilt: _tilt,
          zoom: _zoom,
          pan: _pan,
          cameraOriginXMm: _walk ? _walkX : null,
          cameraOriginYMm: _walk ? _walkY : null,
        ),
      ),
    );
  }

  void _openAr() {
    final callback = widget.onOpenAr;
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AR пока не подключён к production-сборке')),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ZMasterSectionTitle('Настройки просмотра'),
                const SizedBox(height: 12),
                ZMasterPanel(
                  child: Column(
                    children: [
                      _SettingsRow(
                        label: 'Тип камеры',
                        child: ZMasterSegmentedControl(
                          labels: const ['Перспектива', 'Узкий угол'],
                          selectedIndex: _perspective ? 0 : 1,
                          onSelected: (index) {
                            setState(() => _perspective = index == 0);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Скрывать стены',
                        child: Switch.adaptive(
                          value: _hideWalls,
                          onChanged: (value) {
                            setState(() => _hideWalls = value);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Разрез помещения',
                        child: Switch.adaptive(
                          value: _cutaway,
                          onChanged: (value) {
                            setState(() => _cutaway = value);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Время суток',
                        child: ZMasterSegmentedControl(
                          labels: const ['День', 'Вечер', 'Ночь'],
                          selectedIndex: _lightMode,
                          onSelected: (index) {
                            setState(() => _lightMode = index);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Качество рендера',
                        child: ZMasterSegmentedControl(
                          labels: const ['Быстро', 'Стандартно', 'Высоко'],
                          selectedIndex: _qualityMode,
                          onSelected: (index) {
                            setState(() => _qualityMode = index);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      if (_walk) ...[
                        const SizedBox(height: 12),
                        _SettingsRow(
                          label: 'Скорость',
                          child: Slider(
                            value: _walkSpeedMmPerSecond,
                            min: 800,
                            max: 4500,
                            divisions: 37,
                            onChanged: (value) {
                              setState(() => _walkSpeedMmPerSecond = value);
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openRender();
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Открыть рендер'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZMasterSectionTitle('Слои'),
              const SizedBox(height: 12),
              ZMasterPanel(
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.visibility_off_outlined,
                      label: 'Скрывать стены',
                      value: _hideWalls,
                      onChanged: (value) => setState(() => _hideWalls = value),
                    ),
                    const Divider(),
                    _ToggleRow(
                      icon: Icons.content_cut_rounded,
                      label: 'Разрез помещения',
                      value: _cutaway,
                      onChanged: (value) => setState(() => _cutaway = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLightMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZMasterSectionTitle('Режим освещения'),
              const SizedBox(height: 12),
              ZMasterSegmentedControl(
                labels: const ['День', 'Вечер', 'Ночь'],
                selectedIndex: _lightMode,
                onSelected: (index) {
                  setState(() => _lightMode = index);
                  Navigator.pop(sheetContext);
                },
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
      return ColoredBox(
        color: ZamerColors.background,
        child: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: widget.projectTitle,
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
              ),
              const Expanded(child: Center(child: Text('3D пока пуст. Построй стены в «Замере».'))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.projectTitle,
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: _showSettings,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ZMasterSegmentedControl(
                labels: const ['2D', '3D', 'AR'],
                selectedIndex: 1,
                onSelected: (index) {
                  if (index == 0) widget.onOpen2D();
                  if (index == 2) _openAr();
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ZamerGpuViewport(
                          floor: widget.floor,
                          rotation: _rotation,
                          tilt: _tilt,
                          zoom: _zoom,
                          cutaway: !_walk && (_hideWalls || _cutaway),
                          pan: _pan,
                          walkMode: _walk,
                          walkX: _walkX,
                          walkY: _walkY,
                          performanceMode: _qualityMode == 0,
                          photoPreview: _lightMode != 0 || _qualityMode == 2,
                          photoTime: _photoTime,
                          photoHdr: true,
                          cameraFovDegrees: _perspective ? 46 : 24,
                        ),
                      ),
                      if (_walk)
                        const IgnorePointer(
                          child: Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(color: ZamerColors.accent, width: 1.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 14,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: ZamerColors.surface.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ZamerColors.outline),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ZMasterVerticalToolButton(
                                icon: Icons.light_mode_outlined,
                                tooltip: 'Свет',
                                onTap: _showLightMenu,
                              ),
                              ZMasterVerticalToolButton(
                                icon: Icons.view_in_ar_outlined,
                                tooltip: 'Перспектива',
                                selected: _perspective,
                                onTap: () => setState(() => _perspective = !_perspective),
                              ),
                              ZMasterVerticalToolButton(
                                icon: Icons.layers_outlined,
                                tooltip: 'Слои',
                                onTap: _showLayers,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_walk)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: _WalkJoystick(
                            onStep: (forward, sideways, deltaSeconds) => _walkStep(
                              forward * _walkSpeedMmPerSecond * deltaSeconds,
                              sideways * _walkSpeedMmPerSecond * deltaSeconds,
                            ),
                          ),
                        )
                      else
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: IconButton.filledTonal(
                            tooltip: 'Сбросить обзор',
                            onPressed: _resetOverview,
                            icon: const Icon(Icons.open_with_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ZMasterPanel(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: _walk
                      ? [
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.home_outlined,
                              label: 'Обзор',
                              onTap: _toggleWalk,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.blur_on,
                              label: 'Сквозь',
                              selected: _noclip,
                              onTap: () => setState(() => _noclip = !_noclip),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.my_location_outlined,
                              label: 'Центр',
                              onTap: _centerWalk,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.camera_alt_outlined,
                              label: 'Рендер',
                              onTap: _openRender,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.settings_outlined,
                              label: 'Настройки',
                              onTap: _showSettings,
                              compact: true,
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.open_with_rounded,
                              label: 'Обзор',
                              selected: true,
                              onTap: _resetOverview,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.directions_walk_rounded,
                              label: 'Прогулка',
                              onTap: _toggleWalk,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.view_in_ar_outlined,
                              label: 'Разрез',
                              selected: _cutaway,
                              onTap: () => setState(() => _cutaway = !_cutaway),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.visibility_off_outlined,
                              label: 'Скрыть',
                              selected: _hideWalls,
                              onTap: () => setState(() => _hideWalls = !_hideWalls),
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ZMasterToolButton(
                              icon: Icons.settings_outlined,
                              label: 'Настройки',
                              onTap: _showSettings,
                              compact: true,
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
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 116, child: Text(label, style: ZamerTypography.bodySmall)),
          Expanded(child: child),
        ],
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: ZamerTypography.bodySmall)),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      );
}

class _WalkJoystick extends StatefulWidget {
  const _WalkJoystick({required this.onStep});

  final void Function(double forward, double sideways, double deltaSeconds) onStep;

  @override
  State<_WalkJoystick> createState() => _WalkJoystickState();
}

class _WalkJoystickState extends State<_WalkJoystick> {
  static const double _radius = 48;
  static const Duration _frameInterval = Duration(milliseconds: 16);
  Timer? _timer;
  Offset _vector = Offset.zero;
  final Stopwatch _clock = Stopwatch();
  int? _lastFrameMicros;

  void _update(Offset local) {
    final delta = local - const Offset(58, 58);
    final distance = delta.distance;
    final clamped = distance > _radius && distance > 0
        ? delta * (_radius / distance)
        : delta;
    setState(() => _vector = clamped / _radius);
  }

  void _emit() {
    final now = _clock.elapsedMicroseconds;
    final previous = _lastFrameMicros;
    _lastFrameMicros = now;
    final elapsed = previous == null ? _frameInterval.inMicroseconds : now - previous;
    final deltaSeconds = (elapsed / Duration.microsecondsPerSecond).clamp(1 / 240, .05).toDouble();
    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);
    if (input.forward == 0 && input.sideways == 0) return;
    widget.onStep(input.forward, input.sideways, deltaSeconds);
  }

  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    _clock
      ..reset()
      ..start();
    _lastFrameMicros = null;
    _emit();
    _timer = Timer.periodic(_frameInterval, (_) => _emit());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _lastFrameMicros = null;
    if (mounted) setState(() => _vector = Offset.zero);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 116,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _start(event.localPosition),
          onPointerMove: (event) => _update(event.localPosition),
          onPointerUp: (_) => _stop(),
          onPointerCancel: (_) => _stop(),
          child: CustomPaint(painter: _JoystickPainter(vector: _vector)),
        ),
      );
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({required this.vector});
  final Offset vector;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide * .42;
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()..color = ZamerColors.surfaceHighest.withValues(alpha: .88),
    );
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = ZamerColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final knob = center + Offset(vector.dx, vector.dy) * (baseRadius * .72);
    canvas.drawCircle(knob, 21, Paint()..color = ZamerColors.accent);
    final icon = TextPainter(
      text: const TextSpan(
        text: '↑',
        style: TextStyle(
          color: ZamerColors.accentInk,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, knob - Offset(icon.width / 2, icon.height / 2));
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) => oldDelegate.vector != vector;
}
