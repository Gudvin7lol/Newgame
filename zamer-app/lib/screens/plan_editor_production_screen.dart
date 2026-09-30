import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/floor_plan_painter.dart';

enum _AngleSnap { ortho, deg45, free }

class PlanEditorProductionScreen extends StatefulWidget {
  const PlanEditorProductionScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenAdvanced,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenAdvanced;

  @override
  State<PlanEditorProductionScreen> createState() =>
      _PlanEditorProductionScreenState();
}

class _PlanEditorProductionScreenState
    extends State<PlanEditorProductionScreen> {
  static const _canvasSize = Size(5200, 5200);
  static const _origin = Offset(2600, 2600);
  static const _mmToPx = 0.10;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();

  ZMeasureTool _tool = ZMeasureTool.walls;
  WallType _wallType = WallType.exterior;
  WallMaterial _wallMaterial = WallMaterial.gasBlock;
  ProjectLayer _projectLayer = ProjectLayer.existing;
  _AngleSnap _angleSnap = _AngleSnap.ortho;
  OpeningType _openingType = OpeningType.door;
  double _wallThicknessMm = 300;
  bool _showDimensions = true;
  bool _snapping = true;
  bool _centered = false;
  Size _viewport = Size.zero;
  String? _activeNodeId;
  String? _measureStartNodeId;
  String? _selectedWallId;

  FloorPlan get floor => widget.floor;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  math.Point<double> _toMm(Offset p) => math.Point<double>(
        (p.dx - _origin.dx) / _mmToPx,
        (p.dy - _origin.dy) / _mmToPx,
      );

  Offset _toCanvas(PlanNode n) =>
      _origin + Offset(n.xMm * _mmToPx, n.yMm * _mmToPx);

  double get _viewScale =>
      math.max(.1, _transform.value.getMaxScaleOnAxis());

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(floor);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _selectTool(ZMeasureTool tool) {
    if (tool == ZMeasureTool.objects) {
      widget.onOpenObjects();
      return;
    }
    setState(() {
      _tool = tool;
      _activeNodeId = null;
      _measureStartNodeId = null;
    });
    if (tool == ZMeasureTool.text) {
      _editNotes();
    } else if (tool == ZMeasureTool.layers) {
      _showLayers();
    }
  }

  void _centerView() {
    if (_viewport.isEmpty) return;
    var scale = .8;
    var center = const math.Point<double>(0, 0);
    if (floor.nodes.isNotEmpty) {
      final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
      final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
      final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
      final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
      center = math.Point((minX + maxX) / 2, (minY + maxY) / 2);
      final widthPx = math.max(1.0, (maxX - minX) * _mmToPx);
      final heightPx = math.max(1.0, (maxY - minY) * _mmToPx);
      final sx = (_viewport.width - 110) / widthPx;
      final sy = (_viewport.height - 160) / heightPx;
      scale = math.min(.95, math.max(.28, math.min(sx, sy) * .78));
    }
    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    _transform.value = Matrix4.identity()
      ..translate(
        _viewport.width / 2 - target.dx * scale,
        _viewport.height / 2 - target.dy * scale,
      )
      ..scale(scale);
  }

  PlanWall? _wallNear(Offset p, {double px = 28}) {
    PlanWall? best;
    var bestDistance = px / _viewScale;
    for (final wall in floor.walls) {
      if (wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final d = _distanceToSegment(p, _toCanvas(a), _toCanvas(b));
      if (d < bestDistance) {
        bestDistance = d;
        best = wall;
      }
    }
    return best;
  }

  PlanNode? _nodeNear(Offset p, {double px = 28}) {
    PlanNode? best;
    var bestDistance = px / _viewScale;
    for (final node in floor.nodes) {
      final distance = (_toCanvas(node) - p).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
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
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / l2)
        .clamp(0.0, 1.0)
        .toDouble();
    return (p - (a + ab * t)).distance;
  }

  double _snapAngle(double raw) {
    if (!_snapping || _angleSnap == _AngleSnap.free) return raw;
    final step = _angleSnap == _AngleSnap.ortho ? math.pi / 2 : math.pi / 4;
    return (raw / step).round() * step;
  }

  Future<void> _tap(TapUpDetails details) async {
    switch (_tool) {
      case ZMeasureTool.walls:
        await _tapWall(details.localPosition);
      case ZMeasureTool.openings:
        await _tapOpening(details.localPosition);
      case ZMeasureTool.dimensions:
        await _tapDimension(details.localPosition);
      case ZMeasureTool.objects:
        widget.onOpenObjects();
      case ZMeasureTool.text:
        await _editNotes();
      case ZMeasureTool.layers:
        await _showLayers();
    }
  }

  Future<void> _tapWall(Offset p) async {
    if (_activeNodeId == null) {
      final node = GeometryService.ensureAnchor(floor, _toMm(p));
      setState(() {
        _activeNodeId = node.id;
        _selectedWallId = null;
      });
      await _changed();
      return;
    }

    final start = floor.nodeById(_activeNodeId!);
    if (start == null) {
      setState(() => _activeNodeId = null);
      return;
    }
    final raw = _toMm(p);
    final dx = raw.x - start.xMm;
    final dy = raw.y - start.yMm;
    final estimated = math.sqrt(dx * dx + dy * dy);
    if (estimated < 20) return;
    final angle = _snapAngle(math.atan2(dy, dx));
    final opposite = GeometryService.parallelReferenceLength(floor, start, angle);
    final length = await _numberDialog(
      title: opposite == null
          ? 'Длина стены'
          : 'Стена напротив ${opposite.round()} мм',
      label: 'Длина',
      value: (opposite ?? estimated).round().toString(),
      suffix: 'мм',
    );
    if (length == null || length <= 0) return;

    final endpoint = math.Point<double>(
      start.xMm + math.cos(angle) * length,
      start.yMm + math.sin(angle) * length,
    );
    final before = floor.walls.map((e) => e.id).toSet();
    final end = GeometryService.addWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: endpoint,
      type: _wallType,
      thicknessMm: _wallThicknessMm,
      material: _wallMaterial,
    );
    for (final wall in floor.walls.where((e) => !before.contains(e.id))) {
      wall.projectLayer = _projectLayer;
      wall.demolition = _projectLayer == ProjectLayer.demolition;
    }
    setState(() => _activeNodeId = end.id);
    await _changed();
  }

  Future<void> _tapOpening(Offset p) async {
    final wall = _wallNear(p, px: 34);
    if (wall == null) {
      _toast('Нажми на стену, в которую нужно добавить дверь или окно.');
      return;
    }
    setState(() => _selectedWallId = wall.id);
    await _openingSheet(wall);
  }

  Future<void> _tapDimension(Offset p) async {
    final node = _nodeNear(p, px: 34);
    if (node == null) {
      _toast('Для размера нажми на существующий узел стены.');
      return;
    }
    if (_measureStartNodeId == null) {
      setState(() => _measureStartNodeId = node.id);
      return;
    }
    if (_measureStartNodeId == node.id) return;
    final start = floor.nodeById(_measureStartNodeId!);
    if (start == null) return;
    final calculated = GeometryService.distance(start, node);
    final measured = await _numberDialog(
      title: 'Контрольный размер',
      label: 'Измерено',
      value: calculated.round().toString(),
      suffix: 'мм',
    );
    if (measured == null || measured <= 0) return;
    final measure = ControlMeasure(
      id: _id('m'),
      startNodeId: start.id,
      endNodeId: node.id,
      measuredMm: measured,
    );
    floor.measures.add(measure);
    floor.dimensionRecords['control:${measure.id}'] = DimensionRecord(
      valueMm: measured,
      source: DimensionSource.manual,
      author: 'Не указан',
      recordedAt: DateTime.now(),
    );
    setState(() => _measureStartNodeId = null);
    await _changed();
  }

  Future<double?> _numberDialog({
    required String title,
    required String label,
    required String value,
    required String suffix,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openingSheet(PlanWall wall) async {
    final width = TextEditingController(
      text: _openingType == OpeningType.door ? '900' : '1400',
    );
    final height = TextEditingController(
      text: _openingType == OpeningType.door ? '2100' : '1400',
    );
    final sill = TextEditingController(
      text: _openingType == OpeningType.door ? '0' : '850',
    );
    final length = floor.wallLengthMm(wall);
    final offset = TextEditingController(
      text: math.max(0, (length - double.parse(width.text)) / 2).round().toString(),
    );
    var type = _openingType;

    final result = await showModalBottomSheet<WallOpening>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Добавить проём',
                    style: ZamerTypography.h3,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<OpeningType>(
                    segments: const [
                      ButtonSegment(
                        value: OpeningType.door,
                        icon: Icon(Icons.door_front_door_outlined),
                        label: Text('Дверь'),
                      ),
                      ButtonSegment(
                        value: OpeningType.window,
                        icon: Icon(Icons.window_outlined),
                        label: Text('Окно'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) =>
                        setSheet(() => type = value.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: width,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ширина',
                            suffixText: 'мм',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: height,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Высота',
                            suffixText: 'мм',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: offset,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'От угла',
                            suffixText: 'мм',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: sill,
                          enabled: type == OpeningType.window,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'От пола',
                            suffixText: 'мм',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (wall.openings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Уже на стене', style: ZamerTypography.h5),
                    const SizedBox(height: 4),
                    for (final opening in wall.openings)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          opening.type == OpeningType.door
                              ? Icons.door_front_door_outlined
                              : Icons.window_outlined,
                        ),
                        title: Text(
                          '${opening.widthMm.round()} × ${opening.heightMm.round()} мм',
                        ),
                        subtitle: Text(
                          'От угла ${opening.offsetFromStartMm.round()} мм',
                        ),
                        trailing: IconButton(
                          tooltip: 'Удалить проём',
                          onPressed: () async {
                            wall.openings.remove(opening);
                            await _changed();
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final w = double.tryParse(width.text.replaceAll(',', '.'));
                      final h = double.tryParse(height.text.replaceAll(',', '.'));
                      final o = double.tryParse(offset.text.replaceAll(',', '.'));
                      final s = double.tryParse(sill.text.replaceAll(',', '.')) ?? 0;
                      if (w == null ||
                          h == null ||
                          o == null ||
                          w <= 0 ||
                          h <= 0 ||
                          o < 0 ||
                          o + w > length) {
                        return;
                      }
                      Navigator.pop(
                        context,
                        WallOpening(
                          id: _id('o'),
                          type: type,
                          widthMm: w,
                          heightMm: h,
                          offsetFromStartMm: o,
                          sillHeightMm: type == OpeningType.window ? s : 0,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить проём'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    width.dispose();
    height.dispose();
    sill.dispose();
    offset.dispose();
    if (result == null) return;
    wall.openings.add(result);
    _openingType = result.type;
    floor.dimensionRecords['opening:${result.id}:width'] = DimensionRecord(
      valueMm: result.widthMm,
      source: DimensionSource.manual,
      author: 'Не указан',
      recordedAt: DateTime.now(),
    );
    floor.dimensionRecords['opening:${result.id}:height'] = DimensionRecord(
      valueMm: result.heightMm,
      source: DimensionSource.manual,
      author: 'Не указан',
      recordedAt: DateTime.now(),
    );
    floor.dimensionRecords['opening:${result.id}:offset'] = DimensionRecord(
      valueMm: result.offsetFromStartMm,
      source: DimensionSource.manual,
      author: 'Не указан',
      recordedAt: DateTime.now(),
    );
    await _changed();
  }

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: floor.notes);
    final value = await showModalBottomSheet<String>(
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
              Text('Текст и заметка этажа', style: ZamerTypography.h3),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 7,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Добавь заметку по замеру, стенам или помещению',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (value == null || value == floor.notes) return;
    floor.notes = value;
    await _changed();
  }

  Future<void> _showLayers() async {
    final draft = Set<ProjectLayer>.of(_visibleLayers);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Слои проекта', style: ZamerTypography.h3),
                const SizedBox(height: 8),
                for (final layer in ProjectLayer.values)
                  CheckboxListTile(
                    value: draft.contains(layer),
                    contentPadding: EdgeInsets.zero,
                    title: Text(layer.label),
                    onChanged: (enabled) => setSheet(() {
                      if (enabled == true) {
                        draft.add(layer);
                      } else if (draft.length > 1) {
                        draft.remove(layer);
                      }
                    }),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _visibleLayers
                        ..clear()
                        ..addAll(draft);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showWallInspector(PlanWall wall) async {
    var type = wall.type;
    var material = wall.material;
    var layer = wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
    final thickness = TextEditingController(
      text: wall.thicknessMm.round().toString(),
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Стена • ${floor.wallLengthMm(wall).round()} мм',
                    style: ZamerTypography.h3,
                  ),
                  const SizedBox(height: 12),
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
                    selected: {type},
                    onSelectionChanged: (value) =>
                        setSheet(() => type = value.first),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: thickness,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Толщина',
                      suffixText: 'мм',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<WallMaterial>(
                    initialValue: material,
                    decoration: const InputDecoration(labelText: 'Материал'),
                    items: WallMaterial.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheet(() => material = value ?? material),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ProjectLayer>(
                    initialValue: layer,
                    decoration: const InputDecoration(labelText: 'Слой проекта'),
                    items: ProjectLayer.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheet(() => layer = value ?? layer),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            GeometryService.removeWall(floor, wall.id);
                            Navigator.pop(context, true);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Удалить'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final value = double.tryParse(
                              thickness.text.replaceAll(',', '.'),
                            );
                            if (value == null || value <= 0) return;
                            wall.type = type;
                            wall.material = material;
                            wall.thicknessMm = value;
                            wall.projectLayer = layer;
                            wall.demolition = layer == ProjectLayer.demolition;
                            Navigator.pop(context, true);
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    thickness.dispose();
    if (result == true) {
      setState(() => _selectedWallId = null);
      await _changed();
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_centered) {
          _centered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerView());
        }

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: .22,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(1800),
                constrained: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
                  onLongPressEnd: (details) async {
                    final wall = _wallNear(details.localPosition, px: 34);
                    if (wall == null) return;
                    setState(() => _selectedWallId = wall.id);
                    await _showWallInspector(wall);
                  },
                  child: CustomPaint(
                    size: _canvasSize,
                    painter: FloorPlanPainter(
                      floor: floor,
                      mmToPx: _mmToPx,
                      origin: _origin,
                      selectedWallId: _selectedWallId,
                      activeNodeId: _activeNodeId ?? _measureStartNodeId,
                      showDimensions: _showDimensions,
                      visibleLayers: _visibleLayers,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: ZMeasureToolRail(
                value: _tool,
                onChanged: _selectTool,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  ZMeasureCanvasAction(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Показать весь план',
                    onPressed: _centerView,
                  ),
                  const SizedBox(height: 6),
                  ZMeasureCanvasAction(
                    icon: _showDimensions
                        ? Icons.straighten_rounded
                        : Icons.straighten_outlined,
                    tooltip: 'Размеры на плане',
                    active: _showDimensions,
                    onPressed: () =>
                        setState(() => _showDimensions = !_showDimensions),
                  ),
                  const SizedBox(height: 6),
                  ZMeasureCanvasAction(
                    icon: _snapping ? Icons.link_rounded : Icons.link_off_rounded,
                    tooltip: 'Привязка',
                    active: _snapping,
                    onPressed: () => setState(() => _snapping = !_snapping),
                  ),
                  const SizedBox(height: 6),
                  ZMeasureCanvasAction(
                    icon: Icons.fact_check_outlined,
                    tooltip: 'Проверка геометрии',
                    onPressed: widget.onOpenReview,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 76,
              right: 10,
              bottom: 10,
              child: _Inspector(
                tool: _tool,
                wallType: _wallType,
                thicknessMm: _wallThicknessMm,
                layer: _projectLayer,
                angleSnap: _angleSnap,
                openingType: _openingType,
                activeWall: _activeNodeId != null,
                activeDimension: _measureStartNodeId != null,
                notes: floor.notes,
                onWallType: (value) => setState(() {
                  _wallType = value;
                  _wallThicknessMm = value == WallType.exterior ? 300 : 100;
                  _wallMaterial = value == WallType.exterior
                      ? WallMaterial.gasBlock
                      : WallMaterial.drywall;
                }),
                onThickness: (delta) => setState(() {
                  _wallThicknessMm =
                      (_wallThicknessMm + delta).clamp(50, 1000).toDouble();
                }),
                onLayer: (value) => setState(() => _projectLayer = value),
                onAngleSnap: (value) => setState(() => _angleSnap = value),
                onOpeningType: (value) => setState(() => _openingType = value),
                onStop: () => setState(() {
                  _activeNodeId = null;
                  _measureStartNodeId = null;
                }),
                onNotes: _editNotes,
                onLayers: _showLayers,
                onAdvanced: widget.onOpenAdvanced,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.tool,
    required this.wallType,
    required this.thicknessMm,
    required this.layer,
    required this.angleSnap,
    required this.openingType,
    required this.activeWall,
    required this.activeDimension,
    required this.notes,
    required this.onWallType,
    required this.onThickness,
    required this.onLayer,
    required this.onAngleSnap,
    required this.onOpeningType,
    required this.onStop,
    required this.onNotes,
    required this.onLayers,
    required this.onAdvanced,
  });

  final ZMeasureTool tool;
  final WallType wallType;
  final double thicknessMm;
  final ProjectLayer layer;
  final _AngleSnap angleSnap;
  final OpeningType openingType;
  final bool activeWall;
  final bool activeDimension;
  final String notes;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_AngleSnap> onAngleSnap;
  final ValueChanged<OpeningType> onOpeningType;
  final VoidCallback onStop;
  final VoidCallback onNotes;
  final VoidCallback onLayers;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZamerColors.surfaceLow.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(ZamerRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          border: Border.all(color: ZamerColors.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .20),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: switch (tool) {
          ZMeasureTool.walls => _wallControls(context),
          ZMeasureTool.openings => _openingControls(context),
          ZMeasureTool.objects => const SizedBox.shrink(),
          ZMeasureTool.dimensions => _dimensionControls(context),
          ZMeasureTool.text => _textControls(context),
          ZMeasureTool.layers => _layerControls(context),
        },
      ),
    );
  }

  Widget _wallControls(BuildContext context) => Column(
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
                  onSelectionChanged: (value) => onWallType(value.first),
                ),
              ),
              const SizedBox(width: 8),
              _StepValue(
                label: '${thicknessMm.round()} мм',
                onMinus: () => onThickness(-20),
                onPlus: () => onThickness(20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChoiceChip(
                  label: 'Существующее',
                  selected: layer == ProjectLayer.existing,
                  onTap: () => onLayer(ProjectLayer.existing),
                ),
                const SizedBox(width: 6),
                _ChoiceChip(
                  label: 'Демонтаж',
                  selected: layer == ProjectLayer.demolition,
                  onTap: () => onLayer(ProjectLayer.demolition),
                ),
                const SizedBox(width: 6),
                _ChoiceChip(
                  label: 'Новое',
                  selected: layer == ProjectLayer.proposed,
                  onTap: () => onLayer(ProjectLayer.proposed),
                ),
                const SizedBox(width: 10),
                _ChoiceChip(
                  label: '90°',
                  selected: angleSnap == _AngleSnap.ortho,
                  onTap: () => onAngleSnap(_AngleSnap.ortho),
                ),
                const SizedBox(width: 6),
                _ChoiceChip(
                  label: '45°',
                  selected: angleSnap == _AngleSnap.deg45,
                  onTap: () => onAngleSnap(_AngleSnap.deg45),
                ),
                const SizedBox(width: 6),
                _ChoiceChip(
                  label: 'Свободно',
                  selected: angleSnap == _AngleSnap.free,
                  onTap: () => onAngleSnap(_AngleSnap.free),
                ),
                if (activeWall) ...[
                  const SizedBox(width: 10),
                  _ActionChip(label: 'Завершить', onTap: onStop),
                ],
                const SizedBox(width: 6),
                _ActionChip(label: 'Ещё', onTap: onAdvanced),
              ],
            ),
          ),
        ],
      );

  Widget _openingControls(BuildContext context) => Row(
        children: [
          Expanded(
            child: SegmentedButton<OpeningType>(
              segments: const [
                ButtonSegment(
                  value: OpeningType.door,
                  icon: Icon(Icons.door_front_door_outlined),
                  label: Text('Дверь'),
                ),
                ButtonSegment(
                  value: OpeningType.window,
                  icon: Icon(Icons.window_outlined),
                  label: Text('Окно'),
                ),
              ],
              selected: {openingType},
              onSelectionChanged: (value) => onOpeningType(value.first),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Нажми на стену',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZamerTypography.caption,
            ),
          ),
        ],
      );

  Widget _dimensionControls(BuildContext context) => Row(
        children: [
          const Icon(Icons.square_foot_outlined, color: ZamerColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeDimension
                  ? 'Выбери второй узел размера'
                  : 'Выбери первый узел размера',
              style: ZamerTypography.bodySmall,
            ),
          ),
          if (activeDimension)
            TextButton(onPressed: onStop, child: const Text('Отмена')),
        ],
      );

  Widget _textControls(BuildContext context) => Row(
        children: [
          const Icon(Icons.notes_rounded, color: ZamerColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notes.isEmpty ? 'Заметка этажа не заполнена' : notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZamerTypography.bodySmall,
            ),
          ),
          TextButton(onPressed: onNotes, child: const Text('Изменить')),
        ],
      );

  Widget _layerControls(BuildContext context) => Row(
        children: [
          const Icon(Icons.layers_outlined, color: ZamerColors.accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Существующее • Демонтаж • Новая планировка',
              maxLines: 2,
              style: ZamerTypography.bodySmall,
            ),
          ),
          TextButton(onPressed: onLayers, child: const Text('Слои')),
        ],
      );
}

class _StepValue extends StatelessWidget {
  const _StepValue({
    required this.label,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
            Text(label, style: ZamerTypography.technical),
            IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
          ],
        ),
      );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: Material(
          color: selected ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
                border: Border.all(
                  color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Text(
                label,
                style: ZamerTypography.caption.copyWith(
                  color: selected
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: Material(
          color: ZamerColors.surfaceHigh,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
                border: Border.all(color: ZamerColors.outlineSoft),
              ),
              child: Text(label, style: ZamerTypography.caption),
            ),
          ),
        ),
      );
}
