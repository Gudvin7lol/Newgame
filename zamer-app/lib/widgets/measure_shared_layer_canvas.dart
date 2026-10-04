import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';
import 'cad_plan_painter.dart';

enum MeasureSharedLayer { objects, electrical, engineering }

class MeasureSharedLayerCanvas extends StatefulWidget {
  const MeasureSharedLayerCanvas({
    super.key,
    required this.floor,
    required this.layer,
    required this.onChanged,
    required this.onOpenCatalog,
    required this.onOpenAdvancedEditor,
  });

  final FloorPlan floor;
  final MeasureSharedLayer layer;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenAdvancedEditor;

  @override
  State<MeasureSharedLayerCanvas> createState() =>
      _MeasureSharedLayerCanvasState();
}

class _MeasureSharedLayerCanvasState extends State<MeasureSharedLayerCanvas> {
  static const _canvasSize = Size(7000, 12000);
  static const _origin = Offset(3300, 1100);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  Size _viewport = Size.zero;
  bool _initialFitDone = false;
  String? _selectedObjectId;
  String? _selectedElectricalId;
  String? _selectedRunId;
  int? _selectedRunVertex;
  math.Point<double>? _lastDragMm;
  bool _dragDirty = false;

  PlanObject? get _selectedObject {
    final id = _selectedObjectId;
    if (id == null) return null;
    for (final object in widget.floor.planObjects) {
      if (object.id == id) return object;
    }
    return null;
  }

  ElectricalPoint? get _selectedElectrical {
    final id = _selectedElectricalId;
    if (id == null) return null;
    for (final point in widget.floor.electricalPoints) {
      if (point.id == id) return point;
    }
    return null;
  }

  ServiceRun? get _selectedRun {
    final id = _selectedRunId;
    if (id == null) return null;
    for (final run in widget.floor.serviceRuns) {
      if (run.id == id) return run;
    }
    return null;
  }

  bool _isFixture(ElectricalPoint point) => point.id.startsWith('fixture:');

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  math.Point<double> _toMm(Offset canvasPoint) => math.Point<double>(
        (canvasPoint.dx - _origin.dx) / _mmToPx,
        (canvasPoint.dy - _origin.dy) / _mmToPx,
      );

  void _fit() {
    if (_viewport.isEmpty || widget.floor.nodes.isEmpty) return;
    final minX = widget.floor.nodes.map((n) => n.xMm).reduce(math.min);
    final maxX = widget.floor.nodes.map((n) => n.xMm).reduce(math.max);
    final minY = widget.floor.nodes.map((n) => n.yMm).reduce(math.min);
    final maxY = widget.floor.nodes.map((n) => n.yMm).reduce(math.max);
    final width = math.max(1.0, (maxX - minX) * _mmToPx);
    final height = math.max(1.0, (maxY - minY) * _mmToPx);
    final usableW = math.max(160.0, _viewport.width - 56);
    final usableH = math.max(180.0, _viewport.height - 96);
    final scale = math.min(
      3.4,
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
    if (mounted) setState(() {});
  }

  void _zoom(double factor) {
    if (_viewport.isEmpty) return;
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.28, 6.0).toDouble();
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translate(center.dx - scene.dx * next, center.dy - scene.dy * next)
      ..scale(next);
    setState(() {});
  }

  PlanObject? _objectNear(math.Point<double> p) {
    PlanObject? best;
    var bestScore = double.infinity;
    for (final object in widget.floor.planObjects.reversed) {
      final dx = object.xMm - p.x;
      final dy = object.yMm - p.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      final radius = math.max(
        180.0,
        math.sqrt(
              object.widthMm * object.widthMm +
                  object.depthMm * object.depthMm,
            ) /
            2,
      );
      if (distance <= radius + 100 && distance < bestScore) {
        bestScore = distance;
        best = object;
      }
    }
    return best;
  }

  ElectricalPoint? _electricalNear(math.Point<double> p) {
    ElectricalPoint? best;
    var bestDistance = 220.0;
    for (final point in widget.floor.electricalPoints) {
      final dx = point.xMm - p.x;
      final dy = point.yMm - p.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }
    return best;
  }

  ({ServiceRun run, int index})? _serviceVertexNear(math.Point<double> p) {
    ({ServiceRun run, int index})? best;
    var bestDistance = 220.0;
    for (final run in widget.floor.serviceRuns) {
      for (var i = 0; i < run.points.length; i++) {
        final point = run.points[i];
        final dx = point.xMm - p.x;
        final dy = point.yMm - p.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = (run: run, index: i);
        }
      }
    }
    return best;
  }

  void _tap(TapUpDetails details) {
    final mm = _toMm(details.localPosition);
    setState(() {
      if (widget.layer == MeasureSharedLayer.objects) {
        _selectedObjectId = _objectNear(mm)?.id;
      } else if (widget.layer == MeasureSharedLayer.electrical) {
        _selectedElectricalId = _electricalNear(mm)?.id;
      } else {
        final hit = _serviceVertexNear(mm);
        _selectedRunId = hit?.run.id;
        _selectedRunVertex = hit?.index;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedObjectId = null;
      _selectedElectricalId = null;
      _selectedRunId = null;
      _selectedRunVertex = null;
      _lastDragMm = null;
    });
  }

  void _dragStart(DragStartDetails details) {
    _dragDirty = false;
    final current = _toMm(details.localPosition);
    final canGrab = switch (widget.layer) {
      MeasureSharedLayer.objects => _objectNear(current)?.id == _selectedObjectId,
      MeasureSharedLayer.electrical =>
        _selectedElectrical != null &&
            !_isFixture(_selectedElectrical!) &&
            _electricalNear(current)?.id == _selectedElectricalId,
      MeasureSharedLayer.engineering =>
        _serviceVertexNear(current)?.run.id == _selectedRunId &&
            _serviceVertexNear(current)?.index == _selectedRunVertex,
    };
    _lastDragMm = canGrab ? current : null;
  }

  void _dragUpdate(DragUpdateDetails details) {
    final previous = _lastDragMm;
    if (previous == null) return;
    final current = _toMm(details.localPosition);
    final dx = current.x - previous.x;
    final dy = current.y - previous.y;
    _lastDragMm = current;

    if (widget.layer == MeasureSharedLayer.objects) {
      final object = _selectedObject;
      if (object == null) return;
      EquipmentPlacementService.moveBy(
        object,
        dxMm: dx,
        dyMm: dy,
        floor: widget.floor,
      );
      _dragDirty = true;
      setState(() {});
      return;
    }

    if (widget.layer == MeasureSharedLayer.electrical) {
      final point = _selectedElectrical;
      if (point == null || _isFixture(point)) return;
      _moveElectricalPoint(point, current);
      _dragDirty = true;
      setState(() {});
      return;
    }

    final run = _selectedRun;
    final index = _selectedRunVertex;
    if (run == null || index == null || index < 0 || index >= run.points.length) {
      return;
    }
    run.points[index].xMm += dx;
    run.points[index].yMm += dy;
    _dragDirty = true;
    setState(() {});
  }

  void _moveElectricalPoint(
    ElectricalPoint point,
    math.Point<double> raw,
  ) {
    if (!point.isWallDevice) {
      point.xMm = (raw.x / 10).round() * 10.0;
      point.yMm = (raw.y / 10).round() * 10.0;
      point.wallId = null;
      point.wallOffsetMm = null;
      return;
    }

    final hit = GeometryService.nearestWallProjection(
      widget.floor,
      raw,
      thresholdMm: 700,
    );
    if (hit == null) return;
    final wall = hit.wall;
    final a = widget.floor.nodeById(wall.startNodeId);
    final b = widget.floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final wallLength = widget.floor.wallLengthMm(wall);
    var offset = wallLength * hit.t;
    offset = _safeSwitchOffset(point, wall, offset, wallLength);
    final t = wallLength <= 0 ? 0.0 : (offset / wallLength).clamp(0.0, 1.0);
    point
      ..xMm = a.xMm + (b.xMm - a.xMm) * t
      ..yMm = a.yMm + (b.yMm - a.yMm) * t
      ..wallId = wall.id
      ..wallOffsetMm = offset
      ..wallSide = _wallSide(wall, raw, point.wallSide);
  }

  double _safeSwitchOffset(
    ElectricalPoint point,
    PlanWall wall,
    double offset,
    double wallLength,
  ) {
    final hasSwitch = point.type == ElectricalPointType.switchPoint ||
        point.modules.any(
          (module) =>
              module == ElectricalModuleType.switch1 ||
              module == ElectricalModuleType.switch2,
        );
    if (!hasSwitch) return offset.clamp(0.0, wallLength).toDouble();

    const clearance = 120.0;
    var safe = offset;
    for (final opening in wall.openings.where((o) => o.type == OpeningType.door)) {
      final before = opening.offsetFromStartMm - clearance;
      final after = opening.offsetFromStartMm + opening.widthMm + clearance;
      if (safe >= before && safe <= after) {
        final candidates = <double>[before - 1, after + 1]
            .where((v) => v >= clearance && v <= wallLength - clearance)
            .toList();
        if (candidates.isNotEmpty) {
          candidates.sort(
            (x, y) => (x - safe).abs().compareTo((y - safe).abs()),
          );
          safe = candidates.first;
        }
      }
    }
    return safe.clamp(0.0, wallLength).toDouble();
  }

  int _wallSide(
    PlanWall wall,
    math.Point<double> raw,
    int fallback,
  ) {
    final roomEdges = GeometryService.roomFaces(widget.floor)
        .expand((room) => room.edges)
        .where((edge) => edge.wallId == wall.id)
        .toList();
    if (roomEdges.length == 1) {
      return roomEdges.single.fromNodeId == wall.startNodeId ? 1 : -1;
    }
    final a = widget.floor.nodeById(wall.startNodeId);
    final b = widget.floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return fallback;
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final cross = dx * (raw.y - a.yMm) - dy * (raw.x - a.xMm);
    final length = math.sqrt(dx * dx + dy * dy);
    return cross.abs() < wall.thicknessMm * length * .6
        ? fallback
        : (cross > 0 ? 1 : -1);
  }

  void _dragEnd(DragEndDetails details) {
    _lastDragMm = null;
    if (_dragDirty) widget.onChanged();
    _dragDirty = false;
  }

  Future<void> _rotateObject(double delta) async {
    final object = _selectedObject;
    if (object == null) return;
    EquipmentPlacementService.rotateBy(object, delta);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _duplicateObject() async {
    final object = _selectedObject;
    if (object == null) return;
    final duplicate = EquipmentPlacementService.duplicateObject(
      floor: widget.floor,
      source: object,
    );
    await widget.onChanged();
    if (mounted) setState(() => _selectedObjectId = duplicate.id);
  }

  Future<void> _deleteObject() async {
    final object = _selectedObject;
    if (object == null) return;
    EquipmentPlacementService.removeObject(floor: widget.floor, object: object);
    _selectedObjectId = null;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  bool get _editingSelection => switch (widget.layer) {
        MeasureSharedLayer.objects => _selectedObject != null,
        MeasureSharedLayer.electrical =>
          _selectedElectrical != null && !_isFixture(_selectedElectrical!),
        MeasureSharedLayer.engineering =>
          _selectedRun != null && _selectedRunVertex != null,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_initialFitDone && widget.floor.nodes.isNotEmpty) {
          _initialFitDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
        }

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: .28,
                maxScale: 6,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(1800),
                panEnabled: !_editingSelection,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onPanStart: _editingSelection ? _dragStart : null,
                  onPanUpdate: _editingSelection ? _dragUpdate : null,
                  onPanEnd: _editingSelection ? _dragEnd : null,
                  child: SizedBox.fromSize(
                    size: _canvasSize,
                    child: CustomPaint(
                      painter: _MeasureSharedLayerPainter(
                        floor: widget.floor,
                        layer: widget.layer,
                        origin: _origin,
                        mmToPx: _mmToPx,
                        selectedObjectId: _selectedObjectId,
                        selectedElectricalId: _selectedElectricalId,
                        selectedRunId: _selectedRunId,
                        selectedRunVertex: _selectedRunVertex,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _ZoomControls(
                onFit: _fit,
                onZoomIn: () => _zoom(1.22),
                onZoomOut: () => _zoom(.82),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _actionBar(),
            ),
          ],
        );
      },
    );
  }

  Widget _actionBar() {
    return Material(
      color: ZamerColors.surfaceHigh.withValues(alpha: .96),
      elevation: 8,
      borderRadius: BorderRadius.circular(ZamerRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: switch (widget.layer) {
                MeasureSharedLayer.objects => _objectActions(),
                MeasureSharedLayer.electrical => _electricalActions(),
                MeasureSharedLayer.engineering => _engineeringActions(),
              },
            ),
            if (_editingSelection ||
                _selectedObject != null ||
                _selectedElectrical != null ||
                _selectedRun != null)
              IconButton(
                tooltip: 'Снять выделение',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _objectActions() {
    final object = _selectedObject;
    return Row(
      children: [
        Expanded(
          child: Text(
            object == null
                ? 'Нажми на объект, чтобы редактировать его прямо на плане'
                : '${object.label.isEmpty ? object.type.label : object.label} • '
                    '${object.widthMm.round()}×${object.depthMm.round()} мм',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ZamerTypography.caption.copyWith(
              color: object == null
                  ? ZamerColors.textMuted
                  : ZamerColors.textPrimary,
              fontWeight: object == null ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
        ),
        if (object != null) ...[
          _IconAction(
            icon: Icons.rotate_left_rounded,
            onTap: () => _rotateObject(-15),
          ),
          _IconAction(
            icon: Icons.rotate_right_rounded,
            onTap: () => _rotateObject(15),
          ),
          _IconAction(icon: Icons.copy_rounded, onTap: _duplicateObject),
          _IconAction(icon: Icons.delete_outline_rounded, onTap: _deleteObject),
        ],
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          onPressed: widget.onOpenCatalog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Каталог'),
        ),
      ],
    );
  }

  Widget _electricalActions() {
    final point = _selectedElectrical;
    final fixture = point != null && _isFixture(point);
    return Row(
      children: [
        Expanded(
          child: Text(
            point == null
                ? '${widget.floor.electricalPoints.length} точек • выбери точку на плане'
                : fixture
                    ? '${point.type.label} • связан со светильником, двигай в «Объектах»'
                    : '${point.type.label} • ${point.heightMm.round()} мм • ${point.circuit}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ZamerTypography.caption.copyWith(
              color: point == null
                  ? ZamerColors.textMuted
                  : ZamerColors.textPrimary,
              fontWeight: point == null ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: widget.onOpenAdvancedEditor,
          icon: const Icon(Icons.electrical_services_rounded, size: 18),
          label: const Text('Редактор'),
        ),
      ],
    );
  }

  Widget _engineeringActions() {
    final run = _selectedRun;
    final index = _selectedRunVertex;
    return Row(
      children: [
        Expanded(
          child: Text(
            run == null || index == null
                ? '${widget.floor.serviceRuns.length} трасс • выбери узел трассы'
                : '${run.type.label} • точка ${index + 1}/${run.points.length} • '
                    'Ø${run.diameterMm.round()} мм',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ZamerTypography.caption.copyWith(
              color: run == null
                  ? ZamerColors.textMuted
                  : ZamerColors.textPrimary,
              fontWeight: run == null ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: widget.onOpenAdvancedEditor,
          icon: const Icon(Icons.route_rounded, size: 18),
          label: const Text('Редактор'),
        ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZamerColors.surfaceHigh.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Уменьшить',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Вписать план',
            onPressed: onFit,
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Увеличить',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
      );
}

class _MeasureSharedLayerPainter extends CustomPainter {
  const _MeasureSharedLayerPainter({
    required this.floor,
    required this.layer,
    required this.origin,
    required this.mmToPx,
    this.selectedObjectId,
    this.selectedElectricalId,
    this.selectedRunId,
    this.selectedRunVertex,
  });

  final FloorPlan floor;
  final MeasureSharedLayer layer;
  final Offset origin;
  final double mmToPx;
  final String? selectedObjectId;
  final String? selectedElectricalId;
  final String? selectedRunId;
  final int? selectedRunVertex;

  Offset _p(double xMm, double yMm) =>
      origin + Offset(xMm * mmToPx, yMm * mmToPx);

  @override
  void paint(Canvas canvas, Size size) {
    CadPlanPainter(
      floor: floor,
      mmToPx: mmToPx,
      origin: origin,
      showGrid: true,
      showDimensions: layer == MeasureSharedLayer.objects,
    ).paint(canvas, size);

    if (layer == MeasureSharedLayer.objects) {
      _drawObjectSelection(canvas);
    } else if (layer == MeasureSharedLayer.electrical) {
      _drawElectrical(canvas);
    } else {
      _drawEngineering(canvas);
    }
  }

  void _drawObjectSelection(Canvas canvas) {
    final id = selectedObjectId;
    if (id == null) return;
    PlanObject? object;
    for (final candidate in floor.planObjects) {
      if (candidate.id == id) {
        object = candidate;
        break;
      }
    }
    if (object == null) return;
    final center = _p(object.xMm, object.yMm);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: math.max(20, object.widthMm * mmToPx),
      height: math.max(20, object.depthMm * mmToPx),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(object.rotationDeg * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(8), const Radius.circular(8)),
      Paint()
        ..color = ZamerColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  void _drawElectrical(Canvas canvas) {
    final byId = {for (final point in floor.electricalPoints) point.id: point};
    final runPaint = Paint()
      ..color = ZamerColors.info.withValues(alpha: .92)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final run in floor.electricalRuns) {
      final a = byId[run.startPointId];
      final b = byId[run.endPointId];
      if (a == null || b == null) continue;
      final pa = _p(a.xMm, a.yMm);
      final pb = _p(b.xMm, b.yMm);
      final path = Path()..moveTo(pa.dx, pa.dy);
      if (run.routeMode == 'orthogonal') path.lineTo(pb.dx, pa.dy);
      path.lineTo(pb.dx, pb.dy);
      canvas.drawPath(path, runPaint);
    }

    for (final point in floor.electricalPoints) {
      final selected = point.id == selectedElectricalId;
      final center = _p(point.xMm, point.yMm);
      canvas.drawCircle(
        center,
        selected ? 12 : 9,
        Paint()
          ..color = selected ? ZamerColors.accent : ZamerColors.surfaceHighest,
      );
      canvas.drawCircle(
        center,
        selected ? 12 : 9,
        Paint()
          ..color = selected ? ZamerColors.accent : ZamerColors.warning
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 2,
      );
      final label = switch (point.type) {
        ElectricalPointType.socket => 'R',
        ElectricalPointType.switchPoint => 'S',
        ElectricalPointType.ceilingLight => 'L',
        ElectricalPointType.wallLight => 'B',
        ElectricalPointType.tvSocket => 'TV',
        ElectricalPointType.dataSocket => 'RJ',
        ElectricalPointType.panel => 'Щ',
        ElectricalPointType.junctionBox => 'К',
        ElectricalPointType.frame => 'F',
        ElectricalPointType.appliance => 'P',
      };
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: selected ? ZamerColors.accentInk : ZamerColors.textPrimary,
            fontSize: label.length > 1 ? 6.5 : 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  void _drawEngineering(Canvas canvas) {
    final colors = <ServiceRunType, Color>{
      ServiceRunType.coldWater: const Color(0xFF62A9E6),
      ServiceRunType.hotWater: const Color(0xFFE66E67),
      ServiceRunType.drain: const Color(0xFFB69B79),
      ServiceRunType.heating: const Color(0xFFEBA45A),
    };
    for (final run in floor.serviceRuns) {
      if (run.points.isEmpty) continue;
      final selected = run.id == selectedRunId;
      final color = colors[run.type]!;
      final path = Path();
      for (var i = 0; i < run.points.length; i++) {
        final q = _p(run.points[i].xMm, run.points[i].yMm);
        if (i == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 4.4 : 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < run.points.length; i++) {
        final q = _p(run.points[i].xMm, run.points[i].yMm);
        final active = selected && i == selectedRunVertex;
        canvas.drawCircle(
          q,
          active ? 9 : 5,
          Paint()..color = active ? ZamerColors.accent : color,
        );
        if (active) {
          canvas.drawCircle(
            q,
            12,
            Paint()
              ..color = ZamerColors.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeasureSharedLayerPainter oldDelegate) => true;
}
