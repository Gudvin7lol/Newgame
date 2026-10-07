import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../renderer3d/render_quality.dart';
import '../renderer3d/zamer_gpu_viewport.dart';
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
  double _walkFovDeg = 76;
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
  ZamerRenderQuality _renderQuality = ZamerRenderQuality.quality;
  final GlobalKey<ZamerGpuViewportState> _gpuKey =
      GlobalKey<ZamerGpuViewportState>();

  @override
  void initState() {
    super.initState();
    if (widget.floor.id == 'benchmark-floor') {
      _walkMode = true;
      _cutaway = false;
      _walkX = 3400;
      _walkY = 900;
      _rotation = 1.13;
      _tilt = -0.10;
      _zoom = 1;
      _walkFovDeg = 76;
    }
  }

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
        final angle = _rotation + d.focalPointDelta.dx * 0.010;
        _rotation = math.atan2(math.sin(angle), math.cos(angle));
        _tilt = (_tilt - d.focalPointDelta.dy * 0.006)
            .clamp(_walkMode ? -1.35 : 0.22, _walkMode ? 1.20 : 1.48)
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3D-сцена ещё не готова.')),
      );
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
                  title: Text('$label • финальный рендер'),
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
                    color: const Color(0xFF111416),
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
                          label: const Text('В 3D'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Share.shareXFiles(
                            [XFile(file.path)],
                            text: '$label • фоторендер «Замер»',
                          ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Сохранить / поделиться'),
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Финальный рендер',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Это отдельный GPU-рендер, а не увеличенный скриншот. '
                'Для финального кадра включаются PBR-материалы, полноразмерный AO, '
                'отражения, мягкие тени 2048 px, emissive-свет и цветокоррекция. '
                'После расчёта откроется полноэкранный предпросмотр без интерфейса.',
              ),
              const SizedBox(height: 14),
              _RenderPresetTile(
                title: 'HD',
                subtitle: '1920 × 1080 • быстро',
                icon: Icons.hd_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(width: 1920, height: 1080, label: 'HD');
                },
              ),
              _RenderPresetTile(
                title: '2K',
                subtitle: '2560 × 1440 • презентация',
                icon: Icons.image_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(width: 2560, height: 1440, label: '2K');
                },
              ),
              _RenderPresetTile(
                title: '4K',
                subtitle: '3840 × 2160 • максимальное качество',
                icon: Icons.high_quality_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(width: 3840, height: 2160, label: '4K');
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
    if (widget.floor.walls.isEmpty)
      return const Center(child: Text('Построй стены, чтобы увидеть 3D.'));
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: ClipRect(
              child: ZamerGpuViewport(
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
                walkFovDegrees: _walkFovDeg,
                quality: _renderQuality,
              ),
            ),
          ),
        ),
        if (_walkMode)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _toggleWalk,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Общий вид'),
                      ),
                      const Spacer(),
                      FilterChip(
                        selected: _noclip,
                        onSelected: (value) => setState(() => _noclip = value),
                        avatar: const Icon(Icons.blur_on, size: 18),
                        label: const Text('Сквозь стены'),
                      ),
                      IconButton(
                        onPressed: _reset,
                        tooltip: 'В центр комнаты',
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: _WalkJoystick(
                          onStep: (forward, sideways) => _walk(
                            forward * _walkStepMm,
                            sideways * _walkStepMm,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Правая часть сцены — осмотр. Левый стик — плавное движение.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.speed, size: 18),
                                Expanded(
                                  child: Slider(
                                    value: _walkStepMm,
                                    min: 55,
                                    max: 220,
                                    divisions: 11,
                                    label: '${_walkStepMm.round()} мм',
                                    onChanged: (v) =>
                                        setState(() => _walkStepMm = v),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 42,
                                  child: Text(
                                    'FOV',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _walkFovDeg,
                                    min: 55,
                                    max: 100,
                                    divisions: 9,
                                    label: '${_walkFovDeg.round()}°',
                                    onChanged: (v) =>
                                        setState(() => _walkFovDeg = v),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    '${_walkFovDeg.round()}°',
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            _RealtimeQualitySelector(
                              value: _renderQuality,
                              onChanged: (value) =>
                                  setState(() => _renderQuality = value),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.tonalIcon(
                              onPressed: _rendering ? null : _showRenderSheet,
                              icon: const Icon(Icons.high_quality_outlined),
                              label: const Text('Photo 4K / рендер'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rotate_right),
                      Expanded(
                        child: Slider(
                          value: _rotation,
                          min: -math.pi,
                          max: math.pi,
                          onChanged: (v) => setState(() => _rotation = v),
                        ),
                      ),
                      IconButton(
                        onPressed: _reset,
                        tooltip: '3/4 сверху',
                        icon: const Icon(Icons.restart_alt),
                      ),
                      IconButton(
                        onPressed: _topView,
                        tooltip: 'Вид сверху',
                        icon: const Icon(Icons.vertical_align_top),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.zoom_out_map),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          min: 0.15,
                          max: 10.0,
                          onChanged: (v) => setState(() => _zoom = v),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _toggleWalk,
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Прогулка'),
                        ),
                        const SizedBox(width: 8),
                        _RealtimeQualitySelector(
                          value: _renderQuality,
                          onChanged: (value) =>
                              setState(() => _renderQuality = value),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile.adaptive(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _cutaway,
                          onChanged: (v) => setState(() => _cutaway = v),
                          title: const Text('Открытая комната'),
                          subtitle: const Text(
                            'Скрываются наружные стены со стороны камеры.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _rendering ? null : _showRenderSheet,
                        icon: _rendering
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.high_quality_outlined),
                        label: const Text('Рендер'),
                      ),
                    ],
                  ),
                  Text(
                    '1 палец — вращение/наклон. 2 пальца — перемещение и масштаб.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF68717D)),
                  ),
                ],
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

  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    widget.onStep(-_vector.dy, _vector.dx);
    _timer = Timer.periodic(const Duration(milliseconds: 48), (_) {
      if (_vector.distance < 0.08) return;
      final strength = _vector.distance.clamp(0.0, 1.0).toDouble();
      widget.onStep(
        -_vector.dy * strength,
        _vector.dx * strength,
      );
    });
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
    final knob = center + vector * baseRadius;
    canvas.drawCircle(knob, 25, Paint()..color = knobColor);
    final arrow = Paint()
      ..color = iconColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(knob + const Offset(0, 8), knob - const Offset(0, 8), arrow);
    canvas.drawLine(knob - const Offset(0, 8), knob + const Offset(-5, -2), arrow);
    canvas.drawLine(knob - const Offset(0, 8), knob + const Offset(5, -2), arrow);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.vector != vector ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.knobColor != knobColor;
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




class _RealtimeQualitySelector extends StatelessWidget {
  const _RealtimeQualitySelector({
    required this.value,
    required this.onChanged,
  });

  final ZamerRenderQuality value;
  final ValueChanged<ZamerRenderQuality> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ZamerRenderQuality>(
        segments: const <ButtonSegment<ZamerRenderQuality>>[
          ButtonSegment(
            value: ZamerRenderQuality.performance,
            label: Text('Быстро'),
            icon: Icon(Icons.speed),
          ),
          ButtonSegment(
            value: ZamerRenderQuality.quality,
            label: Text('Качество'),
            icon: Icon(Icons.auto_awesome),
          ),
        ],
        selected: <ZamerRenderQuality>{value},
        showSelectedIcon: false,
        onSelectionChanged: (selected) {
          if (selected.isNotEmpty) onChanged(selected.first);
        },
      );
}

class _RenderPresetTile extends StatelessWidget {
  const _RenderPresetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
