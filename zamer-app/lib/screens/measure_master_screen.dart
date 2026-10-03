import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/cad_plan_painter.dart';

/// Canonical Measure page from the approved warm ZAMER master UI.
///
/// The screen intentionally owns its chrome while reusing the production CAD
/// painter and geometry services. This keeps the visual composition faithful
/// without downgrading the editable measurement model.
class MeasureMasterScreen extends StatefulWidget {
  const MeasureMasterScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onMore,
    required this.onOpenObjects,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onMore;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;

  @override
  State<MeasureMasterScreen> createState() => _MeasureMasterScreenState();
}

enum _MasterCadTool {
  wall,
  opening,
  object,
  dimension,
  text,
  partition,
  door,
  window,
  diagonal,
  figure,
  layers,
}

class _MeasureMasterScreenState extends State<MeasureMasterScreen> {
  static const _canvasSize = Size(7000, 12000);
  static const _origin = Offset(3300, 1100);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();

  _MasterCadTool _tool = _MasterCadTool.wall;
  String? _selectedWallId;
  String? _wallStartNodeId;
  String? _dimensionStartNodeId;
  bool _centered = false;
  bool _snapping = true;
  Size _viewport = Size.zero;

  FloorPlan get floor => widget.floor;
  PlanWall? get _selectedWall =>
      _selectedWallId == null ? null : floor.wallById(_selectedWallId!);

  @override
  void initState() {
    super.initState();
    GeometryService.syncRoomMetadata(floor);
    if (floor.walls.isNotEmpty) _selectedWallId = floor.walls.first.id;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(floor);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  double get _scale => math.max(.1, _transform.value.getMaxScaleOnAxis());

  Offset _toCanvas(PlanNode node) =>
      _origin + Offset(node.xMm * _mmToPx, node.yMm * _mmToPx);

  math.Point<double> _toMm(Offset p) => math.Point<double>(
        (p.dx - _origin.dx) / _mmToPx,
        (p.dy - _origin.dy) / _mmToPx,
      );

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (l2 <= 0) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / l2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  PlanWall? _wallNear(Offset point) {
    PlanWall? result;
    var best = 34 / _scale;
    for (final wall in floor.walls) {
      if (wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final distance = _distanceToSegment(point, _toCanvas(a), _toCanvas(b));
      if (distance < best) {
        best = distance;
        result = wall;
      }
    }
    return result;
  }

  PlanNode? _nodeNear(Offset point) {
    PlanNode? result;
    var best = 28 / _scale;
    for (final node in floor.nodes) {
      final distance = (_toCanvas(node) - point).distance;
      if (distance < best) {
        best = distance;
        result = node;
      }
    }
    return result;
  }

  void _fit() {
    if (_viewport.isEmpty || floor.nodes.isEmpty) return;
    const left = 72.0;
    const right = 20.0;
    const top = 18.0;
    const bottom = 18.0;
    final usableWidth = math.max(120.0, _viewport.width - left - right);
    final usableHeight = math.max(160.0, _viewport.height - top - bottom);
    final minX = floor.nodes.map((node) => node.xMm).reduce(math.min);
    final maxX = floor.nodes.map((node) => node.xMm).reduce(math.max);
    final minY = floor.nodes.map((node) => node.yMm).reduce(math.min);
    final maxY = floor.nodes.map((node) => node.yMm).reduce(math.max);
    final widthPx = math.max(1.0, (maxX - minX) * _mmToPx);
    final heightPx = math.max(1.0, (maxY - minY) * _mmToPx);
    final scale = math.min(
      2.8,
      math.max(
        .35,
        math.min(usableWidth / widthPx, usableHeight / heightPx) * .94,
      ),
    );
    final center = _origin +
        Offset(
          (minX + maxX) * .5 * _mmToPx,
          (minY + maxY) * .5 * _mmToPx,
        );
    final target = Offset(left + usableWidth / 2, top + usableHeight / 2);
    _transform.value = Matrix4.identity()
      ..translate(target.dx - center.dx * scale, target.dy - center.dy * scale)
      ..scale(scale);
  }

  void _selectTool(_MasterCadTool tool) {
    if (tool == _MasterCadTool.object) {
      widget.onOpenObjects();
      return;
    }
    if (tool == _MasterCadTool.figure) {
      widget.onOpenGeometry();
      return;
    }
    if (tool == _MasterCadTool.layers) {
      _showLayers();
      return;
    }
    setState(() {
      _tool = tool;
      _wallStartNodeId = null;
      _dimensionStartNodeId = null;
    });
  }

  Future<void> _tapCanvas(TapUpDetails details) async {
    final point = details.localPosition;
    switch (_tool) {
      case _MasterCadTool.wall:
      case _MasterCadTool.partition:
        final wall = _wallNear(point);
        if (wall != null && _wallStartNodeId == null) {
          setState(() => _selectedWallId = wall.id);
          return;
        }
        await _createWall(point, exterior: _tool == _MasterCadTool.wall);
      case _MasterCadTool.opening:
      case _MasterCadTool.door:
        await _addOpening(point, OpeningType.door);
      case _MasterCadTool.window:
        await _addOpening(point, OpeningType.window);
      case _MasterCadTool.dimension:
      case _MasterCadTool.diagonal:
        await _addDimension(point);
      case _MasterCadTool.text:
        await _editNotes();
      case _MasterCadTool.object:
        widget.onOpenObjects();
      case _MasterCadTool.figure:
        widget.onOpenGeometry();
      case _MasterCadTool.layers:
        await _showLayers();
    }
  }

  Future<void> _createWall(Offset point, {required bool exterior}) async {
    if (_wallStartNodeId == null) {
      final node =
          _nodeNear(point) ?? GeometryService.ensureAnchor(floor, _toMm(point));
      setState(() {
        _wallStartNodeId = node.id;
        _selectedWallId = null;
      });
      await _changed();
      return;
    }

    final start = floor.nodeById(_wallStartNodeId!);
    if (start == null) return;
    var endPoint = _toMm(point);
    if (_snapping) {
      final dx = endPoint.x - start.xMm;
      final dy = endPoint.y - start.yMm;
      if (dx.abs() > dy.abs()) {
        endPoint = math.Point(endPoint.x, start.yMm);
      } else {
        endPoint = math.Point(start.xMm, endPoint.y);
      }
    }
    if (math.Point(endPoint.x - start.xMm, endPoint.y - start.yMm)
            .magnitude <
        120) {
      return;
    }

    final before = floor.walls.map((wall) => wall.id).toSet();
    final end = GeometryService.addWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: endPoint,
      type: exterior ? WallType.exterior : WallType.partition,
      thicknessMm: exterior ? 200 : 100,
      material: exterior ? WallMaterial.gasBlock : WallMaterial.drywall,
    );
    final created = floor.walls.where((wall) => !before.contains(wall.id)).toList();
    setState(() {
      _wallStartNodeId = end.id;
      if (created.isNotEmpty) _selectedWallId = created.first.id;
    });
    await _changed();
  }

  Future<void> _addOpening(Offset point, OpeningType type) async {
    final wall = _wallNear(point);
    if (wall == null) return;
    final length = floor.wallLengthMm(wall);
    final width = type == OpeningType.window
        ? math.min(1400.0, math.max(700.0, length * .36))
        : math.min(900.0, math.max(600.0, length * .30));
    if (length <= width + 160) return;

    wall.openings.add(
      WallOpening(
        id: 'o-${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        widthMm: width,
        heightMm: type == OpeningType.window ? 1400 : 2100,
        offsetFromStartMm: (length - width) / 2,
        sillHeightMm: type == OpeningType.window ? 850 : 0,
        doorSwing: type == OpeningType.door ? DoorSwing.leftIn : null,
      ),
    );
    setState(() => _selectedWallId = wall.id);
    await _changed();
  }

  Future<void> _addDimension(Offset point) async {
    final node = _nodeNear(point);
    if (node == null) return;
    if (_dimensionStartNodeId == null) {
      setState(() => _dimensionStartNodeId = node.id);
      return;
    }
    final start = floor.nodeById(_dimensionStartNodeId!);
    if (start == null || start.id == node.id) return;
    final value = GeometryService.distance(start, node);
    final measure = ControlMeasure(
      id: 'm-${DateTime.now().microsecondsSinceEpoch}',
      startNodeId: start.id,
      endNodeId: node.id,
      measuredMm: value,
    );
    floor.measures.add(measure);
    floor.dimensionRecords['control:${measure.id}'] = DimensionRecord(
      valueMm: value,
      source: DimensionSource.calculated,
      author: 'Замер',
      recordedAt: DateTime.now(),
    );
    setState(() => _dimensionStartNodeId = null);
    await _changed();
  }

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: floor.notes);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Текст на плане'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Введите заметку…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Слои', style: ZamerTypography.h2),
                const SizedBox(height: 8),
                for (final layer in ProjectLayer.values)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: draft.contains(layer),
                    title: Text(layer.label),
                    onChanged: (value) => setSheetState(() {
                      if (value == true) {
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

  Future<void> _editWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    final thickness =
        TextEditingController(text: wall.thicknessMm.round().toString());
    final height = TextEditingController(
      text: (wall.heightOverrideMm ?? floor.defaultHeightMm).round().toString(),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
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
            const Text('Параметры стены', style: ZamerTypography.h2),
            const SizedBox(height: 12),
            TextField(
              controller: thickness,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Толщина',
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
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final thicknessValue = double.tryParse(thickness.text);
      final heightValue = double.tryParse(height.text);
      if (thicknessValue != null && thicknessValue > 40) {
        wall.thicknessMm = thicknessValue;
      }
      if (heightValue != null && heightValue > 300) {
        wall.heightOverrideMm = heightValue;
      }
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
      _wallStartNodeId = null;
    });
    await _changed();
  }

  String _wallName(PlanWall wall) {
    final index = math.max(0, floor.walls.indexOf(wall));
    return 'Стена ${String.fromCharCode(65 + index % 26)}';
  }

  double _wallAngle(PlanWall wall) {
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) return 0;
    var degrees =
        math.atan2(end.yMm - start.yMm, end.xMm - start.xMm) * 180 / math.pi;
    if (degrees < 0) degrees += 360;
    return degrees;
  }

  @override
  Widget build(BuildContext context) {
    final wall = _selectedWall;
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _MasterMeasureHeader(
              projectName: widget.project.name,
              onBack: () => Navigator.maybePop(context),
              onFloors: widget.onOpenFloors,
              onMore: widget.onMore,
            ),
            _TopToolBar(
              selected: _tool,
              onSelect: _selectTool,
            ),
            const Divider(height: 1),
            Expanded(child: _canvas()),
            if (wall != null)
              _WallInspector(
                name: _wallName(wall),
                lengthMm: floor.wallLengthMm(wall),
                thicknessMm: wall.thicknessMm,
                heightMm: wall.heightOverrideMm ?? floor.defaultHeightMm,
                angle: _wallAngle(wall),
                type: wall.type,
                material: wall.material,
                onEdit: _editWall,
                onDelete: _deleteSelectedWall,
              )
            else
              const _NoSelectionStrip(),
            _BottomToolBar(
              selected: _tool,
              onObjects: widget.onOpenObjects,
              onDimensions: () => _selectTool(_MasterCadTool.dimension),
              onText: () => _selectTool(_MasterCadTool.text),
              onFigures: widget.onOpenGeometry,
              onLayers: _showLayers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas() => LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_centered) {
            _centered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_fit);
            });
          }
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: .28,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(2200),
                  constrained: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _tapCanvas,
                    child: CustomPaint(
                      size: _canvasSize,
                      painter: CadPlanPainter(
                        floor: floor,
                        mmToPx: _mmToPx,
                        origin: _origin,
                        selectedWallId: _selectedWallId,
                        showGrid: true,
                        visibleLayers: _visibleLayers,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                bottom: 8,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _LeftToolRail(
                    selected: _tool,
                    snapping: _snapping,
                    onSelect: _selectTool,
                    onUndo: widget.canUndo ? widget.onUndo : null,
                    onRedo: widget.canRedo ? widget.onRedo : null,
                    onToggleSnap: () => setState(() => _snapping = !_snapping),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _MasterMeasureHeader extends StatelessWidget {
  const _MasterMeasureHeader({
    required this.projectName,
    required this.onBack,
    required this.onFloors,
    required this.onMore,
  });

  final String projectName;
  final VoidCallback onBack;
  final VoidCallback onFloors;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Назад',
                visualDensity: VisualDensity.compact,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.h3.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Этажи',
                visualDensity: VisualDensity.compact,
                onPressed: onFloors,
                icon: const Icon(Icons.layers_outlined, size: 21),
              ),
              IconButton(
                tooltip: 'Ещё',
                visualDensity: VisualDensity.compact,
                onPressed: onMore,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
              ),
            ],
          ),
        ),
      );
}

class _TopToolBar extends StatelessWidget {
  const _TopToolBar({required this.selected, required this.onSelect});

  final _MasterCadTool selected;
  final ValueChanged<_MasterCadTool> onSelect;

  static const _items = <(_MasterCadTool, IconData, String)>[
    (_MasterCadTool.wall, Icons.architecture_outlined, 'Стена'),
    (_MasterCadTool.opening, Icons.door_front_door_outlined, 'Проём'),
    (_MasterCadTool.object, Icons.chair_alt_outlined, 'Объект'),
    (_MasterCadTool.dimension, Icons.straighten_rounded, 'Размер'),
    (_MasterCadTool.text, Icons.title_rounded, 'Текст'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++) ...[
                Expanded(
                  child: _ToolButton(
                    icon: _items[index].$2,
                    label: _items[index].$3,
                    selected: selected == _items[index].$1,
                    onTap: () => onSelect(_items[index].$1),
                  ),
                ),
                if (index != _items.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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
        selected ? ZamerColors.accent : ZamerColors.textSecondary;
    return Material(
      color: selected
          ? ZamerColors.accent.withValues(alpha: .08)
          : ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZamerRadius.sm),
            border: Border.all(
              color: selected ? ZamerColors.accent : ZamerColors.outline,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftToolRail extends StatelessWidget {
  const _LeftToolRail({
    required this.selected,
    required this.snapping,
    required this.onSelect,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleSnap,
  });

  final _MasterCadTool selected;
  final bool snapping;
  final ValueChanged<_MasterCadTool> onSelect;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onToggleSnap;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ZamerColors.surface.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _item(Icons.view_week_outlined, 'Стена', _MasterCadTool.wall),
            _item(Icons.crop_portrait_rounded, 'Перегородка', _MasterCadTool.partition),
            _item(Icons.door_front_door_outlined, 'Дверь', _MasterCadTool.door),
            _item(Icons.window_outlined, 'Окно', _MasterCadTool.window),
            _item(Icons.straighten_rounded, 'Размер', _MasterCadTool.dimension),
            _item(Icons.compare_arrows_rounded, 'Диагональ', _MasterCadTool.diagonal),
            _item(Icons.hexagon_outlined, 'Фигура', _MasterCadTool.figure),
            _item(Icons.title_rounded, 'Текст', _MasterCadTool.text),
            const Divider(height: 5),
            _command(Icons.undo_rounded, 'Отмена', onUndo),
            _command(Icons.redo_rounded, 'Повтор', onRedo),
            const Divider(height: 5),
            _command(
              Icons.my_location_rounded,
              'Привязка',
              onToggleSnap,
              active: snapping,
            ),
          ],
        ),
      );

  Widget _item(IconData icon, String label, _MasterCadTool tool) =>
      _railButton(
        icon,
        label,
        selected == tool,
        () => onSelect(tool),
      );

  Widget _command(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
  }) =>
      Opacity(
        opacity: onTap == null ? .35 : 1,
        child: _railButton(icon, label, active, onTap),
      );

  Widget _railButton(
    IconData icon,
    String label,
    bool active,
    VoidCallback? onTap,
  ) {
    final foreground =
        active ? ZamerColors.accent : ZamerColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active
            ? ZamerColors.accent.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44,
            height: 41,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 6.6,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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

class _WallInspector extends StatelessWidget {
  const _WallInspector({
    required this.name,
    required this.lengthMm,
    required this.thicknessMm,
    required this.heightMm,
    required this.angle,
    required this.type,
    required this.material,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final double lengthMm;
  final double thicknessMm;
  final double heightMm;
  final double angle;
  final WallType type;
  final WallMaterial material;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: ZamerTypography.h3.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Редактировать',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: ZamerColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _value('Длина', '${lengthMm.round()} мм')),
                const SizedBox(width: 6),
                Expanded(child: _value('Толщина', '${thicknessMm.round()} мм')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _value('Высота', '${heightMm.round()} мм')),
                const SizedBox(width: 6),
                Expanded(child: _value('Угол', '${angle.round()}°')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _value('Тип', _wallTypeLabel(type))),
                const SizedBox(width: 6),
                Expanded(child: _value('Материал', _wallMaterialLabel(material))),
              ],
            ),
          ],
        ),
      );

  Widget _value(String label, String value) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ZamerColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: ZamerColors.textMuted,
                fontSize: 8,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZamerColors.textPrimary,
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _NoSelectionStrip extends StatelessWidget {
  const _NoSelectionStrip();

  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Text(
          'Выберите стену или инструмент',
          style: ZamerTypography.caption,
        ),
      );
}

class _BottomToolBar extends StatelessWidget {
  const _BottomToolBar({
    required this.selected,
    required this.onObjects,
    required this.onDimensions,
    required this.onText,
    required this.onFigures,
    required this.onLayers,
  });

  final _MasterCadTool selected;
  final VoidCallback onObjects;
  final VoidCallback onDimensions;
  final VoidCallback onText;
  final VoidCallback onFigures;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ZamerColors.background,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          children: [
            _item(
              Icons.category_outlined,
              'Объекты',
              selected == _MasterCadTool.object,
              onObjects,
            ),
            _item(
              Icons.straighten_rounded,
              'Размеры',
              selected == _MasterCadTool.dimension ||
                  selected == _MasterCadTool.diagonal,
              onDimensions,
            ),
            _item(
              Icons.text_fields_rounded,
              'Текст',
              selected == _MasterCadTool.text,
              onText,
            ),
            _item(
              Icons.hexagon_outlined,
              'Фигуры',
              selected == _MasterCadTool.figure,
              onFigures,
            ),
            _item(
              Icons.layers_outlined,
              'Слои',
              selected == _MasterCadTool.layers,
              onLayers,
            ),
          ],
        ),
      );

  Widget _item(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) =>
      Expanded(
        child: Material(
          color: active
              ? ZamerColors.accent.withValues(alpha: .08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? ZamerColors.accent : ZamerColors.textSecondary,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color:
                        active ? ZamerColors.accent : ZamerColors.textSecondary,
                    fontSize: 8.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

String _wallTypeLabel(WallType type) => switch (type) {
      WallType.exterior => 'Несущая',
      WallType.partition => 'Перегородка',
    };

String _wallMaterialLabel(WallMaterial material) => switch (material) {
      WallMaterial.concrete => 'Бетон',
      WallMaterial.brick => 'Кирпич',
      WallMaterial.gasBlock => 'Газоблок',
      WallMaterial.drywall => 'ГКЛ',
      WallMaterial.wood => 'Дерево',
      WallMaterial.other => 'Другое',
    };
