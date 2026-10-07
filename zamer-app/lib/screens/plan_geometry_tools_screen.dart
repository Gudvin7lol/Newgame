import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/floor_plan_painter.dart';

enum PlanGeometryTool { radius, nodes }

enum _GeometrySnap { ortho, deg45, free }

class PlanGeometryToolsScreen extends StatefulWidget {
  const PlanGeometryToolsScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.initialTool = PlanGeometryTool.radius,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final PlanGeometryTool initialTool;

  @override
  State<PlanGeometryToolsScreen> createState() =>
      _PlanGeometryToolsScreenState();
}

class _PlanGeometryToolsScreenState extends State<PlanGeometryToolsScreen> {
  static const _canvasSize = Size(5200, 5200);
  static const _origin = Offset(2600, 2600);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();

  late PlanGeometryTool _tool;
  _GeometrySnap _snap = _GeometrySnap.ortho;
  WallType _wallType = WallType.exterior;
  WallMaterial _material = WallMaterial.gasBlock;
  ProjectLayer _layer = ProjectLayer.existing;
  double _thicknessMm = 300;
  bool _snapping = true;
  bool _showDimensions = true;
  bool _centered = false;
  Size _viewport = Size.zero;
  String? _activeNodeId;
  String? _selectedNodeId;
  String? _dragNodeId;
  NodeSnapResult? _dragSnap;

  FloorPlan get floor => widget.floor;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialTool;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  math.Point<double> _toMm(Offset p) => math.Point<double>(
        (p.dx - _origin.dx) / _mmToPx,
        (p.dy - _origin.dy) / _mmToPx,
      );

  Offset _toCanvas(PlanNode node) =>
      _origin + Offset(node.xMm * _mmToPx, node.yMm * _mmToPx);

  double get _viewScale =>
      math.max(.1, _transform.value.getMaxScaleOnAxis());

  double get _snapStep => switch (_snap) {
        _GeometrySnap.ortho => math.pi / 2,
        _GeometrySnap.deg45 => math.pi / 4,
        _GeometrySnap.free => 0,
      };

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(floor);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _centerView() {
    if (_viewport.isEmpty) return;
    var scale = .78;
    var center = const math.Point<double>(0, 0);
    if (floor.nodes.isNotEmpty) {
      final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
      final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
      final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
      final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
      center = math.Point<double>((minX + maxX) / 2, (minY + maxY) / 2);
      final widthPx = math.max(1.0, (maxX - minX) * _mmToPx);
      final heightPx = math.max(1.0, (maxY - minY) * _mmToPx);
      final sx = (_viewport.width - 90) / widthPx;
      final sy = (_viewport.height - 170) / heightPx;
      scale = math.min(.95, math.max(.25, math.min(sx, sy) * .78));
    }
    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    _transform.value = Matrix4.identity()
      ..translate(
        _viewport.width / 2 - target.dx * scale,
        _viewport.height / 2 - target.dy * scale,
      )
      ..scale(scale);
  }

  PlanNode? _nodeNear(Offset p, {double px = 32}) {
    PlanNode? best;
    var bestDistance = px / _viewScale;
    for (final node in floor.nodes) {
      final distance = (_toCanvas(node) - p).distance;
      if (distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    return best;
  }

  double _snappedAngle(double raw) {
    if (!_snapping || _snapStep == 0) return raw;
    return (raw / _snapStep).round() * _snapStep;
  }

  Future<void> _tapRadius(Offset position) async {
    if (_activeNodeId == null) {
      final anchor = GeometryService.ensureAnchor(floor, _toMm(position));
      setState(() {
        _activeNodeId = anchor.id;
        _selectedNodeId = anchor.id;
      });
      await _changed();
      return;
    }

    final start = floor.nodeById(_activeNodeId!);
    if (start == null) {
      setState(() => _activeNodeId = null);
      return;
    }

    final raw = _toMm(position);
    final dx = raw.x - start.xMm;
    final dy = raw.y - start.yMm;
    final estimatedChord = math.sqrt(dx * dx + dy * dy);
    if (estimatedChord < 100) return;
    final angle = _snappedAngle(math.atan2(dy, dx));
    final values = await _arcDialog(estimatedChord);
    if (values == null) return;

    final endPoint = math.Point<double>(
      start.xMm + math.cos(angle) * values.chord,
      start.yMm + math.sin(angle) * values.chord,
    );
    final before = floor.walls.map((e) => e.id).toSet();
    final end = GeometryService.addArcWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: endPoint,
      sagittaMm: values.sagitta,
      type: _wallType,
      thicknessMm: _thicknessMm,
      material: _material,
    );
    for (final wall in floor.walls.where((e) => !before.contains(e.id))) {
      wall.projectLayer = _layer;
      wall.demolition = _layer == ProjectLayer.demolition;
    }
    setState(() {
      _activeNodeId = end.id;
      _selectedNodeId = end.id;
    });
    await _changed();
  }

  Future<({double chord, double sagitta})?> _arcDialog(
    double estimatedChord,
  ) async {
    final chord = TextEditingController(text: estimatedChord.round().toString());
    final rise = TextEditingController(text: '500');
    var side = 1.0;
    final result = await showDialog<({double chord, double sagitta})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Радиусная стена'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: chord,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Хорда L',
                  suffixText: 'мм',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rise,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Стрела h',
                  suffixText: 'мм',
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Влево')),
                  ButtonSegment(value: -1, label: Text('Вправо')),
                ],
                selected: {side},
                onSelectionChanged: (value) =>
                    setDialog(() => side = value.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final l = double.tryParse(chord.text.replaceAll(',', '.'));
                final h = double.tryParse(rise.text.replaceAll(',', '.'));
                if (l == null || h == null || l < 100 || h <= 0 || h > l * 2) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  (chord: l, sagitta: h * side),
                );
              },
              child: const Text('Построить'),
            ),
          ],
        ),
      ),
    );
    chord.dispose();
    rise.dispose();
    return result;
  }

  void _nodeDragStart(DragStartDetails details) {
    if (_tool != PlanGeometryTool.nodes) return;
    final node = _nodeNear(details.localPosition);
    setState(() {
      _dragNodeId = node?.id;
      _selectedNodeId = node?.id;
      _dragSnap = null;
    });
  }

  void _nodeDragUpdate(DragUpdateDetails details) {
    final movingId = _dragNodeId;
    if (_tool != PlanGeometryTool.nodes || movingId == null) return;
    final node = floor.nodeById(movingId);
    if (node == null) return;
    final snap = GeometryService.snapMoveTarget(
      floor,
      movingNodeId: movingId,
      raw: _toMm(details.localPosition),
      enabled: _snapping,
      angleStepRadians: _snapStep,
    );
    node.xMm = snap.point.x;
    node.yMm = snap.point.y;
    setState(() => _dragSnap = snap);
  }

  Future<void> _nodeDragEnd(DragEndDetails details) async {
    final movingId = _dragNodeId;
    if (_tool != PlanGeometryTool.nodes || movingId == null) return;
    final node = floor.nodeById(movingId);
    if (node != null) {
      final snap = _dragSnap ??
          NodeSnapResult(
            point: math.Point<double>(node.xMm, node.yMm),
            kind: NodeSnapKind.none,
          );
      final finalNode = GeometryService.finalizeNodeMove(
        floor,
        movingNodeId: movingId,
        snap: snap,
      );
      _selectedNodeId = finalNode?.id;
      await _changed();
    }
    if (mounted) {
      setState(() {
        _dragNodeId = null;
        _dragSnap = null;
      });
    }
  }

  Future<void> _tapNode(Offset position) async {
    final node = _nodeNear(position);
    if (node == null) return;
    setState(() => _selectedNodeId = node.id);
    await _nodeSheet(node);
  }

  Future<void> _nodeSheet(PlanNode node) async {
    final dx = TextEditingController(text: '0');
    final dy = TextEditingController(text: '0');
    final connected = floor.walls
        .where((w) => w.startNodeId == node.id || w.endNodeId == node.id)
        .length;
    final delta = await showModalBottomSheet<math.Point<double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Точный сдвиг узла', style: ZamerTypography.h3),
              const SizedBox(height: 4),
              Text(
                'X ${node.xMm.round()} мм • Y ${node.yMm.round()} мм • $connected соединений',
                style: ZamerTypography.caption,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dx,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ΔX',
                        suffixText: 'мм',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: dy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ΔY',
                        suffixText: 'мм',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final x = double.tryParse(dx.text.replaceAll(',', '.'));
                  final y = double.tryParse(dy.text.replaceAll(',', '.'));
                  if (x == null || y == null) return;
                  Navigator.pop(context, math.Point<double>(x, y));
                },
                child: const Text('Переместить'),
              ),
            ],
          ),
        ),
      ),
    );
    dx.dispose();
    dy.dispose();
    if (delta == null || (delta.x == 0 && delta.y == 0)) return;

    final target = math.Point<double>(
      node.xMm + delta.x,
      node.yMm + delta.y,
    );
    final snap = GeometryService.snapMoveTarget(
      floor,
      movingNodeId: node.id,
      raw: target,
      enabled: _snapping,
      angleStepRadians: 0,
      nodeThresholdMm: 2,
      wallThresholdMm: 2,
      guideThresholdMm: 0,
      gridMm: 0,
    );
    final finalNode = GeometryService.finalizeNodeMove(
      floor,
      movingNodeId: node.id,
      snap: snap,
    );
    _selectedNodeId = finalNode?.id;
    await _changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Геометрия плана'),
        actions: [
          IconButton(
            tooltip: 'Показать весь план',
            onPressed: _centerView,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: ZamerColors.surfaceLow,
              border: Border(
                bottom: BorderSide(color: ZamerColors.outlineSoft),
              ),
            ),
            child: SegmentedButton<PlanGeometryTool>(
              segments: const [
                ButtonSegment(
                  value: PlanGeometryTool.radius,
                  icon: Icon(Icons.architecture_outlined),
                  label: Text('Радиус'),
                ),
                ButtonSegment(
                  value: PlanGeometryTool.nodes,
                  icon: Icon(Icons.adjust_rounded),
                  label: Text('Узлы'),
                ),
              ],
              selected: {_tool},
              onSelectionChanged: (value) => setState(() {
                _tool = value.first;
                _activeNodeId = null;
                _dragNodeId = null;
                _dragSnap = null;
              }),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = Size(constraints.maxWidth, constraints.maxHeight);
                if (!_centered) {
                  _centered = true;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _centerView());
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: .22,
                        maxScale: 5,
                        panEnabled: _tool != PlanGeometryTool.nodes,
                        scaleEnabled: _tool != PlanGeometryTool.nodes,
                        boundaryMargin: const EdgeInsets.all(1800),
                        constrained: false,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            if (_tool == PlanGeometryTool.radius) {
                              _tapRadius(details.localPosition);
                            } else {
                              _tapNode(details.localPosition);
                            }
                          },
                          onPanStart: _tool == PlanGeometryTool.nodes
                              ? _nodeDragStart
                              : null,
                          onPanUpdate: _tool == PlanGeometryTool.nodes
                              ? _nodeDragUpdate
                              : null,
                          onPanEnd: _tool == PlanGeometryTool.nodes
                              ? _nodeDragEnd
                              : null,
                          child: CustomPaint(
                            size: _canvasSize,
                            painter: FloorPlanPainter(
                              floor: floor,
                              mmToPx: _mmToPx,
                              origin: _origin,
                              activeNodeId: _dragNodeId ??
                                  _selectedNodeId ??
                                  _activeNodeId,
                              showDimensions: _showDimensions,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Column(
                        children: [
                          ZMeasureCanvasAction(
                            icon: _snapping
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            tooltip: 'Привязка',
                            active: _snapping,
                            onPressed: () =>
                                setState(() => _snapping = !_snapping),
                          ),
                          const SizedBox(height: 6),
                          ZMeasureCanvasAction(
                            icon: Icons.straighten_rounded,
                            tooltip: 'Размеры',
                            active: _showDimensions,
                            onPressed: () => setState(
                              () => _showDimensions = !_showDimensions,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_dragSnap != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _SnapBadge(label: _dragSnap!.label),
                      ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: _GeometryInspector(
                        tool: _tool,
                        wallType: _wallType,
                        thicknessMm: _thicknessMm,
                        layer: _layer,
                        snap: _snap,
                        activeRadius: _activeNodeId != null,
                        onWallType: (value) => setState(() {
                          _wallType = value;
                          _thicknessMm =
                              value == WallType.exterior ? 300 : 100;
                          _material = value == WallType.exterior
                              ? WallMaterial.gasBlock
                              : WallMaterial.drywall;
                        }),
                        onThickness: (delta) => setState(() {
                          _thicknessMm =
                              (_thicknessMm + delta).clamp(50, 1000).toDouble();
                        }),
                        onLayer: (value) => setState(() => _layer = value),
                        onSnap: (value) => setState(() => _snap = value),
                        onFinishRadius: () =>
                            setState(() => _activeNodeId = null),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapBadge extends StatelessWidget {
  const _SnapBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, size: 16, color: ZamerColors.accent),
            const SizedBox(width: 6),
            Text(label, style: ZamerTypography.caption),
          ],
        ),
      );
}

class _GeometryInspector extends StatelessWidget {
  const _GeometryInspector({
    required this.tool,
    required this.wallType,
    required this.thicknessMm,
    required this.layer,
    required this.snap,
    required this.activeRadius,
    required this.onWallType,
    required this.onThickness,
    required this.onLayer,
    required this.onSnap,
    required this.onFinishRadius,
  });

  final PlanGeometryTool tool;
  final WallType wallType;
  final double thicknessMm;
  final ProjectLayer layer;
  final _GeometrySnap snap;
  final bool activeRadius;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_GeometrySnap> onSnap;
  final VoidCallback onFinishRadius;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          border: Border.all(color: ZamerColors.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: tool == PlanGeometryTool.nodes
            ? Row(
                children: [
                  const Icon(Icons.adjust_rounded, color: ZamerColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Перетащи узел или нажми на него для точного сдвига в мм',
                      style: ZamerTypography.bodySmall,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<WallType>(
                          segments: const [
                            ButtonSegment(
                              value: WallType.exterior,
                              label: Text('Стена'),
                            ),
                            ButtonSegment(
                              value: WallType.partition,
                              label: Text('Перег.'),
                            ),
                          ],
                          selected: {wallType},
                          onSelectionChanged: (value) =>
                              onWallType(value.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: ZamerColors.surface,
                          borderRadius: BorderRadius.circular(ZamerRadius.sm),
                          border: Border.all(color: ZamerColors.outlineSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => onThickness(-20),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            Text(
                              '${thicknessMm.round()} мм',
                              style: ZamerTypography.technical,
                            ),
                            IconButton(
                              onPressed: () => onThickness(20),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Существующее'),
                          selected: layer == ProjectLayer.existing,
                          onSelected: (_) => onLayer(ProjectLayer.existing),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Демонтаж'),
                          selected: layer == ProjectLayer.demolition,
                          onSelected: (_) => onLayer(ProjectLayer.demolition),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Новое'),
                          selected: layer == ProjectLayer.proposed,
                          onSelected: (_) => onLayer(ProjectLayer.proposed),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('90°'),
                          selected: snap == _GeometrySnap.ortho,
                          onSelected: (_) => onSnap(_GeometrySnap.ortho),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('45°'),
                          selected: snap == _GeometrySnap.deg45,
                          onSelected: (_) => onSnap(_GeometrySnap.deg45),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Свободно'),
                          selected: snap == _GeometrySnap.free,
                          onSelected: (_) => onSnap(_GeometrySnap.free),
                        ),
                        if (activeRadius) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: onFinishRadius,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Завершить'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      );
}
