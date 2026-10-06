import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../services/object_catalog.dart';
import '../services/plan_direct_interaction.dart';
import '../services/space_check_service.dart';
import '../widgets/cad_plan_painter.dart';

/// UI KIT 02 production editor rebuilt around the approved portrait concept.
/// +80 adds direct room selection and one-tap material application.
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
  String? _selectedRoomFaceKey;
  String? _wallStartNodeId;
  String? _dimensionStartNodeId;
  String? _dragObjectId;
  bool _dragObjectDirty = false;
  bool _layoutDragDirty = false;
  bool _materialsExpanded = true;
  String _materialCategory = 'Пол';
  bool _materialPickMode = true;
  bool _grid = true;
  bool _snapping = true;
  bool _centered = false;
  Size _viewport = Size.zero;

  FloorPlan get floor => widget.floor;
  PlanWall? get _selectedWall =>
      _selectedWallId == null ? null : floor.wallById(_selectedWallId!);

  List<RoomFace> get _faces => GeometryService.roomFaces(floor);

  RoomFace? get _selectedRoomFace {
    final key = _selectedRoomFaceKey;
    if (key == null) return null;
    for (final face in _faces) {
      if (face.key == key) return face;
    }
    return null;
  }

  RoomMeta? get _selectedRoomMeta {
    final key = _selectedRoomFaceKey;
    if (key == null) return null;
    for (final meta in floor.roomMetas) {
      if (meta.faceKey == key) return meta;
    }
    return null;
  }

  String? get _selectedMaterialId {
    final meta = _selectedRoomMeta;
    if (meta == null) return null;
    return _materialCategory == 'Стены'
        ? meta.materials.wallMaterialId
        : meta.materials.floorMaterialId;
  }

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
    if (_selectedRoomFaceKey != null && _selectedRoomFace == null) {
      _selectedRoomFaceKey = null;
    }
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

  bool _pointInPolygon(
    math.Point<double> point,
    List<math.Point<double>> polygon,
  ) {
    if (polygon.length < 3) return false;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses = (a.y > point.y) != (b.y > point.y);
      if (crosses) {
        final x = (b.x - a.x) * (point.y - a.y) /
                ((b.y - a.y).abs() < .000001 ? .000001 : b.y - a.y) +
            a.x;
        if (point.x < x) inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  RoomFace? _roomAt(Offset canvasPoint) {
    final mm = _toMm(canvasPoint);
    for (final face in _faces) {
      if (_pointInPolygon(mm, face.innerPolygon)) return face;
    }
    return null;
  }

  void _selectRoomMode() {
    setState(() {
      _materialPickMode = true;
      _wallStartNodeId = null;
      _dimensionStartNodeId = null;
      _selectedWallId = null;
    });
  }

  void _selectMaterialCategory(String category) {
    if (category != 'Пол' && category != 'Стены') {
      widget.onOpenMaterials();
      return;
    }
    setState(() {
      _materialCategory = category;
      _materialPickMode = true;
      _wallStartNodeId = null;
      _dimensionStartNodeId = null;
      _selectedWallId = null;
    });
  }

  Future<void> _applyMaterial(VisualMaterialPreset material) async {
    GeometryService.syncRoomMetadata(floor);
    final meta = _selectedRoomMeta;
    if (meta == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала нажмите на помещение.')),
        );
      }
      _selectRoomMode();
      return;
    }

    final settings = meta.materials;
    if (_materialCategory == 'Стены') {
      settings.wallMaterialId = material.id;
      if (material.pattern == 'tile') {
        settings.wallTile = true;
        settings.wallTileMaterialId = material.id;
      } else {
        settings.wallTile = false;
      }
    } else {
      settings.floorMaterialId = material.id;
      final tile = material.pattern == 'tile';
      settings.floorMode = tile ? 'tile' : 'laminate';
      settings.floorTile = tile;
    }

    await _changed();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1100),
        content: Text('${material.name} • ${meta.name}'),
      ),
    );
  }

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

  void _movePlanObject(PlanObject object, DragUpdateDetails details) {
    if (_dragObjectId != object.id) return;
    final oldX = object.xMm;
    final oldY = object.yMm;
    PlanDirectInteraction.moveObjectByMm(
      object,
      dxMm: details.delta.dx / _mmToPx,
      dyMm: details.delta.dy / _mmToPx,
      snapMm: _snapping ? 10 : 0,
    );
    if (SpaceCheckService.intersectsWall(floor, object)) {
      object.xMm = oldX;
      object.yMm = oldY;
    } else if (object.xMm != oldX || object.yMm != oldY) {
      _dragObjectDirty = true;
    }
    setState(() {});
  }

  Future<void> _finishObjectDrag() async {
    if (_dragObjectId == null) return;
    final changed = _dragObjectDirty;
    setState(() {
      _dragObjectId = null;
      _dragObjectDirty = false;
    });
    if (changed) await _changed();
  }

  Iterable<Widget> _objectDragRegions() sync* {
    for (final object in floor.planObjects) {
      if (!_visibleLayers.contains(object.layer)) continue;
      final catalog = ObjectCatalog.byId(object.catalogId);
      final mount = catalog.id == object.catalogId
          ? catalog.mount
          : CatalogMount.floor;
      if (mount != CatalogMount.floor) continue;

      final width = math.max(28.0, object.widthMm * _mmToPx + 14);
      final depth = math.max(28.0, object.depthMm * _mmToPx + 14);
      final center = _origin + Offset(
        object.xMm * _mmToPx,
        object.yMm * _mmToPx,
      );
      yield Positioned(
        key: ValueKey('direct-object:${object.id}'),
        left: center.dx - width / 2,
        top: center.dy - depth / 2,
        width: width,
        height: depth,
        child: Transform.rotate(
          angle: object.rotationDeg * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => setState(() {
              _dragObjectId = object.id;
              _dragObjectDirty = false;
            }),
            onPanUpdate: (details) => _movePlanObject(object, details),
            onPanEnd: (_) => _finishObjectDrag(),
            onPanCancel: _finishObjectDrag,
            child: const SizedBox.expand(),
          ),
        ),
      );
    }
  }

  void _syncGroupedFloorOffsets(RoomMaterialSettings source) {
    if (floor.carpetRoomIds.isEmpty) return;
    for (final meta in floor.roomMetas) {
      if (!floor.carpetRoomIds.contains(meta.id) ||
          identical(meta.materials, source)) {
        continue;
      }
      final target = meta.materials;
      target.laminateOffsetXMm = source.laminateOffsetXMm;
      target.laminateOffsetYMm = source.laminateOffsetYMm;
      target.tileOffsetXMm = source.tileOffsetXMm;
      target.tileOffsetYMm = source.tileOffsetYMm;
    }
  }

  void _moveFloorLayout(
    RoomMaterialSettings settings,
    DragUpdateDetails details,
  ) {
    PlanDirectInteraction.shiftFloorLayout(
      settings,
      worldDxMm: details.delta.dx / _mmToPx,
      worldDyMm: details.delta.dy / _mmToPx,
    );
    _syncGroupedFloorOffsets(settings);
    _layoutDragDirty = true;
    setState(() {});
  }

  Future<void> _finishLayoutDrag() async {
    if (!_layoutDragDirty) return;
    _layoutDragDirty = false;
    await _changed();
  }

  Widget? _layoutDragRegion() {
    if (!_materialPickMode || _materialCategory != 'Пол') return null;
    final face = _selectedRoomFace;
    final meta = _selectedRoomMeta;
    if (face == null || meta == null || face.innerPolygon.length < 3) return null;

    final points = face.innerPolygon
        .map(
          (point) => _origin + Offset(
            point.x * _mmToPx,
            point.y * _mmToPx,
          ),
        )
        .toList(growable: false);
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final local = points
        .map((point) => point - Offset(minX, minY))
        .toList(growable: false);

    return Positioned(
      left: minX,
      top: minY,
      width: math.max(1.0, maxX - minX),
      height: math.max(1.0, maxY - minY),
      child: ClipPath(
        clipper: _RoomDragClipper(local),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => _layoutDragDirty = false,
          onPanUpdate: (details) => _moveFloorLayout(meta.materials, details),
          onPanEnd: (_) => _finishLayoutDrag(),
          onPanCancel: _finishLayoutDrag,
          child: const SizedBox.expand(),
        ),
      ),
    );
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
    final scale = math.min(
      2.8,
      math.max(.35, math.min(usableW / widthPx, usableH / heightPx) * .96),
    );
    final center = _origin +
        Offset((minX + maxX) * .5 * _mmToPx, (minY + maxY) * .5 * _mmToPx);
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
    if (_materialPickMode) {
      final face = _roomAt(p);
      setState(() {
        _selectedRoomFaceKey = face?.key;
        _selectedWallId = null;
      });
      if (face == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 900),
            content: Text('Нажмите внутри замкнутого помещения.'),
          ),
        );
      }
      return;
    }

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
    if (math.Point(point.x - start.xMm, point.y - start.yMm).magnitude < 120) {
      return;
    }
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
    wall.openings.add(
      WallOpening(
        id: 'o-${DateTime.now().microsecondsSinceEpoch}',
        type: OpeningType.door,
        widthMm: width,
        heightMm: 2100,
        offsetFromStartMm: (length - width) / 2,
        doorSwing: DoorSwing.leftIn,
      ),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить'),
              ),
            ),
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
    setState(
      () => _selectedWallId = floor.walls.isEmpty ? null : floor.walls.first.id,
    );
    await _changed();
  }

  void _selectTool(ZMeasureTool tool) {
    if (tool == ZMeasureTool.objects) {
      widget.onOpenObjects();
      return;
    }
    setState(() {
      _materialPickMode = false;
      _tool = tool;
      _wallStartNodeId = null;
      _dimensionStartNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = _selectedRoomMeta;
    return ColoredBox(
      color: ZamerColors.background,
      child: Column(
        children: [
          Expanded(child: _canvas()),
          if (_selectedWall != null)
            _WallInspector(
              wall: _selectedWall!,
              floor: floor,
              onEdit: _editWall,
              onDelete: _deleteWall,
            ),
          _MaterialPanel(
            category: _materialCategory,
            selectedRoomName: room?.name,
            selectedMaterialId: _selectedMaterialId,
            selectionMode: _materialPickMode,
            expanded: _materialsExpanded,
            onToggle: () => setState(
              () => _materialsExpanded = !_materialsExpanded,
            ),
            onCategory: _selectMaterialCategory,
            onApply: _applyMaterial,
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
                  child: Stack(
                    children: [
                      GestureDetector(
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
                      if (_layoutDragRegion() case final region?) region,
                      ..._objectDragRegions(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: _ToolRail(
                  tool: _tool,
                  materialMode: _materialPickMode,
                  onRoomMode: _selectRoomMode,
                  onTool: _selectTool,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: _ViewRail(
                  grid: _grid,
                  snapping: _snapping,
                  onGrid: () => setState(() => _grid = !_grid),
                  onSnap: () => setState(() => _snapping = !_snapping),
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

class _RoomDragClipper extends CustomClipper<Path> {
  const _RoomDragClipper(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _RoomDragClipper oldClipper) =>
      oldClipper.points != points;
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({
    required this.tool,
    required this.materialMode,
    required this.onRoomMode,
    required this.onTool,
  });
  final ZMeasureTool tool;
  final bool materialMode;
  final VoidCallback onRoomMode;
  final ValueChanged<ZMeasureTool> onTool;

  @override
  Widget build(BuildContext context) => _RailFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailItem(
              icon: Icons.meeting_room_outlined,
              label: 'Помещение',
              selected: materialMode,
              onTap: onRoomMode,
            ),
            const Divider(height: 7, color: ZamerColors.outlineSoft),
            for (final item in ZMeasureTool.values)
              if (item != ZMeasureTool.objects)
                _RailItem(
                  icon: item.icon,
                  label: item.label,
                  selected: !materialMode && tool == item,
                  onTap: () => onTool(item),
                ),
          ],
        ),
      );
}

class _ViewRail extends StatelessWidget {
  const _ViewRail({
    required this.grid,
    required this.snapping,
    required this.onGrid,
    required this.onSnap,
  });
  final bool grid;
  final bool snapping;
  final VoidCallback onGrid;
  final VoidCallback onSnap;

  @override
  Widget build(BuildContext context) => _RailFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailItem(
              icon: Icons.grid_4x4_rounded,
              label: 'Сетка',
              selected: false,
              activeDot: grid,
              onTap: onGrid,
            ),
            _RailItem(
              icon: Icons.link_rounded,
              label: 'Привязка',
              selected: false,
              activeDot: snapping,
              onTap: onSnap,
            ),
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
                        style: TextStyle(
                          color: fg,
                          fontSize: 6.7,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeDot)
                  Positioned(
                    right: 3,
                    top: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: ZamerColors.accent,
                        shape: BoxShape.circle,
                      ),
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

class _UndoRedo extends StatelessWidget {
  const _UndoRedo({required this.onUndo, required this.onRedo});
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF07171D).withValues(alpha: .95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
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
        child: InkWell(
          onTap: tap,
          child: SizedBox(
            width: 31,
            height: 28,
            child: Icon(icon, size: 16, color: ZamerColors.textSecondary),
          ),
        ),
      );
}

class _CanvasControls extends StatelessWidget {
  const _CanvasControls({
    required this.floor,
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });
  final FloorPlan floor;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _small(Icons.remove_rounded, onZoomOut),
              const SizedBox(width: 5),
              _small(Icons.add_rounded, onZoomIn),
            ],
          ),
          const SizedBox(height: 5),
          _small(Icons.fullscreen_rounded, onFit),
          const SizedBox(height: 5),
          InkWell(
            onTap: onFit,
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF07171D).withValues(alpha: .96),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZamerColors.outlineSoft),
              ),
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
          decoration: BoxDecoration(
            color: const Color(0xFF07171D).withValues(alpha: .96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
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
    Offset p(PlanNode n) =>
        Offset(2 + (n.xMm - minX) * s, 2 + (n.yMm - minY) * s);
    final paint = Paint()
      ..color = const Color(0xFFD8DFE0)
      ..strokeWidth = 1.1;
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
  const _WallInspector({
    required this.wall,
    required this.floor,
    required this.onEdit,
    required this.onDelete,
  });
  final PlanWall wall;
  final FloorPlan floor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
        decoration: BoxDecoration(
          color: const Color(0xFF07171D),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ZamerColors.outlineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF102129),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: ZamerColors.outlineSoft),
              ),
              child: const CustomPaint(painter: _WallPreviewPainter()),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 21,
                    child: Row(
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'Действия со стеной',
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          iconColor: ZamerColors.textSecondary,
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Изменить стену'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить стену'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _metric(
                          'Длина',
                          '${floor.wallLengthMm(wall).round()} мм',
                          locked: true,
                        ),
                        _metric('Угол', '${_angle.round()}°'),
                        _metric('Толщина', '${wall.thicknessMm.round()} мм'),
                        _metric(
                          'Высота',
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

  Widget _metric(String label, String value, {bool locked = false}) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2028),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: ZamerColors.textMuted,
                  fontSize: 6.7,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (locked)
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 9,
                      color: ZamerColors.textMuted,
                    ),
                ],
              ),
            ],
          ),
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
    final p = Path()
      ..moveTo(12, 12)
      ..lineTo(size.width - 10, 5)
      ..lineTo(size.width - 10, size.height - 10)
      ..lineTo(12, size.height - 4)
      ..close();
    canvas.drawPath(p, front);
    canvas.drawPath(
      Path()
        ..moveTo(6, 17)
        ..lineTo(12, 12)
        ..lineTo(12, size.height - 4)
        ..lineTo(6, size.height - 10)
        ..close(),
      side,
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, 17)
        ..lineTo(12, 12)
        ..lineTo(size.width - 10, 5)
        ..lineTo(size.width - 16, 10)
        ..close(),
      top,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MaterialPanel extends StatelessWidget {
  const _MaterialPanel({
    required this.category,
    required this.selectedRoomName,
    required this.selectedMaterialId,
    required this.selectionMode,
    required this.expanded,
    required this.onToggle,
    required this.onCategory,
    required this.onApply,
    required this.onOpenMaterials,
  });

  final String category;
  final String? selectedRoomName;
  final String? selectedMaterialId;
  final bool selectionMode;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onCategory;
  final ValueChanged<VisualMaterialPreset> onApply;
  final VoidCallback onOpenMaterials;

  static const _categories = ['Пол', 'Стены'];

  List<VisualMaterialPreset> get _materials =>
      category == 'Пол'
          ? MaterialCatalog.floorFinishes
          : MaterialCatalog.wallFinishes;

  @override
  Widget build(BuildContext context) {
    final materials = _materials;
    final roomLabel = selectedRoomName == null
        ? 'Нажмите на помещение на плане'
        : 'Помещение: $selectedRoomName';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: expanded ? 132 : 38,
      margin: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF07171D),
        borderRadius: BorderRadius.circular(9),
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
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: () => onCategory(item),
                          borderRadius: BorderRadius.circular(6),
                          child: Center(
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                color: item == category
                                    ? ZamerColors.accentInk
                                    : ZamerColors.textSecondary,
                                fontSize: 8.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: expanded ? 'Скрыть материалы' : 'Показать материалы',
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 30,
                  ),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) SizedBox(
            height: 19,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                children: [
                  Icon(
                    selectedRoomName == null
                        ? Icons.touch_app_outlined
                        : Icons.check_circle_rounded,
                    size: 11,
                    color: selectedRoomName == null
                        ? ZamerColors.textMuted
                        : ZamerColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      roomLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectionMode
                            ? ZamerColors.textPrimary
                            : ZamerColors.textMuted,
                        fontSize: 7.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onOpenMaterials,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 11,
                        color: ZamerColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(5, 1, 5, 5),
              scrollDirection: Axis.horizontal,
              itemCount: materials.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final material = materials[index];
                return _MaterialCard(
                  material: material,
                  onTap: () => onApply(material),
                  selected: material.id == selectedMaterialId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onTap,
    required this.selected,
  });
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
          decoration: BoxDecoration(
            color: const Color(0xFF0B1D24),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: material.color,
                    borderRadius: BorderRadius.circular(5),
                    image: material.textureAsset == null
                        ? null
                        : DecorationImage(
                            image: AssetImage(material.textureAsset!),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                material.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? ZamerColors.textPrimary
                      : ZamerColors.textSecondary,
                  fontSize: 6.5,
                  height: 1.05,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
}
