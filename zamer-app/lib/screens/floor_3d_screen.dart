import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../renderer3d/zamer_gpu_viewport.dart';
import '../services/walk_input_service.dart';
import '../services/walk_navigation_service.dart';

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
  bool _rendering = false;
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

  Future<void> _exportRender({
    required int width,
    required int height,
    required String label,
  }) async {
    if (_rendering) return;
    final renderer = _gpuKey.currentState;
    if (renderer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('3D-сцена ещё не готова.')));
      return;
    }
    setState(() => _rendering = true);
    try {
      final png = await renderer.renderPng(
        width: width,
        height: height,
        photoQuality: true,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/zamer-render-${DateTime.now().millisecondsSinceEpoch}-${width}x$height.png',
      );
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: Text('$label • Photo Render'),
                  actions: [
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFF090E11),
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          png,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Вернуться в 3D'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Share.shareXFiles([
                            XFile(file.path),
                          ], text: '$label • фоторендер «Замер»'),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Сохранить кадр'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать рендер: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _showRenderSheet() async {
    if (_rendering) return;
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height >= size.width;
    final hdWidth = portrait ? 1080 : 1920;
    final hdHeight = portrait ? 1920 : 1080;
    final twoKWidth = portrait ? 1440 : 2560;
    final twoKHeight = portrait ? 2560 : 1440;
    final fourKWidth = portrait ? 2160 : 3840;
    final fourKHeight = portrait ? 3840 : 2160;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E161B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2A3941))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43515A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A211B),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF5A4332)),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Color(0xFFF1C79E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Рендер / Фото',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Финальный GPU-кадр без интерфейса',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _PhotoBadge(),
                ],
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RenderFeatureChip(label: 'PBR'),
                  _RenderFeatureChip(label: 'AO'),
                  _RenderFeatureChip(label: 'Мягкие тени'),
                  _RenderFeatureChip(label: 'Отражения'),
                  _RenderFeatureChip(label: 'Цветокоррекция'),
                ],
              ),
              const SizedBox(height: 14),
              _RenderPresetTile(
                title: 'HD',
                subtitle: '${hdWidth} × ${hdHeight} • быстрый просмотр',
                icon: Icons.hd_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(width: hdWidth, height: hdHeight, label: 'HD');
                },
              ),
              _RenderPresetTile(
                title: '2K',
                subtitle: '${twoKWidth} × ${twoKHeight} • презентация',
                icon: Icons.image_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(
                    width: twoKWidth,
                    height: twoKHeight,
                    label: '2K',
                  );
                },
              ),
              _RenderPresetTile(
                title: '4K Photo',
                subtitle: '${fourKWidth} × ${fourKHeight} • максимум качества',
                icon: Icons.high_quality_outlined,
                accent: true,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(
                    width: fourKWidth,
                    height: fourKHeight,
                    label: '4K',
                  );
                },
              ),
              const SizedBox(height: 4),
              const Text(
                '4K формируется рендерером в целевом разрешении. Это не увеличение скриншота.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Color(0xFF7F8B91)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWalkSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Настройки прогулки',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.speed, size: 19),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
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
                const SizedBox(height: 6),
                const Text(
                  'Левый стик отвечает только за движение. Осмотр выполняется одним пальцем прямо по сцене.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A0A6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.floor.walls.isEmpty) {
      return const Center(child: Text('Построй стены, чтобы увидеть 3D.'));
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
                              BorderSide(color: Color(0xCCF1C79E), width: 1.4),
                            ),
                          ),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFF1C79E),
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
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD9111A1F),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF2A3941)),
              ),
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
          bottom: 8,
          child: SafeArea(
            top: false,
            child: Card(
              elevation: 0,
              color: const Color(0xF5111A1F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2A3941)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: Row(
                  children: _walkMode
                      ? [
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.home_outlined,
                              label: 'Обзор',
                              onTap: _toggleWalk,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.blur_on,
                              label: 'Сквозь',
                              selected: _noclip,
                              onTap: () => setState(() => _noclip = !_noclip),
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.tune_rounded,
                              label: 'Настройки',
                              onTap: _showWalkSettingsSheet,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.my_location_outlined,
                              label: 'Центр',
                              onTap: _reset,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: _rendering
                                  ? Icons.hourglass_top_rounded
                                  : Icons.photo_camera_outlined,
                              label: 'Фото',
                              onTap: _rendering ? null : _showRenderSheet,
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.view_in_ar_outlined,
                              label: 'Обзор',
                              selected: true,
                              onTap: _reset,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.directions_walk,
                              label: 'Прогулка',
                              onTap: _toggleWalk,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.layers_clear_outlined,
                              label: 'Разрез',
                              selected: _cutaway,
                              onTap: () => setState(() => _cutaway = !_cutaway),
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.vertical_align_top,
                              label: 'Сверху',
                              onTap: _topView,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: _rendering
                                  ? Icons.hourglass_top_rounded
                                  : Icons.photo_camera_outlined,
                              label: 'Фото',
                              onTap: _rendering ? null : _showRenderSheet,
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SceneAction extends StatelessWidget {
  const _SceneAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF22170F)
        : const Color(0xFFD7DDDF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? const Color(0xFFF1C79E) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
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
            baseColor: scheme.surfaceContainerHighest,
            ringColor: scheme.outlineVariant,
            knobColor: scheme.primaryContainer,
            iconColor: scheme.onPrimaryContainer,
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
    final scheme = Theme.of(context).colorScheme;
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
                ? scheme.primaryContainer
                : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            color: widget.primary
                ? scheme.onPrimaryContainer
                : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF20352C),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF345A49)),
    ),
    child: const Text(
      'PHOTO',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: Color(0xFF8AC8AE),
      ),
    ),
  );
}

class _RenderFeatureChip extends StatelessWidget {
  const _RenderFeatureChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF141E23),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF26363E)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFFB9C2C6),
      ),
    ),
  );
}

class _RenderPresetTile extends StatelessWidget {
  const _RenderPresetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: accent ? const Color(0xFF2A211B) : const Color(0xFF141E23),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: accent ? const Color(0xFF6C503A) : const Color(0xFF26363E),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent
                      ? const Color(0xFFF1C79E)
                      : const Color(0xFF1D2A30),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: accent
                      ? const Color(0xFF22170F)
                      : const Color(0xFFD7DDDF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF8C989D),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: accent
                    ? const Color(0xFFF1C79E)
                    : const Color(0xFF758187),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
