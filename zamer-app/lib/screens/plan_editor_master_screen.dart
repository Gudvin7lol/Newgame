import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/floor_plan_painter.dart';

enum _AngleSnap { ortho, deg45, free }

class PlanEditorMasterScreen extends StatefulWidget {
  const PlanEditorMasterScreen({
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
  State<PlanEditorMasterScreen> createState() => _PlanEditorMasterScreenState();
}

class _PlanEditorMasterScreenState extends State<PlanEditorMasterScreen> {
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
  _AngleSnap _angleSnap = _AngleSnap.ortho;
  double _wallThicknessMm = 120;
  bool _showDimensions = true;
  bool _snapping = true;
  bool _centered = false;
  Size _viewport = Size.zero;
  String? _activeNodeId;
  String? _measureStartNodeId;
  String? _selectedWallId;

  FloorPlan get floor => widget.floor;

  PlanWall? get _selectedWall => _selectedWallId == null
      ? null
      : floor.wallById(_selectedWallId!);

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
      if (tool != ZMeasureTool.walls && tool != ZMeasureTool.openings) {
        _selectedWallId = null;
      }
    });
    if (tool == ZMeasureTool.text) _editNotes();
    if (tool == ZMeasureTool.layers) _showLayers();
  }

  double _bottomReserve() {
    if (_selectedWall != null) return 230;
    if (_tool == ZMeasureTool.dimensions) return 150;
    return 122;
  }

  void _centerView() {
    if (_viewport.isEmpty) return;
    const leftRail = 58.0;
    const rightRail = 54.0;
    final bottom = _bottomReserve();
    final usableW = math.max(120.0, _viewport.width - leftRail - rightRail - 20);
    final usableH = math.max(160.0, _viewport.height - bottom - 20);
    var scale = .82;
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
      scale = math.min(1.45, math.max(.30, math.min(sx, sy) * .88));
    }

    final target = _origin + Offset(center.x * _mmToPx, center.y * _mmToPx);
    final screenCenter = Offset(
      leftRail + usableW / 2,
      10 + usableH / 2,
    );
    _transform.value = Matrix4.identity()
      ..translate(
        screenCenter.dx - target.dx * scale,
        screenCenter.dy - target.dy * scale,
      )
      ..scale(scale);
  }

  void _zoom(double factor) {
    final current = _transform.value.clone();
    current.scale(factor);
    _transform.value = current;
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
        best = wall;
        bestDistance = d;
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
        best = node;
        bestDistance = distance;
      }
    }
    return best;
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
      final existing = _wallNear(p, px: 26);
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
    final wall = _wallNear(p, px: 32);
    if (wall == null) {
      _toast('Нажми на стену для добавления проёма.');
      return;
    }
    setState(() => _selectedWallId = wall.id);
    await _openingSheet(wall);
  }

  Future<void> _tapDimension(Offset p) async {
    final node = _nodeNear(p, px: 32);
    if (node == null) {
      _toast('Нажми на узел стены.');
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
                      if (o < 0 || o + w > length) return;
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
                    label: const Text('Добавить'),
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
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: 'мм'),
    );
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
    final thickness = TextEditingController(text: wall.thicknessMm.round().toString());
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
                      ButtonSegment(value: WallType.exterior, label: Text('Несущая')),
                      ButtonSegment(value: WallType.partition, label: Text('Перегородка')),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) => setSheet(() => type = value.first),
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
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) => setSheet(() => material = value ?? material),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ProjectLayer>(
                    initialValue: layer,
                    decoration: const InputDecoration(labelText: 'Слой'),
                    items: ProjectLayer.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) => setSheet(() => layer = value ?? layer),
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
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(1800),
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
              left: 8,
              top: 8,
              child: _CadToolRail(
                value: _tool,
                onChanged: _selectTool,
                onReview: widget.onOpenReview,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: _RightRail(
                showDimensions: _showDimensions,
                snapping: _snapping,
                onFit: _centerView,
                onDimensions: () => setState(() => _showDimensions = !_showDimensions),
                onSnap: () => setState(() => _snapping = !_snapping),
                onGeometry: widget.onOpenGeometry,
                onReview: widget.onOpenReview,
              ),
            ),
            Positioned(
              left: 66,
              bottom: _bottomReserve() + 8,
              child: _ScaleBadge(scale: _viewScale),
            ),
            Positioned(
              right: 8,
              bottom: _bottomReserve() + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SquareButton(icon: Icons.remove, onTap: () => _zoom(.88)),
                      const SizedBox(width: 4),
                      _SquareButton(icon: Icons.add, onTap: () => _zoom(1.14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _MiniMap(floor: floor),
                ],
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: selected != null
                  ? _SelectedWallPanel(
                      wall: selected,
                      floor: floor,
                      tool: _tool,
                      onTool: _selectTool,
                      onEdit: _editSelectedWall,
                      onDelete: _deleteSelectedWall,
                      onMaterial: (value) async {
                        selected.material = value;
                        _wallMaterial = value;
                        await _changed();
                      },
                    )
                  : _ActiveToolPanel(
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
                        _wallThicknessMm = value == WallType.exterior ? 120 : 100;
                      }),
                      onThickness: (delta) => setState(() {
                        _wallThicknessMm =
                            (_wallThicknessMm + delta).clamp(50, 1000).toDouble();
                      }),
                      onLayer: (value) => setState(() => _projectLayer = value),
                      onAngle: (value) => setState(() => _angleSnap = value),
                      onOpening: (value) => setState(() => _openingType = value),
                      onSource: (value) => setState(() => _dimensionSource = value),
                      onStop: () => setState(() {
                        _activeNodeId = null;
                        _measureStartNodeId = null;
                      }),
                      onGeometry: widget.onOpenGeometry,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CadToolRail extends StatelessWidget {
  const _CadToolRail({
    required this.value,
    required this.onChanged,
    required this.onReview,
  });

  final ZMeasureTool value;
  final ValueChanged<ZMeasureTool> onChanged;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        border: Border.all(color: ZamerColors.outlineSoft),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tool in ZMeasureTool.values)
            _RailItem(
              icon: tool.icon,
              label: tool.label,
              selected: tool == value,
              onTap: () => onChanged(tool),
            ),
          const Divider(height: 8),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: ZPressEffect(
          scale: .94,
          child: Material(
            color: selected ? ZamerColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? ZamerColors.accentInk
                          : ZamerColors.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 7.2,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? ZamerColors.accentInk
                            : ZamerColors.textSecondary,
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

class _RightRail extends StatelessWidget {
  const _RightRail({
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
        width: 46,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .97),
          border: Border.all(color: ZamerColors.outlineSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RightItem(icon: Icons.center_focus_strong_rounded, label: 'Весь', onTap: onFit),
            _RightItem(
              icon: Icons.straighten_rounded,
              label: 'Размеры',
              active: showDimensions,
              onTap: onDimensions,
            ),
            _RightItem(
              icon: snapping ? Icons.link_rounded : Icons.link_off_rounded,
              label: 'Привязка',
              active: snapping,
              onTap: onSnap,
            ),
            _RightItem(icon: Icons.polyline_rounded, label: 'Геом.', onTap: onGeometry),
            _RightItem(icon: Icons.fact_check_outlined, label: 'Проверка', onTap: onReview),
          ],
        ),
      );
}

class _RightItem extends StatelessWidget {
  const _RightItem({
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
          color: active ? ZamerColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? ZamerColors.accentInk : ZamerColors.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 6.8,
                      fontWeight: FontWeight.w700,
                      color: active ? ZamerColors.accentInk : ZamerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SelectedWallPanel extends StatelessWidget {
  const _SelectedWallPanel({
    required this.wall,
    required this.floor,
    required this.tool,
    required this.onTool,
    required this.onEdit,
    required this.onDelete,
    required this.onMaterial,
  });

  final PlanWall wall;
  final FloorPlan floor;
  final ZMeasureTool tool;
  final ValueChanged<ZMeasureTool> onTool;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: ZamerColors.surfaceLow.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 82,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                border: Border.all(color: ZamerColors.outlineSoft),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 66,
                    decoration: BoxDecoration(
                      color: ZamerColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.view_week_outlined, size: 30),
                  ),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 68,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text('Нажми для свойств', style: ZamerTypography.caption.copyWith(fontSize: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Row(
                      children: [
                        _Metric(label: 'Длина', value: '${floor.wallLengthMm(wall).round()} мм'),
                        _Metric(label: 'Угол', value: '${_angle.round()}°'),
                        _Metric(label: 'Толщина', value: '${wall.thicknessMm.round()} мм'),
                        _Metric(
                          label: 'Высота',
                          value: '${(wall.heightOverrideMm ?? floor.defaultHeightMm).round()} мм',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _QuickTools(tool: tool, onTool: onTool, onDelete: onDelete),
        const SizedBox(height: 6),
        _MaterialStrip(value: wall.material, onChanged: onMaterial),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 54,
          margin: const EdgeInsets.only(left: 3),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: ZamerColors.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, maxLines: 1, style: ZamerTypography.caption.copyWith(fontSize: 7.5)),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: ZamerTypography.technical.copyWith(fontSize: 10.5),
              ),
            ],
          ),
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
      (ZMeasureTool.objects, 'Объект', Icons.hexagon_outlined),
      (ZMeasureTool.layers, 'Слой', Icons.layers_outlined),
    ];
    return Container(
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        children: [
          for (final entry in tools)
            Expanded(
              child: _QuickItem(
                icon: entry.$3,
                label: entry.$2,
                selected: tool == entry.$1,
                onTap: () => onTool(entry.$1),
              ),
            ),
          Expanded(
            child: _QuickItem(
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

class _QuickItem extends StatelessWidget {
  const _QuickItem({
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
                  size: 17,
                  color: danger
                      ? ZamerColors.danger
                      : selected
                          ? ZamerColors.accentInk
                          : ZamerColors.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 6.8,
                    fontWeight: FontWeight.w700,
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

class _MaterialStrip extends StatelessWidget {
  const _MaterialStrip({required this.value, required this.onChanged});
  final WallMaterial value;
  final ValueChanged<WallMaterial> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Материал стены', style: ZamerTypography.caption.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: WallMaterial.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (context, index) {
                  final material = WallMaterial.values[index];
                  final selected = material == value;
                  return ZPressEffect(
                    scale: .96,
                    child: InkWell(
                      onTap: () => onChanged(material),
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        width: 64,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: selected ? ZamerColors.accent : ZamerColors.surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.texture_rounded,
                              size: 18,
                              color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              material.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7.2,
                                fontWeight: FontWeight.w700,
                                color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
                              ),
                            ),
                          ],
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

class _ActiveToolPanel extends StatelessWidget {
  const _ActiveToolPanel({
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
  final _AngleSnap angleSnap;
  final OpeningType openingType;
  final DimensionSource dimensionSource;
  final bool activeWall;
  final bool activeDimension;
  final ValueChanged<WallType> onWallType;
  final ValueChanged<double> onThickness;
  final ValueChanged<ProjectLayer> onLayer;
  final ValueChanged<_AngleSnap> onAngle;
  final ValueChanged<OpeningType> onOpening;
  final ValueChanged<DimensionSource> onSource;
  final VoidCallback onStop;
  final VoidCallback onGeometry;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: switch (tool) {
          ZMeasureTool.walls => _wallBar(),
          ZMeasureTool.openings => _openingBar(),
          ZMeasureTool.dimensions => _dimensionBar(),
          ZMeasureTool.text => _simple('Текст', Icons.title_rounded, 'Нажми на холст или открой заметку'),
          ZMeasureTool.layers => _simple('Слои', Icons.layers_outlined, 'Существующее • Демонтаж • Новое'),
          ZMeasureTool.objects => _simple('Объекты', Icons.chair_alt_outlined, 'Открытие библиотеки объектов'),
        },
      );

  Widget _wallBar() => Column(
        mainAxisSize: MainAxisSize.min,
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
                label: '${thickness.round()} мм',
                onMinus: () => onThickness(-20),
                onPlus: () => onThickness(20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(label: 'Существующее', selected: layer == ProjectLayer.existing, onTap: () => onLayer(ProjectLayer.existing)),
                _Chip(label: 'Демонтаж', selected: layer == ProjectLayer.demolition, onTap: () => onLayer(ProjectLayer.demolition)),
                _Chip(label: 'Новое', selected: layer == ProjectLayer.proposed, onTap: () => onLayer(ProjectLayer.proposed)),
                _Chip(label: '90°', selected: angleSnap == _AngleSnap.ortho, onTap: () => onAngle(_AngleSnap.ortho)),
                _Chip(label: '45°', selected: angleSnap == _AngleSnap.deg45, onTap: () => onAngle(_AngleSnap.deg45)),
                _Chip(label: 'Свободно', selected: angleSnap == _AngleSnap.free, onTap: () => onAngle(_AngleSnap.free)),
                _Chip(label: 'Радиус/узлы', selected: false, onTap: onGeometry),
                if (activeWall) _Chip(label: 'Завершить', selected: true, onTap: onStop),
              ],
            ),
          ),
        ],
      );

  Widget _openingBar() => Row(
        children: [
          Expanded(
            child: SegmentedButton<OpeningType>(
              segments: const [
                ButtonSegment(value: OpeningType.door, icon: Icon(Icons.door_front_door_outlined), label: Text('Дверь')),
                ButtonSegment(value: OpeningType.window, icon: Icon(Icons.window_outlined), label: Text('Окно')),
              ],
              selected: {openingType},
              onSelectionChanged: (value) => onOpening(value.first),
            ),
          ),
          const SizedBox(width: 8),
          Text('Нажми на стену', style: ZamerTypography.caption),
        ],
      );

  Widget _dimensionBar() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 18, color: ZamerColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activeDimension ? 'Выбери второй узел' : 'Выбери первый узел',
                  style: ZamerTypography.bodySmall,
                ),
              ),
              if (activeDimension) TextButton(onPressed: onStop, child: const Text('Отмена')),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final source in DimensionSource.values)
                  _Chip(
                    label: source.label,
                    selected: source == dimensionSource,
                    onTap: () => onSource(source),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _simple(String title, IconData icon, String text) => Row(
        children: [
          Icon(icon, color: ZamerColors.accent),
          const SizedBox(width: 8),
          Text(title, style: ZamerTypography.h5),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: ZamerTypography.caption)),
        ],
      );
}

class _StepValue extends StatelessWidget {
  const _StepValue({required this.label, required this.onMinus, required this.onPlus});
  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onMinus, iconSize: 16, icon: const Icon(Icons.remove_rounded)),
            Text(label, style: ZamerTypography.technical.copyWith(fontSize: 11)),
            IconButton(onPressed: onPlus, iconSize: 16, icon: const Icon(Icons.add_rounded)),
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
        child: ZPressEffect(
          scale: .96,
          child: Material(
            color: selected ? ZamerColors.accent : ZamerColors.surface,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: ZamerTypography.caption.copyWith(
                    fontSize: 9,
                    color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outlineSoft),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16),
          ),
        ),
      );
}

class _ScaleBadge extends StatelessWidget {
  const _ScaleBadge({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final ratio = (50 / scale).round().clamp(25, 500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Text('1:$ratio', style: ZamerTypography.caption.copyWith(fontSize: 9)),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.floor});
  final FloorPlan floor;

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 62,
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: CustomPaint(painter: _MiniMapPainter(floor)),
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
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}
