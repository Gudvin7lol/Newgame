import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/plan_viewport_link.dart';
import '../widgets/cad_plan_painter.dart';
import '../widgets/floor_finish_plan_overlay.dart';
import 'layouts_screen.dart';

/// Floor layout editor presented on the same measured plan used by Measure.
class MeasureFloorPlanLayerScreen extends StatefulWidget {
  const MeasureFloorPlanLayerScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.sharedViewport,
    this.viewportActive = true,
    this.fanCommand,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final ValueNotifier<PlanViewportSnapshot?>? sharedViewport;
  final bool viewportActive;
  final ValueNotifier<String?>? fanCommand;

  @override
  State<MeasureFloorPlanLayerScreen> createState() =>
      _MeasureFloorPlanLayerScreenState();
}

class _MeasureFloorPlanLayerScreenState
    extends State<MeasureFloorPlanLayerScreen> {
  static const _canvasSize = Size(7000, 12000);
  static const _origin = Offset(3300, 1100);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  String? _selectedFaceKey;
  bool _placingLayoutStart = false;
  bool _centered = false;
  Size _viewport = Size.zero;

  List<RoomFace> get _faces => GeometryService.roomFaces(widget.floor);

  RoomFace? get _selectedFace {
    if (_selectedFaceKey == null) return null;
    for (final face in _faces) {
      if (face.key == _selectedFaceKey) return face;
    }
    return null;
  }

  RoomMeta? get _selectedMeta {
    final face = _selectedFace;
    return face == null ? null : widget.floor.roomMetaByKey(face.key);
  }

  @override
  void initState() {
    super.initState();
    widget.fanCommand?.addListener(_handleFanCommand);
    GeometryService.syncRoomMetadata(widget.floor);
    if (_faces.isNotEmpty) _selectedFaceKey = _faces.first.key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.viewportActive && widget.sharedViewport?.value != null) {
        _adoptViewport();
      } else {
        _fit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MeasureFloorPlanLayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fanCommand != widget.fanCommand) {
      oldWidget.fanCommand?.removeListener(_handleFanCommand);
      widget.fanCommand?.addListener(_handleFanCommand);
    }
    if (widget.viewportActive && (!oldWidget.viewportActive ||
        oldWidget.sharedViewport != widget.sharedViewport)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _adoptViewport());
    }
  }

  @override
  void dispose() {
    widget.fanCommand?.removeListener(_handleFanCommand);
    _transform.dispose();
    super.dispose();
  }

  Future<void> _handleFanCommand() async {
    final raw = widget.fanCommand?.value;
    if (raw == null) return;
    final separator = raw.lastIndexOf(':');
    final command = separator < 0 ? raw : raw.substring(separator + 1);
    switch (command) {
      case 'select':
        if (_placingLayoutStart && mounted) {
          setState(() => _placingLayoutStart = false);
        }
        break;
      case 'start':
        if (mounted) {
          setState(() => _placingLayoutStart = !_placingLayoutStart);
        }
        break;
      case 'direction':
        await _rotate(90);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              duration: Duration(milliseconds: 900),
              content: Text('Направление раскладки повернуто на 90°'),
            ));
        }
    }
  }

  math.Point<double> _toMm(Offset p) => math.Point<double>(
        (p.dx - _origin.dx) / _mmToPx,
        (p.dy - _origin.dy) / _mmToPx,
      );

  bool _pointInPolygon(
    math.Point<double> point,
    List<math.Point<double>> polygon,
  ) {
    if (polygon.length < 3) return false;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.y > point.y) != (b.y > point.y)) {
        final divisor = (b.y - a.y).abs() < .000001 ? .000001 : b.y - a.y;
        final x = (b.x - a.x) * (point.y - a.y) / divisor + a.x;
        if (point.x < x) inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  double _phase(double v, double step) {
    final unit = math.max(1.0, step);
    return (v % unit + unit) % unit;
  }

  Future<void> _selectAt(Offset canvasPoint) async {
    final mm = _toMm(canvasPoint);
    for (final face in _faces) {
      if (!_pointInPolygon(mm, face.innerPolygon)) continue;
      if (_placingLayoutStart) {
        final settings = widget.floor.roomMetaByKey(face.key)?.materials;
        if (settings != null) {
          // A room-local minimum changes when the plan geometry is edited.
          // Save the phase against world zero so the same board/tile remains
          // under the user's chosen start marker in every screen.
          settings.laminateOffsetXMm =
              _phase(mm.x, settings.laminatePlankLengthMm);
          settings.laminateOffsetYMm =
              _phase(mm.y, settings.laminatePlankWidthMm);
          settings.tileOffsetXMm =
              _phase(mm.x, settings.tileWidthMm);
          settings.tileOffsetYMm =
              _phase(mm.y, settings.tileHeightMm);
          // Persist the actual chosen point, not just the repeated
          // grid phase. Reopening the project must restore the marker.
          settings.floorLayoutStartXMm = mm.x;
          settings.floorLayoutStartYMm = mm.y;
          setState(() {
            _selectedFaceKey = face.key;
            _placingLayoutStart = false;
          });
          await widget.onChanged();
          return;
        }
      }
      setState(() => _selectedFaceKey = face.key);
      return;
    }
  }


  void _publishViewport() {
    if (!widget.viewportActive) return;
    final link = widget.sharedViewport;
    if (link == null) return;
    final snapshot = PlanViewportSnapshot.capture(
      viewport: _viewport, origin: _origin,
      mmToPx: _mmToPx, transform: _transform.value);
    if (snapshot == null) return;
    if (link.value case final previous?) {
      if (previous.nearlyEquals(snapshot)) return;
    }
    link.value = snapshot;
  }

  void _adoptViewport() {
    if (!mounted || !widget.viewportActive || _viewport.isEmpty) return;
    final saved = widget.sharedViewport?.value;
    if (saved == null) return;
    final matrix = saved.toCanvasTransform(
      viewport: _viewport, origin: _origin,
      mmToPx: _mmToPx, minScale: .22, maxScale: 6);
    if (matrix == null) return;
    _transform.value = matrix;
    setState(() => _centered = true);
  }

  void _fit() {
    if (_viewport.isEmpty || widget.floor.nodes.isEmpty) return;
    final minX = widget.floor.nodes.map((n) => n.xMm).reduce(math.min);
    final maxX = widget.floor.nodes.map((n) => n.xMm).reduce(math.max);
    final minY = widget.floor.nodes.map((n) => n.yMm).reduce(math.min);
    final maxY = widget.floor.nodes.map((n) => n.yMm).reduce(math.max);
    final width = math.max(1.0, (maxX - minX) * _mmToPx);
    final height = math.max(1.0, (maxY - minY) * _mmToPx);
    final usableW = math.max(160.0, _viewport.width - 48);
    final usableH = math.max(180.0, _viewport.height - 48);
    final scale = math.min(
      3.2,
      math.max(.28, math.min(usableW / width, usableH / height) * .92),
    );
    final center = _origin +
        Offset(
          (minX + maxX) * .5 * _mmToPx,
          (minY + maxY) * .5 * _mmToPx,
        );
    final target = Offset(_viewport.width / 2, _viewport.height / 2);
    _transform.value = Matrix4.identity()
      ..translate(target.dx - center.dx * scale, target.dy - center.dy * scale)
      ..scale(scale);
    if (mounted) setState(() => _centered = true);
    _publishViewport();
  }

  Future<void> _mutate(void Function(RoomMaterialSettings settings) change) async {
    final meta = _selectedMeta;
    if (meta == null) return;
    change(meta.materials);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _rotate(double delta) => _mutate((settings) {
        settings.floorDirectionDeg =
            (settings.floorDirectionDeg + delta) % 360;
      });

  Future<void> _setPattern(String pattern) => _mutate((settings) {
        settings.laminatePattern = pattern;
        settings.floorMode = 'laminate';
        settings.floorTile = false;
      });

  Future<void> _setFloorMode(String mode) => _mutate((settings) {
        settings.floorMode = mode;
        settings.floorTile = mode == 'tile';
      });

  Future<void> _openAdvanced() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Точная раскладка пола')),
          body: LayoutsScreen(
            floor: widget.floor,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final meta = _selectedMeta;
    final settings = meta?.materials;

    return ColoredBox(
      color: ZamerColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meta == null
                        ? 'Нажми на помещение'
                        : '${meta.name} • ${_selectedFace?.areaM2.toStringAsFixed(2)} м²',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.bodySmall.copyWith(
                      color: ZamerColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: _placingLayoutStart
                      ? 'Отменить выбор начальной точки'
                      : 'Указать начало укладки',
                  onPressed: () => setState(
                    () => _placingLayoutStart = !_placingLayoutStart),
                  icon: Icon(Icons.my_location_rounded,
                    color: _placingLayoutStart
                        ? ZamerColors.accent : null, size: 19),
                ),
                IconButton.filledTonal(
                  tooltip: 'Вписать план',
                  onPressed: _fit,
                  icon: Icon(
                    _centered
                        ? Icons.center_focus_strong
                        : Icons.center_focus_weak,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: _openAdvanced,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Точно'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('Ламинат'),
                  selected: settings?.floorMode != 'tile',
                  onSelected:
                      meta == null ? null : (_) => _setFloorMode('laminate'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Плитка'),
                  selected: settings?.floorMode == 'tile',
                  onSelected: meta == null ? null : (_) => _setFloorMode('tile'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: meta == null ? null : () => _rotate(-90),
                  icon: const Icon(Icons.rotate_left_rounded, size: 18),
                  label: const Text('-90°'),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: meta == null ? null : () => _rotate(90),
                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                  label: const Text('+90°'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Обычная'),
                  selected: settings?.laminatePattern != 'herringbone',
                  onSelected:
                      meta == null ? null : (_) => _setPattern('straight'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Ёлочка'),
                  selected: settings?.laminatePattern == 'herringbone',
                  onSelected:
                      meta == null ? null : (_) => _setPattern('herringbone'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = constraints.biggest;
                if (!_centered && widget.floor.nodes.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (widget.viewportActive && widget.sharedViewport?.value != null) {
                      _adoptViewport();
                    } else {
                      _fit();
                    }
                  });
                }
                return ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    onInteractionEnd: (_) => _publishViewport(),
                    minScale: .22,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(2400),
                    constrained: false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _selectAt(details.localPosition),
                      child: SizedBox(
                        width: _canvasSize.width,
                        height: _canvasSize.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: CadPlanPainter(
                                floor: widget.floor,
                                mmToPx: _mmToPx,
                                origin: _origin,
                                showGrid: true,
                                showDimensions: false,
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: FloorFinishPlanOverlayPainter(
                                  floor: widget.floor,
                                  mmToPx: _mmToPx,
                                  origin: _origin,
                                  selectedFaceKey: _selectedFaceKey,
                                  layoutStartMm: settings?.floorLayoutStartXMm != null &&
                                      settings?.floorLayoutStartYMm != null
                                      ? math.Point<double>(
                                          settings!.floorLayoutStartXMm!,
                                          settings.floorLayoutStartYMm!)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}
