import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/cad_plan_painter.dart';

/// UI KIT 02 production editor rebuilt around the approved portrait concept.
/// The canvas gets priority; toolbars stay narrow and contextual information
/// lives below it instead of stealing plan space.
class PlanEditorMasterV4Screen extends StatefulWidget {
  const PlanEditorMasterV4Screen({
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
  State<PlanEditorMasterV4Screen> createState() => _PlanEditorMasterV4ScreenState();
}

class _PlanEditorMasterV4ScreenState extends State<PlanEditorMasterV4Screen> {
  static const _canvasSize = Size(7000, 12000);
  static const _origin = Offset(3300, 1100);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();

  ZMeasureTool _tool = ZMeasureTool.walls;
  String? _selectedWallId;
  String? _wallStartNodeId;
  String? _dimensionStartNodeId;
  String _materialCategory = 'Пол';
  bool _grid = true;
  bool _snapping = true;
  bool _centered = false;
  Size _viewport = Size.zero;

  FloorPlan get floor => widget.floor;
  PlanWall? get _selectedWall =>
      _selectedWallId == null ? null : floor.wallById(_selectedWallId!);

  @override
  void initState() {
    super.initState();
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
      final d = _distanceToSegment(point, _toCanvas(a), _toCanvas(b));
      if (d < best) {
        best = d;
        result = wall;
      }
    }
    return result;
  }

  PlanNode? _nodeNear(Offset point) {
    PlanNode? result;
    var best = 28 / _scale;
    for (final node in floor.nodes) {
      final d = (_toCanvas(node) - point).distance;
      if (d < best) {
        best = d;
        result = node;
      }
    }
    return result;
  }

  void _fit() {
    if (_viewport.isEmpty || floor.nodes.isEmpty) return;
    const left = 70.0;
    const right = 70.0;
    const top = 18.0;
    const bottom = 18.0;
    final usableW = math.max(120.0, _viewport.width - left - right);
    final usableH = math.max(160.0, _viewport.height - top - bottom);
    final minX = floor.nodes.map((e) => e.xMm).reduce(math.min);
    final maxX = floor.nodes.map((e) => e.xMm).reduce(math.max);
    final minY = floor.nodes.map((e) => e.yMm).reduce(math.min);
    final maxY = floor.nodes.map((e) => e.yMm).reduce(math.max);
    final widthPx = math.max(1.0, (maxX - minX) * _mmToPx);
    final heightPx = math.max(1.0, (maxY - minY) * _mmToPx);
    final scale = math.min(2.8, math.max(.35, math.min(usableW / widthPx, usableH / heightPx) * .96));
    final center = _origin + Offset((minX + maxX) * .5 * _mmToPx, (minY + maxY) * .5 * _mmToPx);
    final target = Offset(left + usableW / 2, top + usableH / 2);
    _transform.value = Matrix4.identity()
      ..translate(target.dx - center.dx * scale, target.dy - center.dy * scale)
      ..scale(scale);
    if (mounted) setState(() {});
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.28, 6.0);
    if (_viewport.isEmpty) return;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translate(center.dx - scene.dx * next, center.dy - scene.dy * next)
      ..scale(next);
    setState(() {});
  }

  Future<void> _tapCanvas(TapUpDetails details) async {
    final p = details.localPosition;
    switch (_tool) {
      case ZMeasureTool.walls:
        final wall = _wallNear(p);
        if (wall != null && _wallStartNodeId == null) {
          setState(() => _selectedWallId = wall.id);
          return;
        }
        await _createWall(p);
      case ZMeasureTool.openings:
        await _addOpening(p);
      case ZMeasureTool.objects:
        widget.onOpenObjects();
      case ZMeasureTool.dimensions:
        await _addDimension(p);
      case ZMeasureTool.text:
        await _editNotes();
      case ZMeasureTool.layers:
        await _layersSheet();
    }
  }

  Future<void> _createWall(Offset p) async {
    if (_wallStartNodeId == null) {
      final node = _nodeNear(p) ?? GeometryService.ensureAnchor(floor, _toMm(p));
      setState(() {
        _wallStartNodeId = node.id;
        _selectedWallId = null;
      });
      await _changed();
      return;
    }
    final start = floor.nodeById(_wallStartNodeId!);
    if (start == null) return;
    var point = _toMm(p);
    if (_snapping) {
      final dx = point.x - start.xMm;
      final dy = point.y - start.yMm;
      if (dx.abs() > dy.abs()) {
        point = math.Point(point.x, start.yMm);
      } else {
        point = math.Point(start.xMm, point.y);
      }
    }
    if (math.Point(point.x - start.xMm, point.y - start.yMm).magnitude < 120) return;
    final before = floor.walls.map((e) => e.id).toSet();
    final end = GeometryService.addWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: point,
      type: WallType.partition,
      thicknessMm: 120,
      material: WallMaterial.drywall,
    );
    final created = floor.walls.where((w) => !before.contains(w.id)).toList();
    setState(() {
      _wallStartNodeId = end.id;
      if (created.isNotEmpty) _selectedWallId = created.first.id;
    });
    await _changed();
  }

  Future<void> _addOpening(Offset p) async {
    final wall = _wallNear(p);
    if (wall == null) return;
    final length = floor.wallLengthMm(wall);
    final width = math.min(900.0, math.max(600.0, length * .32));
    if (length <= width + 160) return;
    final opening = WallOpening(
      id: 'o-${DateTime.now().microsecondsSinceEpoch}',
      type: OpeningType.door,
      widthMm: width,
      heightMm: 2100,
      offsetFromStartMm: (length - width) / 2,
      doorSwing: DoorSwing.leftIn,
    );
    wall.openings.add(opening);
    setState(() => _selectedWallId = wall.id);
    await _changed();
  }

  Future<void> _addDimension(Offset p) async {
    final node = _nodeNear(p);
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
      builder: (context) => AlertDialog(
        title: const Text('Текст на плане'),
        content: TextField(controller: controller, minLines: 3, maxLines: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Сохранить')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    floor.notes = value;
    await _changed();
  }

  Future<void> _layersSheet() async {
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
              children: [
                for (final layer in ProjectLayer.values)
                  CheckboxListTile(
                    value: draft.contains(layer),
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

  Future<void> _editWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    final thickness = TextEditingController(text: wall.thicknessMm.round().toString());
    final height = TextEditingController(text: (wall.heightOverrideMm ?? floor.defaultHeightMm).round().toString());
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: thickness, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Толщина', suffixText: 'мм')),
            const SizedBox(height: 8),
            TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Высота', suffixText: 'мм')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить'))),
          ],
        ),
      ),
    );
    if (save == true) {
      final t = double.tryParse(thickness.text);
      final h = double.tryParse(height.text);
      if (t != null && t > 40) wall.thicknessMm = t;
      if (h != null && h > 300) wall.heightOverrideMm = h;
      await _changed();
    }
    thickness.dispose();
    height.dispose();
  }

  Future<void> _deleteWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    GeometryService.removeWall(floor, wall.id);
    setState(() => _selectedWallId = floor.walls.isEmpty ? null : floor.walls.first.id);
    await _changed();
  }

  void _selectTool(ZMeasureTool tool) {
    if (tool == ZMeasureTool.objects) {
      widget.onOpenObjects();
      return;
    }
    setState(() {
      _tool = tool;
      _wallStartNodeId = null;
      _dimensionStartNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ZamerColors.background,
      child: Column(
        children: [
          Expanded(child: _canvas()),
          if (_selectedWall != null)
            _WallInspector(wall: _selectedWall!, floor: floor, onEdit: _editWall),
          _ActionBar(
            tool: _tool,
            hasSelection: _selectedWall != null,
            onWall: () => _selectTool(ZMeasureTool.walls),
            onOpening: () => _selectTool(ZMeasureTool.openings),
            onDimension: () => _selectTool(ZMeasureTool.dimensions),
            onText: () => _selectTool(ZMeasureTool.text),
            onGeometry: widget.onOpenGeometry,
            onLayers: () => _selectTool(ZMeasureTool.layers),
            onDelete: _selectedWall == null ? null : _deleteWall,
          ),
          _MaterialPanel(
            category: _materialCategory,
            onCategory: (value) => setState(() => _materialCategory = value),
            onOpenMaterials: widget.onOpenMaterials,
          ),
        ],
      ),
    );
  }

  Widget _canvas() => LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_centered) {
            _centered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
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
                        showGrid: _grid,
                        visibleLayers: _visibleLayers,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(left: 8, top: 8, child: _ToolRail(tool: _tool, onTool: _selectTool, onReview: widget.onOpenReview)),
              Positioned(
                right: 8,
                top: 8,
                child: _ViewRail(
                  grid: _grid,
                  snapping: _snapping,
                  onGrid: () => setState(() => _grid = !_grid),
                  on3D: widget.onOpen3D,
                  onFloors: widget.onOpenFloors,
                  onSnap: () => setState(() => _snapping = !_snapping),
                  onSettings: widget.onOpenSettings,
                ),
              ),
              Positioned(
                left: 8,
                bottom: 10,
                child: _UndoRedo(
                  onUndo: widget.canUndo ? widget.onUndo : null,
                  onRedo: widget.canRedo ? widget.onRedo : null,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _CanvasControls(
                  floor: floor,
                  onFit: _fit,
                  onZoomIn: () => _zoom(1.18),
                  onZoomOut: () => _zoom(.84),
                ),
              ),
            ],
          );
        },
      );
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({required this.tool, required this.onTool, required this.onReview});
  final ZMeasureTool tool;
  final ValueChanged<ZMeasureTool> onTool;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => _RailFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in ZMeasureTool.values)
              _RailItem(icon: item.icon, label: item.label, selected: tool == item, onTap: () => onTool(item)),
            const Divider(height: 7, color: ZamerColors.outlineSoft),
            _RailItem(icon: Icons.check_circle_outline_rounded, label: 'Проверка', selected: false, onTap: onReview),
          ],
        ),
      );
}

class _ViewRail extends StatelessWidget {
  const _ViewRail({
    required this.grid,
    required this.snapping,
    required this.onGrid,
    required this.on3D,
    required this.onFloors,
    required this.onSnap,
    required this.onSettings,
  });
  final bool grid;
  final bool snapping;
  final VoidCallback onGrid;
  final VoidCallback on3D;
  final VoidCallback onFloors;
  final VoidCallback onSnap;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => _RailFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailItem(icon: Icons.grid_4x4_rounded, label: 'Сетка', selected: false, activeDot: grid, onTap: onGrid),
            _RailItem(icon: Icons.view_in_ar_outlined, label: '3D вид', selected: false, onTap: on3D),
            _RailItem(icon: Icons.layers_outlined, label: 'Этажи', selected: false, onTap: onFloors),
            _RailItem(icon: Icons.link_rounded, label: 'Привязка', selected: false, activeDot: snapping, onTap: onSnap),
            _RailItem(icon: Icons.settings_outlined, label: 'Настройки', selected: false, onTap: onSettings),
          ],
        ),
      );
}

class _RailFrame extends StatelessWidget {
  const _RailFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF07171D).withValues(alpha: .97),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: child,
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeDot = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool activeDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? ZamerColors.accentInk : ZamerColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 42,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 17, color: fg),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(color: fg, fontSize: 6.7, fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (activeDot)
                  Positioned(right: 3, top: 4, child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: ZamerColors.accent, shape: BoxShape.circle))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoRedo extends StatelessWidget {
  const _UndoRedo({required this.onUndo, required this.onRedo});
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: const Color(0xFF07171D).withValues(alpha: .95), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZamerColors.outlineSoft)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _square(Icons.arrow_back_rounded, onUndo),
            const SizedBox(width: 3),
            _square(Icons.arrow_forward_rounded, onRedo),
          ],
        ),
      );

  Widget _square(IconData icon, VoidCallback? tap) => Opacity(
        opacity: tap == null ? .3 : 1,
        child: InkWell(onTap: tap, child: SizedBox(width: 31, height: 28, child: Icon(icon, size: 16, color: ZamerColors.textSecondary))),
      );
}

class _CanvasControls extends StatelessWidget {
  const _CanvasControls({required this.floor, required this.onFit, required this.onZoomIn, required this.onZoomOut});
  final FloorPlan floor;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [_small(Icons.remove_rounded, onZoomOut), const SizedBox(width: 5), _small(Icons.add_rounded, onZoomIn)]),
          const SizedBox(height: 5),
          _small(Icons.fullscreen_rounded, onFit),
          const SizedBox(height: 5),
          InkWell(
            onTap: onFit,
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF07171D).withValues(alpha: .96), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZamerColors.outlineSoft)),
              child: CustomPaint(painter: _MiniMapPainter(floor)),
            ),
          ),
        ],
      );

  Widget _small(IconData icon, VoidCallback tap) => InkWell(
        onTap: tap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: const Color(0xFF07171D).withValues(alpha: .96), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZamerColors.outlineSoft)),
          child: Icon(icon, size: 18, color: ZamerColors.textPrimary),
        ),
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
    final s = math.min((size.width - 4) / w, (size.height - 4) / h);
    Offset p(PlanNode n) => Offset(2 + (n.xMm - minX) * s, 2 + (n.yMm - minY) * s);
    final paint = Paint()..color = const Color(0xFFD8DFE0)..strokeWidth = 1.1;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a != null && b != null) canvas.drawLine(p(a), p(b), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

class _WallInspector extends StatelessWidget {
  const _WallInspector({required this.wall, required this.floor, required this.onEdit});
  final PlanWall wall;
  final FloorPlan floor;
  final VoidCallback onEdit;

  double get _angle {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return 0;
    var d = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm) * 180 / math.pi;
    if (d < 0) d += 360;
    return d;
  }

  String get _name {
    final i = math.max(0, floor.walls.indexOf(wall));
    return 'Стена ${String.fromCharCode(65 + i % 26)}${i ~/ 26 + 1}';
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 66,
        margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF07171D), borderRadius: BorderRadius.circular(9), border: Border.all(color: ZamerColors.outlineSoft)),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 52,
              decoration: BoxDecoration(color: const Color(0xFF102129), borderRadius: BorderRadius.circular(7), border: Border.all(color: ZamerColors.outlineSoft)),
              child: const CustomPaint(painter: _WallPreviewPainter()),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 21,
                    child: Row(children: [Text(_name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)), const SizedBox(width: 3), InkWell(onTap: onEdit, child: const Icon(Icons.edit_outlined, size: 13, color: ZamerColors.textSecondary)), const Spacer(), const Icon(Icons.more_vert_rounded, size: 16, color: ZamerColors.textSecondary)]),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _metric('Длина', '${floor.wallLengthMm(wall).round()} мм', locked: true),
                        _metric('Угол', '${_angle.round()}°'),
                        _metric('Толщина', '${wall.thicknessMm.round()} мм'),
                        _metric('Высота', '${(wall.heightOverrideMm ?? floor.defaultHeightMm).round()} мм'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _metric(String label, String value, {bool locked = false}) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF0D2028), borderRadius: BorderRadius.circular(6), border: Border.all(color: ZamerColors.outlineSoft)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, maxLines: 1, style: const TextStyle(color: ZamerColors.textMuted, fontSize: 6.7)), Row(children: [Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w500))), if (locked) const Icon(Icons.lock_outline_rounded, size: 9, color: ZamerColors.textMuted)])]),
        ),
      );
}

class _WallPreviewPainter extends CustomPainter {
  const _WallPreviewPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final side = Paint()..color = const Color(0xFF68727A);
    final front = Paint()..color = const Color(0xFFD6D7D3);
    final top = Paint()..color = const Color(0xFFF0F0EC);
    final p = Path()..moveTo(12, 12)..lineTo(size.width - 10, 5)..lineTo(size.width - 10, size.height - 10)..lineTo(12, size.height - 4)..close();
    canvas.drawPath(p, front);
    canvas.drawPath(Path()..moveTo(6, 17)..lineTo(12, 12)..lineTo(12, size.height - 4)..lineTo(6, size.height - 10)..close(), side);
    canvas.drawPath(Path()..moveTo(6, 17)..lineTo(12, 12)..lineTo(size.width - 10, 5)..lineTo(size.width - 16, 10)..close(), top);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.tool, required this.hasSelection, required this.onWall, required this.onOpening, required this.onDimension, required this.onText, required this.onGeometry, required this.onLayers, required this.onDelete});
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
        height: 49,
        margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
        child: Row(children: [
          _item(Icons.view_week_outlined, 'Стена', tool == ZMeasureTool.walls, onWall),
          _item(Icons.door_front_door_outlined, 'Проём', tool == ZMeasureTool.openings, onOpening),
          _item(Icons.straighten_rounded, 'Размер', tool == ZMeasureTool.dimensions, onDimension),
          _item(Icons.title_rounded, 'Текст', tool == ZMeasureTool.text, onText),
          _item(Icons.hexagon_outlined, 'Фигура', false, onGeometry),
          _item(Icons.layers_outlined, 'Слой', tool == ZMeasureTool.layers, onLayers),
          _item(Icons.delete_outline_rounded, 'Удалить', false, onDelete, danger: true),
        ]),
      );

  Widget _item(IconData icon, String label, bool selected, VoidCallback? tap, {bool danger = false}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Opacity(
            opacity: tap == null ? .35 : 1,
            child: Material(
              color: selected ? ZamerColors.accent : const Color(0xFF07171D),
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                onTap: tap,
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: selected ? ZamerColors.accent : danger ? ZamerColors.danger.withValues(alpha: .65) : ZamerColors.outlineSoft)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: selected ? ZamerColors.accentInk : danger ? ZamerColors.danger : ZamerColors.textPrimary), const SizedBox(height: 1), Text(label, style: TextStyle(color: selected ? ZamerColors.accentInk : danger ? ZamerColors.danger : ZamerColors.textSecondary, fontSize: 6.7, fontWeight: FontWeight.w600))]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _MaterialPanel extends StatelessWidget {
  const _MaterialPanel({required this.category, required this.onCategory, required this.onOpenMaterials});
  final String category;
  final ValueChanged<String> onCategory;
  final VoidCallback onOpenMaterials;
  static const _categories = ['Пол', 'Стены', 'Потолок', 'Двери', 'Окна', 'Освещение'];

  List<VisualMaterialPreset> get _materials {
    if (category == 'Пол') return MaterialCatalog.floorFinishes.take(6).toList();
    if (category == 'Стены') return MaterialCatalog.forCategory('Стены').take(6).toList();
    return MaterialCatalog.presets.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final materials = _materials;
    return Container(
      height: 108,
      margin: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(color: const Color(0xFF07171D), borderRadius: BorderRadius.circular(9), border: Border.all(color: ZamerColors.outlineSoft)),
      child: Column(children: [
        SizedBox(
          height: 31,
          child: Row(children: [for (final item in _categories) Expanded(child: Padding(padding: const EdgeInsets.all(3), child: Material(color: item == category ? ZamerColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(6), child: InkWell(onTap: () => onCategory(item), borderRadius: BorderRadius.circular(6), child: Center(child: Text(item, maxLines: 1, overflow: TextOverflow.fade, style: TextStyle(color: item == category ? ZamerColors.accentInk : ZamerColors.textSecondary, fontSize: 7.2, fontWeight: FontWeight.w700)))))))]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(5, 1, 5, 5),
            scrollDirection: Axis.horizontal,
            itemCount: materials.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) => _MaterialCard(material: materials[index], onTap: onOpenMaterials, selected: index == 0),
          ),
        ),
      ]),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.onTap, required this.selected});
  final VisualMaterialPreset material;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 68,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xFF0B1D24), borderRadius: BorderRadius.circular(7), border: Border.all(color: selected ? ZamerColors.accent : ZamerColors.outlineSoft, width: selected ? 1.4 : 1)),
          child: Column(children: [
            Expanded(child: Container(decoration: BoxDecoration(color: material.color, borderRadius: BorderRadius.circular(5), image: material.textureAsset == null ? null : DecorationImage(image: AssetImage(material.textureAsset!), fit: BoxFit.cover)))),
            const SizedBox(height: 2),
            Text(material.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: ZamerColors.textSecondary, fontSize: 6.5, height: 1.05)),
          ]),
        ),
      );
}
