import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/floor_plan_painter.dart';

enum _AngleSnapV3 { ortho, deg45, free }

/// UI KIT 02 / CAD implementation for the approved Measure concept.
///
/// The structure intentionally mirrors the reference board:
/// - large plan viewport;
/// - labelled left CAD toolbar;
/// - labelled right view toolbar;
/// - undo/redo inside the viewport;
/// - selected-object inspector;
/// - contextual action row;
/// - finish-category row and material thumbnails.
class PlanEditorMasterV3Screen extends StatefulWidget {
  const PlanEditorMasterV3Screen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpen3D,
    required this.onOpenFloors,
    required this.onOpenSettings,
    required this.onOpenMaterials,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpen3D;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenMaterials;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  @override
  State<PlanEditorMasterV3Screen> createState() =>
      _PlanEditorMasterV3ScreenState();
}

class _PlanEditorMasterV3ScreenState extends State<PlanEditorMasterV3Screen> {
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
  _AngleSnapV3 _angleSnap = _AngleSnapV3.ortho;

  double _wallThicknessMm = 120;
  bool _showDimensions = true;
  bool _snapping = true;
  bool _gridActive = true;
  bool _centered = false;
  Size _viewport = Size.zero;

  String? _activeNodeId;
  String? _measureStartNodeId;
  String? _selectedWallId;
  String _materialCategory = 'Пол';

  FloorPlan get floor => widget.floor;

  PlanWall? get _selectedWall =>
      _selectedWallId == null ? null : floor.wallById(_selectedWallId!);

  @override
  void initState() {
    super.initState();
    if (floor.walls.isNotEmpty) {
      _selectedWallId = floor.walls.first.id;
      _wallMaterial = floor.walls.first.material;
      _wallThicknessMm = floor.walls.first.thicknessMm;
      _wallType = floor.walls.first.type;
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

  Offset _toCanvas(PlanNode node) =>
      _origin + Offset(node.xMm * _mmToPx, node.yMm * _mmToPx);

  math.Point<double> _toMm(Offset point) => math.Point<double>(
        (point.dx - _origin.dx) / _mmToPx,
        (point.dy - _origin.dy) / _mmToPx,
      );

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

  void _centerView() {
    if (_viewport.isEmpty) return;

    const leftRail = 82.0;
    const rightRail = 74.0;
    const topPad = 12.0;
    const bottomPad = 44.0;
    final usableW = math.max(150.0, _viewport.width - leftRail - rightRail);
    final usableH = math.max(150.0, _viewport.height - topPad - bottomPad);

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
      scale = math.min(2.35, math.max(.36, math.min(sx, sy) * 1.03));
    }

    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    final screenCenter = Offset(
      leftRail + usableW / 2,
      topPad + usableH / 2,
    );
    _transform.value = Matrix4.identity()
      ..translate(
        screenCenter.dx - target.dx * scale,
        screenCenter.dy - target.dy * scale,
      )
      ..scale(scale);
    if (mounted) setState(() {});
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

  PlanWall? _wallNear(Offset p, {double px = 34}) {
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

  PlanNode? _nodeNear(Offset p, {double px = 34}) {
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
    if (!_snapping || _angleSnap == _AngleSnapV3.free) return raw;
    final step =
        _angleSnap == _AngleSnapV3.ortho ? math.pi / 2 : math.pi / 4;
    return (raw / step).round() * step;
  }

  Future<void> _tapCanvas(TapUpDetails details) async {
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

  Future<void> _tapWall(Offset point) async {
    if (_activeNodeId == null) {
      final existing = _wallNear(point);
      if (existing != null) {
        setState(() {
          _selectedWallId = existing.id;
          _wallMaterial = existing.material;
          _wallThicknessMm = existing.thicknessMm;
          _wallType = existing.type;
        });
        return;
      }
      final node = GeometryService.ensureAnchor(floor, _toMm(point));
      setState(() {
        _selectedWallId = null;
        _activeNodeId = node.id;
      });
      await _changed();
      return;
    }

    final start = floor.nodeById(_activeNodeId!);
    if (start == null) {
      setState(() => _activeNodeId = null);
      return;
    }

    final raw = _toMm(point);
    final dx = raw.x - start.xMm;
    final dy = raw.y - start.yMm;
    final estimate = math.sqrt(dx * dx + dy * dy);
    if (estimate < 20) return;

    final angle = _snapAngle(math.atan2(dy, dx));
    final opposite = GeometryService.parallelReferenceLength(floor, start, angle);
    final length = await _numberDialog(
      title: 'Длина стены',
      label: opposite == null ? 'Длина' : 'Стена напротив',
      value: (opposite ?? estimate).round().toString(),
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
    PlanWall? created;
    for (final wall in floor.walls.where((e) => !before.contains(e.id))) {
      wall.projectLayer = _projectLayer;
      wall.demolition = _projectLayer == ProjectLayer.demolition;
      created ??= wall;
    }
    setState(() {
      _activeNodeId = end.id;
      _selectedWallId = created?.id;
    });
    await _changed();
  }

  Future<void> _tapOpening(Offset point) async {
    final wall = _wallNear(point);
    if (wall == null) {
      _toast('Выбери стену для проёма');
      return;
    }
    setState(() => _selectedWallId = wall.id);
    await _openingSheet(wall);
  }

  Future<void> _tapDimension(Offset point) async {
    final node = _nodeNear(point);
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
          decoration: InputDecoration(labelText: label, suffixText: 'мм'),
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
    var type = _openingType;
    final width = TextEditingController(
      text: type == OpeningType.door ? '900' : '1500',
    );
    final height = TextEditingController(
      text: type == OpeningType.door ? '2100' : '1500',
    );
    final sill = TextEditingController(
      text: type == OpeningType.door ? '0' : '900',
    );
    final offset = TextEditingController(text: '450');
    final wallLength = floor.wallLengthMm(wall);

    final result = await showModalBottomSheet<WallOpening>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
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
                    onSelectionChanged: (selection) =>
                        setSheet(() => type = selection.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(width, 'Ширина')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(height, 'Высота')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(offset, 'Отступ слева')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          sill,
                          'Подоконник',
                          enabled: type == OpeningType.window,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      final w = double.tryParse(width.text.replaceAll(',', '.'));
                      final h = double.tryParse(height.text.replaceAll(',', '.'));
                      final o = double.tryParse(offset.text.replaceAll(',', '.'));
                      final s = double.tryParse(sill.text.replaceAll(',', '.')) ?? 0;
                      if (w == null || h == null || o == null) return;
                      if (w <= 0 || h <= 0 || o < 0 || o + w > wallLength) return;
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
                    child: const Text('Добавить проём'),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'мм'),
      );

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: floor.notes);
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Текст', style: ZamerTypography.h3),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
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
                    Navigator.pop(sheetContext);
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
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
                  Text('Стена A1', style: ZamerTypography.h3),
                  const SizedBox(height: 12),
                  SegmentedButton<WallType>(
                    segments: const [
                      ButtonSegment(value: WallType.exterior, label: Text('Стена')),
                      ButtonSegment(
                        value: WallType.partition,
                        label: Text('Перегородка'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) =>
                        setSheet(() => type = selection.first),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(thickness, 'Толщина')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(height, 'Высота')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<WallMaterial>(
                    initialValue: material,
                    decoration: const InputDecoration(labelText: 'Материал'),
                    items: WallMaterial.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
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
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setSheet(() => layer = value ?? layer),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
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
      final newThickness =
          double.tryParse(thickness.text.replaceAll(',', '.'));
      final newHeight = double.tryParse(height.text.replaceAll(',', '.'));
      if (newThickness != null && newThickness > 0) {
        wall.thicknessMm = newThickness;
      }
      if (newHeight != null && newHeight > 0) {
        wall.heightOverrideMm = newHeight;
      }
      wall.type = type;
      wall.material = material;
      wall.projectLayer = layer;
      wall.demolition = layer == ProjectLayer.demolition;
      setState(() {
        _wallType = type;
        _wallMaterial = material;
        _wallThicknessMm = wall.thicknessMm;
      });
      await _changed();
    }

    thickness.dispose();
    height.dispose();
  }

  Future<void> _deleteSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    GeometryService.removeWall(floor, wall.id);
    setState(() {
      _selectedWallId = floor.walls.isEmpty ? null : floor.walls.first.id;
    });
    await _changed();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedWall;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
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
                      minScale: .24,
                      maxScale: 7,
                      boundaryMargin: const EdgeInsets.all(2200),
                      constrained: false,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _tapCanvas,
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
                    child: _ExactToolRail(
                      tool: _tool,
                      onTool: _selectTool,
                      onReview: widget.onOpenReview,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _ExactViewRail(
                      gridActive: _gridActive,
                      snapActive: _snapping,
                      onGrid: () => setState(() => _gridActive = !_gridActive),
                      on3D: widget.onOpen3D,
                      onFloors: widget.onOpenFloors,
                      onSnap: () => setState(() => _snapping = !_snapping),
                      onSettings: widget.onOpenSettings,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _ViewportUndoRedo(
                      onUndo: widget.canUndo ? widget.onUndo : null,
                      onRedo: widget.canRedo ? widget.onRedo : null,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _ViewportMiniMap(
                      floor: floor,
                      onFit: _centerView,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (selected != null)
          _ExactWallInspector(
            wall: selected,
            floor: floor,
            onEdit: _editSelectedWall,
          )
        else
          _ExactCreateStrip(
            wallType: _wallType,
            thickness: _wallThicknessMm,
            layer: _projectLayer,
            angleSnap: _angleSnap,
            active: _activeNodeId != null,
            onWallType: (value) => setState(() {
              _wallType = value;
              _wallThicknessMm = value == WallType.exterior ? 120 : 100;
            }),
            onThickness: (delta) => setState(() {
              _wallThicknessMm =
                  (_wallThicknessMm + delta).clamp(50, 1000).toDouble();
            }),
            onLayer: (value) => setState(() => _projectLayer = value),
            onAngle: (value) => setState(() => _angleSnap = value),
            onStop: () => setState(() => _activeNodeId = null),
          ),
        _ExactActionBar(
          tool: _tool,
          hasSelection: selected != null,
          onWall: () => _selectTool(ZMeasureTool.walls),
          onOpening: () => _selectTool(ZMeasureTool.openings),
          onDimension: () => _selectTool(ZMeasureTool.dimensions),
          onText: () => _selectTool(ZMeasureTool.text),
          onGeometry: widget.onOpenGeometry,
          onLayers: () => _selectTool(ZMeasureTool.layers),
          onDelete: selected == null ? null : _deleteSelectedWall,
        ),
        _ExactMaterialPanel(
          category: _materialCategory,
          onCategory: (value) => setState(() => _materialCategory = value),
          onMaterial: widget.onOpenMaterials,
        ),
      ],
    );
  }
}

class _ExactToolRail extends StatelessWidget {
  const _ExactToolRail({
    required this.tool,
    required this.onTool,
    required this.onReview,
  });

  final ZMeasureTool tool;
  final ValueChanged<ZMeasureTool> onTool;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in ZMeasureTool.values)
            _RailItem(
              icon: value.icon,
              label: value.label,
              selected: value == tool,
              onTap: () => onTool(value),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Divider(height: 8, color: ZamerColors.outlineSoft),
          ),
          _RailItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Проверка',
            selected: false,
            onTap: onReview,
          ),
        ],
      ),
    );
  }
}

class _ExactViewRail extends StatelessWidget {
  const _ExactViewRail({
    required this.gridActive,
    required this.snapActive,
    required this.onGrid,
    required this.on3D,
    required this.onFloors,
    required this.onSnap,
    required this.onSettings,
  });

  final bool gridActive;
  final bool snapActive;
  final VoidCallback onGrid;
  final VoidCallback on3D;
  final VoidCallback onFloors;
  final VoidCallback onSnap;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailItem(
            icon: Icons.grid_4x4_rounded,
            label: 'Сетка',
            selected: gridActive,
            onTap: onGrid,
          ),
          _RailItem(
            icon: Icons.view_in_ar_outlined,
            label: '3D вид',
            selected: false,
            onTap: on3D,
          ),
          _RailItem(
            icon: Icons.layers_outlined,
            label: 'Этажи',
            selected: false,
            onTap: onFloors,
          ),
          _RailItem(
            icon: Icons.link_rounded,
            label: 'Привязка',
            selected: snapActive,
            onTap: onSnap,
          ),
          _RailItem(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            selected: false,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
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
  Widget build(BuildContext context) {
    final foreground =
        selected ? ZamerColors.accentInk : ZamerColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 43,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 7.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewportUndoRedo extends StatelessWidget {
  const _ViewportUndoRedo({required this.onUndo, required this.onRedo});

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniAction(icon: Icons.arrow_back_rounded, onTap: onUndo),
            const SizedBox(width: 4),
            _MiniAction(icon: Icons.arrow_forward_rounded, onTap: onRedo),
          ],
        ),
      );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .34 : 1,
        child: Material(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 34,
              height: 30,
              child: Icon(icon, size: 17, color: ZamerColors.textPrimary),
            ),
          ),
        ),
      );
}

class _ViewportMiniMap extends StatelessWidget {
  const _ViewportMiniMap({required this.floor, required this.onFit});

  final FloorPlan floor;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: ZamerColors.surfaceLow.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onFit,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: ZamerColors.outlineSoft),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  size: 20,
                  color: ZamerColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ZamerColors.surfaceLow.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZamerColors.outlineSoft),
            ),
            child: CustomPaint(painter: _MiniMapPainter(floor)),
          ),
        ],
      );
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter(this.floor);

  final FloorPlan floor;

  @override
  void paint(Canvas canvas, Size size) {
    if (floor.nodes.isEmpty) return;
    final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
    final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
    final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
    final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
    final width = math.max(1.0, maxX - minX);
    final height = math.max(1.0, maxY - minY);
    final scale = math.min((size.width - 6) / width, (size.height - 6) / height);

    Offset map(PlanNode node) => Offset(
          3 + (node.xMm - minX) * scale,
          3 + (node.yMm - minY) * scale,
        );

    final paint = Paint()
      ..color = ZamerColors.gray300
      ..strokeWidth = 1.3;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      canvas.drawLine(map(a), map(b), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

class _ExactWallInspector extends StatelessWidget {
  const _ExactWallInspector({
    required this.wall,
    required this.floor,
    required this.onEdit,
  });

  final PlanWall wall;
  final FloorPlan floor;
  final VoidCallback onEdit;

  double get _angle {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return 0;
    var value = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm) * 180 / math.pi;
    if (value < 0) value += 360;
    return value;
  }

  String get _name {
    final index = floor.walls.indexWhere((value) => value.id == wall.id);
    final safe = index < 0 ? 0 : index;
    final letter = String.fromCharCode(65 + safe % 26);
    final number = safe ~/ 26 + 1;
    return 'Стена $letter$number';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: ZamerColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZamerColors.outlineSoft),
            ),
            child: const CustomPaint(painter: _WallPreviewPainter()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _name,
                      style: ZamerTypography.bodySmall.copyWith(
                        color: ZamerColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: ZamerColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.more_vert_rounded,
                        size: 17,
                        color: ZamerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      _MetricBox(
                        label: 'Длина',
                        value: '${floor.wallLengthMm(wall).round()} мм',
                        locked: true,
                      ),
                      _MetricBox(label: 'Угол', value: '${_angle.round()}°'),
                      _MetricBox(
                        label: 'Толщина',
                        value: '${wall.thicknessMm.round()} мм',
                      ),
                      _MetricBox(
                        label: 'Высота',
                        value:
                            '${(wall.heightOverrideMm ?? floor.defaultHeightMm).round()} мм',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WallPreviewPainter extends CustomPainter {
  const _WallPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final front = Path()
      ..moveTo(size.width * .27, size.height * .27)
      ..lineTo(size.width * .72, size.height * .13)
      ..lineTo(size.width * .72, size.height * .82)
      ..lineTo(size.width * .27, size.height * .94)
      ..close();
    final side = Path()
      ..moveTo(size.width * .72, size.height * .13)
      ..lineTo(size.width * .82, size.height * .2)
      ..lineTo(size.width * .82, size.height * .77)
      ..lineTo(size.width * .72, size.height * .82)
      ..close();
    final top = Path()
      ..moveTo(size.width * .27, size.height * .27)
      ..lineTo(size.width * .37, size.height * .33)
      ..lineTo(size.width * .82, size.height * .2)
      ..lineTo(size.width * .72, size.height * .13)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFFDFE3E6));
    canvas.drawPath(side, Paint()..color = const Color(0xFF8E9AA4));
    canvas.drawPath(top, Paint()..color = const Color(0xFFF2F4F5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    this.locked = false,
  });

  final String label;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: ZamerColors.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                style: ZamerTypography.caption.copyWith(fontSize: 7.2),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: ZamerTypography.technical.copyWith(fontSize: 9),
                    ),
                  ),
                  if (locked)
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 10,
                      color: ZamerColors.textMuted,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ExactCreateStrip extends StatelessWidget {
  const _ExactCreateStrip({
    required this.wallType,
    required this.thickness,
    required this.layer,
    required this.angleSnap,
    required this.active,
    required this.onWallType,
    required this.onThickness,
    required this.onLayer,
    required this.onAngle,
    required this.onStop,
  });

  final WallType wallType;
  final double thickness;
  final ProjectLayer layer;
  final _AngleSnapV3 angleSnap;
  final bool active;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_AngleSnapV3> onAngle;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TwoChoice<WallType>(
                    value: wallType,
                    first: WallType.exterior,
                    firstLabel: 'Стена',
                    second: WallType.partition,
                    secondLabel: 'Перегородка',
                    onChanged: onWallType,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: ZamerColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZamerColors.outlineSoft),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => onThickness(-20),
                        visualDensity: VisualDensity.compact,
                        iconSize: 15,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text(
                        '${thickness.round()} мм',
                        style: ZamerTypography.technical.copyWith(fontSize: 9.5),
                      ),
                      IconButton(
                        onPressed: () => onThickness(20),
                        visualDensity: VisualDensity.compact,
                        iconSize: 15,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _SmallChip(
                    label: 'Существующее',
                    active: layer == ProjectLayer.existing,
                    onTap: () => onLayer(ProjectLayer.existing),
                  ),
                  _SmallChip(
                    label: 'Демонтаж',
                    active: layer == ProjectLayer.demolition,
                    onTap: () => onLayer(ProjectLayer.demolition),
                  ),
                  _SmallChip(
                    label: 'Новое',
                    active: layer == ProjectLayer.proposed,
                    onTap: () => onLayer(ProjectLayer.proposed),
                  ),
                  _SmallChip(
                    label: '90°',
                    active: angleSnap == _AngleSnapV3.ortho,
                    onTap: () => onAngle(_AngleSnapV3.ortho),
                  ),
                  _SmallChip(
                    label: '45°',
                    active: angleSnap == _AngleSnapV3.deg45,
                    onTap: () => onAngle(_AngleSnapV3.deg45),
                  ),
                  _SmallChip(
                    label: 'Свободно',
                    active: angleSnap == _AngleSnapV3.free,
                    onTap: () => onAngle(_AngleSnapV3.free),
                  ),
                  if (active)
                    _SmallChip(label: 'Завершить', active: true, onTap: onStop),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TwoChoice<T> extends StatelessWidget {
  const _TwoChoice({
    required this.value,
    required this.first,
    required this.firstLabel,
    required this.second,
    required this.secondLabel,
    required this.onChanged,
  });

  final T value;
  final T first;
  final String firstLabel;
  final T second;
  final String secondLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          children: [
            Expanded(child: _choice(first, firstLabel)),
            const SizedBox(width: 3),
            Expanded(child: _choice(second, secondLabel)),
          ],
        ),
      );

  Widget _choice(T item, String label) {
    final selected = item == value;
    return Material(
      color: selected ? ZamerColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => onChanged(item),
        borderRadius: BorderRadius.circular(6),
        child: Center(
          child: Text(
            label,
            style: ZamerTypography.caption.copyWith(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? ZamerColors.accentInk
                  : ZamerColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: active ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: active ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Text(
                label,
                style: ZamerTypography.caption.copyWith(
                  fontSize: 7.6,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
}

class _ExactActionBar extends StatelessWidget {
  const _ExactActionBar({
    required this.tool,
    required this.hasSelection,
    required this.onWall,
    required this.onOpening,
    required this.onDimension,
    required this.onText,
    required this.onGeometry,
    required this.onLayers,
    required this.onDelete,
  });

  final ZMeasureTool tool;
  final bool hasSelection;
  final VoidCallback onWall;
  final VoidCallback onOpening;
  final VoidCallback onDimension;
  final VoidCallback onText;
  final VoidCallback onGeometry;
  final VoidCallback onLayers;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Row(
          children: [
            _action(
              Icons.view_week_outlined,
              'Стена',
              tool == ZMeasureTool.walls,
              onWall,
            ),
            _action(
              Icons.door_front_door_outlined,
              'Проём',
              tool == ZMeasureTool.openings,
              onOpening,
            ),
            _action(
              Icons.straighten_rounded,
              'Размер',
              tool == ZMeasureTool.dimensions,
              onDimension,
            ),
            _action(
              Icons.title_rounded,
              'Текст',
              tool == ZMeasureTool.text,
              onText,
            ),
            _action(Icons.hexagon_outlined, 'Фигура', false, onGeometry),
            _action(
              Icons.layers_outlined,
              'Слой',
              tool == ZMeasureTool.layers,
              onLayers,
            ),
            _action(
              Icons.delete_outline_rounded,
              'Удалить',
              false,
              onDelete,
              danger: true,
            ),
          ],
        ),
      );

  Widget _action(
    IconData icon,
    String label,
    bool selected,
    VoidCallback? onTap, {
    bool danger = false,
  }) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Opacity(
            opacity: onTap == null ? .35 : 1,
            child: Material(
              color: selected ? ZamerColors.accent : ZamerColors.surfaceLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? ZamerColors.accent
                          : danger
                              ? ZamerColors.danger.withValues(alpha: .55)
                              : ZamerColors.outlineSoft,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: selected
                            ? ZamerColors.accentInk
                            : danger
                                ? ZamerColors.danger
                                : ZamerColors.textPrimary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? ZamerColors.accentInk
                              : danger
                                  ? ZamerColors.danger
                                  : ZamerColors.textSecondary,
                          fontSize: 7.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ExactMaterialPanel extends StatelessWidget {
  const _ExactMaterialPanel({
    required this.category,
    required this.onCategory,
    required this.onMaterial,
  });

  final String category;
  final ValueChanged<String> onCategory;
  final VoidCallback onMaterial;

  static const _categories = [
    'Пол',
    'Стены',
    'Потолок',
    'Двери',
    'Окна',
    'Освещение',
  ];

  List<VisualMaterialPreset> get _presets {
    if (category == 'Пол') return MaterialCatalog.floorFinishes.take(6).toList();
    if (category == 'Стены') {
      return MaterialCatalog.forCategory('Стены').take(6).toList();
    }
    return MaterialCatalog.presets.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets;
    return Container(
      height: 96,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                for (final item in _categories)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Material(
                        color: item == category
                            ? ZamerColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        child: InkWell(
                          onTap: () => onCategory(item),
                          borderRadius: BorderRadius.circular(7),
                          child: Center(
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: item == category
                                    ? ZamerColors.accentInk
                                    : ZamerColors.textSecondary,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(5, 2, 5, 5),
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final preset = presets[index];
                return _MaterialCard(preset: preset, onTap: onMaterial);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.preset, required this.onTap});

  final VisualMaterialPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 62,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                    decoration: BoxDecoration(
                      color: preset.color,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: ZamerColors.outlineSoft),
                      image: preset.textureAsset == null
                          ? null
                          : DecorationImage(
                              image: AssetImage(preset.textureAsset!),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
                  child: Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZamerColors.textSecondary,
                      fontSize: 6.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
