import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/floor_plan_painter.dart';

enum _AngleSnapV2 { ortho, deg45, free }

/// Production 2D editor aligned to the approved Master UI / UI Kit 01-02.
///
/// Unlike the legacy editor this screen gives the drawing the majority of the
/// viewport and keeps CAD controls in compact floating toolbars. The bottom
/// area is a contextual inspector rather than a permanent oversized control
/// tray.
class PlanEditorMasterV2Screen extends StatefulWidget {
  const PlanEditorMasterV2Screen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;

  @override
  State<PlanEditorMasterV2Screen> createState() =>
      _PlanEditorMasterV2ScreenState();
}

class _PlanEditorMasterV2ScreenState extends State<PlanEditorMasterV2Screen> {
  static const _canvasSize = Size(6000, 6000);
  static const _origin = Offset(3000, 3000);
  static const _mmToPx = .11;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();

  ZMeasureTool _tool = ZMeasureTool.walls;
  WallType _wallType = WallType.exterior;
  WallMaterial _wallMaterial = WallMaterial.gasBlock;
  ProjectLayer _projectLayer = ProjectLayer.existing;
  OpeningType _openingType = OpeningType.door;
  DimensionSource _dimensionSource = DimensionSource.manual;
  _AngleSnapV2 _angleSnap = _AngleSnapV2.ortho;
  double _wallThicknessMm = 120;
  bool _showDimensions = true;
  bool _snapping = true;
  bool _centered = false;
  Size _viewport = Size.zero;
  String? _activeNodeId;
  String? _measureStartNodeId;
  String? _selectedWallId;

  FloorPlan get floor => widget.floor;

  PlanWall? get _selectedWall =>
      _selectedWallId == null ? null : floor.wallById(_selectedWallId!);

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

  double get _bottomReserve {
    if (_selectedWall != null) return 176;
    if (_tool == ZMeasureTool.walls || _tool == ZMeasureTool.dimensions) {
      return 112;
    }
    return 84;
  }

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
      if (tool != ZMeasureTool.walls && tool != ZMeasureTool.openings) {
        _selectedWallId = null;
      }
    });
    if (tool == ZMeasureTool.text) _editNotes();
    if (tool == ZMeasureTool.layers) _showLayers();
  }

  void _centerView() {
    if (_viewport.isEmpty) return;
    const sideReserve = 54.0;
    final usableW = math.max(160.0, _viewport.width - sideReserve * 2 - 20);
    final usableH =
        math.max(220.0, _viewport.height - _bottomReserve - 24);
    var scale = .95;
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
      scale = math.min(1.75, math.max(.32, math.min(sx, sy) * .93));
    }

    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    final screenCenter = Offset(
      sideReserve + usableW / 2,
      12 + usableH / 2,
    );
    _transform.value = Matrix4.identity()
      ..translate(
        screenCenter.dx - target.dx * scale,
        screenCenter.dy - target.dy * scale,
      )
      ..scale(scale);
    if (mounted) setState(() {});
  }

  void _zoom(double factor) {
    final matrix = _transform.value.clone()..scale(factor);
    _transform.value = matrix;
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
      final d = _distanceToSegment(p, _toCanvas(a), _toCanvas(b));
      if (d < bestDistance) {
        best = wall;
        bestDistance = d;
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
    if (!_snapping || _angleSnap == _AngleSnapV2.free) return raw;
    final step =
        _angleSnap == _AngleSnapV2.ortho ? math.pi / 2 : math.pi / 4;
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
      final existing = _wallNear(p, px: 28);
      if (existing != null) {
        setState(() => _selectedWallId = existing.id);
        return;
      }
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
      _toast('Выбери стену для проёма');
      return;
    }
    setState(() => _selectedWallId = wall.id);
    await _openingSheet(wall);
  }

  Future<void> _tapDimension(Offset p) async {
    final node = _nodeNear(p, px: 34);
    if (node == null) {
      _toast('Выбери узел стены');
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
      label: 'Значение',
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
      text: _openingType == OpeningType.door ? '900' : '1500',
    );
    final height = TextEditingController(
      text: _openingType == OpeningType.door ? '2100' : '1500',
    );
    final sill = TextEditingController(
      text: _openingType == OpeningType.door ? '0' : '900',
    );
    final wallLength = floor.wallLengthMm(wall);
    final offset = TextEditingController(
      text: math.max(0, (wallLength - double.parse(width.text)) / 2)
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
                  Text('Проём', style: ZamerTypography.h3),
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
                      Expanded(child: _numberField(width, 'Ширина')),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(height, 'Высота')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _numberField(offset, 'От угла')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          sill,
                          'Подоконник',
                          enabled: type == OpeningType.window,
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
                      if (w == null || h == null || o == null || w <= 0 || h <= 0) {
                        return;
                      }
                      if (o < 0 || o + w > wallLength) return;
                      Navigator.pop(
                        sheetContext,
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
    offset.dispose();
    sill.dispose();
    if (result == null) return;
    wall.openings.add(result);
    _openingType = result.type;
    for (final entry in <String, double>{
      'width': result.widthMm,
      'height': result.heightMm,
      'offset': result.offsetFromStartMm,
    }.entries) {
      floor.dimensionRecords['opening:${result.id}:${entry.key}'] =
          DimensionRecord(
        valueMm: entry.value,
        source: _dimensionSource,
        author: 'Не указан',
        recordedAt: DateTime.now(),
      );
    }
    await _changed();
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: 'мм'),
      );

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
              Text('Текст и заметка', style: ZamerTypography.h3),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 7,
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
                Text('Слои', style: ZamerTypography.h3),
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
    var type = wall.type;
    var material = wall.material;
    var layer = wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
    final thickness =
        TextEditingController(text: wall.thicknessMm.round().toString());
    final height = TextEditingController(
      text: (wall.heightOverrideMm ?? floor.defaultHeightMm).round().toString(),
    );

    final save = await showModalBottomSheet<bool>(
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
                  Text('Свойства стены', style: ZamerTypography.h3),
                  const SizedBox(height: 12),
                  SegmentedButton<WallType>(
                    segments: const [
                      ButtonSegment(
                        value: WallType.exterior,
                        label: Text('Стена'),
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
                  Row(
                    children: [
                      Expanded(child: _numberField(thickness, 'Толщина')),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(height, 'Высота')),
                    ],
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
                    decoration: const InputDecoration(labelText: 'Слой'),
                    items: ProjectLayer.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheet(() => layer = value ?? layer),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (save == true) {
      final thick = double.tryParse(thickness.text.replaceAll(',', '.'));
      final h = double.tryParse(height.text.replaceAll(',', '.'));
      if (thick != null && thick > 0) wall.thicknessMm = thick;
      if (h != null && h > 0) wall.heightOverrideMm = h;
      wall.type = type;
      wall.material = material;
      wall.projectLayer = layer;
      wall.demolition = layer == ProjectLayer.demolition;
      _wallMaterial = material;
      await _changed();
    }
    thickness.dispose();
    height.dispose();
  }

  Future<void> _deleteSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    GeometryService.removeWall(floor, wall.id);
    setState(() => _selectedWallId = null);
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
                maxScale: 7,
                boundaryMargin: const EdgeInsets.all(2100),
                constrained: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _tap,
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
              child: _MasterToolRail(
                value: _tool,
                onChanged: _selectTool,
                onReview: widget.onOpenReview,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _MasterActionRail(
                showDimensions: _showDimensions,
                snapping: _snapping,
                onFit: _centerView,
                onDimensions: () =>
                    setState(() => _showDimensions = !_showDimensions),
                onSnap: () => setState(() => _snapping = !_snapping),
                onGeometry: widget.onOpenGeometry,
                onReview: widget.onOpenReview,
              ),
            ),
            Positioned(
              left: 62,
              bottom: _bottomReserve + 10,
              child: _ScalePill(scale: _viewScale),
            ),
            Positioned(
              right: 10,
              bottom: _bottomReserve + 10,
              child: _CanvasNavigation(
                floor: floor,
                onMinus: () => _zoom(.88),
                onPlus: () => _zoom(1.14),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected != null
                    ? _WallInspectorV2(
                        key: ValueKey('wall-${selected.id}'),
                        wall: selected,
                        floor: floor,
                        onEdit: _editSelectedWall,
                        onDelete: _deleteSelectedWall,
                        onMaterial: (value) async {
                          selected.material = value;
                          _wallMaterial = value;
                          await _changed();
                        },
                      )
                    : _ToolbeltV2(
                        key: ValueKey('tool-${_tool.name}'),
                        tool: _tool,
                        wallType: _wallType,
                        thickness: _wallThicknessMm,
                        layer: _projectLayer,
                        angleSnap: _angleSnap,
                        openingType: _openingType,
                        dimensionSource: _dimensionSource,
                        activeWall: _activeNodeId != null,
                        activeDimension: _measureStartNodeId != null,
                        onWallType: (value) => setState(() {
                          _wallType = value;
                          _wallThicknessMm =
                              value == WallType.exterior ? 120 : 100;
                        }),
                        onThickness: (delta) => setState(() {
                          _wallThicknessMm = (_wallThicknessMm + delta)
                              .clamp(50, 1000)
                              .toDouble();
                        }),
                        onLayer: (value) =>
                            setState(() => _projectLayer = value),
                        onAngle: (value) => setState(() => _angleSnap = value),
                        onOpening: (value) =>
                            setState(() => _openingType = value),
                        onSource: (value) =>
                            setState(() => _dimensionSource = value),
                        onStop: () => setState(() {
                          _activeNodeId = null;
                          _measureStartNodeId = null;
                        }),
                        onGeometry: widget.onOpenGeometry,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MasterToolRail extends StatelessWidget {
  const _MasterToolRail({
    required this.value,
    required this.onChanged,
    required this.onReview,
  });

  final ZMeasureTool value;
  final ValueChanged<ZMeasureTool> onChanged;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZamerColors.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tool in ZMeasureTool.values)
              _RailButton(
                icon: tool.icon,
                tooltip: tool.label,
                active: value == tool,
                onTap: () => onChanged(tool),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Divider(height: 8),
            ),
            _RailButton(
              icon: Icons.fact_check_outlined,
              tooltip: 'Проверка',
              active: false,
              onTap: onReview,
            ),
          ],
        ),
      );
}

class _MasterActionRail extends StatelessWidget {
  const _MasterActionRail({
    required this.showDimensions,
    required this.snapping,
    required this.onFit,
    required this.onDimensions,
    required this.onSnap,
    required this.onGeometry,
    required this.onReview,
  });

  final bool showDimensions;
  final bool snapping;
  final VoidCallback onFit;
  final VoidCallback onDimensions;
  final VoidCallback onSnap;
  final VoidCallback onGeometry;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Весь план',
              active: false,
              onTap: onFit,
            ),
            _RailButton(
              icon: Icons.straighten_rounded,
              tooltip: 'Размеры',
              active: showDimensions,
              onTap: onDimensions,
            ),
            _RailButton(
              icon: snapping ? Icons.link_rounded : Icons.link_off_rounded,
              tooltip: 'Привязка',
              active: snapping,
              onTap: onSnap,
            ),
            _RailButton(
              icon: Icons.polyline_rounded,
              tooltip: 'Геометрия',
              active: false,
              onTap: onGeometry,
            ),
            _RailButton(
              icon: Icons.fact_check_outlined,
              tooltip: 'Проверка',
              active: false,
              onTap: onReview,
            ),
          ],
        ),
      );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: ZPressEffect(
            scale: .92,
            child: Material(
              color: active ? ZamerColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    icon,
                    size: 18,
                    color: active
                        ? ZamerColors.accentInk
                        : ZamerColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _WallInspectorV2 extends StatelessWidget {
  const _WallInspectorV2({
    super.key,
    required this.wall,
    required this.floor,
    required this.onEdit,
    required this.onDelete,
    required this.onMaterial,
  });

  final PlanWall wall;
  final FloorPlan floor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<WallMaterial> onMaterial;

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
    final index = math.max(0, floor.walls.indexWhere((e) => e.id == wall.id));
    final name = 'Стена ${String.fromCharCode(65 + (index % 26))}${index ~/ 26 + 1}';
    return Container(
      height: 160,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZamerColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ZamerColors.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.view_week_outlined,
                  size: 19,
                  color: ZamerColors.accentInk,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: ZamerTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${wall.material.label} • ${wall.projectLayer.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZamerTypography.caption.copyWith(fontSize: 8.5),
                    ),
                  ],
                ),
              ),
              _InspectorAction(
                icon: Icons.tune_rounded,
                tooltip: 'Свойства',
                onTap: onEdit,
              ),
              const SizedBox(width: 5),
              _InspectorAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Удалить',
                danger: true,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricPill(
                label: 'Длина',
                value: '${floor.wallLengthMm(wall).round()} мм',
              ),
              _MetricPill(label: 'Угол', value: '${_angle.round()}°'),
              _MetricPill(
                label: 'Толщина',
                value: '${wall.thicknessMm.round()} мм',
              ),
              _MetricPill(
                label: 'Высота',
                value:
                    '${(wall.heightOverrideMm ?? floor.defaultHeightMm).round()} мм',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: WallMaterial.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final material = WallMaterial.values[index];
                return _MaterialPill(
                  label: material.label,
                  active: material == wall.material,
                  onTap: () => onMaterial(material),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: ZamerColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                style: ZamerTypography.caption.copyWith(fontSize: 7.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: ZamerTypography.technical.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      );
}

class _InspectorAction extends StatelessWidget {
  const _InspectorAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: ZamerColors.outlineSoft),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: danger ? ZamerColors.danger : ZamerColors.textSecondary,
              ),
            ),
          ),
        ),
      );
}

class _MaterialPill extends StatelessWidget {
  const _MaterialPill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: Material(
          color: active ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZamerTypography.caption.copyWith(
                  fontSize: 8.5,
                  color: active
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
}

class _ToolbeltV2 extends StatelessWidget {
  const _ToolbeltV2({
    super.key,
    required this.tool,
    required this.wallType,
    required this.thickness,
    required this.layer,
    required this.angleSnap,
    required this.openingType,
    required this.dimensionSource,
    required this.activeWall,
    required this.activeDimension,
    required this.onWallType,
    required this.onThickness,
    required this.onLayer,
    required this.onAngle,
    required this.onOpening,
    required this.onSource,
    required this.onStop,
    required this.onGeometry,
  });

  final ZMeasureTool tool;
  final WallType wallType;
  final double thickness;
  final ProjectLayer layer;
  final _AngleSnapV2 angleSnap;
  final OpeningType openingType;
  final DimensionSource dimensionSource;
  final bool activeWall;
  final bool activeDimension;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_AngleSnapV2> onAngle;
  final ValueChanged<OpeningType> onOpening;
  final ValueChanged<DimensionSource> onSource;
  final VoidCallback onStop;
  final VoidCallback onGeometry;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 62, maxHeight: 100),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ZamerColors.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: switch (tool) {
          ZMeasureTool.walls => _wallControls(),
          ZMeasureTool.openings => _openingControls(),
          ZMeasureTool.dimensions => _dimensionControls(),
          ZMeasureTool.text => _simple(
              Icons.title_rounded,
              'Текст',
              'Добавление заметки к проекту',
            ),
          ZMeasureTool.layers => _simple(
              Icons.layers_outlined,
              'Слои',
              'Существующее • Демонтаж • Новое',
            ),
          ZMeasureTool.objects => _simple(
              Icons.chair_alt_outlined,
              'Объекты',
              'Библиотека оснащения',
            ),
        },
      );

  Widget _wallControls() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Segment<WallType>(
                  value: wallType,
                  items: const [
                    (WallType.exterior, 'Стена'),
                    (WallType.partition, 'Перегородка'),
                  ],
                  onChanged: onWallType,
                ),
              ),
              const SizedBox(width: 6),
              _StepControl(
                value: '${thickness.round()} мм',
                onMinus: () => onThickness(-20),
                onPlus: () => onThickness(20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ChoiceChipV2(
                  label: 'Существующее',
                  active: layer == ProjectLayer.existing,
                  onTap: () => onLayer(ProjectLayer.existing),
                ),
                _ChoiceChipV2(
                  label: 'Демонтаж',
                  active: layer == ProjectLayer.demolition,
                  onTap: () => onLayer(ProjectLayer.demolition),
                ),
                _ChoiceChipV2(
                  label: 'Новое',
                  active: layer == ProjectLayer.proposed,
                  onTap: () => onLayer(ProjectLayer.proposed),
                ),
                _ChoiceChipV2(
                  label: '90°',
                  active: angleSnap == _AngleSnapV2.ortho,
                  onTap: () => onAngle(_AngleSnapV2.ortho),
                ),
                _ChoiceChipV2(
                  label: '45°',
                  active: angleSnap == _AngleSnapV2.deg45,
                  onTap: () => onAngle(_AngleSnapV2.deg45),
                ),
                _ChoiceChipV2(
                  label: 'Свободно',
                  active: angleSnap == _AngleSnapV2.free,
                  onTap: () => onAngle(_AngleSnapV2.free),
                ),
                _ChoiceChipV2(
                  label: 'Радиус / узлы',
                  active: false,
                  onTap: onGeometry,
                ),
                if (activeWall)
                  _ChoiceChipV2(
                    label: 'Завершить',
                    active: true,
                    onTap: onStop,
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _openingControls() => Row(
        children: [
          Expanded(
            child: _Segment<OpeningType>(
              value: openingType,
              items: const [
                (OpeningType.door, 'Дверь'),
                (OpeningType.window, 'Окно'),
              ],
              onChanged: onOpening,
            ),
          ),
          const SizedBox(width: 8),
          Text('Нажми на стену', style: ZamerTypography.caption),
        ],
      );

  Widget _dimensionControls() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.straighten_rounded,
                size: 17,
                color: ZamerColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activeDimension ? 'Выбери второй узел' : 'Выбери первый узел',
                  style: ZamerTypography.bodySmall,
                ),
              ),
              if (activeDimension)
                TextButton(onPressed: onStop, child: const Text('Отмена')),
            ],
          ),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final source in DimensionSource.values)
                  _ChoiceChipV2(
                    label: source.label,
                    active: source == dimensionSource,
                    onTap: () => onSource(source),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _simple(IconData icon, String title, String text) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ZamerColors.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: ZamerColors.outlineSoft),
            ),
            child: Icon(icon, size: 18, color: ZamerColors.accent),
          ),
          const SizedBox(width: 8),
          Text(title, style: ZamerTypography.bodySmall),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: ZamerTypography.caption)),
        ],
      );
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Material(
                  color: value == item.$1
                      ? ZamerColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  child: InkWell(
                    onTap: () => onChanged(item.$1),
                    borderRadius: BorderRadius.circular(7),
                    child: Center(
                      child: Text(
                        item.$2,
                        style: ZamerTypography.caption.copyWith(
                          color: value == item.$1
                              ? ZamerColors.accentInk
                              : ZamerColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _StepControl extends StatelessWidget {
  const _StepControl({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onMinus,
              visualDensity: VisualDensity.compact,
              iconSize: 15,
              icon: const Icon(Icons.remove_rounded),
            ),
            Text(value, style: ZamerTypography.technical.copyWith(fontSize: 10.5)),
            IconButton(
              onPressed: onPlus,
              visualDensity: VisualDensity.compact,
              iconSize: 15,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      );
}

class _ChoiceChipV2 extends StatelessWidget {
  const _ChoiceChipV2({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Material(
          color: active ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: ZamerTypography.caption.copyWith(
                  fontSize: 8.5,
                  color: active
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
}

class _CanvasNavigation extends StatelessWidget {
  const _CanvasNavigation({
    required this.floor,
    required this.onMinus,
    required this.onPlus,
  });
  final FloorPlan floor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SquareButtonV2(icon: Icons.remove, onTap: onMinus),
              const SizedBox(width: 5),
              _SquareButtonV2(icon: Icons.add, onTap: onPlus),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            width: 58,
            height: 54,
            decoration: BoxDecoration(
              color: ZamerColors.surfaceLow.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: ZamerColors.outlineSoft),
            ),
            child: CustomPaint(painter: _MiniMapPainterV2(floor)),
          ),
        ],
      );
}

class _SquareButtonV2 extends StatelessWidget {
  const _SquareButtonV2({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surfaceLow.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outlineSoft),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16),
          ),
        ),
      );
}

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final ratio = (50 / scale).round().clamp(25, 500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Text(
        '1:$ratio',
        style: ZamerTypography.caption.copyWith(fontSize: 8.5),
      ),
    );
  }
}

class _MiniMapPainterV2 extends CustomPainter {
  const _MiniMapPainterV2(this.floor);
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
    final scale = math.min((size.width - 10) / w, (size.height - 10) / h);
    Offset map(PlanNode n) => Offset(
          5 + (n.xMm - minX) * scale,
          5 + (n.yMm - minY) * scale,
        );
    final paint = Paint()
      ..color = ZamerColors.textSecondary
      ..strokeWidth = 1.3;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      canvas.drawLine(map(a), map(b), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainterV2 oldDelegate) => true;
}
