import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/floor_plan_painter.dart';

enum _ConceptAngleSnap { ortho, deg45, free }

class PlanEditorConceptScreen extends StatefulWidget {
  const PlanEditorConceptScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpen3D,
    required this.onOpenFloors,
    required this.onOpenSettings,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpen3D;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;

  @override
  State<PlanEditorConceptScreen> createState() =>
      _PlanEditorConceptScreenState();
}

class _PlanEditorConceptScreenState extends State<PlanEditorConceptScreen> {
  static const _canvasSize = Size(5200, 5200);
  static const _origin = Offset(2600, 2600);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();

  ZMeasureTool _tool = ZMeasureTool.walls;
  WallType _wallType = WallType.exterior;
  WallMaterial _wallMaterial = WallMaterial.gasBlock;
  ProjectLayer _projectLayer = ProjectLayer.existing;
  OpeningType _openingType = OpeningType.door;
  DimensionSource _dimensionSource = DimensionSource.manual;
  _ConceptAngleSnap _angleSnap = _ConceptAngleSnap.ortho;
  double _wallThicknessMm = 120;
  bool _showDimensions = true;
  bool _snapping = true;
  bool _gridEnabled = true;
  bool _centered = false;
  Size _viewport = Size.zero;
  String? _activeNodeId;
  String? _measureStartNodeId;
  String? _selectedWallId;
  String _finishCategory = 'Пол';

  FloorPlan get floor => widget.floor;

  PlanWall? get _selectedWall => _selectedWallId == null
      ? null
      : floor.wallById(_selectedWallId!);

  @override
  void initState() {
    super.initState();
    if (floor.walls.isNotEmpty) {
      _selectedWallId = floor.walls.first.id;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  double get _viewScale =>
      math.max(.1, _transform.value.getMaxScaleOnAxis());

  math.Point<double> _toMm(Offset p) => math.Point<double>(
        (p.dx - _origin.dx) / _mmToPx,
        (p.dy - _origin.dy) / _mmToPx,
      );

  Offset _toCanvas(PlanNode node) =>
      _origin + Offset(node.xMm * _mmToPx, node.yMm * _mmToPx);

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
    if (tool == ZMeasureTool.text) _editNotes();
    if (tool == ZMeasureTool.layers) _showLayers();
  }

  double _bottomReserve() => _selectedWall != null ? 246 : 118;

  void _centerView() {
    if (_viewport.isEmpty) return;
    const leftRail = 64.0;
    const rightRail = 58.0;
    final bottom = _bottomReserve();
    final usableW = math.max(120.0, _viewport.width - leftRail - rightRail - 22);
    final usableH = math.max(160.0, _viewport.height - bottom - 18);
    var scale = .9;
    var center = const math.Point<double>(0, 0);

    if (floor.nodes.isNotEmpty) {
      final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
      final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
      final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
      final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
      center = math.Point((minX + maxX) / 2, (minY + maxY) / 2);
      final widthPx = math.max(1.0, (maxX - minX) * _mmToPx);
      final heightPx = math.max(1.0, (maxY - minY) * _mmToPx);
      final sx = usableW / widthPx;
      final sy = usableH / heightPx;
      scale = math.min(1.7, math.max(.32, math.min(sx, sy) * .94));
    }

    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    final screenCenter = Offset(leftRail + usableW / 2, 8 + usableH / 2);
    _transform.value = Matrix4.identity()
      ..translate(
        screenCenter.dx - target.dx * scale,
        screenCenter.dy - target.dy * scale,
      )
      ..scale(scale);
  }

  void _zoom(double factor) {
    final next = _transform.value.clone()..scale(factor);
    _transform.value = next;
    setState(() {});
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

  PlanWall? _wallNear(Offset p, {double px = 30}) {
    PlanWall? best;
    var bestDistance = px / _viewScale;
    for (final wall in floor.walls) {
      if (wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final distance = _distanceToSegment(p, _toCanvas(a), _toCanvas(b));
      if (distance < bestDistance) {
        best = wall;
        bestDistance = distance;
      }
    }
    return best;
  }

  PlanNode? _nodeNear(Offset p, {double px = 30}) {
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

  double _snapAngle(double raw) {
    if (!_snapping || _angleSnap == _ConceptAngleSnap.free) return raw;
    final step = _angleSnap == _ConceptAngleSnap.ortho
        ? math.pi / 2
        : math.pi / 4;
    return (raw / step).round() * step;
  }

  Future<void> _tap(TapUpDetails details) async {
    switch (_tool) {
      case ZMeasureTool.walls:
        final wall = _wallNear(details.localPosition, px: 25);
        if (_activeNodeId == null && wall != null) {
          setState(() => _selectedWallId = wall.id);
          return;
        }
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
    String? newestWall;
    for (final wall in floor.walls.where((e) => !before.contains(e.id))) {
      wall.projectLayer = _projectLayer;
      wall.demolition = _projectLayer == ProjectLayer.demolition;
      newestWall = wall.id;
    }
    setState(() {
      _activeNodeId = end.id;
      _selectedWallId = newestWall;
    });
    await _changed();
  }

  Future<void> _tapOpening(Offset p) async {
    final wall = _wallNear(p, px: 34);
    if (wall == null) {
      _toast('Нажми на стену для добавления проёма.');
      return;
    }
    setState(() => _selectedWallId = wall.id);
    await _openingSheet(wall);
  }

  Future<void> _tapDimension(Offset p) async {
    final node = _nodeNear(p, px: 34);
    if (node == null) {
      _toast('Выбери существующий узел стены.');
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
      source: _dimensionSource,
      author: 'Не указан',
      recordedAt: DateTime.now(),
    );
    setState(() => _measureStartNodeId = null);
    await _changed();
  }

  Future<double?> _numberDialog({
    required String title,
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
          decoration: InputDecoration(labelText: 'Размер', suffixText: suffix),
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
      text: _openingType == OpeningType.door ? '900' : '1500',
    );
    final height = TextEditingController(
      text: _openingType == OpeningType.door ? '2100' : '1500',
    );
    final sill = TextEditingController(
      text: _openingType == OpeningType.door ? '0' : '900',
    );
    final length = floor.wallLengthMm(wall);
    final offset = TextEditingController(
      text: math.max(0, (length - double.parse(width.text)) / 2)
          .round()
          .toString(),
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
                  Text('Добавить проём', style: ZamerTypography.h3),
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
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      final w = double.tryParse(width.text.replaceAll(',', '.'));
                      final h = double.tryParse(height.text.replaceAll(',', '.'));
                      final o = double.tryParse(offset.text.replaceAll(',', '.'));
                      final s = double.tryParse(sill.text.replaceAll(',', '.')) ?? 0;
                      if (w == null || h == null || o == null || w <= 0 || h <= 0 || o < 0 || o + w > length) {
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
    for (final entry in <String, double>{
      'width': result.widthMm,
      'height': result.heightMm,
      'offset': result.offsetFromStartMm,
    }.entries) {
      floor.dimensionRecords['opening:${result.id}:${entry.key}'] = DimensionRecord(
        valueMm: entry.value,
        source: _dimensionSource,
        author: 'Не указан',
        recordedAt: DateTime.now(),
      );
    }
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
                maxLines: 6,
                autofocus: true,
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
    if (value == null) return;
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
                    onChanged: (value) => setSheet(() {
                      if (value == true) {
                        draft.add(layer);
                      } else if (draft.length > 1) {
                        draft.remove(layer);
                      }
                    }),
                  ),
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

  Future<void> _editSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    final thickness = TextEditingController(text: wall.thicknessMm.round().toString());
    final height = TextEditingController(
      text: (wall.heightOverrideMm ?? floor.defaultHeightMm).round().toString(),
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Свойства стены', style: ZamerTypography.h3),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: thickness,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Толщина', suffixText: 'мм'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Высота', suffixText: 'мм'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final t = double.tryParse(thickness.text.replaceAll(',', '.'));
                final h = double.tryParse(height.text.replaceAll(',', '.'));
                if (t == null || h == null || t <= 0 || h <= 0) return;
                wall.thicknessMm = t;
                wall.heightOverrideMm = h;
                Navigator.pop(context, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    thickness.dispose();
    height.dispose();
    if (result == true) await _changed();
  }

  Future<void> _deleteSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    GeometryService.removeWall(floor, wall.id);
    setState(() {
      _selectedWallId = floor.walls.isEmpty ? null : floor.walls.first.id;
      _activeNodeId = null;
    });
    await _changed();
  }

  Future<void> _applyFinish(VisualMaterialPreset preset) async {
    GeometryService.syncRoomMetadata(floor);
    if (floor.roomMetas.isEmpty) {
      _toast('Сначала замкни помещение, затем назначай отделку.');
      return;
    }
    for (final room in floor.roomMetas) {
      if (_finishCategory == 'Пол') {
        room.materials.floorMaterialId = preset.id;
        final tile = preset.category == 'Плитка';
        room.materials.floorTile = tile;
        room.materials.floorMode = tile ? 'tile' : 'laminate';
      } else if (_finishCategory == 'Стены') {
        room.materials.wallMaterialId = preset.id;
        room.materials.wallPaint = true;
      }
    }
    await _changed();
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
        final selected = _selectedWall;
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
                  onLongPressEnd: (details) {
                    final wall = _wallNear(details.localPosition, px: 34);
                    if (wall != null) setState(() => _selectedWallId = wall.id);
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
              left: 8,
              top: 8,
              child: _ConceptToolRail(
                value: _tool,
                onChanged: _selectTool,
                onReview: widget.onOpenReview,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: _ConceptRightRail(
                gridEnabled: _gridEnabled,
                snapping: _snapping,
                onGrid: () => setState(() => _gridEnabled = !_gridEnabled),
                on3D: widget.onOpen3D,
                onFloors: widget.onOpenFloors,
                onSnap: () => setState(() => _snapping = !_snapping),
                onSettings: widget.onOpenSettings,
              ),
            ),
            Positioned(
              left: 12,
              bottom: _bottomReserve() + 8,
              child: Row(
                children: [
                  _CanvasButton(icon: Icons.arrow_back_rounded, onTap: widget.onOpenGeometry),
                  const SizedBox(width: 4),
                  _CanvasButton(icon: Icons.arrow_forward_rounded, onTap: widget.onOpenGeometry),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: _bottomReserve() + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CanvasButton(icon: Icons.fullscreen_rounded, onTap: _centerView),
                  const SizedBox(height: 6),
                  _MiniMap(floor: floor),
                ],
              ),
            ),
            Positioned(
              right: 68,
              bottom: _bottomReserve() + 8,
              child: Row(
                children: [
                  _CanvasButton(icon: Icons.remove_rounded, onTap: () => _zoom(.88)),
                  const SizedBox(width: 4),
                  _CanvasButton(icon: Icons.add_rounded, onTap: () => _zoom(1.14)),
                ],
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: selected == null
                  ? _ToolSettingsPanel(
                      wallType: _wallType,
                      thickness: _wallThicknessMm,
                      layer: _projectLayer,
                      angleSnap: _angleSnap,
                      onWallType: (value) => setState(() {
                        _wallType = value;
                        _wallThicknessMm = value == WallType.exterior ? 120 : 100;
                      }),
                      onThickness: (delta) => setState(() {
                        _wallThicknessMm = (_wallThicknessMm + delta).clamp(50, 1000).toDouble();
                      }),
                      onLayer: (value) => setState(() => _projectLayer = value),
                      onAngle: (value) => setState(() => _angleSnap = value),
                      onGeometry: widget.onOpenGeometry,
                    )
                  : _SelectedWallConceptPanel(
                      floor: floor,
                      wall: selected,
                      tool: _tool,
                      finishCategory: _finishCategory,
                      onTool: _selectTool,
                      onEdit: _editSelectedWall,
                      onDelete: _deleteSelectedWall,
                      onCategory: (value) => setState(() => _finishCategory = value),
                      onFinish: _applyFinish,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ConceptToolRail extends StatelessWidget {
  const _ConceptToolRail({
    required this.value,
    required this.onChanged,
    required this.onReview,
  });

  final ZMeasureTool value;
  final ValueChanged<ZMeasureTool> onChanged;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xF20A1720),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tool in ZMeasureTool.values)
              _RailButton(
                icon: tool.icon,
                label: tool.label,
                selected: tool == value,
                onTap: () => onChanged(tool),
              ),
            const Divider(height: 7),
            _RailButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Проверка',
              selected: false,
              onTap: onReview,
            ),
          ],
        ),
      );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: ZPressEffect(
          scale: .94,
          child: Material(
            color: selected ? ZamerColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 44,
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? ZamerColors.accentInk : ZamerColors.textPrimary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 7.2,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
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

class _ConceptRightRail extends StatelessWidget {
  const _ConceptRightRail({
    required this.gridEnabled,
    required this.snapping,
    required this.onGrid,
    required this.on3D,
    required this.onFloors,
    required this.onSnap,
    required this.onSettings,
  });

  final bool gridEnabled;
  final bool snapping;
  final VoidCallback onGrid;
  final VoidCallback on3D;
  final VoidCallback onFloors;
  final VoidCallback onSnap;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xF20A1720),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RightButton(icon: Icons.grid_4x4_rounded, label: 'Сетка', active: gridEnabled, onTap: onGrid),
            _RightButton(icon: Icons.view_in_ar_outlined, label: '3D вид', onTap: on3D),
            _RightButton(icon: Icons.layers_outlined, label: 'Этажи', onTap: onFloors),
            _RightButton(icon: Icons.link_rounded, label: 'Привязка', active: snapping, onTap: onSnap),
            _RightButton(icon: Icons.settings_outlined, label: 'Настройки', onTap: onSettings),
          ],
        ),
      );
}

class _RightButton extends StatelessWidget {
  const _RightButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .94,
        child: Material(
          color: active ? ZamerColors.accent.withValues(alpha: .14) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 46,
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21, color: ZamerColors.textPrimary),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 6.7,
                      fontWeight: FontWeight.w600,
                      color: ZamerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SelectedWallConceptPanel extends StatelessWidget {
  const _SelectedWallConceptPanel({
    required this.floor,
    required this.wall,
    required this.tool,
    required this.finishCategory,
    required this.onTool,
    required this.onEdit,
    required this.onDelete,
    required this.onCategory,
    required this.onFinish,
  });

  final FloorPlan floor;
  final PlanWall wall;
  final ZMeasureTool tool;
  final String finishCategory;
  final ValueChanged<ZMeasureTool> onTool;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onCategory;
  final ValueChanged<VisualMaterialPreset> onFinish;

  double get _angle {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return 0;
    var value = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm) * 180 / math.pi;
    if (value < 0) value += 360;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final index = math.max(0, floor.walls.indexWhere((item) => item.id == wall.id));
    final name = 'Стена ${String.fromCharCode(65 + (index % 26))}${index ~/ 26 + 1}';
    final categories = const ['Пол', 'Стены', 'Потолок', 'Двери', 'Окна', 'Освещение'];
    final presets = finishCategory == 'Стены'
        ? MaterialCatalog.forCategory('Стены').take(6).toList()
        : MaterialCatalog.floorFinishes.take(6).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 62,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xF20A1720),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                decoration: BoxDecoration(
                  color: ZamerColors.surface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.view_week_outlined, size: 28),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 62,
                child: InkWell(
                  onTap: onEdit,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _Metric(label: 'Длина', value: '${floor.wallLengthMm(wall).round()} мм')),
              Expanded(child: _Metric(label: 'Угол', value: '${_angle.round()}°')),
              Expanded(child: _Metric(label: 'Толщина', value: '${wall.thicknessMm.round()} мм')),
              Expanded(child: _Metric(label: 'Высота', value: '${(wall.heightOverrideMm ?? floor.defaultHeightMm).round()} мм')),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.more_vert_rounded, size: 17)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _QuickTools(tool: tool, onTool: onTool, onDelete: onDelete),
        const SizedBox(height: 4),
        Container(
          height: 104,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
          decoration: BoxDecoration(
            color: const Color(0xF20A1720),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (final category in categories)
                      Expanded(
                        child: _CategoryButton(
                          label: category,
                          selected: category == finishCategory,
                          onTap: () => onCategory(category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 5),
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    return _MaterialCard(preset: preset, onTap: () => onFinish(preset));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        margin: const EdgeInsets.only(left: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, style: const TextStyle(fontSize: 6.8, color: ZamerColors.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _QuickTools extends StatelessWidget {
  const _QuickTools({required this.tool, required this.onTool, required this.onDelete});
  final ZMeasureTool tool;
  final ValueChanged<ZMeasureTool> onTool;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tools = <(ZMeasureTool, String, IconData)>[
      (ZMeasureTool.walls, 'Стена', Icons.view_week_outlined),
      (ZMeasureTool.openings, 'Проём', Icons.door_front_door_outlined),
      (ZMeasureTool.dimensions, 'Размер', Icons.straighten_outlined),
      (ZMeasureTool.text, 'Текст', Icons.title_rounded),
      (ZMeasureTool.objects, 'Фигура', Icons.hexagon_outlined),
      (ZMeasureTool.layers, 'Слой', Icons.layers_outlined),
    ];
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xF20A1720),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        children: [
          for (final entry in tools)
            Expanded(
              child: _QuickButton(
                icon: entry.$3,
                label: entry.$2,
                selected: tool == entry.$1,
                onTap: () => onTool(entry.$1),
              ),
            ),
          Expanded(
            child: _QuickButton(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить',
              selected: false,
              danger: true,
              onTap: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .94,
        child: Material(
          color: selected ? ZamerColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: danger
                      ? ZamerColors.danger
                      : selected
                          ? ZamerColors.accentInk
                          : ZamerColors.textPrimary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w600,
                    color: danger
                        ? ZamerColors.danger
                        : selected
                            ? ZamerColors.accentInk
                            : ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? ZamerColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 7.2,
                  fontWeight: FontWeight.w700,
                  color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.preset, required this.onTap});
  final VisualMaterialPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 68,
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: preset.textureAsset == null
                        ? ColoredBox(color: preset.color)
                        : Image.asset(
                            preset.textureAsset!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(color: preset.color),
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 6.7, color: ZamerColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ToolSettingsPanel extends StatelessWidget {
  const _ToolSettingsPanel({
    required this.wallType,
    required this.thickness,
    required this.layer,
    required this.angleSnap,
    required this.onWallType,
    required this.onThickness,
    required this.onLayer,
    required this.onAngle,
    required this.onGeometry,
  });

  final WallType wallType;
  final double thickness;
  final ProjectLayer layer;
  final _ConceptAngleSnap angleSnap;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_ConceptAngleSnap> onAngle;
  final VoidCallback onGeometry;

  @override
  Widget build(BuildContext context) => Container(
        height: 104,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xF20A1720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<WallType>(
                    segments: const [
                      ButtonSegment(value: WallType.exterior, label: Text('Стена')),
                      ButtonSegment(value: WallType.partition, label: Text('Перег.')),
                    ],
                    selected: {wallType},
                    onSelectionChanged: (value) => onWallType(value.first),
                  ),
                ),
                const SizedBox(width: 6),
                _StepValue(
                  value: '${thickness.round()} мм',
                  onMinus: () => onThickness(-20),
                  onPlus: () => onThickness(20),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(label: 'Существующее', selected: layer == ProjectLayer.existing, onTap: () => onLayer(ProjectLayer.existing)),
                  _Chip(label: 'Демонтаж', selected: layer == ProjectLayer.demolition, onTap: () => onLayer(ProjectLayer.demolition)),
                  _Chip(label: 'Новое', selected: layer == ProjectLayer.proposed, onTap: () => onLayer(ProjectLayer.proposed)),
                  _Chip(label: '90°', selected: angleSnap == _ConceptAngleSnap.ortho, onTap: () => onAngle(_ConceptAngleSnap.ortho)),
                  _Chip(label: '45°', selected: angleSnap == _ConceptAngleSnap.deg45, onTap: () => onAngle(_ConceptAngleSnap.deg45)),
                  _Chip(label: 'Свободно', selected: angleSnap == _ConceptAngleSnap.free, onTap: () => onAngle(_ConceptAngleSnap.free)),
                  _Chip(label: 'Радиус/узлы', selected: false, onTap: onGeometry),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StepValue extends StatelessWidget {
  const _StepValue({required this.value, required this.onMinus, required this.onPlus});
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded, size: 18)),
            Text(value, style: ZamerTypography.technical),
            IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded, size: 18)),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Material(
          color: selected ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _CanvasButton extends StatelessWidget {
  const _CanvasButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .92,
        child: Material(
          color: const Color(0xF20A1720),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: ZamerColors.outlineSoft),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18),
            ),
          ),
        ),
      );
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.floor});
  final FloorPlan floor;

  @override
  Widget build(BuildContext context) => Container(
        width: 58,
        height: 58,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xF20A1720),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: CustomPaint(painter: _MiniMapPainter(floor)),
      );
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.floor);
  final FloorPlan floor;

  @override
  void paint(Canvas canvas, Size size) {
    if (floor.nodes.isEmpty) return;
    final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
    final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
    final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
    final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
    final w = math.max(1.0, maxX - minX);
    final h = math.max(1.0, maxY - minY);
    final scale = math.min(size.width / w, size.height / h) * .88;
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    Offset p(PlanNode node) => Offset(
          dx + (node.xMm - minX) * scale,
          dy + (node.yMm - minY) * scale,
        );
    final paint = Paint()
      ..color = ZamerColors.textSecondary
      ..strokeWidth = 1.5;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a != null && b != null) canvas.drawLine(p(a), p(b), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => oldDelegate.floor != floor;
}
