import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/wall_drawing_service.dart';
import '../services/wall_length_edit_service.dart';
import '../services/room_interior_dimensions_service.dart';
import '../services/material_catalog.dart';
import '../services/object_catalog.dart';
import '../services/plan_direct_interaction.dart';
import '../services/orthogonal_wall_edit_service.dart';
import '../services/node_move_constraint_service.dart';
import '../services/opening_alignment_service.dart';
import '../services/plan_visibility_service.dart';
import 'measure_plan_tool.dart';
import '../services/space_check_service.dart';
import '../services/plan_viewport_link.dart';
import '../widgets/cad_plan_painter.dart';
import '../widgets/wall_draft_guide_painter.dart';

/// UI KIT 02 production editor rebuilt around the approved portrait concept.
/// +80 adds direct room selection and one-tap material application.
class PlanEditorMasterV4Screen extends StatefulWidget {
  const PlanEditorMasterV4Screen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.planTool = MeasurePlanTool.overview,
    this.preferredOpeningType,
    this.onSelectionChanged,
    this.nativeKitV2 = false,
    this.sharedViewport,
    this.viewportActive = true,
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
  final MeasurePlanTool planTool;
  final OpeningType? preferredOpeningType;
  final ValueChanged<String?>? onSelectionChanged;
  final bool nativeKitV2;
  final ValueNotifier<PlanViewportSnapshot?>? sharedViewport;
  final bool viewportActive;
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
  // Extended virtual CAD plane: no more short viewport edges cutting off
  // a 30–100 m run. Grid rendering is clipped to the visible camera region.
  static const _canvasSize = Size(32000, 32000);
  Offset _origin = const Offset(16000, 16000);
  static const _mmToPx = .10;

  final TransformationController _transform = TransformationController();
  final Set<ProjectLayer> _visibleLayers = ProjectLayer.values.toSet();
  final Set<PlanDisplayLayer> _visibleCategories = PlanDisplayLayer.values.toSet()
    ..remove(PlanDisplayLayer.axisDimensions)
    ..remove(PlanDisplayLayer.dimensions);
  final Set<PlanCollisionKind> _collisionKinds = PlanCollisionKind.values.toSet();

  ZMeasureTool _tool = ZMeasureTool.walls;
  String? _selectedWallId;
  String? _selectedNodeId;
  String? _dragNodeId;
  FloorPlan? _nodeDragStartFloor;
  Set<String> _nodeDragAffected = <String>{};
  String? _nodeDragInvalid;
  NodeSnapResult? _dragSnap;
  math.Point<double> _fingerNodeOffsetMm = const math.Point(0, 0);
  bool _nodeDragChanged = false;
  int _angleSnapDegrees = 90;
  double _lastWallAngleDegrees = 0;
  String? _lastWallSnapLabel;
  WallDrawingTarget? _liveWallSnap;
  bool _showLiveWallFaces = true;
  bool _captureWallFace = true;
  // Drawing and viewport navigation are mutually exclusive. This prevents
  // accidental camera shifts while placing a wall on a phone.
  bool _moveCameraInsteadOfDrawing = false;
  Timer? _edgePanTimer;
  final Set<int> _activeCanvasPointers = <int>{};
  bool _pinchInProgress = false;
  int? _wallPointerId;
  Offset? _wallPointerStartGlobal;
  Offset? _wallPointerViewport;
  bool _wallPointerDragging = false;
  String? _dragOpeningWallId;
  String? _dragOpeningId;
  String? _selectedOpeningWallId;
  String? _selectedOpeningId;
  double _openingGrabOffsetMm = 0;
  bool _openingDragDirty = false;
  String? _openingSnapHint;
  String? _dragWallId;
  double _dragWallOffsetMm = 0;
  bool _dragWallModified = false;
  String? _dragWallRejected;
  Matrix4? _dragWallBaseTransform;
  FloorPlan? _dragWallStartFloor;
  math.Point<double>? _dragWallStartMm;
  ProjectLayer _drawingLayer = ProjectLayer.existing;
  String? _selectedRoomFaceKey;
  String? _wallStartNodeId;
  String? _wallChainFirstNodeId;
  int _wallChainSegments = 0;
  String? _dimensionStartNodeId;
  math.Point<double>? _dimensionStartInterior;
  String? _dimensionStartInteriorNodeId;
  bool _measureRoomInterior = true;
  String? _dragObjectId;
  String? _selectedObjectId;
  Offset? _lastObjectDragGlobal;
  bool _dragObjectBlocked = false;
  bool _dragObjectDirty = false;
  bool _layoutDragDirty = false;
  bool _materialsExpanded = false;
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
    _materialPickMode = widget.planTool == MeasurePlanTool.overview;
  }

  @override
  void didUpdateWidget(covariant PlanEditorMasterV4Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewportActive && (!oldWidget.viewportActive ||
        oldWidget.sharedViewport != widget.sharedViewport)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _adoptViewport());
    }
    if (oldWidget.planTool != widget.planTool) {
      // Tool changes also cancel uncommitted gestures. Without rollback,
      // linked nodes and door/socket offsets could be left half-dragged.
      final unfinishedDrag = _nodeDragStartFloor ?? _dragWallStartFloor;
      if (unfinishedDrag != null) floor.restoreFrom(unfinishedDrag);
      // Switching tools must not continue an unfinished wall/arc, dimension,
      // or vertex drag on the same shared canvas.
      _wallStartNodeId = null;
      _wallChainFirstNodeId = null;
      _wallChainSegments = 0;
      _lastWallSnapLabel = null;
      _liveWallSnap = null;
      _moveCameraInsteadOfDrawing = false;
      _stopEdgePan();
      _dimensionStartNodeId = null;
      _dimensionStartInterior = null;
      _dimensionStartInteriorNodeId = null;
      _dragNodeId = null;
      _nodeDragStartFloor = null;
      _nodeDragAffected.clear();
      _nodeDragInvalid = null;
      _dragSnap = null;
      _nodeDragChanged = false;
      _selectedNodeId = null;
      _selectedWallId = null;
      _dragWallId = null;
      _dragOpeningWallId = null;
      _dragOpeningId = null;
      _selectedOpeningWallId = null;
      _selectedOpeningId = null;
      _dragWallStartMm = null;
      _dragWallStartFloor = null;
      _dragWallBaseTransform = null;
      _dragWallOffsetMm = 0;
      _dragWallModified = false;
      _dragWallRejected = null;
      _materialPickMode = widget.planTool == MeasurePlanTool.overview;
      _materialsExpanded = false;
    }
  }

  @override
  void dispose() {
    _stopEdgePan();
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
      _wallChainFirstNodeId = null;
      _wallChainSegments = 0;
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
      _wallChainFirstNodeId = null;
      _wallChainSegments = 0;
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
      if (!_visibleCategories.contains(PlanDisplayLayer.walls) ||
          !_visibleLayers.contains(
            wall.demolition ? ProjectLayer.demolition : wall.projectLayer,
          ) || wall.isCurved) continue;
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
    final previousGlobal = _lastObjectDragGlobal;
    _lastObjectDragGlobal = details.globalPosition;
    if (previousGlobal == null) return;
    final screenDelta = details.globalPosition - previousGlobal;
    final oldX = object.xMm;
    final oldY = object.yMm;
    PlanDirectInteraction.moveObjectByMm(
      object,
      // Local delta is rotated by the hit target and affected by zoom.
      // Global screen delta divided by zoom follows the user's finger.
      dxMm: screenDelta.dx / (_mmToPx * _scale),
      dyMm: screenDelta.dy / (_mmToPx * _scale),
      snapMm: _snapping ? 10 : 0,
    );
    if (SpaceCheckService.intersectsWall(floor, object)) {
      object.xMm = oldX;
      object.yMm = oldY;
      _dragObjectBlocked = true;
    } else if (object.xMm != oldX || object.yMm != oldY) {
      _dragObjectBlocked = false;
      _dragObjectDirty = true;
    }
    setState(() {});
  }

  Future<void> _finishObjectDrag() async {
    if (_dragObjectId == null) return;
    final changed = _dragObjectDirty;
    setState(() {
      _dragObjectId = null;
      _lastObjectDragGlobal = null;
      _dragObjectBlocked = false;
      _dragObjectDirty = false;
    });
    if (changed) await _changed();
  }

  Iterable<Widget> _objectDragRegions() sync* {
    for (final object in floor.planObjects) {
      if (!_visibleLayers.contains(object.layer) ||
          !_visibleCategories.contains(switch (object.type) {
            PlanObjectType.furniture => PlanDisplayLayer.furniture,
            PlanObjectType.sanitary || PlanObjectType.waterPoint ||
            PlanObjectType.drainPoint => PlanDisplayLayer.sanitary,
            PlanObjectType.radiator => PlanDisplayLayer.engineering,
            PlanObjectType.lighting => PlanDisplayLayer.electrical,
            _ => PlanDisplayLayer.structures,
          })) continue;
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
            onTap: () => setState(() => _selectedObjectId = object.id),
            onPanStart: (details) => setState(() {
              _selectedObjectId = object.id;
              _dragObjectId = object.id;
              _lastObjectDragGlobal = details.globalPosition;
              _dragObjectBlocked = false;
              _dragObjectDirty = false;
            }),
            onPanUpdate: (details) => _movePlanObject(object, details),
            onPanEnd: (_) => _finishObjectDrag(),
            onPanCancel: _finishObjectDrag,
            child: Container(
              decoration: BoxDecoration(
                color: _selectedObjectId == object.id
                    ? ZamerColors.accent.withValues(alpha: .065)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: _selectedObjectId == object.id
                    ? Border.all(
                        color: _dragObjectBlocked
                            ? ZamerColors.danger : ZamerColors.accent,
                        width: 1.5 / _scale,
                      )
                    : null,
              ),
            ),
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


  void _publishViewport() {
    if (!widget.viewportActive) return;
    final link = widget.sharedViewport;
    if (link == null) return;
    final snapshot = PlanViewportSnapshot.capture(
      viewport: _viewport, origin: _origin,
      mmToPx: _mmToPx, transform: _transform.value);
    if (snapshot == null) return;
    if (link.value case final existing?) {
      if (snapshot.nearlyEquals(existing)) return;
    }
    link.value = snapshot;
  }

  void _adoptViewport() {
    if (!mounted || !widget.viewportActive || _viewport.isEmpty) return;
    final saved = widget.sharedViewport?.value;
    if (saved == null) return;
    final matrix = saved.toCanvasTransform(
      viewport: _viewport, origin: _origin,
      mmToPx: _mmToPx, minScale: .28, maxScale: 6);
    if (matrix == null) return;
    _transform.value = matrix;
    setState(() => _centered = true);
  }

  void _fit() {
    if (_viewport.isEmpty) return;
    if (floor.nodes.isEmpty) {
      final center = Offset(_viewport.width / 2, _viewport.height / 2);
      _transform.value = Matrix4.identity()
        ..translate(center.dx - _origin.dx,
            center.dy - _origin.dy);
      if (mounted) setState(() {});
      _publishViewport();
      return;
    }
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
    _publishViewport();
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
    _publishViewport();
  }

  // In Select mode a one-finger drag starting on an eligible straight wall
  // translates both endpoints together. An empty-space gesture still pans
  // the viewport; a two-finger gesture always remains a normal zoom.
  void _wallDragStart(ScaleStartDetails details) {
    if (widget.planTool != MeasurePlanTool.select ||
        details.pointerCount != 1) return;
    final point = _transform.toScene(details.localFocalPoint);
    final wall = _wallNear(point);
    if (wall == null || !OrthogonalWallEditService.preview(
      floor, wallId: wall.id, offsetMm: 0,
    ).isValid) return;
    setState(() {
      _selectedWallId = wall.id;
      _dragWallId = wall.id;
      _dragWallStartMm = _toMm(point);
      _dragWallBaseTransform = Matrix4.copy(_transform.value);
      _dragWallStartFloor = FloorPlan.fromJson(floor.toJson());
      _dragWallOffsetMm = 0;
      _dragWallModified = false;
      _dragWallRejected = null;
    });
  }

  void _wallDragUpdate(ScaleUpdateDetails details) {
    final id = _dragWallId;
    final originMm = _dragWallStartMm;
    final base = _dragWallBaseTransform;
    if (id == null || originMm == null || base == null) return;
    if (details.pointerCount != 1) {
      _wallDragCancel();
      return;
    }
    // InteractiveViewer updates its matrix as part of the same gesture.
    // Undo ONLY that camera pan while an actual wall is being dragged.
    _transform.value = Matrix4.copy(base);
    final touch = _toMm(_transform.toScene(details.localFocalPoint));
    final wall = floor.wallById(id);
    if (wall == null) return;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final vertical = (a.xMm - b.xMm).abs() < .5;
    final horizontal = (a.yMm - b.yMm).abs() < .5;
    if (!vertical && !horizontal) return;

    // Only the normal direction moves the wall; length and right angles
    // remain constrained by OrthogonalWallEditService.
    final rawOffset = vertical
        ? touch.x - originMm.x : touch.y - originMm.y;
    final step = _snapping ? 10.0 : 1.0;
    final wanted = (rawOffset / step).round() * step;
    final change = wanted - _dragWallOffsetMm;
    if (change.abs() < .01) {
      // The user moved back into the last valid position: clear a previously
      // rejected preview rather than incorrectly cancelling on release.
      if (_dragWallRejected != null) {
        setState(() => _dragWallRejected = null);
      }
      return;
    }
    final result = OrthogonalWallEditService.move(
      floor, wallId: id, offsetMm: change,
    );
    if (!result.isValid) {
      setState(() => _dragWallRejected = result.message);
      return;
    }
    _dragWallOffsetMm = wanted;
    _dragWallRejected = null;
    _dragWallModified = true;
    setState(() {});
  }

  // Cancelled multi-touch and invalid releases must preserve the exact
  // original project, including door offsets and wall-attached devices.
  void _wallDragCancel() {
    final before = _dragWallStartFloor;
    if (before != null) floor.restoreFrom(before);
    setState(() {
      _dragWallId = null;
      _dragWallStartFloor = null;
      _dragWallBaseTransform = null;
      _dragWallStartMm = null;
      _dragWallModified = false;
      _dragWallRejected = null;
      _dragWallOffsetMm = 0;
    });
  }

  Future<void> _wallDragFinish() async {
    if (_dragWallId == null) return;
    final changed = _dragWallModified;
    final rejected = _dragWallRejected;
    final before = _dragWallStartFloor;
    if (rejected != null && before != null) {
      floor.restoreFrom(before);
    }
    setState(() {
      _dragWallId = null;
      _dragWallStartFloor = null;
      _dragWallBaseTransform = null;
      _dragWallStartMm = null;
      _dragWallModified = false;
      _dragWallRejected = null;
      _dragWallOffsetMm = 0;
    });
    if (rejected != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 2200),
          content: Text('Перемещение стены отменено: $rejected'),
        ));
      }
      return;
    }
    if (changed) await _changed(); // single undo/history snapshot per drag
  }

  Future<void> _tapCanvas(TapUpDetails details) async {
    // A tap in the deliberate navigation mode must never create a wall.
    if (_moveCameraInsteadOfDrawing) return;
    final p = details.localPosition;
    // Direct interaction on the same production CAD viewport. A tool change
    // never navigates to an alternate floor-plan canvas.
    if (widget.planTool != MeasurePlanTool.overview) {
      switch (widget.planTool) {
        case MeasurePlanTool.select:
          setState(() {
            _selectedWallId = _wallNear(p)?.id;
            _selectedNodeId = _nodeNear(p)?.id;
          });
          widget.onSelectionChanged?.call(_selectedWallId != null
              ? 'wall' : _selectedNodeId != null ? 'node' : null);
        case MeasurePlanTool.nodes:
          setState(() {
            _selectedNodeId = _nodeNear(p)?.id;
            _selectedWallId = null;
          });
          widget.onSelectionChanged?.call(
              _selectedNodeId != null ? 'node' : null);
        case MeasurePlanTool.exterior:
          await _createWall(p, type: WallType.exterior);
        case MeasurePlanTool.partition:
          await _createWall(p, type: WallType.partition);
        case MeasurePlanTool.arc:
        case MeasurePlanTool.precision:
          await _createArc(p);
        case MeasurePlanTool.openings:
          final hit = _openingNear(p);
          if (hit != null) {
            final alreadySelected =
                _selectedOpeningWallId == hit.wall.id &&
                _selectedOpeningId == hit.opening.id;
            setState(() {
              _selectedOpeningWallId = hit.wall.id;
              _selectedOpeningId = hit.opening.id;
            });
            widget.onSelectionChanged?.call(
              hit.opening.type == OpeningType.door ? 'door' : 'window');
            // Second tap opens the full numeric editor. The first tap shows
            // only the compact, anchored inspector.
            if (alreadySelected) await _editOpening(hit.wall, hit.opening);
          } else {
            setState(() {
              _selectedOpeningWallId = null;
              _selectedOpeningId = null;
            });
            widget.onSelectionChanged?.call(null);
            await _addOpening(p,
              chooseType: widget.preferredOpeningType == null);
          }
        case MeasurePlanTool.demolition:
          await _toggleDemolition(p);
        case MeasurePlanTool.dimensions:
          await _addDimension(p);
        case MeasurePlanTool.overview:
          break;
      }
      return;
    }
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

  WallDrawingTarget _snapDrawTarget(
    PlanNode start,
    math.Point<double> raw,
  ) => WallDrawingService.snap(
    floor,
    startNodeId: start.id,
    raw: raw,
    enabled: _snapping,
    angleStepDegrees: _angleSnapDegrees,
    nodeCaptureMm: 14 / (_mmToPx * _scale),
    wallCaptureMm: 12 / (_mmToPx * _scale),
    allowWallFaces: _captureWallFace,
    previousSnap: _liveWallSnap,
    priorityNodeId: _wallChainSegments >= 2
        ? _wallChainFirstNodeId : null,
  );

  // Listener is passive: it never claims a gesture. Navigation is only
  // possible when the user explicitly selects the hand control. The draft
  // uses the same WallDrawingService.snap() result as the committed segment.
  void _stopEdgePan() {
    _edgePanTimer?.cancel();
    _edgePanTimer = null;
    _wallPointerId = null;
    _wallPointerViewport = null;
    _wallPointerStartGlobal = null;
    _wallPointerDragging = false;
  }

  void _wallPointerDown(PointerDownEvent event) {
    _activeCanvasPointers.add(event.pointer);
    if (_activeCanvasPointers.length > 1) {
      // Two fingers zoom without committing a phantom wall segment or
      // dragging any active CAD node by the second finger.
      _pinchInProgress = true;
      _stopEdgePan();
      if (_dragNodeId != null) _nodeDragCancel();
      return;
    }
    if (_pinchInProgress ||
        !_drawingWall || _moveCameraInsteadOfDrawing ||
        (widget.planTool != MeasurePlanTool.exterior &&
         widget.planTool != MeasurePlanTool.partition) ||
        _wallStartNodeId == null || _wallPointerId != null) return;
    _wallPointerId = event.pointer;
    _wallPointerStartGlobal = event.position;
    _wallPointerViewport = MatrixUtils.transformPoint(
      _transform.value, event.localPosition,
    );
    _wallPointerDragging = false;
    _updateLiveWallGuide(event);
  }

  void _wallPointerMove(PointerMoveEvent event) {
    if (_pinchInProgress) return;
    if (_wallPointerId != null && event.pointer != _wallPointerId) return;
    _updateLiveWallGuide(event);
    if (event.pointer != _wallPointerId || _wallPointerStartGlobal == null ||
        !_drawingWall || _moveCameraInsteadOfDrawing) return;
    _wallPointerViewport = MatrixUtils.transformPoint(
      _transform.value, event.localPosition,
    );
    if ((event.position - _wallPointerStartGlobal!).distance > 9) {
      _wallPointerDragging = true;
    }
    if (_wallPointerDragging && _edgePanTimer == null) {
      _edgePanTimer = Timer.periodic(
        const Duration(milliseconds: 30), (_) => _edgePanTick(),
      );
    }
  }

  void _edgePanTick() {
    final pos = _wallPointerViewport;
    if (!mounted || pos == null || !_wallPointerDragging ||
        !_drawingWall || _moveCameraInsteadOfDrawing || _viewport.isEmpty) {
      _edgePanTimer?.cancel();
      _edgePanTimer = null;
      return;
    }
    // An extended edge band avoids the old premature slowdown; speed
    // continues ramping up as the finger approaches or passes the edge.
    const margin = 105.0;
    const speed = 22.0;
    double velocity(double coordinate, double extent) {
      if (coordinate < margin) {
        return speed * ((margin - coordinate) / margin).clamp(0.0, 1.0);
      }
      if (coordinate > extent - margin) {
        return -speed *
            ((coordinate - (extent - margin)) / margin).clamp(0.0, 1.0);
      }
      return 0;
    }
    final dx = velocity(pos.dx, _viewport.width);
    final dy = velocity(pos.dy, _viewport.height);
    if (dx == 0 && dy == 0) return;
    final matrix = Matrix4.copy(_transform.value);
    matrix.storage[12] += dx;
    matrix.storage[13] += dy;
    _transform.value = matrix;
    _rebaseSceneAt(pos);
    _updateWallGuideAt(_transform.toScene(pos));
  }

  // Rebase CAD scene coordinates when an edge-drawn wall approaches the
  // finite Flutter canvas. Changing the origin and compensating the camera
  // by exactly zoom*shift preserves every saved millimetre coordinate and
  // the wall endpoint under the user's finger. Panning can continue across
  // successive virtual tiles without changing the saved floor geometry.
  void _rebaseSceneAt(Offset viewportPoint) {
    final scene = _transform.toScene(viewportPoint);
    const low = 6000.0, high = 26000.0, step = 12000.0;
    final shiftX = scene.dx < low ? step : scene.dx > high ? -step : 0.0;
    final shiftY = scene.dy < low ? step : scene.dy > high ? -step : 0.0;
    if (shiftX == 0 && shiftY == 0) return;
    final delta = Offset(shiftX, shiftY);
    final zoom = _scale;
    final matrix = Matrix4.copy(_transform.value);
    matrix.storage[12] -= delta.dx * zoom;
    matrix.storage[13] -= delta.dy * zoom;
    _origin += delta;
    _transform.value = matrix;
    if (mounted) setState(() {});
  }

  void _wallPointerCancel(PointerCancelEvent event) {
    _activeCanvasPointers.remove(event.pointer);
    if (event.pointer == _wallPointerId) _stopEdgePan();
    if (_activeCanvasPointers.isEmpty) _pinchInProgress = false;
  }

  void _wallPointerUp(PointerEvent event) {
    _activeCanvasPointers.remove(event.pointer);
    if (_pinchInProgress) {
      if (_activeCanvasPointers.isEmpty) _pinchInProgress = false;
      return;
    }
    if (event.pointer != _wallPointerId) return;
    final endViewport = _wallPointerViewport;
    final shouldCommit = _wallPointerDragging && _wallStartNodeId != null &&
        _drawingWall && !_moveCameraInsteadOfDrawing && endViewport != null;
    final target = endViewport == null ? null :
        _transform.toScene(endViewport);
    _stopEdgePan();
    // Edge auto-pan moves the CAD camera outside InteractiveViewer gestures.
    // Publish its final position, otherwise switching to Floor resets zoom.
    _publishViewport();
    if (shouldCommit && target != null) {
      unawaited(_createWall(
        target,
        type: widget.planTool == MeasurePlanTool.exterior
            ? WallType.exterior : WallType.partition,
      ));
    }
  }

  void _updateLiveWallGuide(PointerEvent event) {
    _updateWallGuideAt(event.localPosition);
  }

  void _updateWallGuideAt(Offset canvasPosition) {
    if (_moveCameraInsteadOfDrawing || !_drawingWall ||
        (widget.planTool != MeasurePlanTool.exterior &&
         widget.planTool != MeasurePlanTool.partition) ||
        _wallStartNodeId == null) return;
    final start = floor.nodeById(_wallStartNodeId!);
    if (start == null) return;
    final raw = _toMm(canvasPosition);
    final snap = _snapDrawTarget(start, raw);
    final previous = _liveWallSnap;
    if (previous != null &&
        previous.kind == snap.kind &&
        previous.targetNodeId == snap.targetNodeId &&
        previous.targetWallId == snap.targetWallId &&
        previous.facePoint == snap.facePoint &&
        WallDrawingService.distance(previous.point, snap.point) < 2) {
      return;
    }
    setState(() {
      _liveWallSnap = snap;
      _lastWallSnapLabel = snap.label;
    });
  }

  /// Compact drafting HUD: feedback comes from the exact same captured
  /// point that will be committed, not from a decorative cursor overlay.
  Widget _liveSnapHud() {
    final start = floor.nodeById(_wallStartNodeId ?? '');
    final snap = _liveWallSnap;
    if (start == null || snap == null) return const SizedBox.shrink();
    final dx = snap.point.x - start.xMm;
    final dy = snap.point.y - start.yMm;
    final lengthMm = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    final closesOutline = _wallChainSegments >= 2 &&
        snap.targetNodeId == _wallChainFirstNodeId &&
        snap.targetNodeId != null;
    final kind = closesOutline
        ? 'Замкнуть контур' : !_snapping ? 'Без привязки' : snap.label;
    final target = snap.targetNodeId != null
        ? ' · Узел' : snap.targetWallId != null ? ' · Стена' : '';
    final kindLabel = '$kind$target';
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xED10171D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZamerColors.accent.withValues(alpha: .38)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kindLabel,
                style: const TextStyle(
                  color: ZamerColors.accent, fontSize: 11,
                  fontWeight: FontWeight.w700)),
              Text('${lengthMm.round()} мм  ·  ${angle.round()}°',
                style: const TextStyle(
                  color: ZamerColors.textPrimary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  WallDraftGuidePainter? _wallPreviewPainter() {
    final startId = _wallStartNodeId;
    final snap = _liveWallSnap;
    if (startId == null || snap == null ||
        (widget.planTool != MeasurePlanTool.exterior &&
         widget.planTool != MeasurePlanTool.partition)) return null;
    final start = floor.nodeById(startId);
    if (start == null) return null;
    final corner = _snapping ? WallDrawingService.alignedCornerAhead(
      floor, startNodeId: start.id, currentPoint: snap.point,
    ) : null;
    return WallDraftGuidePainter(
      from: _toCanvas(start),
      oppositeCorner: corner == null ? null :
          _origin + Offset(corner.x * _mmToPx, corner.y * _mmToPx),
      to: _origin + Offset(
        snap.point.x * _mmToPx,
        snap.point.y * _mmToPx,
      ),
      mmToPx: _mmToPx,
      zoom: _scale,
      wallThicknessMm: widget.planTool == MeasurePlanTool.exterior ? 300 : 100,
      snapKind: snap.kind,
      snapLabel: snap.label,
      facePoint: snap.facePoint == null ? null :
          _origin + Offset(
            snap.facePoint!.x * _mmToPx,
            snap.facePoint!.y * _mmToPx,
          ),
      drawFaces: _showLiveWallFaces,
    );
  }

  Future<void> _createWall(Offset p, {WallType type = WallType.partition}) async {
    if (_wallStartNodeId == null) {
      final snapshot = FloorPlan.fromJson(floor.toJson());
      late final PlanNode node;
      try {
        node = GeometryService.ensureAnchor(
          floor,
          _toMm(p),
          captureMm: _snapping ? 13 / (_mmToPx * _scale) : 0,
          newNodeRoundingMm: _snapping ? 5 : 0,
        );
      } on StateError catch (error) {
        floor.restoreFrom(snapshot);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message.toString())),
          );
        }
        return;
      }
      setState(() {
        _wallStartNodeId = node.id;
        _wallChainFirstNodeId = node.id;
        _wallChainSegments = 0;
        _lastWallSnapLabel = 'Начало стены';
        _liveWallSnap = null;
        _selectedWallId = null;
      });
      await _changed();
      return;
    }
    final start = floor.nodeById(_wallStartNodeId!);
    if (start == null) {
      setState(() => _wallStartNodeId = null);
      return;
    }
    final snap = _snapDrawTarget(start, _toMm(p));
    setState(() => _lastWallSnapLabel = snap.label);
    await _commitWallSegment(
      start: start,
      point: snap.point,
      type: type,
    );
  }

  Future<void> _commitWallSegment({
    required PlanNode start,
    required math.Point<double> point,
    required WallType type,
  }) async {
    final startPoint = math.Point<double>(start.xMm, start.yMm);
    final distance = WallDrawingService.distance(startPoint, point);
    if (distance < WallDrawingService.minimumLengthMm) return;
    if (distance > WallDrawingService.maximumLengthMm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Длина стены должна быть не больше 100 м')),
      );
      return;
    }
    final oldIds = floor.walls.map((w) => w.id).toSet();
    final snapshot = FloorPlan.fromJson(floor.toJson());
    final drawn = <PlanWall>[];
    late final PlanNode end;
    try {
      end = GeometryService.addWallFromNode(
        floor,
        startNodeId: start.id,
        endPoint: point,
        type: type,
        thicknessMm: type == WallType.exterior ? 300 : 100,
        material: type == WallType.exterior
            ? WallMaterial.gasBlock : WallMaterial.drywall,
        // The snap engine already chose the geometric target: do not
        // capture an unrelated node within 80 mm or round exact dimensions.
        endpointCaptureMm: .5,
        endpointRoundingMm: 0,
        newlyDrawnWalls: drawn,
      );
    } on StateError catch (error) {
      // A wall can intersect multiple hosts; if any requested split is
      // invalid, never leave a half-completed floor or detached opening.
      floor.restoreFrom(snapshot);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
      }
      return;
    }
    final changed = drawn.isNotEmpty ||
        floor.walls.any((wall) => !oldIds.contains(wall.id));
    for (final wall in drawn) {
      wall.projectLayer = _drawingLayer;
      wall.demolition = _drawingLayer == ProjectLayer.demolition;
    }
    _lastWallAngleDegrees =
        math.atan2(end.yMm - start.yMm, end.xMm - start.xMm) * 180 / math.pi;
    final closed = WallDrawingService.closesChain(
      firstNodeId: _wallChainFirstNodeId,
      endNodeId: end.id,
      completedSegments: _wallChainSegments,
      changed: changed,
    );
    setState(() {
      _wallStartNodeId = closed ? null : end.id;
      _wallChainSegments = closed ? 0 : _wallChainSegments + (changed ? 1 : 0);
      if (closed) _wallChainFirstNodeId = null;
      _lastWallSnapLabel = closed ? 'Контур замкнут' : _lastWallSnapLabel;
      _liveWallSnap = null;
      if (drawn.isNotEmpty) _selectedWallId = drawn.last.id;
    });
    if (changed) await _changed();
  }

  Future<void> _enterWallLength() async {
    final id = _wallStartNodeId;
    if (id == null) return;
    final start = floor.nodeById(id);
    if (start == null) return;

    // TextFormField owns its internal controller for its entire lifetime.
    // Disposing an external controller immediately after Navigator.pop would
    // break Flutter's outgoing bottom-sheet animation (and on-screen keyboard).
    var lengthText = '3000';
    var angleText = _lastWallAngleDegrees.round().toString();
    final values = await showModalBottomSheet<(double, double)>(
      context: context,
      backgroundColor: ZamerColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Построить стену по размеру',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('wall-build-length-mm'),
                  initialValue: lengthText,
                  onChanged: (value) => lengthText = value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Точная длина',
                    suffixText: 'мм',
                    helperText: 'Длина по оси стены от последнего узла',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('wall-build-angle-deg'),
                  initialValue: angleText,
                  onChanged: (value) => angleText = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Направление от оси X',
                    suffixText: '°',
                    helperText:
                        '0° вправо, 90° вниз, 180° влево, −90° вверх',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('wall-build-apply'),
                    onPressed: () {
                      final value = double.tryParse(
                        lengthText.trim().replaceAll(',', '.'),
                      );
                      final degrees = double.tryParse(
                        angleText.trim().replaceAll(',', '.'),
                      );
                      if (value == null ||
                          degrees == null ||
                          !value.isFinite ||
                          !degrees.isFinite ||
                          value < WallDrawingService.minimumLengthMm ||
                          value > WallDrawingService.maximumLengthMm) {
                        ScaffoldMessenger.of(sheet).showSnackBar(
                          const SnackBar(content: Text(
                            'Укажите длину 120–100000 мм и допустимый угол',
                          )),
                        );
                        return;
                      }
                      Navigator.pop(sheet, (value, degrees));
                    },
                    child: const Text('Построить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (values == null || !mounted) return;
    final point = WallDrawingService.lengthEndpoint(
      start: math.Point<double>(start.xMm, start.yMm),
      lengthMm: values.$1,
      angleDegrees: values.$2,
    );
    await _commitWallSegment(
      start: start,
      point: point,
      type: widget.planTool == MeasurePlanTool.exterior
          ? WallType.exterior : WallType.partition,
    );
    if (mounted) setState(() => _lastWallSnapLabel = 'По точному размеру');
  }

  ({PlanWall wall, WallOpening opening, double positionMm})?
      _openingNear(Offset canvasPoint) {
    final radius = 28 / _scale;
    ({PlanWall wall, WallOpening opening, double positionMm})? best;
    var bestDistance = double.infinity;
    for (final wall in floor.walls) {
      if (wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final first = _toCanvas(a), last = _toCanvas(b);
      final v = last - first;
      final lengthPx = v.distance;
      if (lengthPx < 1) continue;
      final unit = v / lengthPx;
      final projectedPx = (canvasPoint - first).dx * unit.dx +
          (canvasPoint - first).dy * unit.dy;
      final normalDistance = (canvasPoint - (first + unit * projectedPx)).distance;
      final positionMm = projectedPx / _mmToPx;
      for (final opening in wall.openings) {
        final across = math.max(
          opening.offsetFromStartMm - positionMm,
          positionMm - (opening.offsetFromStartMm + opening.widthMm),
        );
        final extraAlong = math.max(0.0, across) * _mmToPx;
        final distance = math.sqrt(
          normalDistance * normalDistance + extraAlong * extraAlong,
        );
        if (distance <= math.max(radius, wall.thicknessMm * _mmToPx / 2) &&
            distance < bestDistance) {
          best = (wall: wall, opening: opening, positionMm: positionMm);
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  bool _openingValid(PlanWall wall, WallOpening opening,
      double offset, double width) {
    final length = floor.wallLengthMm(wall);
    if (!offset.isFinite || !width.isFinite || width < 350 ||
        offset < 80 || offset + width > length - 80) return false;
    for (final other in wall.openings) {
      if (other.id == opening.id) continue;
      if (offset < other.offsetFromStartMm + other.widthMm + 30 &&
          offset + width + 30 > other.offsetFromStartMm) return false;
    }
    return true;
  }

  void _openingDragStart(DragStartDetails details) {
    final hit = _openingNear(details.localPosition);
    _dragOpeningWallId = hit?.wall.id;
    _dragOpeningId = hit?.opening.id;
    _openingGrabOffsetMm = hit == null
        ? 0 : hit.opening.offsetFromStartMm - hit.positionMm;
    _openingDragDirty = false;
    _openingSnapHint = null;
    if (hit != null) setState(() {
      _selectedWallId = hit.wall.id;
      _selectedOpeningWallId = hit.wall.id;
      _selectedOpeningId = hit.opening.id;
    });
  }

  void _openingDragUpdate(DragUpdateDetails details) {
    final wallId = _dragOpeningWallId, openingId = _dragOpeningId;
    if (wallId == null || openingId == null) return;
    final wall = floor.wallById(wallId);
    if (wall == null) return;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final opening = wall.openings.where((o) => o.id == openingId).firstOrNull;
    if (opening == null) return;
    final start = _toCanvas(a), end = _toCanvas(b);
    final v = end - start;
    if (v.distance < 1) return;
    final touch = details.localPosition - start;
    final position = (touch.dx * v.dx + touch.dy * v.dy) /
        v.distance / _mmToPx;
    final raw = position + _openingGrabOffsetMm;
    final snap = _snapping ? OpeningAlignmentService.snap(
      floor, wall, desiredOffsetMm: raw, openingWidthMm: opening.widthMm,
      toleranceMm: 15 / (_mmToPx * _scale),
    ) : null;
    final chosen = snap != null && _openingValid(wall, opening,
        snap.offsetMm, opening.widthMm) ? snap : null;
    final wanted = (chosen?.offsetMm ?? raw).roundToDouble();
    if (!_openingValid(wall, opening, wanted, opening.widthMm)) return;
    _openingSnapHint = chosen?.label;
    if ((opening.offsetFromStartMm - wanted).abs() < .5) return;
    opening.offsetFromStartMm = wanted;
    _openingDragDirty = true;
    setState(() {});
  }

  void _openingDragEnd(DragEndDetails details) {
    final changed = _openingDragDirty;
    _dragOpeningWallId = null;
    _dragOpeningId = null;
    _openingDragDirty = false;
    setState(() => _openingSnapHint = null);
    if (changed) unawaited(_changed());
  }

  Future<void> _editOpening(PlanWall wall, WallOpening opening) async {
    final positionController = TextEditingController(
        text: opening.offsetFromStartMm.round().toString());
    var widthText = opening.widthMm.round().toString();
    var heightText = opening.heightMm.round().toString();
    var sillText = opening.sillHeightMm.round().toString();
    var swing = opening.doorSwing;

    void alignTo(String target, BuildContext sheetContext) {
      final width = double.tryParse(widthText.replaceAll(',', '.'));
      final requested = double.tryParse(
          positionController.text.replaceAll(',', '.'));
      if (width == null || requested == null || width <= 0) return;
      final candidates = OpeningAlignmentService.targets(
        floor, wall, desiredOffsetMm: requested,
        openingWidthMm: width,
        toleranceMm: floor.wallLengthMm(wall),
      ).where((p) => p.label == target &&
          _openingValid(wall, opening, p.offsetMm, width)).toList();
      if (candidates.isEmpty) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text('Нет доступной привязки: $target'),
        ));
        return;
      }
      candidates.sort((a, b) =>
        (a.offsetMm - requested).abs().compareTo(
            (b.offsetMm - requested).abs()));
      positionController.text = candidates.first.offsetMm.round().toString();
      positionController.selection = TextSelection.collapsed(
          offset: positionController.text.length);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16, 4, 16,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(opening.type == OpeningType.door
                      ? 'Редактирование двери' : 'Редактирование окна',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: positionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'От начала стены, мм'),
                  ),
                  Wrap(
                    spacing: 5, runSpacing: 0,
                    children: [
                      ActionChip(
                        label: const Text('Центр стены'),
                        onPressed: () => alignTo(
                            'Центр стены', sheetContext),
                      ),
                      ActionChip(
                        label: const Text('Центр участка'),
                        onPressed: () => alignTo(
                            'Центр участка стены', sheetContext),
                      ),
                      ActionChip(
                        label: const Text('По оси двери'),
                        onPressed: () => alignTo(
                            'По оси двери напротив', sheetContext),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: widthText,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ширина, мм'),
                    onChanged: (v) => widthText = v,
                  ),
                  TextFormField(
                    initialValue: heightText,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Высота, мм'),
                    onChanged: (v) => heightText = v,
                  ),
                  if (opening.type == OpeningType.window)
                    TextFormField(
                      initialValue: sillText,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Высота подоконника, мм'),
                      onChanged: (v) => sillText = v,
                    ),
                  if (opening.type == OpeningType.door)
                    DropdownButtonFormField<DoorSwing>(
                      initialValue: swing,
                      decoration: const InputDecoration(
                        labelText: 'Петли и направление открывания'),
                      items: const [
                        DropdownMenuItem(value: DoorSwing.leftIn,
                          child: Text('Петли слева · внутрь')),
                        DropdownMenuItem(value: DoorSwing.rightIn,
                          child: Text('Петли справа · внутрь')),
                        DropdownMenuItem(value: DoorSwing.leftOut,
                          child: Text('Петли слева · наружу')),
                        DropdownMenuItem(value: DoorSwing.rightOut,
                          child: Text('Петли справа · наружу')),
                      ],
                      onChanged: (v) {
                        if (v != null) update(() => swing = v);
                      },
                    ),
                  const SizedBox(height: 14),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () async {
                        wall.openings.removeWhere((o) => o.id == opening.id);
                        Navigator.pop(sheetContext);
                        await _changed();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        final position = double.tryParse(
                          positionController.text.replaceAll(',', '.'));
                        final width = double.tryParse(
                          widthText.replaceAll(',', '.'));
                        final height = double.tryParse(
                          heightText.replaceAll(',', '.'));
                        final sill = double.tryParse(
                          sillText.replaceAll(',', '.'));
                        if (position == null || width == null || height == null ||
                            sill == null || height < 300 || height > 5000 ||
                            sill < 0 || sill > 3000 ||
                            !_openingValid(wall, opening, position, width)) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text(
                              'Проверьте размеры и расстояния до других проёмов')),
                          );
                          return;
                        }
                        opening.offsetFromStartMm = position;
                        opening.widthMm = width;
                        opening.heightMm = height;
                        opening.sillHeightMm = sill;
                        opening.doorSwing = swing;
                        Navigator.pop(sheetContext);
                        await _changed();
                      },
                      child: const Text('Сохранить'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    positionController.dispose();
  }

  Future<void> _addOpening(Offset p, {bool chooseType = false}) async {
    final wall = _wallNear(p);
    if (wall == null) return;
    var kind = widget.preferredOpeningType ?? OpeningType.door;
    if (chooseType) {
      final selected = await showModalBottomSheet<OpeningType>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.door_front_door_outlined),
                title: const Text('Дверной проём'),
                onTap: () => Navigator.pop(sheetContext, OpeningType.door),
              ),
              ListTile(
                leading: const Icon(Icons.window_outlined),
                title: const Text('Оконный проём'),
                onTap: () => Navigator.pop(sheetContext, OpeningType.window),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      kind = selected;
    }
    final length = floor.wallLengthMm(wall);
    final width = math.min(kind == OpeningType.door ? 900.0 : 1200.0,
        math.max(600.0, length * .32));
    if (length <= width + 160) return;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final v = _toCanvas(b) - _toCanvas(a);
    final touch = p - _toCanvas(a);
    final atMm = (touch.dx * v.dx + touch.dy * v.dy) /
        v.distance / _mmToPx;
    final candidate = WallOpening(
        id: 'o-${DateTime.now().microsecondsSinceEpoch}',
        type: kind,
        widthMm: width,
        heightMm: kind == OpeningType.door ? 2100 : 1300,
        sillHeightMm: kind == OpeningType.door ? 0 : 900,
        offsetFromStartMm: (length - width) / 2,
        doorSwing: DoorSwing.leftIn,
      );
    final rawOffset = (atMm - width / 2)
        .clamp(80.0, length - width - 80.0).toDouble();
    final snap = _snapping ? OpeningAlignmentService.snap(
      floor, wall, desiredOffsetMm: rawOffset, openingWidthMm: width,
      toleranceMm: 17 / (_mmToPx * _scale),
    ) : null;
    candidate.offsetFromStartMm = snap?.offsetMm ?? rawOffset;
    _openingSnapHint = snap?.label;
    if (!_openingValid(wall, candidate, candidate.offsetFromStartMm, width)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Здесь проём пересекается с другим проёмом.'),
      ));
      return;
    }
    wall.openings.add(candidate);
    setState(() {
      _selectedWallId = wall.id;
      _selectedOpeningWallId = wall.id;
      _selectedOpeningId = candidate.id;
    });
    await _changed();
  }

  Future<void> _toggleDemolition(Offset p) async {
    final wall = _wallNear(p);
    if (wall == null) return;
    if (wall.demolition || wall.projectLayer == ProjectLayer.demolition) {
      wall.demolition = false;
      wall.projectLayer = ProjectLayer.existing;
    } else {
      wall.demolition = true;
      wall.projectLayer = ProjectLayer.demolition;
    }
    setState(() => _selectedWallId = wall.id);
    await _changed();
  }

  Future<void> _createArc(Offset p) async {
    if (_wallStartNodeId == null) {
      final start = GeometryService.ensureAnchor(floor, _toMm(p));
      setState(() => _wallStartNodeId = start.id);
      await _changed();
      return;
    }
    final start = floor.nodeById(_wallStartNodeId!);
    if (start == null) return;
    final point = _snapDrawTarget(start, _toMm(p)).point;
    final chord = math.sqrt(math.pow(point.x - start.xMm, 2) +
        math.pow(point.y - start.yMm, 2));
    if (chord < 100) return;

    final sagitta = TextEditingController(text: '400');
    final height = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Радиусная стена'),
        content: TextField(
          controller: sagitta,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true, decimal: true),
          decoration: const InputDecoration(
            labelText: 'Стрела дуги ±h', suffixText: 'мм',
            helperText: 'Знак задаёт сторону изгиба',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final h = double.tryParse(sagitta.text.replaceAll(',', '.'));
              if (h == null || !h.isFinite || h.abs() < 1 ||
                  h.abs() > chord * 2) return;
              Navigator.pop(dialogContext, h);
            },
            child: const Text('Построить'),
          ),
        ],
      ),
    );
    sagitta.dispose();
    if (height == null || !mounted) return;
    final existing = floor.walls.map((w) => w.id).toSet();
    final end = GeometryService.addArcWallFromNode(
      floor,
      startNodeId: start.id,
      endPoint: point,
      sagittaMm: height,
      type: WallType.partition,
      thicknessMm: 100,
      material: WallMaterial.drywall,
    );
    for (final wall in floor.walls.where((w) => !existing.contains(w.id))) {
      wall.projectLayer = _drawingLayer;
      wall.demolition = _drawingLayer == ProjectLayer.demolition;
    }
    setState(() => _wallStartNodeId = end.id);
    await _changed();
  }

  void _nodeDragStart(DragStartDetails details) {
    if (widget.planTool != MeasurePlanTool.nodes ||
        _pinchInProgress || _activeCanvasPointers.length > 1) return;
    final node = _nodeNear(details.localPosition);
    if (node == null) return;
    final finger = _toMm(details.localPosition);
    setState(() {
      _selectedNodeId = node.id;
      _dragNodeId = node.id;
      _nodeDragStartFloor = FloorPlan.fromJson(floor.toJson());
      _nodeDragAffected.clear();
      _nodeDragInvalid = null;
      _nodeDragChanged = false;
      _dragSnap = null;
      _fingerNodeOffsetMm = math.Point<double>(
        node.xMm - finger.x, node.yMm - finger.y,
      );
    });
  }

  void _nodeDragUpdate(DragUpdateDetails details) {
    if (_pinchInProgress || _activeCanvasPointers.length > 1) return;
    final id = _dragNodeId;
    final base = _nodeDragStartFloor;
    if (widget.planTool != MeasurePlanTool.nodes ||
        id == null || base == null) return;
    final finger = _toMm(details.localPosition);
    final raw = finger + _fingerNodeOffsetMm;
    final radiusMm = 16 / (_mmToPx * _scale);
    // Snap against the frozen drag-start floor. Moving linked walls during a
    // gesture must not cause capture targets to chase the moving finger.
    final snap = GeometryService.snapMoveTarget(
      base,
      movingNodeId: id,
      raw: raw,
      enabled: _snapping,
      nodeThresholdMm: radiusMm,
      wallThresholdMm: radiusMm * 0.75,
      guideThresholdMm: radiusMm * 0.6,
      previousSnap: _dragSnap,
      releaseThresholdMm: radiusMm * 1.5,
    );
    final preview = NodeMoveConstraintService.evaluate(
      base, nodeId: id, destination: snap.point,
    );
    if (!preview.isValid) {
      // Keep the last valid geometry, not a diagonal triangle accidentally
      // introduced into a previously orthogonal room.
      setState(() => _nodeDragInvalid = preview.message);
      return;
    }
    NodeMoveConstraintService.apply(floor, preview);
    setState(() {
      _dragSnap = snap;
      _nodeDragAffected = preview.movedNodeIds;
      _nodeDragChanged = preview.movedNodeIds.isNotEmpty;
      _nodeDragInvalid = null;
    });
  }

  Future<void> _nodeDragEnd(DragEndDetails details) async {
    final id = _dragNodeId;
    if (id == null) return;
    final changed = _nodeDragChanged;
    final snap = _dragSnap;
    final affected = Set<String>.of(_nodeDragAffected);
    final rejected = _nodeDragInvalid;
    // Preserve the *original* topology for rollback if a target host wall
    // rejects splitting (for example when it would bisect a door opening).
    final beforeDrag = _nodeDragStartFloor;
    setState(() {
      _dragNodeId = null;
      _nodeDragStartFloor = null;
      _nodeDragAffected.clear();
      _dragSnap = null;
      _nodeDragInvalid = null;
      _nodeDragChanged = false;
    });
    if (rejected != null) {
      // The pointer was released in a prohibited position. Do not silently
      // commit the last valid intermediate position from the same gesture:
      // restore the whole edit so the user's room cannot unexpectedly shift.
      if (beforeDrag != null) floor.restoreFrom(beforeDrag);
      _selectedNodeId = id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 2200),
          content: Text('Перемещение отменено: $rejected'),
        ));
        setState(() {});
      }
      return;
    }
    if (!changed) return;

    // Only a solitary free endpoint may merge/split other topology nodes.
    // A constrained grid shift has already moved all linked wall axes and
    // must not additionally perform destructive merge operations.
    if (affected.length <= 1 && snap != null) {
      try {
        final moved = GeometryService.finalizeNodeMove(
          floor, movingNodeId: id, snap: snap,
        );
        _selectedNodeId = moved?.id;
      } on StateError catch (error) {
        // A failed join must never leave a moved free endpoint in front of an
        // unsplit wall. Otherwise it looks closed while topology stays open.
        if (beforeDrag != null) floor.restoreFrom(beforeDrag);
        _selectedNodeId = id;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 2500),
            content: Text('Стык отменён: ${error.message}'),
          ));
          setState(() {});
        }
        return;
      }
    } else {
      _selectedNodeId = id;
    }
    await _changed();
  }

  void _nodeDragCancel() {
    final base = _nodeDragStartFloor;
    if (base != null) floor.restoreFrom(base);
    setState(() {
      _dragNodeId = null;
      _nodeDragStartFloor = null;
      _nodeDragAffected.clear();
      _dragSnap = null;
      _nodeDragInvalid = null;
      _nodeDragChanged = false;
    });
  }

  Future<void> _editSelectedNode() async {
    final id = _selectedNodeId;
    if (id == null) return;
    final node = floor.nodeById(id);
    if (node == null) return;
    final x = TextEditingController(text: node.xMm.round().toString());
    final y = TextEditingController(text: node.yMm.round().toString());
    final result = await showModalBottomSheet<math.Point<double>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16,
          20 + MediaQuery.viewInsetsOf(sheet).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Точные координаты узла'),
            TextField(controller: x,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(labelText: 'X', suffixText: 'мм')),
            TextField(controller: y,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(labelText: 'Y', suffixText: 'мм')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final px = double.tryParse(x.text.replaceAll(',', '.'));
                final py = double.tryParse(y.text.replaceAll(',', '.'));
                if (px == null || py == null || !px.isFinite || !py.isFinite ||
                    px.abs() > 100000 || py.abs() > 100000) return;
                Navigator.pop(sheet, math.Point<double>(px, py));
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
    x.dispose();
    y.dispose();
    if (result == null || !mounted) return;
    final preview = NodeMoveConstraintService.evaluate(
      floor, nodeId: id, destination: result,
    );
    if (!preview.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(preview.message ?? 'Недопустимая геометрия стен'),
      ));
      return;
    }
    NodeMoveConstraintService.apply(floor, preview);
    setState(() => _selectedNodeId = id);
    await _changed();
  }

  Future<void> _resizeSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;

    var lengthText = floor.wallLengthMm(wall).round().toString();
    var keepStartFixed = true;
    final target = await showModalBottomSheet<(double, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZamerColors.surface,
      builder: (sheet) => SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: StatefulBuilder(
              builder: (context, refresh) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Изменить длину стены',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Текущая длина: ${floor.wallLengthMm(wall).round()} мм',
                    style: const TextStyle(
                      fontSize: 12, color: ZamerColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('existing-wall-length-mm'),
                    initialValue: lengthText,
                    autofocus: true,
                    onChanged: (value) => lengthText = value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Новая длина',
                      suffixText: 'мм',
                      helperText: 'От 120 мм до 100 м',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Какой конец оставить неподвижным?',
                      style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('wall-resize-fix-start'),
                        label: const Text('Начало'),
                        selected: keepStartFixed,
                        onSelected: (_) =>
                          refresh(() => keepStartFixed = true),
                      ),
                      ChoiceChip(
                        key: const ValueKey('wall-resize-fix-end'),
                        label: const Text('Конец'),
                        selected: !keepStartFixed,
                        onSelected: (_) =>
                          refresh(() => keepStartFixed = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Смежная перпендикулярная стена сместится, сохраняя '
                    'прямые углы. Сложные узлы блокируются.',
                    style: TextStyle(
                      fontSize: 11, color: ZamerColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('existing-wall-length-apply'),
                      onPressed: () {
                        final newLength = double.tryParse(
                          lengthText.trim().replaceAll(',', '.'),
                        );
                        if (newLength == null ||
                            !newLength.isFinite ||
                            newLength < WallLengthEditService.minLengthMm ||
                            newLength > WallLengthEditService.maxLengthMm) {
                          ScaffoldMessenger.of(sheet).showSnackBar(
                            const SnackBar(
                              content: Text('Укажите длину 120–100000 мм'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(sheet, (newLength, keepStartFixed));
                      },
                      child: const Text('Применить размер'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;

    final result = WallLengthEditService.resize(
      floor, wallId: wall.id, lengthMm: target.$1,
      keepStartFixed: target.$2,
    );
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    await _changed();
  }

  Future<void> _shiftSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    var offsetText = '0';
    final offset = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: ZamerColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          duration: const Duration(milliseconds: 150),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Сдвинуть стену параллельно'),
                TextFormField(
                  initialValue: offsetText,
                  onChanged: (value) => offsetText = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Смещение по X / Y',
                    suffixText: 'мм',
                    helperText: 'Вертикальная стена: X; горизонтальная: Y',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final mm = double.tryParse(
                      offsetText.trim().replaceAll(',', '.'),
                    );
                    if (mm == null || !mm.isFinite) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        const SnackBar(content: Text('Укажите смещение в мм')),
                      );
                      return;
                    }
                    Navigator.pop(sheet, mm);
                  },
                  child: const Text('Переместить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (offset == null || offset == 0 || !mounted) return;
    final result = OrthogonalWallEditService.move(
      floor, wallId: wall.id, offsetMm: offset,
    );
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    await _changed();
  }

  ({math.Point<double> point, String nodeId})?
      _nearestRoomInteriorCorner(Offset canvasPoint) {
    final raw = _toMm(canvasPoint);
    final pixelToleranceMm = 18 / (_mmToPx * _scale);
    var best = pixelToleranceMm;
    ({math.Point<double> point, String nodeId})? result;
    for (final face in _faces) {
      if (face.edges.any(
        (edge) => floor.wallById(edge.wallId)?.isCurved != false,
      )) continue;
      // The real corners exclude intermediate collinear vertices introduced
      // when a host wall was split at a T-junction.
      for (final dimension in RoomInteriorDimensionsService.forFace(face)) {
        final i = dimension.startEdgeIndex;
        if (i >= face.nodeIds.length) continue;
        final candidate = dimension.start;
        final d = WallDrawingService.distance(raw, candidate);
        if (d >= best) continue;
        best = d;
        result = (point: candidate, nodeId: face.nodeIds[i]);
      }
    }
    return result;
  }

  Future<void> _addDimension(Offset p) async {
    if (_measureRoomInterior) {
      final corner = _nearestRoomInteriorCorner(p);
      if (corner == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
              'Нажмите на внутренний угол замкнутого помещения',
            )),
          );
        }
        return;
      }
      final from = _dimensionStartInterior;
      final nodeId = _dimensionStartInteriorNodeId;
      if (from == null || nodeId == null) {
        setState(() {
          _dimensionStartInterior = corner.point;
          _dimensionStartInteriorNodeId = corner.nodeId;
        });
        return;
      }
      if (nodeId == corner.nodeId) return;
      final length = WallDrawingService.distance(from, corner.point);
      if (length < 1) return;
      final measure = ControlMeasure(
        id: 'm-${DateTime.now().microsecondsSinceEpoch}',
        startNodeId: nodeId,
        endNodeId: corner.nodeId,
        startXMm: from.x,
        startYMm: from.y,
        endXMm: corner.point.x,
        endYMm: corner.point.y,
        measuredMm: length,
        label: 'Внутренний размер',
      );
      floor.measures.add(measure);
      floor.dimensionRecords['control:${measure.id}'] = DimensionRecord(
        valueMm: length,
        source: DimensionSource.calculated,
        author: 'Замер',
        recordedAt: DateTime.now(),
      );
      setState(() {
        _dimensionStartInterior = null;
        _dimensionStartInteriorNodeId = null;
      });
      await _changed();
      return;
    }

    // Axial measurements remain available intentionally for structural
    // checks; they are not silently treated as actual room dimensions.
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
      label: 'По осям',
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

  /// Visibility is view state only: toggling a category never mutates a
  /// PlanWall, PlanObject, ElectricalPoint or saved project material.
  Future<void> _layersSheet() async {
    final draftConstruction = Set<ProjectLayer>.of(_visibleLayers);
    final draftCategories = Set<PlanDisplayLayer>.of(_visibleCategories);
    final draftCollisions = Set<PlanCollisionKind>.of(_collisionKinds);
    final marks = PlanCollisionService.inspect(floor);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          void toggle<T>(Set<T> target, T value, bool enabled) {
            setSheet(() {
              if (enabled) {
                target.add(value);
              } else {
                target.remove(value);
              }
            });
          }
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .77,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      const Icon(Icons.layers_outlined, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Слои и коллизии',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () => setSheet(() {
                          draftConstruction
                            ..clear()
                            ..addAll(ProjectLayer.values);
                          draftCategories
                            ..clear()
                            ..addAll(PlanDisplayLayer.values)
                            ..remove(PlanDisplayLayer.axisDimensions)
                            ..remove(PlanDisplayLayer.dimensions);
                          draftCollisions
                            ..clear()
                            ..addAll(PlanCollisionKind.values);
                        }),
                        child: const Text('Сброс'),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('plan-layers-list'),
                      children: [
                        const ListTile(
                          dense: true,
                          title: Text('Строительные слои',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Существующее, демонтаж и новая планировка'),
                        ),
                        for (final layer in ProjectLayer.values)
                          SwitchListTile.adaptive(
                            dense: true,
                            title: Text(layer.label),
                            value: draftConstruction.contains(layer),
                            onChanged: (enabled) =>
                              toggle(draftConstruction, layer, enabled),
                          ),
                        const Divider(height: 16),
                        const ListTile(
                          dense: true,
                          title: Text('Элементы плана',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Скрытые объекты не удаляются из проекта'),
                        ),
                        for (final layer in PlanDisplayLayer.values)
                          SwitchListTile.adaptive(
                            dense: true,
                            key: ValueKey('layer-${layer.name}'),
                            title: Text(layer.label),
                            value: draftCategories.contains(layer),
                            onChanged: (enabled) =>
                              toggle(draftCategories, layer, enabled),
                          ),
                        const Divider(height: 16),
                        ListTile(
                          dense: true,
                          title: const Text('Контроль коллизий',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${marks.length} обнаружено · цветные метки на плане',
                          ),
                        ),
                        for (final kind in PlanCollisionKind.values)
                          SwitchListTile.adaptive(
                            dense: true,
                            key: ValueKey('collision-${kind.name}'),
                            title: Text(kind.label),
                            subtitle: Text(
                              '${marks.where((issue) => issue.kind == kind).length} конфликтов',
                            ),
                            value: draftCollisions.contains(kind),
                            onChanged: (enabled) =>
                              toggle(draftCollisions, kind, enabled),
                          ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            'Сейчас проверяются 2D-пересечения стен и объектов, '
                            'а также свободный проход у двери. '
                            'Коллизии кабелей и труб с конструкциями '
                            'пока не рассчитываются.',
                            style: TextStyle(fontSize: 11,
                              color: ZamerColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: marks.isEmpty ? null : () {
                              Navigator.pop(sheetContext);
                              _collisionReport(marks);
                            },
                            icon: const Icon(Icons.fact_check_outlined, size: 18),
                            label: Text('Ошибки (${marks.length})'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _visibleLayers
                                  ..clear()
                                  ..addAll(draftConstruction);
                                _visibleCategories
                                  ..clear()
                                  ..addAll(draftCategories);
                                _collisionKinds
                                  ..clear()
                                  ..addAll(draftCollisions);
                                // Hidden walls/objects cannot remain selected.
                                if (!_visibleCategories.contains(
                                  PlanDisplayLayer.walls,
                                )) _selectedWallId = null;
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Применить'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _focusCollision(math.Point<double> position) {
    if (_viewport.isEmpty) return;
    final scale = math.max(1.0, _transform.value.getMaxScaleOnAxis())
        .clamp(.28, 6.0);
    final point = _origin +
        Offset(position.x * _mmToPx, position.y * _mmToPx);
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    _transform.value = Matrix4.identity()
      ..translate(center.dx - point.dx * scale, center.dy - point.dy * scale)
      ..scale(scale);
    setState(() {});
  }

  Future<void> _collisionReport(List<PlanCollisionMark> marks) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (reportContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(reportContext).height * .62,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text('Коллизии: ${marks.length}'),
                subtitle: const Text('Нажмите на ошибку, чтобы найти её на плане'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: marks.length,
                  itemBuilder: (context, index) {
                    final mark = marks[index];
                    return ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                        color: mark.kind == PlanCollisionKind.doorClearance
                          ? const Color(0xFFF6B35B)
                          : const Color(0xFFEF5350)),
                      title: Text(mark.kind.label),
                      subtitle: Text(mark.description),
                      trailing: const Icon(Icons.my_location_outlined),
                      onTap: () {
                        Navigator.pop(reportContext);
                        setState(() => _collisionKinds.add(mark.kind));
                        _focusCollision(mark.position);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editWall() async {
    final wall = _selectedWall;
    if (wall == null) return;
    var thicknessText = wall.thicknessMm.round().toString();
    var heightText =
        (wall.heightOverrideMm ?? floor.defaultHeightMm).round().toString();
    final properties = await showModalBottomSheet<(double, double)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Параметры стены',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: thicknessText,
                  onChanged: (value) => thicknessText = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Толщина', suffixText: 'мм',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: heightText,
                  onChanged: (value) => heightText = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Высота', suffixText: 'мм',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final thickness = double.tryParse(
                        thicknessText.trim().replaceAll(',', '.'),
                      );
                      final height = double.tryParse(
                        heightText.trim().replaceAll(',', '.'),
                      );
                      if (thickness == null || height == null ||
                          !thickness.isFinite || !height.isFinite ||
                          thickness <= 40 || thickness > 1500 ||
                          height <= 300 || height > 10000) {
                        ScaffoldMessenger.of(sheet).showSnackBar(
                          const SnackBar(
                            content: Text('Проверьте толщину и высоту стены'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(sheet, (thickness, height));
                    },
                    child: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (properties == null || !mounted) return;
    wall.thicknessMm = properties.$1;
    wall.heightOverrideMm = properties.$2;
    await _changed();
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
      _wallChainFirstNodeId = null;
      _wallChainSegments = 0;
      _dimensionStartNodeId = null;
    });
  }

  bool get _drawingWall => <MeasurePlanTool>{
    MeasurePlanTool.exterior,
    MeasurePlanTool.partition,
    MeasurePlanTool.arc,
    MeasurePlanTool.precision,
  }.contains(widget.planTool);

  bool get _editingGeometry =>
      widget.planTool != MeasurePlanTool.overview &&
      widget.planTool != MeasurePlanTool.select;

  // Completely freeze the viewport (including pinch scaling) during wall
  // placement; navigation is explicitly enabled with the hand control.
  // This is safer than restoring the camera matrix in a gesture callback:
  // tap coordinates and snap capture stay consistent for the whole gesture.
  bool get _cameraGestureEnabled =>
      (!_drawingWall && widget.planTool != MeasurePlanTool.openings) ||
      _moveCameraInsteadOfDrawing;

  void _toggleCameraNavigation() {
    _stopEdgePan();
    setState(() {
      _moveCameraInsteadOfDrawing = !_moveCameraInsteadOfDrawing;
      _liveWallSnap = null;
      _lastWallSnapLabel = _moveCameraInsteadOfDrawing
          ? 'Навигация по плану' : null;
    });
  }

  Widget _compactEditingBar() {
    final hasStart = _wallStartNodeId != null;
    final nodesSelected = widget.planTool == MeasurePlanTool.nodes &&
        _selectedNodeId != null;
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xEE0C1B20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_drawingWall) ...[
                    if (_moveCameraInsteadOfDrawing)
                      const Text('Режим перемещения · нажмите руку снова',
                        style: TextStyle(fontSize: 11,
                          color: ZamerColors.textSecondary)),
                    if (!_moveCameraInsteadOfDrawing && !hasStart)
                      const Text('Нажмите начало стены',
                        style: TextStyle(fontSize: 11,
                          color: ZamerColors.textPrimary)),
                    if (!_moveCameraInsteadOfDrawing && hasStart &&
                        (widget.planTool == MeasurePlanTool.exterior ||
                         widget.planTool == MeasurePlanTool.partition))
                      TextButton.icon(
                        key: const ValueKey('wall-build-exact-length'),
                        onPressed: _enterWallLength,
                        icon: const Icon(Icons.straighten_outlined, size: 17),
                        label: const Text('Длина'),
                      ),
                    const SizedBox(width: 6),
                    PopupMenuButton<int>(
                      tooltip: 'Угловая привязка',
                      onSelected: (value) => setState(() => _angleSnapDegrees = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 90, child: Text('90°')),
                        PopupMenuItem(value: 45, child: Text('45°')),
                        PopupMenuItem(value: 0, child: Text('Свободно')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(_angleSnapDegrees == 0
                            ? 'Свободно' : '${_angleSnapDegrees}°',
                            style: const TextStyle(color: ZamerColors.accent,
                              fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Tooltip(
                      message: 'Показать границы толщины строящейся стены',
                      child: InkWell(
                        key: const ValueKey('wall-live-face-guides'),
                        onTap: () => setState(() =>
                            _showLiveWallFaces = !_showLiveWallFaces),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.border_outer_rounded,
                            size: 18,
                            color: _showLiveWallFaces
                                ? ZamerColors.accent
                                : ZamerColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<bool>(
                      tooltip: 'Привязка новой стены к оси или грани',
                      onSelected: (capture) => setState(() {
                        _captureWallFace = capture;
                        _liveWallSnap = null;
                      }),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: false,
                          child: Text('К оси существующей стены'),
                        ),
                        PopupMenuItem(
                          value: true,
                          child: Text('К грани → общий узел на оси'),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          _captureWallFace ? 'Грани' : 'Оси',
                          style: const TextStyle(
                            color: ZamerColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<ProjectLayer>(
                      tooltip: 'Слой построения',
                      onSelected: (layer) => setState(() => _drawingLayer = layer),
                      itemBuilder: (_) => ProjectLayer.values.map(
                        (layer) => PopupMenuItem(
                          value: layer,
                          child: Text(layer.label),
                        ),
                      ).toList(),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.layers_outlined, size: 18,
                          color: ZamerColors.textSecondary),
                      ),
                    ),
                    if (hasStart &&
                        _lastWallSnapLabel != null &&
                        _lastWallSnapLabel != 'Начало стены')
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(_lastWallSnapLabel!,
                          style: const TextStyle(
                            fontSize: 10, color: ZamerColors.textSecondary)),
                      ),
                  ] else if (nodesSelected)
                    TextButton.icon(
                      onPressed: _editSelectedNode,
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                      label: const Text('Координаты узла'),
                    )
                  else if (widget.planTool == MeasurePlanTool.dimensions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _measureRoomInterior
                            ? (_dimensionStartInterior == null
                                ? 'Внутренний угол 1 → угол 2'
                                : 'Выберите второй внутренний угол')
                            : (_dimensionStartNodeId == null
                                ? 'Конструктивный размер по осям'
                                : 'Выберите второй узел'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: ZamerColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 7),
                        PopupMenuButton<bool>(
                          key: const ValueKey('dimension-reference-mode'),
                          tooltip: 'База измерения',
                          onSelected: (value) => setState(() {
                            _measureRoomInterior = value;
                            _dimensionStartNodeId = null;
                            _dimensionStartInterior = null;
                            _dimensionStartInteriorNodeId = null;
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: true,
                              child: Text('Внутри помещения (по граням)'),
                            ),
                            PopupMenuItem(
                              value: false,
                              child: Text('Конструктивно (по осям)'),
                            ),
                          ],
                          child: Text(
                            _measureRoomInterior ? 'Внутри ▾' : 'Оси ▾',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ZamerColors.accent,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(widget.planTool == MeasurePlanTool.nodes
                        ? 'Перетащите узел пальцем'
                        : widget.planTool == MeasurePlanTool.openings
                            ? 'Выберите стену для двери или окна'
                            : widget.planTool == MeasurePlanTool.demolition
                                ? 'Нажмите стену для демонтажа'
                                : 'Выберите точки на плане',
                      style: const TextStyle(fontSize: 11,
                        color: ZamerColors.textSecondary)),
                ],
              ),
            ),
          ),
          if (hasStart)
            TextButton.icon(
              onPressed: () => setState(() {
                _wallStartNodeId = null;
                _wallChainFirstNodeId = null;
                _wallChainSegments = 0;
                _lastWallSnapLabel = null;
                _liveWallSnap = null;
              }),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Стоп'),
            ),
        ],
      ),
    );
  }


  // Selection never changes the available CAD viewport height.
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ZamerColors.background,
    child: _canvas(),
  );

  // Anchored overlay rather than a permanently reserved bottom panel.
  Widget _wallContextInspector() => AnimatedBuilder(
    animation: _transform,
    builder: (context, _) {
      final wall = _selectedWall;
      if (wall == null) return const SizedBox.shrink();
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) return const SizedBox.shrink();
      final anchor = (_toCanvas(a) + _toCanvas(b)) / 2;
      final screenX = anchor.dx * _transform.value.storage[0] +
          _transform.value.storage[12];
      final screenY = anchor.dy * _transform.value.storage[5] +
          _transform.value.storage[13];
      final width = math.min(270.0, math.max(180.0, _viewport.width - 16));
      final left = (screenX - width / 2)
          .clamp(8.0, math.max(8.0, _viewport.width - width - 8))
          .toDouble();
      final desiredTop = screenY + 134 > _viewport.height
          ? screenY - 118 : screenY + 18;
      final top = desiredTop
          .clamp(54.0, math.max(54.0, _viewport.height - 126))
          .toDouble();
      return Positioned(
        key: const ValueKey('floating-wall-inspector'),
        left: left,
        top: top,
        width: width,
        child: Material(
          elevation: 9,
          color: const Color(0xF30A1A21),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 6, 8),
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outlineSoft),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.architecture_outlined,
                    size: 17, color: ZamerColors.accent),
                const SizedBox(width: 6),
                const Expanded(child: Text('Параметры стены',
                    style: TextStyle(fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.w700))),
                PopupMenuButton<String>(
                  tooltip: 'Действия со стеной',
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  onSelected: (action) {
                    switch (action) {
                      case 'edit': _editWall();
                      case 'resize': _resizeSelectedWall();
                      case 'shift': _shiftSelectedWall();
                      case 'delete': _deleteWall();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit',
                        child: Text('Толщина и высота')),
                    PopupMenuItem(value: 'resize',
                        child: Text('Изменить длину')),
                    PopupMenuItem(value: 'shift',
                        child: Text('Сдвинуть стену')),
                    PopupMenuItem(value: 'delete',
                        child: Text('Удалить стену')),
                  ],
                ),
                IconButton(
                  tooltip: 'Скрыть параметры',
                  icon: const Icon(Icons.close_rounded, size: 17),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _selectedWallId = null),
                ),
              ]),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  key: const ValueKey('selected-wall-length'),
                  onPressed: _resizeSelectedWall,
                  icon: const Icon(Icons.straighten_rounded, size: 14),
                  label: Text('${floor.wallLengthMm(wall).round()} мм',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 11)),
                )),
                const SizedBox(width: 7),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _editWall,
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: Text('${wall.thicknessMm.round()} мм',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 11)),
                )),
              ]),
            ]),
          ),
        ),
      );
    },
  );


  ({PlanWall wall, WallOpening opening})? get _selectedOpening {
    final wallId = _selectedOpeningWallId;
    final openingId = _selectedOpeningId;
    if (wallId == null || openingId == null) return null;
    final wall = floor.wallById(wallId);
    if (wall == null) return null;
    for (final opening in wall.openings) {
      if (opening.id == openingId) {
        return (wall: wall, opening: opening);
      }
    }
    return null;
  }

  Future<void> _changeDoorHinge() async {
    final selected = _selectedOpening;
    if (selected == null || selected.opening.type != OpeningType.door) return;
    final door = selected.opening;
    door.doorSwing = switch (door.doorSwing) {
      DoorSwing.leftIn => DoorSwing.rightIn,
      DoorSwing.rightIn => DoorSwing.leftIn,
      DoorSwing.leftOut => DoorSwing.rightOut,
      DoorSwing.rightOut => DoorSwing.leftOut,
    };
    await _changed();
  }

  Future<void> _changeDoorSide() async {
    final selected = _selectedOpening;
    if (selected == null || selected.opening.type != OpeningType.door) return;
    final door = selected.opening;
    door.doorSwing = switch (door.doorSwing) {
      DoorSwing.leftIn => DoorSwing.leftOut,
      DoorSwing.rightIn => DoorSwing.rightOut,
      DoorSwing.leftOut => DoorSwing.leftIn,
      DoorSwing.rightOut => DoorSwing.rightIn,
    };
    await _changed();
  }

  Widget _openingContextInspector() => AnimatedBuilder(
    animation: _transform,
    builder: (context, _) {
      final selected = _selectedOpening;
      if (selected == null) return const SizedBox.shrink();
      final wall = selected.wall;
      final opening = selected.opening;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) return const SizedBox.shrink();
      final length = floor.wallLengthMm(wall);
      if (length <= 0) return const SizedBox.shrink();
      final t = (opening.offsetFromStartMm + opening.widthMm / 2) / length;
      final center = _toCanvas(a) + (_toCanvas(b) - _toCanvas(a)) * t;
      final screenX = center.dx * _transform.value.storage[0] +
          _transform.value.storage[12];
      final screenY = center.dy * _transform.value.storage[5] +
          _transform.value.storage[13];
      final width = math.min(248.0, math.max(180.0, _viewport.width - 16));
      final left = (screenX - width / 2)
          .clamp(8.0, math.max(8.0, _viewport.width - width - 8))
          .toDouble();
      // Place the 176px inspector on the side with space. Never force
      // a bottom sheet or reposition the camera when selecting a door.
      const cardHeight = 176.0;
      final proposed = screenY + cardHeight + 24 > _viewport.height
          ? screenY - cardHeight - 16 : screenY + 22;
      final top = proposed
          .clamp(52.0, math.max(52.0, _viewport.height - cardHeight - 8))
          .toDouble();
      final isDoor = opening.type == OpeningType.door;
      final leftHinge = opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.leftOut;
      final inward = opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.rightIn;
      return Positioned(
        key: const ValueKey('floating-opening-inspector'),
        left: left, top: top, width: width,
        child: Material(
          elevation: 10,
          color: const Color(0xF40A1A21),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outlineSoft),
              borderRadius: BorderRadius.circular(13)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(isDoor ? Icons.door_front_door_outlined
                    : Icons.window_outlined,
                    size: 17, color: ZamerColors.accent),
                const SizedBox(width: 6),
                Expanded(child: Text(isDoor ? 'Дверь' : 'Окно',
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Точные параметры',
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  onPressed: () => _editOpening(wall, opening)),
                IconButton(
                  tooltip: 'Скрыть параметры',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _selectedOpeningWallId = null;
                    _selectedOpeningId = null;
                  })),
              ]),
              Row(children: [
                Expanded(child: TextButton.icon(
                  key: const ValueKey('selected-opening-width'),
                  onPressed: () => _editOpening(wall, opening),
                  icon: const Icon(Icons.straighten_outlined, size: 14),
                  label: Text('${opening.widthMm.round()} мм',
                    style: const TextStyle(fontSize: 11)),
                )),
                Expanded(child: TextButton.icon(
                  onPressed: () => _editOpening(wall, opening),
                  icon: const Icon(Icons.height_rounded, size: 14),
                  label: Text('${opening.heightMm.round()} мм',
                    style: const TextStyle(fontSize: 11)),
                )),
              ]),
              // Distances are measured along the host wall from the door's
              // edges, not from the phone screen's left/right directions.
              Row(children: [
                Expanded(child: TextButton(
                  key: const ValueKey('opening-offset-from-start'),
                  onPressed: () => _editOpening(wall, opening),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: EdgeInsets.zero),
                  child: Text('← ${opening.offsetFromStartMm.round()} мм',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10)),
                )),
                const SizedBox(width: 7),
                Expanded(child: TextButton(
                  key: const ValueKey('opening-offset-to-end'),
                  onPressed: () => _editOpening(wall, opening),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: EdgeInsets.zero),
                  child: Text('${math.max(0.0, length -
                    opening.offsetFromStartMm - opening.widthMm).round()} мм →',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10)),
                )),
              ]),
              if (isDoor) Row(children: [
                Expanded(child: OutlinedButton(
                  key: const ValueKey('door-flip-hinges'),
                  onPressed: _changeDoorHinge,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: EdgeInsets.zero),
                  child: Text(leftHinge ? 'Петли слева' : 'Петли справа',
                    style: const TextStyle(fontSize: 10)),
                )),
                const SizedBox(width: 7),
                Expanded(child: OutlinedButton(
                  key: const ValueKey('door-flip-swing'),
                  onPressed: _changeDoorSide,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: EdgeInsets.zero),
                  child: Text(inward ? 'Внутрь' : 'Наружу',
                    style: const TextStyle(fontSize: 10)),
                )),
              ]),
            ]),
          ),
        ),
      );
    },
  );

  Widget _canvas() => LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_centered) {
            _centered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (widget.viewportActive && widget.sharedViewport?.value != null) {
                _adoptViewport();
              } else {
                _fit();
              }
            });
          }
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: .28,
                  maxScale: 6,
                  onInteractionStart: _wallDragStart,
                  onInteractionUpdate: _wallDragUpdate,
                  onInteractionEnd: (_) {
                    unawaited(_wallDragFinish());
                    _publishViewport();
                  },
                  // The user's finger draws walls; it must not drag or zoom
                  // the camera until the dedicated hand mode is activated.
                  panEnabled: widget.planTool != MeasurePlanTool.nodes &&
                      _cameraGestureEnabled,
                  // Two-finger pinch is safe during drawing; single-finger pan
                  // remains locked so moving a wall cannot move the camera.
                  scaleEnabled: widget.planTool == MeasurePlanTool.nodes ||
                      _drawingWall || _cameraGestureEnabled,
                  boundaryMargin: const EdgeInsets.all(32000),
                  constrained: false,
                  child: Stack(
                    children: [
                      Listener(
                        onPointerDown: _wallPointerDown,
                        onPointerMove: _wallPointerMove,
                        onPointerUp: _wallPointerUp,
                        onPointerCancel: _wallPointerCancel,
                        onPointerHover: _updateLiveWallGuide,
                        child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _tapCanvas,
                        onPanStart: widget.planTool == MeasurePlanTool.nodes
                            ? _nodeDragStart
                            : widget.planTool == MeasurePlanTool.openings &&
                                !_moveCameraInsteadOfDrawing
                                ? _openingDragStart : null,
                        onPanUpdate: widget.planTool == MeasurePlanTool.nodes
                            ? _nodeDragUpdate
                            : widget.planTool == MeasurePlanTool.openings &&
                                !_moveCameraInsteadOfDrawing
                                ? _openingDragUpdate : null,
                        onPanCancel: widget.planTool == MeasurePlanTool.nodes
                            ? _nodeDragCancel : null,
                        onPanEnd: widget.planTool == MeasurePlanTool.nodes
                            ? _nodeDragEnd
                            : widget.planTool == MeasurePlanTool.openings &&
                                !_moveCameraInsteadOfDrawing
                                ? _openingDragEnd : null,
                        child: CustomPaint(
                          key: const ValueKey('measure-shared-canvas'),
                          size: _canvasSize,
                          painter: CadPlanPainter(
                            floor: floor,
                            mmToPx: _mmToPx,
                            origin: _origin,
                            selectedWallId: _selectedWallId,
                            showGrid: _grid,
                            zoom: _scale,
                            visibleLayers: _visibleLayers,
                            visibleCategories: <PlanDisplayLayer>{
                              ..._visibleCategories,
                              if (widget.planTool == MeasurePlanTool.dimensions)
                                PlanDisplayLayer.dimensions,
                            },
                            collisionKinds: _collisionKinds,
                            showOpeningDimensions:
                                widget.planTool == MeasurePlanTool.openings,
                          ),
                          foregroundPainter: _wallPreviewPainter(),
                        ),
                      ),
                      ),
                      // Always reveal the chained wall's real CAD start node
                      // without stealing touch events or covering furniture.
                      if (_drawingWall && _wallStartNodeId != null)
                        if (floor.nodeById(_wallStartNodeId!) case final start?)
                          Positioned(
                            left: _toCanvas(start).dx - 5,
                            top: _toCanvas(start).dy - 5,
                            child: IgnorePointer(
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: ZamerColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ZamerColors.background, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                      // When the contour has at least two sides, keep its
                      // initial junction visible as the precise closing target.
                      if (_drawingWall && _wallChainSegments >= 2 &&
                          _wallChainFirstNodeId != null)
                        if (floor.nodeById(_wallChainFirstNodeId!)
                            case final first?)
                          Positioned(
                            key: const ValueKey('wall-chain-first-node'),
                            left: _toCanvas(first).dx - 10,
                            top: _toCanvas(first).dy - 10,
                            child: IgnorePointer(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ZamerColors.accent.withValues(alpha: .16),
                                  border: Border.all(
                                    color: ZamerColors.accent, width: 2),
                                ),
                                child: const Icon(Icons.check_rounded,
                                  color: ZamerColors.accent, size: 13),
                              ),
                            ),
                          ),
                      // Anchor the control measurement at the actual
                      // inside-corner intersection, not the axis node.
                      if (widget.planTool == MeasurePlanTool.dimensions &&
                          _measureRoomInterior)
                        if (_dimensionStartInterior case final p?)
                          Positioned(
                          left: _origin.dx + p.x * _mmToPx - 6,
                          top: _origin.dy + p.y * _mmToPx - 6,
                          child: const IgnorePointer(
                            child: Icon(
                              Icons.add_circle,
                              color: ZamerColors.accent,
                              size: 12,
                            ),
                          ),
                        ),
                      if (widget.planTool == MeasurePlanTool.overview)
                        if (_layoutDragRegion() case final region?) region,
                      if (widget.planTool == MeasurePlanTool.overview)
                        ..._objectDragRegions(),
                    ],
                  ),
                ),
              ),

              if (_selectedWall != null &&
                  !_drawingWall &&
                  _dragWallId == null &&
                  (widget.planTool == MeasurePlanTool.select ||
                   widget.planTool == MeasurePlanTool.overview))
                _wallContextInspector(),
              if (widget.planTool == MeasurePlanTool.openings &&
                  _selectedOpening != null && _dragOpeningId == null)
                _openingContextInspector(),
              // A single compact control opens the full material picker.
              if (widget.planTool == MeasurePlanTool.overview) ...[
                if (_materialsExpanded)
                  Positioned(
                    left: 8,
                    bottom: 51,
                    width: math.min(274.0, _viewport.width - 16),
                    child: _MaterialPanel(
                      category: _materialCategory,
                      selectedRoomName: _selectedRoomMeta?.name,
                      selectedMaterialId: _selectedMaterialId,
                      selectionMode: _materialPickMode,
                      expanded: true,
                      onToggle: () => setState(() => _materialsExpanded = false),
                      onCategory: _selectMaterialCategory,
                      onApply: _applyMaterial,
                      onOpenMaterials: widget.onOpenMaterials,
                    ),
                  ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: ZMeasureCanvasAction(
                    key: const ValueKey('floating-materials-toggle'),
                    icon: _materialsExpanded
                        ? Icons.close_rounded : Icons.palette_outlined,
                    tooltip: _materialsExpanded
                        ? 'Скрыть материалы' : 'Материалы и покрытия',
                    active: _materialsExpanded,
                    onPressed: () => setState(
                      () => _materialsExpanded = !_materialsExpanded),
                  ),
                ),
              ],
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_drawingWall || widget.planTool == MeasurePlanTool.openings) ...[
                      ZMeasureCanvasAction(
                        key: const ValueKey('wall-camera-navigation'),
                        icon: _moveCameraInsteadOfDrawing
                            ? Icons.edit_outlined
                            : Icons.pan_tool_alt_outlined,
                        tooltip: _moveCameraInsteadOfDrawing
                            ? 'Вернуться к построению стен'
                            : 'Переместить или увеличить план',
                        active: _moveCameraInsteadOfDrawing,
                        onPressed: _toggleCameraNavigation,
                      ),
                      const SizedBox(width: 5),
                    ],
                    ZMeasureCanvasAction(
                      compact: widget.nativeKitV2,
                      subtleActive: widget.nativeKitV2,
                      key: const ValueKey('plan-layers-button'),
                      icon: Icons.layers_outlined,
                      tooltip: 'Слои и коллизии',
                      active: _collisionKinds.isNotEmpty ||
                        _visibleCategories.length != PlanDisplayLayer.values.length,
                      onPressed: _layersSheet,
                    ),
                    const SizedBox(width: 5),
                    ZMeasureCanvasAction(
                      compact: widget.nativeKitV2,
                      subtleActive: widget.nativeKitV2,
                      icon: _grid ? Icons.grid_on_outlined : Icons.grid_off_outlined,
                      tooltip: 'Сетка',
                      active: _grid,
                      onPressed: () => setState(() => _grid = !_grid),
                    ),
                    const SizedBox(width: 5),
                    ZMeasureCanvasAction(
                      compact: widget.nativeKitV2,
                      subtleActive: widget.nativeKitV2,
                      icon: _snapping ? Icons.link : Icons.link_off,
                      tooltip: 'Привязки',
                      active: _snapping,
                      onPressed: () => setState(() => _snapping = !_snapping),
                    ),
                  ],
                ),
              ),
              // Keep snap feedback by the exact intended wall endpoint,
              // not pinned in the header where it hides editing controls.
              if (_drawingWall && _wallStartNodeId != null &&
                  _liveWallSnap != null && !_moveCameraInsteadOfDrawing)
                if (_liveWallSnap case final snap?)
                  Builder(builder: (context) {
                    const tooltipWidth = 210.0;
                    const tooltipHeight = 56.0;
                    final world = _origin + Offset(
                      snap.point.x * _mmToPx,
                      snap.point.y * _mmToPx,
                    );
                    final tip = MatrixUtils.transformPoint(
                      _transform.value, world);
                    final preferLeft = tip.dx + tooltipWidth + 18 >
                        _viewport.width;
                    final proposedLeft = preferLeft
                        ? tip.dx - tooltipWidth - 18 : tip.dx + 18;
                    final proposedTop = tip.dy + tooltipHeight + 14 >
                            _viewport.height
                        ? tip.dy - tooltipHeight - 14 : tip.dy + 12;
                    return Positioned(
                      key: const ValueKey('measure-live-snap-hud'),
                      left: proposedLeft.clamp(8.0,
                        math.max(8.0, _viewport.width - tooltipWidth - 8))
                          .toDouble(),
                      top: proposedTop.clamp(112.0,
                        math.max(112.0, _viewport.height - tooltipHeight - 8))
                          .toDouble(),
                      width: math.min(tooltipWidth,
                        math.max(1.0, _viewport.width - 16)),
                      child: _liveSnapHud(),
                    );
                  }),

              // Fixed-size feedback above the tool strip: the measured
              // coordinates and snap kind remain legible at any zoom.
              if (widget.planTool == MeasurePlanTool.nodes &&
                  _dragNodeId != null)
                Positioned(
                  left: 12,
                  right: 82,
                  bottom: 62,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE60B2630),
                        border: Border.all(
                          color: _nodeDragInvalid == null
                              ? ZamerColors.accent.withValues(alpha: .34)
                              : const Color(0xFFF6B35B),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                        child: Text(
                          _nodeDragInvalid ??
                          'X: ${floor.nodeById(_dragNodeId!)?.xMm.round() ?? 0}  '
                          'Y: ${floor.nodeById(_dragNodeId!)?.yMm.round() ?? 0} мм'
                          ' · ${_dragSnap?.kind.label ?? 'Без привязки'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _nodeDragInvalid == null
                                ? ZamerColors.accent
                                : const Color(0xFFF6B35B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.planTool == MeasurePlanTool.openings &&
                  _openingSnapHint != null)
                Positioned(
                  left: 12,
                  bottom: 62,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xDF0B2630),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(_openingSnapHint!,
                          style: const TextStyle(fontSize: 10,
                              color: ZamerColors.accent)),
                      ),
                    ),
                  ),
                ),
              // Opening placement only needs a small contextual hint,
              // not another full-width toolbar over the apartment.
              if (widget.planTool == MeasurePlanTool.openings &&
                  _selectedOpening == null && !_moveCameraInsteadOfDrawing)
                Positioned(
                  key: const ValueKey('compact-opening-hint'),
                  left: 8,
                  top: widget.nativeKitV2 ? 55 : 8,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE80C1B20),
                        border: Border.all(color: ZamerColors.outlineSoft),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                        child: Text('Коснитесь стены, чтобы добавить проём',
                          style: TextStyle(
                            fontSize: 10, color: ZamerColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
              if (_editingGeometry &&
                  widget.planTool != MeasurePlanTool.openings)
                Positioned(
                  key: const ValueKey('compact-wall-tools'),
                  left: 8,
                  width: math.min(282.0, math.max(1.0, _viewport.width - 16)),
                  top: widget.nativeKitV2 ? 65 : null,
                  bottom: widget.nativeKitV2 ? null : 8,
                  child: _compactEditingBar(),
                ),
              Positioned(
                right: 8,
                bottom: _editingGeometry ? 60 : 8,
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _small(Icons.remove_rounded, onZoomOut),
          const SizedBox(width: 5),
          _small(Icons.add_rounded, onZoomIn),
          const SizedBox(width: 5),
          _small(Icons.center_focus_strong_rounded, onFit),
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
    required this.onResize,
    required this.onShift,
    required this.onDelete,
  });
  final PlanWall wall;
  final FloorPlan floor;
  final VoidCallback onEdit;
  final VoidCallback onResize;
  final VoidCallback onShift;
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
                            if (value == 'resize') onResize();
                            if (value == 'shift') onShift();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Изменить стену'),
                            ),
                            PopupMenuItem(
                              value: 'resize',
                              child: Text('Изменить длину'),
                            ),
                            PopupMenuItem(
                              value: 'shift',
                              child: Text('Сдвинуть стену'),
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
                          'Длина по оси',
                          '${floor.wallLengthMm(wall).round()} мм',
                          onTap: onResize,
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

  Widget _metric(String label, String value, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          key: label == 'Длина по оси' ? const ValueKey('selected-wall-length') : null,
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
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
                  if (onTap != null)
                    const Icon(
                      Icons.edit_outlined,
                      size: 9,
                      color: ZamerColors.accent,
                    ),
                ],
              ),
            ],
          ),
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
