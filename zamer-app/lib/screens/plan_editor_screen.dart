import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/floor_plan_painter.dart';

enum PlanMode {
  select,
  nodes,
  exterior,
  partition,
  arc,
  opening,
  demolition,
  dimension,
}

enum SnapMode { ortho, deg45, free }

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  static const _canvasSize = Size(5200, 5200);
  static const _origin = Offset(2600, 2600);
  static const _mmToPx = 0.10;

  final TransformationController _transform = TransformationController();
  final _undo = <String>[];
  final _redo = <String>[];
  PlanMode _mode = PlanMode.exterior;
  SnapMode _snap = SnapMode.ortho;
  OpeningType _openingType = OpeningType.door;
  WallType _arcWallType = WallType.exterior;
  String? _activeNodeId;
  String? _selectedWallId;
  String? _measureStartNodeId;
  String? _selectedNodeId;
  String? _dragNodeId;
  NodeSnapResult? _lastNodeSnap;
  bool _dragUndoPushed = false;
  String? _dragOpeningWallId;
  String? _dragOpeningId;
  bool _openingDragUndoPushed = false;
  bool _snappingEnabled = true;
  bool _showDimensions = true;
  ProjectLayer _projectLayer = ProjectLayer.existing;
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();
  bool _centered = false;
  Size _viewport = Size.zero;

  FloorPlan get floor => widget.floor;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';
  math.Point<double> _toMm(Offset p) =>
      math.Point((p.dx - _origin.dx) / _mmToPx, (p.dy - _origin.dy) / _mmToPx);
  Offset _toCanvas(PlanNode n) =>
      _origin + Offset(n.xMm * _mmToPx, n.yMm * _mmToPx);

  void _pushUndo() {
    _undo.add(jsonEncode(floor.toJson()));
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(floor);
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  Future<void> _undoAction() async {
    if (_undo.isEmpty) return;
    _redo.add(jsonEncode(floor.toJson()));
    floor.restoreFrom(
      FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(_undo.removeLast()) as Map),
      ),
    );
    _activeNodeId = null;
    _selectedWallId = null;
    _measureStartNodeId = null;
    _selectedNodeId = null;
    await _changed();
  }

  Future<void> _redoAction() async {
    if (_redo.isEmpty) return;
    _undo.add(jsonEncode(floor.toJson()));
    floor.restoreFrom(
      FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(_redo.removeLast()) as Map),
      ),
    );
    await _changed();
  }

  math.Point<double> _snapPoint(PlanNode start, math.Point<double> raw) {
    if (!_snappingEnabled) return raw;
    final dx = raw.x - start.xMm;
    final dy = raw.y - start.yMm;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return math.Point(start.xMm + 1000, start.yMm);
    final rawAngle = math.atan2(dy, dx);
    final step = switch (_snap) {
      SnapMode.ortho => math.pi / 2,
      SnapMode.deg45 => math.pi / 4,
      SnapMode.free => 0.0,
    };
    final angle = step == 0 ? rawAngle : (rawAngle / step).round() * step;
    return math.Point(
      start.xMm + math.cos(angle) * len,
      start.yMm + math.sin(angle) * len,
    );
  }

  PlanWall? _wallNear(Offset p, {double px = 22}) {
    PlanWall? best;
    var bestD = px;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final d = _distanceToSegment(p, _toCanvas(a), _toCanvas(b));
      if (d < bestD) {
        bestD = d;
        best = wall;
      }
    }
    return best;
  }

  PlanNode? _nodeNear(Offset p, {double px = 20}) {
    PlanNode? best;
    var bestD = px;
    for (final node in floor.nodes) {
      final d = (_toCanvas(node) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = node;
      }
    }
    return best;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (l2 == 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / l2).clamp(0.0, 1.0).toDouble();
    return (p - (a + ab * t)).distance;
  }

  double get _viewScale => math.max(0.1, _transform.value.getMaxScaleOnAxis());

  double get _moveAngleStep => switch (_snap) {
    SnapMode.ortho => math.pi / 2,
    SnapMode.deg45 => math.pi / 4,
    SnapMode.free => 0.0,
  };

  void _nodeDragStart(DragStartDetails details) {
    if (_mode != PlanMode.nodes) return;
    final node = _nodeNear(details.localPosition, px: 30 / _viewScale);
    if (node == null) {
      setState(() {
        _selectedNodeId = null;
        _dragNodeId = null;
        _lastNodeSnap = null;
      });
      return;
    }
    setState(() {
      _selectedNodeId = node.id;
      _dragNodeId = node.id;
      _dragUndoPushed = false;
      _lastNodeSnap = null;
    });
  }

  void _nodeDragUpdate(DragUpdateDetails details) {
    if (_mode != PlanMode.nodes || _dragNodeId == null) return;
    final node = floor.nodeById(_dragNodeId!);
    if (node == null) return;
    if (!_dragUndoPushed) {
      _pushUndo();
      _dragUndoPushed = true;
    }
    final snap = GeometryService.snapMoveTarget(
      floor,
      movingNodeId: node.id,
      raw: _toMm(details.localPosition),
      enabled: _snappingEnabled,
      angleStepRadians: _moveAngleStep,
    );
    node.xMm = snap.point.x;
    node.yMm = snap.point.y;
    setState(() => _lastNodeSnap = snap);
  }

  Future<void> _nodeDragEnd(DragEndDetails details) async {
    if (_mode != PlanMode.nodes || _dragNodeId == null) return;
    final movingId = _dragNodeId!;
    final snap =
        _lastNodeSnap ??
        NodeSnapResult(
          point: math.Point(
            floor.nodeById(movingId)?.xMm ?? 0.0,
            floor.nodeById(movingId)?.yMm ?? 0.0,
          ),
          kind: NodeSnapKind.none,
        );
    if (_dragUndoPushed) {
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
        _lastNodeSnap = null;
        _dragUndoPushed = false;
      });
    }
  }

  Future<void> _nodeSheet(PlanNode node) async {
    final connected = floor.walls
        .where((w) => w.startNodeId == node.id || w.endNodeId == node.id)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Точка • ${connected.length} соединений',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _infoTile('X', '${node.xMm.round()} мм')),
                  const SizedBox(width: 8),
                  Expanded(child: _infoTile('Y', '${node.yMm.round()} мм')),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _preciseNodeMove(node);
                },
                icon: const Icon(Icons.open_with),
                label: const Text('Сдвинуть точно'),
              ),
              if (connected.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Связанные стены',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ...connected
                    .take(4)
                    .map(
                      (wall) => Text(
                        '• ${wall.type.label}: ${floor.wallLengthMm(wall).round()} мм',
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _preciseNodeMove(PlanNode node) async {
    final dx = TextEditingController(text: '0');
    final dy = TextEditingController(text: '0');
    final delta = await showDialog<math.Point<double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Точный сдвиг точки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
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
            const SizedBox(height: 8),
            TextField(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final x = double.tryParse(dx.text.replaceAll(',', '.'));
              final y = double.tryParse(dy.text.replaceAll(',', '.'));
              if (x == null || y == null) return;
              Navigator.pop(context, math.Point(x, y));
            },
            child: const Text('Переместить'),
          ),
        ],
      ),
    );
    if (delta == null || (delta.x == 0 && delta.y == 0)) return;
    _pushUndo();
    final raw = math.Point(node.xMm + delta.x, node.yMm + delta.y);
    final snap = GeometryService.snapMoveTarget(
      floor,
      movingNodeId: node.id,
      raw: raw,
      enabled: true,
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

  double? _parallelReferenceLength(PlanNode start, double angle) =>
      GeometryService.parallelReferenceLength(floor, start, angle);

  _OpeningHit? _openingNear(Offset p, {double px = 28}) {
    _OpeningHit? best;
    var bestDistance = px;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final len = floor.wallLengthMm(wall);
      if (len <= 0) continue;
      final pa = _toCanvas(a);
      final pb = _toCanvas(b);
      final v = pb - pa;
      for (final opening in wall.openings) {
        final t1 = (opening.offsetFromStartMm / len).clamp(0.0, 1.0).toDouble();
        final t2 = ((opening.offsetFromStartMm + opening.widthMm) / len)
            .clamp(0.0, 1.0)
            .toDouble();
        final o1 = pa + v * t1;
        final o2 = pa + v * t2;
        final d = _distanceToSegment(p, o1, o2);
        if (d < bestDistance) {
          bestDistance = d;
          best = _OpeningHit(wall, opening);
        }
      }
    }
    return best;
  }

  void _openingDragStart(DragStartDetails details) {
    if (_mode != PlanMode.opening) return;
    final hit = _openingNear(details.localPosition, px: 34 / _viewScale);
    setState(() {
      _dragOpeningWallId = hit?.wall.id;
      _dragOpeningId = hit?.opening.id;
      _openingDragUndoPushed = false;
      if (hit != null) _selectedWallId = hit.wall.id;
    });
  }

  void _openingDragUpdate(DragUpdateDetails details) {
    if (_mode != PlanMode.opening ||
        _dragOpeningWallId == null ||
        _dragOpeningId == null)
      return;
    final wall = floor.wallById(_dragOpeningWallId!);
    if (wall == null) return;
    WallOpening? opening;
    for (final o in wall.openings) {
      if (o.id == _dragOpeningId) opening = o;
    }
    if (opening == null) return;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    if (!_openingDragUndoPushed) {
      _pushUndo();
      _openingDragUndoPushed = true;
    }
    final p = _toMm(details.localPosition);
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final l2 = dx * dx + dy * dy;
    if (l2 < 1) return;
    final t = (((p.x - a.xMm) * dx + (p.y - a.yMm) * dy) / l2)
        .clamp(0.0, 1.0)
        .toDouble();
    final len = math.sqrt(l2);
    final centerMm = len * t;
    opening.offsetFromStartMm = (centerMm - opening.widthMm / 2)
        .clamp(0.0, math.max(0.0, len - opening.widthMm))
        .toDouble();
    setState(() {});
  }

  Future<void> _openingDragEnd(DragEndDetails details) async {
    if (_mode != PlanMode.opening || _dragOpeningId == null) return;
    if (_openingDragUndoPushed) await _changed();
    if (mounted) {
      setState(() {
        _dragOpeningWallId = null;
        _dragOpeningId = null;
        _openingDragUndoPushed = false;
      });
    }
  }

  Future<void> _tap(TapUpDetails details) async {
    final p = details.localPosition;
    if (_mode == PlanMode.nodes) {
      final node = _nodeNear(p, px: 30 / _viewScale);
      setState(() => _selectedNodeId = node?.id);
      if (node != null) await _nodeSheet(node);
      return;
    }
    if (_mode == PlanMode.select) {
      final wall = _wallNear(p);
      setState(() => _selectedWallId = wall?.id);
      if (wall != null) await _wallSheet(wall);
      return;
    }

    if (_mode == PlanMode.demolition) {
      final wall = _wallNear(p, px: 34 / _viewScale);
      if (wall == null) {
        _toast(
          'Нажми на существующую стену: она будет отмечена как демонтаж. Повторное нажатие вернёт её в существующее состояние.',
        );
        return;
      }
      _pushUndo();
      if (wall.projectLayer == ProjectLayer.demolition || wall.demolition) {
        wall.projectLayer = ProjectLayer.existing;
        wall.demolition = false;
        _toast('Стена возвращена в существующее состояние.');
      } else {
        wall.projectLayer = ProjectLayer.demolition;
        wall.demolition = true;
        _toast('Стена добавлена в план демонтажа.');
      }
      await _changed();
      if (mounted) setState(() => _selectedWallId = wall.id);
      return;
    }

    if (_mode == PlanMode.opening) {
      final existing = _openingNear(p, px: 30 / _viewScale);
      if (existing != null) {
        _selectedWallId = existing.wall.id;
        await _editOpening(existing.wall, existing.opening);
        return;
      }
      final wall = _wallNear(p, px: 30 / _viewScale);
      if (wall == null) {
        _toast(
          'Нажми на стену, чтобы добавить проём, или перетащи существующую дверь/окно пальцем.',
        );
        return;
      }
      _selectedWallId = wall.id;
      await _addOpening(wall, _openingType);
      return;
    }

    if (_mode == PlanMode.dimension) {
      final node = _nodeNear(p, px: 28);
      if (node == null) {
        _toast('Для размера нажми на существующий узел.');
        return;
      }
      if (_measureStartNodeId == null) {
        setState(() => _measureStartNodeId = node.id);
        return;
      }
      if (_measureStartNodeId == node.id) return;
      final a = floor.nodeById(_measureStartNodeId!);
      if (a == null) return;
      final calculated = GeometryService.distance(a, node);
      final measured = await _numberDialog(
        'Контрольный размер',
        'Измерено',
        calculated.round().toString(),
        'мм',
      );
      if (measured != null && measured > 0) {
        _pushUndo();
        floor.measures.add(
          ControlMeasure(
            id: _id('m'),
            startNodeId: a.id,
            endNodeId: node.id,
            measuredMm: measured,
          ),
        );
        _setDimension(
          'control:${floor.measures.last.id}',
          measured,
          DimensionSource.manual,
        );
        _measureStartNodeId = null;
        await _changed();
      }
      return;
    }

    if (_activeNodeId == null) {
      _pushUndo();
      final n = GeometryService.ensureAnchor(floor, _toMm(p));
      _activeNodeId = n.id;
      await _changed();
      return;
    }

    final start = floor.nodeById(_activeNodeId!);
    if (start == null) return;
    final target = _snapPoint(start, _toMm(p));
    final dx = target.x - start.xMm;
    final dy = target.y - start.yMm;
    final estimated = math.sqrt(dx * dx + dy * dy).round().clamp(50, 50000);
    final angle = math.atan2(dy, dx);
    late final double length;
    double sagitta = 0;
    if (_mode == PlanMode.arc) {
      final arc = await _arcDialog(estimated.toDouble());
      if (arc == null) return;
      length = arc.x;
      sagitta = arc.y;
    } else {
      final opposite = _parallelReferenceLength(start, angle);
      final suggested = opposite?.round() ?? estimated;
      final entered = await _numberDialog(
        opposite == null
            ? 'Новая стена'
            : 'Новая стена • напротив ${opposite.round()} мм',
        opposite == null ? 'Длина' : 'Длина (предложено по параллельной стене)',
        '$suggested',
        'мм',
      );
      if (entered == null || entered <= 0) return;
      length = entered;
    }
    final exact = math.Point(
      start.xMm + math.cos(angle) * length,
      start.yMm + math.sin(angle) * length,
    );

    _pushUndo();
    final beforeWallIds = floor.walls.map((w) => w.id).toSet();
    final isExterior =
        _mode == PlanMode.exterior ||
        (_mode == PlanMode.arc && _arcWallType == WallType.exterior);
    final end = _mode == PlanMode.arc
        ? GeometryService.addArcWallFromNode(
            floor,
            startNodeId: start.id,
            endPoint: exact,
            sagittaMm: sagitta,
            type: _arcWallType,
            thicknessMm: _arcWallType == WallType.exterior ? 300 : 100,
            material: _arcWallType == WallType.exterior
                ? WallMaterial.gasBlock
                : WallMaterial.drywall,
          )
        : GeometryService.addWallFromNode(
            floor,
            startNodeId: start.id,
            endPoint: exact,
            type: isExterior ? WallType.exterior : WallType.partition,
            thicknessMm: isExterior ? 300 : 100,
            material: isExterior ? WallMaterial.gasBlock : WallMaterial.drywall,
          );
    for (final wall in floor.walls.where(
      (w) => !beforeWallIds.contains(w.id),
    )) {
      wall.projectLayer = _projectLayer;
      wall.demolition = _projectLayer == ProjectLayer.demolition;
    }
    _activeNodeId = end.id;
    await _changed();
  }

  Future<math.Point<double>?> _arcDialog(double estimatedChord) async {
    final chord = TextEditingController(
      text: estimatedChord.round().toString(),
    );
    final rise = TextEditingController(text: '500');
    var side = 1.0;
    return showDialog<math.Point<double>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Радиусная стена'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Задай хорду L и стрелу подъёма h. Знак стороны выбирается кнопками ниже.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: chord,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Хорда L',
                  suffixText: 'мм',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rise,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                onSelectionChanged: (v) => setModal(() => side = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final l = double.tryParse(chord.text.replaceAll(',', '.'));
                final h = double.tryParse(rise.text.replaceAll(',', '.'));
                if (l == null || h == null || l < 100 || h <= 0 || h > l * 2)
                  return;
                Navigator.pop(context, math.Point<double>(l, h * side));
              },
              child: const Text('Построить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _numberDialog(
    String title,
    String label,
    String initial,
    String suffix,
  ) async {
    final c = TextEditingController(text: initial);
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(c.text.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _wallSheet(PlanWall wall) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          final length = floor.wallLengthMm(wall);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${wall.type.label} • ${length.round()} мм',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Контроль длины и источник'),
                      subtitle: Text(() {
                        final record =
                            floor.dimensionRecords['wall:${wall.id}:length'];
                        return record == null
                            ? 'На плане ${length.round()} мм • отдельный замер не записан'
                            : '${record.valueMm.round()} мм • ${record.source.label} • ${record.author}';
                      }()),
                      onTap: () async {
                        await _recordEvidence('wall:${wall.id}:length', length);
                        modalSetState(() {});
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            'Толщина',
                            '${wall.thicknessMm.round()} мм',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _infoTile('Материал', wall.material.label),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _editThickness(wall);
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.width_normal),
                            label: const Text('Толщина'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _editMaterial(wall);
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.category_outlined),
                            label: const Text('Материал'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<WallType>(
                      segments: const [
                        ButtonSegment(
                          value: WallType.exterior,
                          label: Text('Наружная'),
                        ),
                        ButtonSegment(
                          value: WallType.partition,
                          label: Text('Перегородка'),
                        ),
                      ],
                      selected: {wall.type},
                      onSelectionChanged: (s) async {
                        _pushUndo();
                        wall.type = s.first;
                        await _changed();
                        modalSetState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProjectLayer>(
                      value: wall.demolition
                          ? ProjectLayer.demolition
                          : wall.projectLayer,
                      decoration: const InputDecoration(
                        labelText: 'Слой проекта',
                      ),
                      items: ProjectLayer.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        _pushUndo();
                        wall.projectLayer = v;
                        wall.demolition = v == ProjectLayer.demolition;
                        await _changed();
                        modalSetState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Проёмы',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...wall.openings.map(
                      (o) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          o.type == OpeningType.window
                              ? Icons.window
                              : Icons.door_front_door_outlined,
                        ),
                        title: Text(
                          '${o.type == OpeningType.window ? 'Окно' : 'Дверь'} ${o.widthMm.round()}×${o.heightMm.round()}',
                        ),
                        subtitle: Text(
                          'От угла A ${o.offsetFromStartMm.round()} мм • до угла B ${math.max(0.0, floor.wallLengthMm(wall) - o.offsetFromStartMm - o.widthMm).round()} мм${o.type == OpeningType.window ? ' • от пола ${o.sillHeightMm.round()} мм' : ''}',
                        ),
                        trailing: const Icon(Icons.drag_indicator),
                        onTap: () async {
                          await _editOpening(wall, o);
                          modalSetState(() {});
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              await _addOpening(wall, OpeningType.window);
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.window),
                            label: const Text('Окно'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              await _addOpening(wall, OpeningType.door);
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.door_front_door_outlined),
                            label: const Text('Дверь'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        _pushUndo();
                        GeometryService.removeWall(floor, wall.id);
                        _selectedWallId = null;
                        await _changed();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить стену'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF68717D)),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  void _setDimension(
    String key,
    double value,
    DimensionSource source, [
    String author = 'Не указан',
  ]) {
    final old = floor.dimensionRecords[key];
    if (old == null) {
      floor.dimensionRecords[key] = DimensionRecord(
        valueMm: value,
        source: source,
        author: author,
        recordedAt: DateTime.now(),
      );
    } else if (old.valueMm != value ||
        old.source != source ||
        old.author != author) {
      old.revise(value, source, author);
    }
  }

  Future<void> _recordEvidence(String key, double suggested) async {
    final existing = floor.dimensionRecords[key];
    var raw = (existing?.valueMm ?? suggested).round().toString();
    var author = existing?.author ?? '';
    var source = existing?.source ?? DimensionSource.manual;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Источник размера'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: raw,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Измерено',
                    suffixText: 'мм',
                  ),
                  onChanged: (value) => raw = value,
                ),
                DropdownButtonFormField<DimensionSource>(
                  initialValue: source,
                  decoration: const InputDecoration(labelText: 'Источник'),
                  items: DimensionSource.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialog(() => source = value ?? source),
                ),
                TextFormField(
                  initialValue: author,
                  decoration: const InputDecoration(labelText: 'Кто измерил'),
                  onChanged: (value) => author = value,
                ),
                if (existing != null)
                  Text(
                    'Исправлений: ${existing.history.length} • '
                    '${existing.recordedAt.toLocal().toString().split('.').first}',
                  ),
                if (existing != null)
                  for (final previous in existing.history.reversed.take(5))
                    Text(
                      '${previous.valueMm.round()} мм • ${previous.source.label} • '
                      '${previous.author} • ${previous.at.toLocal().toString().split('.').first}',
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    final measured = double.tryParse(raw.replaceAll(',', '.'));
    if (accepted != true ||
        measured == null ||
        !measured.isFinite ||
        measured <= 0)
      return;
    _pushUndo();
    _setDimension(
      key,
      measured,
      source,
      author.trim().isEmpty ? 'Не указан' : author.trim(),
    );
    await _changed();
  }

  Future<void> _editThickness(PlanWall wall) async {
    final v = await _numberDialog(
      'Толщина стены',
      'Толщина',
      wall.thicknessMm.round().toString(),
      'мм',
    );
    if (v == null || v <= 0) return;
    _pushUndo();
    wall.thicknessMm = v;
    await _changed();
  }

  Future<void> _editMaterial(PlanWall wall) async {
    final value = await showDialog<WallMaterial>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Материал стены'),
        children: WallMaterial.values
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m),
                child: Text(m.label),
              ),
            )
            .toList(),
      ),
    );
    if (value == null) return;
    _pushUndo();
    wall.material = value;
    await _changed();
  }

  Future<void> _editOpening(PlanWall wall, WallOpening opening) async {
    final len = floor.wallLengthMm(wall);
    final width = TextEditingController(
      text: opening.widthMm.round().toString(),
    );
    final height = TextEditingController(
      text: opening.heightMm.round().toString(),
    );
    final offset = TextEditingController(
      text: opening.offsetFromStartMm.round().toString(),
    );
    final sill = TextEditingController(
      text: opening.sillHeightMm.round().toString(),
    );
    var swing = opening.doorSwing;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(opening.type == OpeningType.window ? 'Окно' : 'Дверь'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: width,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ширина',
                    suffixText: 'мм',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Высота',
                    suffixText: 'мм',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: offset,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'От угла A до проёма',
                    suffixText: 'мм',
                  ),
                ),
                if (opening.type == OpeningType.window) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: sill,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'От пола',
                      suffixText: 'мм',
                    ),
                  ),
                ],
                if (opening.type == OpeningType.door) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DoorSwing>(
                    value: swing,
                    decoration: const InputDecoration(labelText: 'Открывание'),
                    items: DoorSwing.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (v) => setModal(() => swing = v ?? swing),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (result == 'delete') {
      _pushUndo();
      wall.openings.removeWhere((o) => o.id == opening.id);
      await _changed();
      return;
    }
    if (result != 'save') return;
    final w = double.tryParse(width.text.replaceAll(',', '.'));
    final h = double.tryParse(height.text.replaceAll(',', '.'));
    final o = double.tryParse(offset.text.replaceAll(',', '.'));
    final sh =
        double.tryParse(sill.text.replaceAll(',', '.')) ?? opening.sillHeightMm;
    if (w == null ||
        h == null ||
        o == null ||
        w <= 0 ||
        h <= 0 ||
        o < 0 ||
        o + w > len) {
      _toast('Проверь размеры проёма: он должен полностью помещаться в стене.');
      return;
    }
    _pushUndo();
    opening.widthMm = w;
    opening.heightMm = h;
    opening.offsetFromStartMm = o;
    _setDimension('opening:${opening.id}:offset', o, DimensionSource.manual);
    _setDimension('opening:${opening.id}:height', h, DimensionSource.manual);
    _setDimension('opening:${opening.id}:width', w, DimensionSource.manual);
    _setDimension(
      'opening:${opening.id}:rightOffset',
      math.max(0.0, len - o - w),
      DimensionSource.calculated,
    );
    opening.sillHeightMm = sh;
    opening.doorSwing = swing;
    await _changed();
  }

  Future<void> _addOpening(PlanWall wall, OpeningType type) async {
    final len = floor.wallLengthMm(wall);
    final width = TextEditingController(
      text: type == OpeningType.window ? '1400' : '900',
    );
    final height = TextEditingController(
      text: type == OpeningType.window ? '1400' : '2100',
    );
    final offset = TextEditingController(
      text: math
          .max(0, (len - double.parse(width.text)) / 2)
          .round()
          .toString(),
    );
    final sill = TextEditingController(
      text: type == OpeningType.window ? '850' : '0',
    );
    final opening = await showDialog<WallOpening>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          type == OpeningType.window ? 'Добавить окно' : 'Добавить дверь',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: width,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ширина',
                  suffixText: 'мм',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Высота',
                  suffixText: 'мм',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: offset,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'От угла A до проёма',
                  suffixText: 'мм',
                ),
              ),
              if (type == OpeningType.window) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: sill,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'От пола',
                    suffixText: 'мм',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(width.text);
              final h = double.tryParse(height.text);
              final o = double.tryParse(offset.text);
              final s = double.tryParse(sill.text) ?? 0;
              if (w == null ||
                  h == null ||
                  o == null ||
                  w <= 0 ||
                  h <= 0 ||
                  o < 0 ||
                  o + w > len)
                return;
              Navigator.pop(
                context,
                WallOpening(
                  id: _id('o'),
                  type: type,
                  widthMm: w,
                  heightMm: h,
                  offsetFromStartMm: o,
                  sillHeightMm: s,
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (opening == null) return;
    _pushUndo();
    wall.openings.add(opening);
    _setDimension(
      'opening:${opening.id}:offset',
      opening.offsetFromStartMm,
      DimensionSource.calculated,
    );
    _setDimension(
      'opening:${opening.id}:height',
      opening.heightMm,
      DimensionSource.calculated,
    );
    _setDimension(
      'opening:${opening.id}:width',
      opening.widthMm,
      DimensionSource.calculated,
    );
    _setDimension(
      'opening:${opening.id}:rightOffset',
      math.max(
        0.0,
        floor.wallLengthMm(wall) -
            opening.offsetFromStartMm -
            opening.widthMm,
      ),
      DimensionSource.calculated,
    );
    await _changed();
  }

  void _centerView(Size viewport) {
    if (viewport.isEmpty) return;
    final scale = 0.8;
    _transform.value = Matrix4.identity()
      ..translate(
        viewport.width / 2 - _origin.dx * scale,
        viewport.height / 2 - _origin.dy * scale,
      )
      ..scale(scale);
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _viewport = Size(c.maxWidth, c.maxHeight);
        if (!_centered) {
          _centered = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _centerView(_viewport),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 0.25,
                maxScale: 4,
                panEnabled:
                    _mode != PlanMode.nodes && _mode != PlanMode.opening,
                scaleEnabled:
                    _mode != PlanMode.nodes && _mode != PlanMode.opening,
                boundaryMargin: const EdgeInsets.all(1600),
                constrained: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onPanStart: _mode == PlanMode.nodes
                      ? _nodeDragStart
                      : (_mode == PlanMode.opening ? _openingDragStart : null),
                  onPanUpdate: _mode == PlanMode.nodes
                      ? _nodeDragUpdate
                      : (_mode == PlanMode.opening ? _openingDragUpdate : null),
                  onPanEnd: _mode == PlanMode.nodes
                      ? _nodeDragEnd
                      : (_mode == PlanMode.opening ? _openingDragEnd : null),
                  child: CustomPaint(
                    size: _canvasSize,
                    painter: FloorPlanPainter(
                      floor: floor,
                      mmToPx: _mmToPx,
                      origin: _origin,
                      selectedWallId: _selectedWallId,
                      activeNodeId: _mode == PlanMode.nodes
                          ? (_dragNodeId ?? _selectedNodeId)
                          : _activeNodeId,
                      showDimensions: _showDimensions,
                      visibleLayers: _visibleLayers,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 8,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _undo.isEmpty ? null : _undoAction,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        onPressed: _redo.isEmpty ? null : _redoAction,
                        icon: const Icon(Icons.redo),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _showDimensions = !_showDimensions),
                        icon: Icon(
                          _showDimensions
                              ? Icons.straighten
                              : Icons.straighten_outlined,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _centerView(_viewport),
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                      IconButton(
                        tooltip: _snappingEnabled
                            ? 'Привязка включена'
                            : 'Привязка выключена',
                        onPressed: () => setState(
                          () => _snappingEnabled = !_snappingEnabled,
                        ),
                        icon: Icon(
                          _snappingEnabled ? Icons.link : Icons.link_off,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Слои проекта',
                        onPressed: _layerVisibilityDialog,
                        icon: const Icon(Icons.layers_outlined),
                      ),
                      const Spacer(),
                      if (_activeNodeId != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _activeNodeId = null),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Стоп'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_mode == PlanMode.nodes && _lastNodeSnap != null)
              Positioned(
                top: 78,
                left: 18,
                child: Card(
                  color: const Color(0xFFF0F5FF),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link,
                          size: 16,
                          color: Color(0xFF315DA8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Привязка: ${_lastNodeSnap!.label}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF315DA8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: SafeArea(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _modeButton(
                                PlanMode.select,
                                Icons.pan_tool_alt_outlined,
                                'Навигация',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.nodes,
                                Icons.adjust,
                                'Точки',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.exterior,
                                Icons.home_work_outlined,
                                'Наружная',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.partition,
                                Icons.view_week_outlined,
                                'Перегородка',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.arc,
                                Icons.architecture_outlined,
                                'Радиус',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.opening,
                                Icons.door_front_door_outlined,
                                'Проёмы',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.demolition,
                                Icons.auto_delete_outlined,
                                'Демонтаж',
                              ),
                              const SizedBox(width: 6),
                              _modeButton(
                                PlanMode.dimension,
                                Icons.square_foot_outlined,
                                'Размер',
                              ),
                            ],
                          ),
                        ),
                        if (_mode == PlanMode.exterior ||
                            _mode == PlanMode.partition ||
                            _mode == PlanMode.arc) ...[
                          const SizedBox(height: 7),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<ProjectLayer>(
                              segments: const [
                                ButtonSegment(
                                  value: ProjectLayer.existing,
                                  label: Text('Существующее'),
                                ),
                                ButtonSegment(
                                  value: ProjectLayer.demolition,
                                  label: Text('Демонтаж'),
                                ),
                                ButtonSegment(
                                  value: ProjectLayer.proposed,
                                  label: Text('Новая планировка'),
                                ),
                              ],
                              selected: {_projectLayer},
                              onSelectionChanged: (v) =>
                                  setState(() => _projectLayer = v.first),
                            ),
                          ),
                        ],
                        if (_mode == PlanMode.exterior ||
                            _mode == PlanMode.partition ||
                            _mode == PlanMode.arc ||
                            _mode == PlanMode.nodes) ...[
                          const SizedBox(height: 7),
                          SegmentedButton<SnapMode>(
                            segments: const [
                              ButtonSegment(
                                value: SnapMode.ortho,
                                label: Text('90°'),
                              ),
                              ButtonSegment(
                                value: SnapMode.deg45,
                                label: Text('45°'),
                              ),
                              ButtonSegment(
                                value: SnapMode.free,
                                label: Text('Свободно'),
                              ),
                            ],
                            selected: {_snap},
                            onSelectionChanged: (s) =>
                                setState(() => _snap = s.first),
                          ),
                        ],
                        if (_mode == PlanMode.partition) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _activeNodeId == null
                                      ? 'Выбери начало, затем нажми в любой точке для свободного конца.'
                                      : 'Конец перегородки может быть свободным: нажми в нужной точке и заверши линию.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (_activeNodeId != null)
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _activeNodeId = null),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Завершить'),
                                ),
                            ],
                          ),
                        ],
                        if (_mode == PlanMode.arc) ...[
                          const SizedBox(height: 7),
                          SegmentedButton<WallType>(
                            segments: const [
                              ButtonSegment(
                                value: WallType.exterior,
                                label: Text('Наружная 300'),
                              ),
                              ButtonSegment(
                                value: WallType.partition,
                                label: Text('Перегородка 100'),
                              ),
                            ],
                            selected: {_arcWallType},
                            onSelectionChanged: (s) =>
                                setState(() => _arcWallType = s.first),
                          ),
                        ],
                        if (_mode == PlanMode.opening) ...[
                          const SizedBox(height: 7),
                          SegmentedButton<OpeningType>(
                            segments: const [
                              ButtonSegment(
                                value: OpeningType.door,
                                icon: Icon(Icons.door_front_door_outlined),
                                label: Text('Дверь'),
                              ),
                              ButtonSegment(
                                value: OpeningType.window,
                                icon: Icon(Icons.window),
                                label: Text('Окно'),
                              ),
                            ],
                            selected: {_openingType},
                            onSelectionChanged: (s) =>
                                setState(() => _openingType = s.first),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажми на стену, чтобы добавить. Существующие двери и окна можно двигать пальцем.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (_mode == PlanMode.demolition) ...[
                          const SizedBox(height: 7),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'Нажимай существующие стены для включения/исключения из демонтажа. Красная штриховка = будет удалено.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _layerVisibilityDialog() async {
    final draft = Set<ProjectLayer>.of(_visibleLayers);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Видимость слоёв'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ProjectLayer.values
                .map(
                  (layer) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draft.contains(layer),
                    title: Text(layer.label),
                    onChanged: (v) => setModal(() {
                      if (v == true)
                        draft.add(layer);
                      else
                        draft.remove(layer);
                    }),
                  ),
                )
                .toList(),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _visibleLayers
        ..clear()
        ..addAll(draft);
    });
  }

  Widget _modeButton(PlanMode mode, IconData icon, String label) {
    final active = _mode == mode;
    final button = active
        ? FilledButton.icon(
            onPressed: () => setState(() => _mode = mode),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1),
          )
        : OutlinedButton.icon(
            onPressed: () => setState(() {
              _mode = mode;
              _activeNodeId = null;
              _measureStartNodeId = null;
              _selectedNodeId = null;
              _dragNodeId = null;
              _lastNodeSnap = null;
            }),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1),
          );
    return SizedBox(width: 132, child: button);
  }
}

class _OpeningHit {
  const _OpeningHit(this.wall, this.opening);
  final PlanWall wall;
  final WallOpening opening;
}
