import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_mounting.dart';
import '../models/electrical_design_draft.dart';
import '../services/electrical_design_engine.dart';
import '../widgets/electrical_consumer_draft_editor.dart';
import '../services/electrical_mounting_service.dart';
import '../services/electrical_frame_geometry.dart';
import '../services/electrical_snap_service.dart';
import '../widgets/electrical_mounting_editor.dart';
import '../widgets/electrical_point_properties.dart';
import '../widgets/electrical_compact_inspector.dart';
import '../widgets/electrical_junction_editor.dart';
import '../models/electrical_network.dart';
import '../services/electrical_junction_edit_service.dart';
import '../services/geometry_service.dart';
import '../widgets/electrical_plan_painter.dart';
import '../widgets/electrical_cable_journal_sheet.dart';
import '../widgets/electrical_crossing_sheet.dart';
import '../widgets/electrical_wall_elevation_screen.dart';
import '../widgets/electrical_wall_face_screen.dart';
import '../models/electrical_wall_face.dart';
import '../models/electrical_finished_reveal.dart';
import '../services/electrical_opening_reveal_service.dart';
import '../services/electrical_datum_assignment_service.dart';
import '../services/electrical_wall_face_service.dart';
import '../widgets/cad_plan_painter.dart';
import '../services/plan_visibility_service.dart';
import '../services/plan_viewport_link.dart';
import '../services/electrical_board_draft_service.dart';

enum ElectricalMode { add, wire, select }

/// Three task-level surfaces. Editing action (add/wire/select) stays separate.
enum ElectricalWorkspaceView { pointsRoutes, loads, board }
enum ElectricalBoardView { layout, wiring, checks }

class ElectricalScreen extends StatefulWidget {
  const ElectricalScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.requestedMode,
    this.requestedType,
    this.embedded = false,
    this.sharedViewport,
    this.viewportActive = true,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final ElectricalMode? requestedMode;
  final ElectricalPointType? requestedType;
  final bool embedded;
  final ValueNotifier<PlanViewportSnapshot?>? sharedViewport;
  final bool viewportActive;

  @override
  State<ElectricalScreen> createState() => _ElectricalScreenState();
}

class _ElectricalScreenState extends State<ElectricalScreen> {
  ElectricalMode _mode = ElectricalMode.add;
  ElectricalWorkspaceView _workspaceView = ElectricalWorkspaceView.pointsRoutes;
  ElectricalBoardView _boardView = ElectricalBoardView.layout;
  bool _addArcOpen = false;
  int _fanOuterIndex = 0;
  double _fanScrollAccumulation = 0;
  final GlobalKey _planCanvasKey = GlobalKey();
  final GlobalKey _fanGeometryKey = GlobalKey();
  Offset? _placingAt;
  ElectricalPointType _type = ElectricalPointType.socket;
  String _cable = 'ВВГнг-LS 3×1.5';
  String _routeMode = 'orthogonal';
  String? _wireStartId;
  String? _selectedId;
  /// Physical cable routes and sketch lines are hidden by default.
  bool _show3dRoutes = false;
  bool _showCrossings = false;
  bool _showLegacyLines = false;
  bool _showLights = true;
  bool _showPower = true;
  bool _showJunctions = true;

  Set<ElectricalPointType> get _visiblePointTypes {
    final all = <ElectricalPointType>{};
    if (_showLights) all.addAll([
      ElectricalPointType.ceilingLight,
      ElectricalPointType.wallLight,
    ]);
    if (_showPower) all.addAll([
      ElectricalPointType.socket,
      ElectricalPointType.switchPoint,
      ElectricalPointType.tvSocket,
      ElectricalPointType.dataSocket,
      ElectricalPointType.frame,
      ElectricalPointType.appliance,
      ElectricalPointType.panel,
    ]);
    if (_showJunctions) all.add(ElectricalPointType.junctionBox);
    return all;
  }
  String? _routeCircuitFilterId;
  String? _dragPointId;
  bool _dragUndoPushed = false;
  String? _dragProblem;
  final _undo = <String>[];
  final _redo = <String>[];
  PlanViewportSnapshot? _camera;
  Size _viewportSize = Size.zero;
  final Map<int, Offset> _touches = <int, Offset>{};
  math.Point<double>? _pinchWorldAnchor;
  double _pinchStartDistance = 1;
  double _pinchStartScale = .1;
  bool _pinchingCamera = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.requestedMode ?? _mode;
    _type = widget.requestedType ?? _type;
    if (widget.embedded && widget.viewportActive) _camera = widget.sharedViewport?.value;
  }

  @override
  void didUpdateWidget(covariant ElectricalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedded && widget.viewportActive &&
        (!oldWidget.viewportActive || widget.sharedViewport != oldWidget.sharedViewport)) {
      _camera = widget.sharedViewport?.value;
    }
    if (widget.requestedMode != oldWidget.requestedMode &&
        widget.requestedMode != null) {
      _mode = widget.requestedMode!;
      _wireStartId = null;
    }
    if (widget.requestedType != oldWidget.requestedType &&
        widget.requestedType != null) {
      _type = widget.requestedType!;
    }
  }

  void _publishCamera() {
    if (!widget.embedded || !widget.viewportActive) return;
    final camera = _camera;
    final link = widget.sharedViewport;
    if (camera == null || !camera.valid || link == null) return;
    if (link.value case final old?) {
      if (old.nearlyEquals(camera)) return;
    }
    link.value = camera;
  }

  void _touchDown(PointerDownEvent e) {
    _touches[e.pointer] = e.localPosition;
    if (_touches.length != 2 || _viewportSize.isEmpty) return;
    final points = _touches.values.toList();
    final midpoint = (points[0] + points[1]) / 2;
    final tx = _tx(_viewportSize);
    _pinchWorldAnchor = math.Point<double>(
      (midpoint.dx - tx.origin.dx) / tx.scale,
      (midpoint.dy - tx.origin.dy) / tx.scale,
    );
    _pinchStartScale = tx.scale;
    _pinchStartDistance = math.max(1, (points[1] - points[0]).distance);
    _pinchingCamera = true;
    // If a second finger arrives during electrical-point dragging, restore
    // the point's previous geometry before turning this into camera pinch.
    // Otherwise a half-dragged socket can survive without an undo/save.
    if (_dragPointId != null && _dragUndoPushed && _undo.isNotEmpty) {
      final before = jsonDecode(_undo.removeLast()) as Map;
      widget.floor.restoreFrom(
        FloorPlan.fromJson(Map<String, dynamic>.from(before)));
    }
    _dragPointId = null;
    _dragUndoPushed = false;
    _dragProblem = null;
    _placingAt = null;
    _wireStartId = null;
  }

  void _touchMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    if (!_pinchingCamera || _touches.length != 2 ||
        _pinchWorldAnchor == null || _viewportSize.isEmpty) return;
    final points = _touches.values.toList();
    final midpoint = (points[0] + points[1]) / 2;
    final spread = math.max(1, (points[1] - points[0]).distance);
    final scale = (_pinchStartScale * spread / _pinchStartDistance)
        .clamp(.004, .8).toDouble();
    final origin = Offset(
      midpoint.dx - _pinchWorldAnchor!.x * scale,
      midpoint.dy - _pinchWorldAnchor!.y * scale,
    );
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final camera = PlanViewportSnapshot(
      centerXMm: (center.dx - origin.dx) / scale,
      centerYMm: (center.dy - origin.dy) / scale,
      pixelsPerMm: scale,
    );
    if (!camera.valid) return;
    setState(() => _camera = camera);
    _publishCamera();
  }

  void _touchEnd(PointerEvent e) {
    _touches.remove(e.pointer);
    if (_touches.isEmpty) {
      _pinchingCamera = false;
      _pinchWorldAnchor = null;
      _publishCamera();
    }
  }

  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';

  void _pushUndo() {
    _undo.add(jsonEncode(widget.floor.toJson()));
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> _undoAction() async {
    if (_undo.isEmpty) return;
    _redo.add(jsonEncode(widget.floor.toJson()));
    widget.floor.restoreFrom(
      FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(_undo.removeLast()) as Map),
      ),
    );
    _wireStartId = null;
    _selectedId = null;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _redoAction() async {
    if (_redo.isEmpty) return;
    _undo.add(jsonEncode(widget.floor.toJson()));
    widget.floor.restoreFrom(
      FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(_redo.removeLast()) as Map),
      ),
    );
    _wireStartId = null;
    _selectedId = null;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  _Tx _tx(Size size) {
    final linked = widget.embedded ? (_camera ?? widget.sharedViewport?.value) : null;
    if (linked != null && linked.valid) {
      final scale = linked.pixelsPerMm;
      return _Tx(scale: scale, origin: Offset(
        size.width / 2 - linked.centerXMm * scale,
        size.height / 2 - linked.centerYMm * scale,
      ));
    }
    final pts = <math.Point<double>>[];
    for (final n in widget.floor.nodes) pts.add(math.Point(n.xMm, n.yMm));
    for (final e in widget.floor.electricalPoints)
      pts.add(math.Point(e.xMm, e.yMm));
    if (pts.isEmpty)
      return _Tx(scale: 0.08, origin: Offset(size.width / 2, size.height / 2));
    var minX = pts.first.x,
        maxX = pts.first.x,
        minY = pts.first.y,
        maxY = pts.first.y;
    for (final p in pts.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final w = math.max(1000.0, maxX - minX);
    final h = math.max(1000.0, maxY - minY);
    final scale = math.min((size.width - 36) / w, (size.height - 36) / h);
    return _Tx(
      scale: scale,
      origin: Offset(
        (size.width - w * scale) / 2 - minX * scale,
        (size.height - h * scale) / 2 - minY * scale,
      ),
    );
  }

  ElectricalPoint? _near(math.Point<double> p, double thresholdMm) {
    ElectricalPoint? best;
    var dBest = thresholdMm;
    for (final e in widget.floor.electricalPoints) {
      if (!_visiblePointTypes.contains(e.type)) continue;
      final dx = e.xMm - p.x;
      final dy = e.yMm - p.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < dBest) {
        dBest = d;
        best = e;
      }
    }
    return best;
  }

  _WallHit? _nearestWall(math.Point<double> p, {double maxDistanceMm = 550}) {
    _WallHit? best;
    for (final wall in widget.floor.walls) {
      final a = widget.floor.nodeById(wall.startNodeId);
      final b = widget.floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final dx = b.xMm - a.xMm;
      final dy = b.yMm - a.yMm;
      final l2 = dx * dx + dy * dy;
      if (l2 < 1) continue;
      final t = (((p.x - a.xMm) * dx + (p.y - a.yMm) * dy) / l2)
          .clamp(0.0, 1.0)
          .toDouble();
      final x = a.xMm + dx * t;
      final y = a.yMm + dy * t;
      final ddx = p.x - x;
      final ddy = p.y - y;
      final distance = math.sqrt(ddx * ddx + ddy * ddy);
      if (distance > maxDistanceMm) continue;
      final len = math.sqrt(l2);
      final hit = _WallHit(
        wall: wall,
        point: math.Point(x, y),
        offsetMm: len * t,
        distanceMm: distance,
      );
      if (best == null || hit.distanceMm < best.distanceMm) best = hit;
    }
    return best;
  }

  bool _hasSwitch(
    ElectricalPointType type, [
    List<ElectricalModuleType>? modules,
  ]) =>
      type == ElectricalPointType.switchPoint ||
      (modules ?? const <ElectricalModuleType>[]).any(
        (m) =>
            m == ElectricalModuleType.switch1 ||
            m == ElectricalModuleType.switch2,
      );

  _WallHit? _clearOfDoor(_WallHit hit, bool switchDevice) {
    if (!switchDevice) return hit;
    final wall = hit.wall;
    final a = widget.floor.nodeById(wall.startNodeId);
    final b = widget.floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return null;
    final len = widget.floor.wallLengthMm(wall);
    double offset = hit.offsetMm;
    const clearance = 120.0;
    for (final door in wall.openings.where((o) => o.type == OpeningType.door)) {
      final before = door.offsetFromStartMm - clearance;
      final after = door.offsetFromStartMm + door.widthMm + clearance;
      if (offset >= before && offset <= after) {
        final options = [before - 1, after + 1]
            .where((v) => v >= clearance && v <= len - clearance)
            .where(
              (v) => wall.openings
                  .where((o) => o.type == OpeningType.door)
                  .every(
                    (o) =>
                        v < o.offsetFromStartMm - clearance ||
                        v > o.offsetFromStartMm + o.widthMm + clearance,
                  ),
            )
            .toList();
        if (options.isEmpty) return null;
        options.sort(
          (x, y) => (x - offset).abs().compareTo((y - offset).abs()),
        );
        offset = options.first;
      }
    }
    final t = len <= 0 ? 0.0 : offset / len;
    return _WallHit(
      wall: wall,
      point: math.Point(
        a.xMm + (b.xMm - a.xMm) * t,
        a.yMm + (b.yMm - a.yMm) * t,
      ),
      offsetMm: offset,
      distanceMm: hit.distanceMm,
    );
  }

  math.Point<double> _screenToMm(Offset p, Size size) {
    final t = _tx(size);
    return math.Point<double>(
      (p.dx - t.origin.dx) / t.scale,
      (p.dy - t.origin.dy) / t.scale,
    );
  }

  double _activePlanScale() => _viewportSize.isEmpty
      ? .08 : _tx(_viewportSize).scale;

  _WallHit _snapWallHit(_WallHit hit) {
    final wall = hit.wall;
    final a = widget.floor.nodeById(wall.startNodeId);
    final b = widget.floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return hit;
    final length = widget.floor.wallLengthMm(wall);
    final station = ElectricalSnapService.wallOffset(
        widget.floor, wall, hit.offsetMm, _activePlanScale());
    if (length <= 0) return hit;
    final t = station / length;
    return _WallHit(
      wall: wall,
      point: math.Point<double>(
        a.xMm + (b.xMm - a.xMm) * t,
        a.yMm + (b.yMm - a.yMm) * t,
      ),
      offsetMm: station,
      distanceMm: hit.distanceMm,
    );
  }

  void _movePoint(ElectricalPoint point, math.Point<double> raw) {
    if (_needsWall(point.type) || (point.type == ElectricalPointType.junctionBox && point.wallId != null)) {
      final rawHit = _nearestWall(raw,
          maxDistanceMm: ElectricalSnapService.captureMm(
              _activePlanScale(), capturePx: 32));
      final hit = rawHit == null
          ? null
          : _clearOfDoor(_snapWallHit(rawHit),
              _hasSwitch(point.type, point.modules));
      if (hit != null) {
        point.wallSide = _sideOfWall(hit.wall, raw, point.wallSide);
        point.xMm = hit.point.x;
        point.yMm = hit.point.y;
        point.wallId = hit.wall.id;
        point.wallOffsetMm = hit.offsetMm;
      }
      return;
    }
    final guided = point.type == ElectricalPointType.ceilingLight
        ? ElectricalSnapService.light(
            widget.floor, raw, _activePlanScale(),
            movingPointId: point.id).position
        : raw;
    final step = ElectricalSnapService.stepMm(_activePlanScale());
    point.xMm = point.type == ElectricalPointType.ceilingLight
        ? guided.x : (guided.x / step).round() * step;
    point.yMm = point.type == ElectricalPointType.ceilingLight
        ? guided.y : (guided.y / step).round() * step;
    point.wallId = null;
    point.wallOffsetMm = null;
  }

  int _sideOfWall(PlanWall wall, math.Point<double> raw, int fallback) {
    // The lone face of an exterior wall must point into its room, even when
    // the tap falls on the outer half of the thick wall stroke.
    final roomEdges = GeometryService.roomFaces(widget.floor)
        .expand((room) => room.edges)
        .where((edge) => edge.wallId == wall.id)
        .toList();
    if (roomEdges.length == 1) {
      return roomEdges.single.fromNodeId == wall.startNodeId ? 1 : -1;
    }
    final a = widget.floor.nodeById(wall.startNodeId);
    final b = widget.floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return fallback;
    final cross =
        (b.xMm - a.xMm) * (raw.y - a.yMm) - (b.yMm - a.yMm) * (raw.x - a.xMm);
    final length = math.sqrt(
      math.pow(b.xMm - a.xMm, 2) + math.pow(b.yMm - a.yMm, 2),
    );
    return cross.abs() < wall.thicknessMm * length * 0.6
        ? fallback
        : (cross > 0 ? 1 : -1);
  }

  void _dragStart(DragStartDetails d, Size size) {
    if (_pinchingCamera || _touches.length > 1) return;
    if (_mode != ElectricalMode.select) return;
    final mm = _screenToMm(d.localPosition, size);
    final t = _tx(size);
    final point = _near(mm, math.max(160.0, 28 / math.max(t.scale, 0.001)));
    setState(() {
      _dragPointId = point?.id;
      _selectedId = point?.id;
      _dragUndoPushed = false;
      _dragProblem = null;
    });
  }

  void _dragUpdate(DragUpdateDetails d, Size size) {
    if (_pinchingCamera || _touches.length > 1) return;
    if (_mode != ElectricalMode.select || _dragPointId == null) return;
    final point = widget.floor.electricalPoints
        .where((p) => p.id == _dragPointId).firstOrNull;
    if (point == null) return;
    // Evaluate a detached point: invalid drag frames must never mutate plan.
    final proposed = ElectricalPoint.fromJson(point.toJson());
    _movePoint(proposed, _screenToMm(d.localPosition, size));
    final issue = ElectricalFrameGeometry.placementIssue(
        widget.floor, proposed) ??
        ElectricalFrameGeometry.conflictWithFrames(widget.floor, proposed);
    if (issue != null) {
      setState(() => _dragProblem = issue);
      return;
    }
    final changed = proposed.xMm != point.xMm ||
        proposed.yMm != point.yMm ||
        proposed.wallId != point.wallId ||
        proposed.wallSide != point.wallSide ||
        proposed.wallOffsetMm != point.wallOffsetMm;
    if (!changed) {
      if (_dragProblem != null) setState(() => _dragProblem = null);
      return;
    }
    if (!_dragUndoPushed) {
      _pushUndo();
      _dragUndoPushed = true;
    }
    point.xMm = proposed.xMm;
    point.yMm = proposed.yMm;
    point.wallId = proposed.wallId;
    point.wallOffsetMm = proposed.wallOffsetMm;
    point.wallSide = proposed.wallSide;
    setState(() => _dragProblem = null);
  }

  Future<void> _dragEnd(DragEndDetails d) async {
    if (_mode != ElectricalMode.select || _dragPointId == null) return;
    final error = _dragProblem;
    if (error != null && _dragUndoPushed && _undo.isNotEmpty) {
      final snapshot = jsonDecode(_undo.removeLast()) as Map;
      widget.floor.restoreFrom(
          FloorPlan.fromJson(Map<String, dynamic>.from(snapshot)));
    } else if (error == null && _dragUndoPushed) {
      await widget.onChanged();
    }
    if (mounted) {
      setState(() {
        _dragPointId = null;
        _dragUndoPushed = false;
        _dragProblem = null;
      });
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Перемещение отменено: $error')));
      }
    }
  }

  bool _needsWall(ElectricalPointType type) => {
    ElectricalPointType.wallLight,
    ElectricalPointType.switchPoint,
    ElectricalPointType.socket,
    ElectricalPointType.tvSocket,
    ElectricalPointType.dataSocket,
    ElectricalPointType.frame,
    ElectricalPointType.panel,
    ElectricalPointType.appliance,
  }.contains(type);

  double _defaultHeight(ElectricalPointType type) {
    if ({
      ElectricalPointType.socket,
      ElectricalPointType.tvSocket,
      ElectricalPointType.dataSocket,
      ElectricalPointType.frame,
    }.contains(type)) {
      return widget.floor.defaultSocketHeightMm;
    }
    return switch (type) {
      ElectricalPointType.ceilingLight => widget.floor.defaultHeightMm,
      ElectricalPointType.wallLight => widget.floor.defaultWallLightHeightMm,
      ElectricalPointType.switchPoint => widget.floor.defaultSwitchHeightMm,
      ElectricalPointType.junctionBox => 2200,
      ElectricalPointType.panel => 1500,
      ElectricalPointType.appliance => widget.floor.defaultSocketHeightMm,
      _ => widget.floor.defaultSocketHeightMm,
    };
  }

  List<ElectricalModuleType> _defaultModules(ElectricalPointType type) =>
      switch (type) {
        ElectricalPointType.switchPoint => [ElectricalModuleType.switch1],
        ElectricalPointType.tvSocket => [ElectricalModuleType.tv],
        ElectricalPointType.dataSocket => [ElectricalModuleType.data],
        ElectricalPointType.frame => [
          ElectricalModuleType.socket220,
          ElectricalModuleType.socket220,
        ],
        _ => [ElectricalModuleType.socket220],
      };

  Future<void> _tap(TapUpDetails d, Size size) async {
    if (_pinchingCamera) return;
    final t = _tx(size);
    final mm = math.Point<double>(
      (d.localPosition.dx - t.origin.dx) / t.scale,
      (d.localPosition.dy - t.origin.dy) / t.scale,
    );
    if (_mode == ElectricalMode.add) {
      final scale = _activePlanScale();
      final guided = _type == ElectricalPointType.ceilingLight
          ? ElectricalSnapService.light(widget.floor, mm, scale).position
          : mm;
      final step = ElectricalSnapService.stepMm(scale);
      var x = _type == ElectricalPointType.ceilingLight
          ? guided.x : ((guided.x / step).round() * step).toDouble();
      var y = _type == ElectricalPointType.ceilingLight
          ? guided.y : ((guided.y / step).round() * step).toDouble();
      String? wallId;
      double? wallOffset;
      var wallSide = 1;
      if (_needsWall(_type)) {
        final rawHit = _nearestWall(mm,
            maxDistanceMm: ElectricalSnapService.captureMm(
                scale, capturePx: 32));
        final hit = rawHit == null
            ? null
            : _clearOfDoor(_snapWallHit(rawHit),
                _hasSwitch(_type, _defaultModules(_type)));
        if (hit == null) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Выбери свободное место на стене вне дверного проёма.',
                ),
              ),
            );
          return;
        }
        x = hit.point.x;
        y = hit.point.y;
        wallId = hit.wall.id;
        wallOffset = hit.offsetMm;
        wallSide = _sideOfWall(hit.wall, mm, 1);
      }
      final created = ElectricalPoint(
        id: _id('ep'),
        type: _type,
        xMm: x,
        yMm: y,
        heightMm: _defaultHeight(_type),
        wallId: wallId,
        wallOffsetMm: wallOffset,
        wallSide: wallSide,
        modules: _defaultModules(_type),
      );
      final frameIssue = ElectricalFrameGeometry.placementIssue(
          widget.floor, created) ??
          ElectricalFrameGeometry.conflictWithFrames(widget.floor, created);
      if (frameIssue != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(frameIssue)),
          );
        }
        return;
      }
      _pushUndo();
      widget.floor.electricalPoints.add(created);
      await widget.onChanged();
      if (mounted) setState(() => _selectedId = created.id);
      if (_type == ElectricalPointType.frame && mounted)
        await _pointSheet(created);
      return;
    }

    final point = _near(mm,
        ElectricalSnapService.captureMm(t.scale, capturePx: 20));
    if (point == null) return;
    if (_mode == ElectricalMode.select) {
      setState(() {
        _selectedId = point.id;
        });
      // Embedded CAD uses a persistent one-row inspector. Keep the legacy
      // stand-alone editor interaction compatible with existing projects/tests.
      if (!widget.embedded) await _pointSheet(point);
      return;
    }
    if (_mode == ElectricalMode.wire) {
      if (_wireStartId == null) {
        setState(() => _wireStartId = point.id);
        return;
      }
      if (_wireStartId == point.id) {
        setState(() => _wireStartId = null);
        return;
      }
      final exists = widget.floor.electricalRuns.any(
        (r) =>
            (r.startPointId == _wireStartId && r.endPointId == point.id) ||
            (r.startPointId == point.id && r.endPointId == _wireStartId),
      );
      if (!exists) {
        _pushUndo();
        widget.floor.electricalRuns.add(
          ElectricalRun(
            id: _id('er'),
            startPointId: _wireStartId!,
            endPointId: point.id,
            cable: _cable,
            routeMode: _routeMode,
          ),
        );
        await widget.onChanged();
      }
      setState(() => _wireStartId = point.id);
    }
  }

  String _mm(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Future<void> _editConsumerDraftDirect(ElectricalPoint point) async {
    final previous = widget.floor.electricalDesignDraft?.consumers[point.id];
    final next = await showModalBottomSheet<ElectricalConsumerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ElectricalConsumerDraftEditor(
        point: point, initial: previous),
    );
    if (!mounted || next == null) return;
    _pushUndo();
    final draft = widget.floor.electricalDesignDraft ?? ElectricalDesignDraft();
    draft.consumers[point.id] = next;
    widget.floor.electricalDesignDraft = draft;
    await widget.onChanged();
    if (mounted) setState(() => _selectedId = point.id);
  }

  Future<void> _editSupplySettings() async {
    final initial = widget.floor.electricalDesignDraft?.settings ??
        const ElectricalSupplyDraft();
    var phases = initial.phasesCount;
    final rated = TextEditingController(
        text: initial.inputBreakerAmps?.toString() ?? '');
    final allowed = TextEditingController(
        text: initial.approvedInputPowerKw?.toString() ?? '');
    final factor = TextEditingController(text: initial.powerFactor.toString());
    try {
      final next = await showDialog<ElectricalSupplyDraft>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, setDialogState) => AlertDialog(
            title: const Text('Параметры ввода (проектные)'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1 фаза')),
                    ButtonSegment(value: 3, label: Text('3 фазы')),
                  ],
                  selected: {phases},
                  onSelectionChanged: (v) =>
                      setDialogState(() => phases = v.first),
                ),
                TextField(
                  controller: allowed,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Подтверждённая выделенная мощность',
                    suffixText: 'кВт'),
                ),
                TextField(
                  controller: rated,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Вводной аппарат (если известен)',
                    suffixText: 'А'),
                ),
                TextField(
                  controller: factor,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'cos φ (допущение)'),
                ),
                const SizedBox(height: 6),
                const Text('Номинал вводного аппарата не выводится '
                    'автоматически из выделенной мощности.'),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog),
                  child: const Text('Отмена')),
              FilledButton(
                onPressed: () {
                  try {
                    double? optional(TextEditingController c) =>
                        c.text.trim().isEmpty ? null :
                        double.tryParse(c.text.replaceAll(',', '.'));
                    final value = ElectricalSupplyDraft(
                      phasesCount: phases,
                      inputBreakerAmps: optional(rated),
                      approvedInputPowerKw: optional(allowed),
                      powerFactor:
                        double.tryParse(factor.text.replaceAll(',', '.')) ??
                            double.nan,
                    );
                    value.validate();
                    Navigator.pop(dialog, value);
                  } on FormatException catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.message)));
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      );
      if (next == null || !mounted) return;
      _pushUndo();
      final draft = widget.floor.electricalDesignDraft ??
          ElectricalDesignDraft();
      draft.settings = next;
      widget.floor.electricalDesignDraft = draft;
      await widget.onChanged();
      if (mounted) setState(() {});
    } finally {
      rated.dispose();
      allowed.dispose();
      factor.dispose();
    }
  }

  Future<void> _selectManualPhase(ElectricalLineProposal line) async {
    final draft = widget.floor.electricalDesignDraft;
    if (draft == null) return;
    final current = draft.lineOverrides[line.id];
    final choice = await showModalBottomSheet<ElectricalPhase>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text('Фаза • ${line.id}')),
          for (final (phase, label) in const [
            (ElectricalPhase.unassigned, 'Автобалансировка'),
            (ElectricalPhase.l1, 'Закрепить L1'),
            (ElectricalPhase.l2, 'Закрепить L2'),
            (ElectricalPhase.l3, 'Закрепить L3'),
          ])
            ListTile(
              title: Text(label),
              trailing: line.phase == phase
                  ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheet, phase),
            ),
        ],
      )),
    );
    if (choice == null || !mounted) return;
    final locks = <String>{...?current?.lockedFields};
    if (choice == ElectricalPhase.unassigned) {
      locks.remove('phase');
    } else {
      locks.add('phase');
    }
    final next = ElectricalLineManualDraft(
      lineId: line.id,
      phase: choice,
      protection: current?.protection ?? ElectricalProtection.unknown,
      rcdId: current?.rcdId,
      breakerAmps: current?.breakerAmps,
      cableSectionMm2: current?.cableSectionMm2,
      adjustedAmpacityAmps: current?.adjustedAmpacityAmps,
      rcdLeakageMa: current?.rcdLeakageMa,
      rcdRatedAmps: current?.rcdRatedAmps,
      moduleRow: current?.moduleRow,
      moduleIndex: current?.moduleIndex,
      pointIdsSnapshot: List<String>.from(line.pointIds)..sort(),
      lockedFields: locks,
    );
    _pushUndo();
    draft.lineOverrides[line.id] = next;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _editMountingDirect(ElectricalPoint point) async {
    if (point.wallId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала закрепи точку на стене.'),
      ));
      return;
    }
    final next = await Navigator.of(context).push<ElectricalMounting>(
      MaterialPageRoute(
        builder: (_) => ElectricalMountingEditor(
          floor: widget.floor, point: point),
      ),
    );
    if (!mounted || next == null) return;
    try {
      // Verify a detached copy before pushing undo history.
      ElectricalMountingService.apply(widget.floor,
          ElectricalPoint.fromJson(point.toJson()), next);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)));
      return;
    }
    _pushUndo();
    ElectricalMountingService.apply(widget.floor, point, next);
    await widget.onChanged();
    if (mounted) setState(() => _selectedId = point.id);
  }

  Future<void> _editPropertiesDirect(ElectricalPoint point) async {
    final next = await showModalBottomSheet<ElectricalPoint>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ElectricalPointProperties(
        point: point,
        circuits: widget.floor.electricalPoints
            .map((p) => p.circuit).toSet().toList(),
      ),
    );
    if (!mounted || next == null) return;
    final frameIssue = ElectricalFrameGeometry.placementIssue(
        widget.floor, next) ??
        ElectricalFrameGeometry.conflictWithFrames(widget.floor, next);
    if (frameIssue != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(frameIssue)));
      return;
    }
    _pushUndo();
    point.label = next.label;
    point.circuit = next.circuit;
    point.powerW = next.powerW;
    point.heightMm = next.heightMm;
    point.modules
      ..clear()
      ..addAll(next.modules);
    point.frameVertical = next.frameVertical;
    point.modulePitchMm = next.modulePitchMm;
    point.type = next.type;
    await widget.onChanged();
    if (!mounted) return;
    setState(() => _selectedId = point.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Точка сохранена'),
      action: SnackBarAction(label: 'Отменить', onPressed: _undoAction),
    ));
  }

  Future<void> _pointSheet(ElectricalPoint p) async {
    final canMount =
        p.isWallDevice || p.type == ElectricalPointType.junctionBox;
    final issue = canMount
        ? ElectricalMountingService.problem(widget.floor, p)
        : null;
    final mounting = issue == null ? p.mounting : null;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.label.isEmpty ? p.type.label : p.label,
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть карточку',
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${p.circuit.trim().isEmpty ? 'Без группы' : p.circuit} · '
                'Высота ${_mm(p.heightMm)} мм от чистого пола',
              ),
              if (mounting != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_mm(mounting.distanceMm)} мм · ${mounting.datumName}',
                  ),
                ),
              if (issue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    issue,
                    style: TextStyle(color: p.mounting == null
                      ? Theme.of(sheet).colorScheme.onSurfaceVariant
                      : Theme.of(sheet).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              if (canMount)
                FilledButton.icon(
                  key: const ValueKey('edit-mounting'),
                  onPressed: () => Navigator.pop(sheet, 'mount'),
                  icon: const Icon(Icons.straighten),
                  label: const Text('Размеры и положение'),
                ),
              if (p.type == ElectricalPointType.junctionBox)
                OutlinedButton.icon(
                  key: const ValueKey('junction-connections'),
                  onPressed: () => Navigator.pop(sheet, 'junction'),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Кабели и клеммы'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('electrical-consumer-classify'),
                onPressed: () => Navigator.pop(sheet, 'consumer'),
                icon: const Icon(Icons.category_outlined),
                label: const Text('Потребитель и расчёт'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('edit-point-properties'),
                onPressed: () => Navigator.pop(sheet, 'properties'),
                icon: const Icon(Icons.tune),
                label: const Text('Свойства и группа'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, 'delete'),
                child: const Text('Удалить точку'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'mount') {
      await _editMountingDirect(p);
      return;
    } else if (action == 'properties') {
      await _editPropertiesDirect(p);
      return;
    } else if (action == 'consumer') {
      await _editConsumerDraftDirect(p);
      return;
    } else if (action == 'junction') {
      final before = jsonEncode(widget.floor.toJson());
      final updated = await Navigator.of(context).push<ElectricalNetwork>(
        MaterialPageRoute(
          builder: (_) => ElectricalJunctionEditor(
            floor: widget.floor, junctionPointId: p.id,
          ),
        ),
      );
      if (!mounted || updated == null) return;
      if (jsonEncode(widget.floor.toJson()) != before) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Проект изменился. Откройте редактор коробки заново.'),
        ));
        return;
      }
      try {
        ElectricalJunctionEditService.validateForSave(
          widget.floor, p.id, updated,
        );
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
      final serialized = jsonEncode(updated.toJson());
      if (widget.floor.electricalNetwork != null &&
          serialized == jsonEncode(widget.floor.electricalNetwork!.toJson())) {
        return;
      }
      _pushUndo();
      widget.floor.electricalNetwork =
          ElectricalJunctionEditService.copy(updated);
      await widget.onChanged();
      if (!mounted) return;
      setState(() => _selectedId = p.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Соединения сохранены как черновая схема'),
        action: SnackBarAction(label: 'Отменить', onPressed: _undoAction),
      ));
      return;
    } else if (action == 'delete') {
      if (ElectricalJunctionEditService.pointInUse(
        widget.floor.electricalNetwork, p.id,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Точка участвует в схеме. Сначала удалите её связи.'),
        ));
        return;
      }
      _pushUndo();
      widget.floor.electricalRuns.removeWhere(
        (r) => r.startPointId == p.id || r.endPointId == p.id,
      );
      widget.floor.electricalPoints.removeWhere((e) => e.id == p.id);
    }
    await widget.onChanged();
    if (!mounted) return;
    setState(() => _selectedId = action == 'delete' ? null : p.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'delete'
              ? 'Точка удалена вместе с её линиями'
              : 'Точка сохранена',
        ),
        action: SnackBarAction(label: 'Отменить', onPressed: _undoAction),
      ),
    );
  }

  Future<void> _heightDefaults() async {
    final sockets = TextEditingController(
      text: widget.floor.defaultSocketHeightMm.round().toString(),
    );
    final switches = TextEditingController(
      text: widget.floor.defaultSwitchHeightMm.round().toString(),
    );
    final sconces = TextEditingController(
      text: widget.floor.defaultWallLightHeightMm.round().toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Высоты по умолчанию'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sockets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Розетки / TV / интернет',
                suffixText: 'мм',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: switches,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Выключатели',
                suffixText: 'мм',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sconces,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Бра',
                suffixText: 'мм',
              ),
            ),
          ],
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
    );
    if (ok != true) return;
    final a = double.tryParse(sockets.text.replaceAll(',', '.'));
    final b = double.tryParse(switches.text.replaceAll(',', '.'));
    final c = double.tryParse(sconces.text.replaceAll(',', '.'));
    if (a == null || b == null || c == null || a < 0 || b < 0 || c < 0) return;
    _pushUndo();
    widget.floor.defaultSocketHeightMm = a;
    widget.floor.defaultSwitchHeightMm = b;
    widget.floor.defaultWallLightHeightMm = c;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _saveWallFace(
      String wallId, int side, WallFaceFinish? finish) async {
    final wall = widget.floor.wallById(wallId);
    if (wall == null) throw const FormatException('Стена удалена.');
    ElectricalWallFaceService.validate(widget.floor, wall, side, finish);
    final previous = ElectricalWallFaceService.saved(wall, side);
    if (previous?.thicknessMm == finish?.thicknessMm &&
        previous?.source == finish?.source &&
        previous?.note == finish?.note &&
        (finish == null || (
          previous?.axisStartNodeId == wall.startNodeId &&
          previous?.axisEndNodeId == wall.endNodeId
        ))) return;
    _pushUndo();
    ElectricalWallFaceService.apply(widget.floor, wallId, side, finish);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _saveFinishedReveal(String wallId, String openingId,
      int side, ElectricalFinishedReveal? reveal) async {
    ElectricalOpeningRevealService.validate(
        widget.floor, wallId, openingId, side, reveal);
    final wall = widget.floor.wallById(wallId)!;
    final opening = wall.openings.singleWhere((o) => o.id == openingId);
    final old = ElectricalOpeningRevealService.saved(opening, side);
    final existingValid = ElectricalOpeningRevealService.problem(
        widget.floor, wallId, openingId, side) == null;
    if ((old == null && reveal == null) ||
        (existingValid && old != null && reveal != null &&
          old.startUMm == reveal.startUMm &&
          old.endUMm == reveal.endUMm &&
          old.source == reveal.source &&
          old.uncertaintyMm == reveal.uncertaintyMm &&
          old.note == reveal.note)) return;
    _pushUndo();
    ElectricalOpeningRevealService.apply(
        widget.floor, wallId, openingId, side, reveal);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _assignElectricalDatum(
      String pointId, String wallId, int side, String? datumId) async {
    final matches = widget.floor.electricalPoints
        .where((p) => p.id == pointId).toList();
    if (matches.length != 1) {
      throw const FormatException('Электроточка удалена или повторяется.');
    }
    final point = matches.single;
    if (datumId == null && point.datumAssignment == null) return;
    final detached = datumId == null ? null :
        ElectricalDatumAssignmentService.prepare(
            widget.floor, pointId, wallId, side, datumId);
    final existing = point.datumAssignment;
    if (existing != null && detached != null &&
        existing.geometrySnapshot == detached.geometrySnapshot &&
        existing.datumId == detached.datumId &&
        existing.pointUMm == detached.pointUMm &&
        existing.pointHeightMm == detached.pointHeightMm) return;
    _pushUndo();
    ElectricalDatumAssignmentService.apply(
        widget.floor, pointId, detached);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _showWallFaces() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ElectricalWallFaceScreen(
        floor: widget.floor,
        onSaveFace: _saveWallFace,
        onSaveReveal: _saveFinishedReveal,
        onAssignDatum: _assignElectricalDatum,
      )),
    );
  }

  Future<void> _showWallElevation() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ElectricalWallElevationScreen(
        floor: widget.floor,
        initialCircuitId: _routeCircuitFilterId,
        initialWallId: widget.floor.electricalPoints
            .where((p) => p.id == _selectedId).firstOrNull?.wallId,
      )),
    );
  }

  Future<void> _showCrossingsReview() async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => ElectricalCrossingSheet(
        floor: widget.floor,
        initialCircuitId: _routeCircuitFilterId,
        onCircuitChanged: (id) {
          if (!mounted) return;
          setState(() => _routeCircuitFilterId = id);
        },
      ),
    );
  }

  Future<void> _showCableJournal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ElectricalCableJournalSheet(
        floor: widget.floor,
        initialCircuitId: _routeCircuitFilterId,
        onCircuitChanged: (circuitId) {
          if (!mounted) return;
          setState(() {
            _routeCircuitFilterId = circuitId;
            _show3dRoutes = true;
          });
        },
      ),
    );
  }

  Widget _routeControls() {
    final id = _routeCircuitFilterId;
    final circuit = widget.floor.electricalNetwork?.circuits
        .where((c) => c.id == id).firstOrNull;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end, spacing: 2, runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('electrical-wall-elevation'),
            tooltip: 'Развёртка стены',
            icon: const Icon(Icons.architecture_outlined),
            onPressed: _showWallElevation,
          ),
          IconButton(
            key: const ValueKey('electrical-cable-journal'),
            tooltip: 'Кабельный журнал',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: _showCableJournal,
          ),
          PopupMenuButton<String>(
            key: const ValueKey('electrical-plan-layers'),
            tooltip: 'Слои проводки',
            icon: const Icon(Icons.layers_outlined),
            onSelected: (choice) {
              if (choice == 'faces') {
                _showWallFaces();
                return;
              }
              setState(() {
                if (choice == 'legacy') _showLegacyLines = !_showLegacyLines;
                if (choice == 'physical') _show3dRoutes = !_show3dRoutes;
                if (choice == 'lights') _showLights = !_showLights;
                if (choice == 'power') _showPower = !_showPower;
                if (choice == 'junctions') _showJunctions = !_showJunctions;
                if (choice == 'crossings') _showCrossings = !_showCrossings;
                if (choice == 'all') _routeCircuitFilterId = null;
              });
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'lights',
                checked: _showLights,
                child: const Text('Световые точки'),
              ),
              CheckedPopupMenuItem(
                value: 'power',
                checked: _showPower,
                child: const Text('Розетки, выключатели, щит'),
              ),
              CheckedPopupMenuItem(
                value: 'junctions',
                checked: _showJunctions,
                child: const Text('Распределительные коробки'),
              ),
              CheckedPopupMenuItem(
                key: const ValueKey('electrical-toggle-physical-routes'),
                value: 'physical',
                checked: _show3dRoutes,
                child: const Text('Физические трассы'),
              ),
              CheckedPopupMenuItem(
                value: 'legacy',
                checked: _showLegacyLines,
                child: const Text('Черновые линии'),
              ),
              CheckedPopupMenuItem(
                value: 'crossings',
                checked: _showCrossings,
                child: const Text('Маркеры пересечений'),
              ),
              const PopupMenuItem(
                value: 'faces',
                child: Text('Стороны и отделка стен'),
              ),
              PopupMenuItem(
                value: 'review',
                onTap: _showCrossingsReview,
                child: const Text('Журнал пересечений'),
              ),
              if (id != null)
                const PopupMenuItem(
                  value: 'all', child: Text('Все группы'),
                ),
            ],
          ),
          if (id != null)
            TextButton(
              key: const ValueKey('electrical-selected-route-group'),
              onPressed: () => setState(() => _routeCircuitFilterId = null),
              child: Text(circuit?.name ?? 'Сбросить группу',
                overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  Future<void> _showLoadInventory() async {
    final board = ElectricalBoardDraftService.create(widget.floor);
    final circuits = board.circuits;
    final total = board.knownConnectedWatts;
    final unrated = board.unratedLoads;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .75,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text('Нагрузки и распределительный щит',
                style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Известная подключённая мощность: ${total.toStringAsFixed(0)} Вт'
                   ' · групп: ${circuits.length}'),
              const SizedBox(height: 5),
              Text('Оценка по известным мощностям: '
                   '${board.knownLoadAmps.toStringAsFixed(1)} А '
                   'при ${board.voltageV.toStringAsFixed(0)} В / '
                   'cosφ ${board.powerFactor.toStringAsFixed(2)}. '
                   'Не является расчётным током щита.',
                   style: Theme.of(sheet).textTheme.bodySmall),
              if (unrated > 0) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Не указана нагрузка у ${unrated} точек. '
                  'Расчёт неполный: розетка без мощности не означает 0 Вт.',
                  style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              if (circuits.isEmpty)
                const Text('Добавь электроточки и присвой им группы '
                    'и расчётную мощность в карточках точек.'),
              for (final circuit in circuits)
                Card(
                  child: ListTile(
                    title: Text(circuit.load.name),
                    subtitle: Text(
                      '${circuit.load.loadCount} точек · '
                      '${circuit.load.connectedWatts.toStringAsFixed(0)} Вт'
                      ' · ≈${circuit.load.estimatedAmps.toStringAsFixed(1)} А '
                      '(известные нагрузки)\n'
                      '${circuit.runCount} трасс · '
                      '${circuit.routedCableMeters.toStringAsFixed(1)} м · '
                      '${circuit.cableTypes.isEmpty ? 'кабель не указан' : circuit.cableTypes.join(', ')}\n'
                      '${circuit.protectiveDeviceStatus}'),
                    isThreeLine: true,
                    trailing: circuit.incomplete || circuit.hasUnassignedCircuit
                      ? const Icon(Icons.warning_amber_rounded) : null,
                  ),
                ),
              if (board.crossCircuitRuns > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ошибка группировки: ${board.crossCircuitRuns} '
                    'кабельных линий связывают точки разных групп.',
                    style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Эскиз секций щита', style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Условная последовательность функций, без привязки '
                   'к DIN-модулям, номиналам и клеммам.',
                   style: Theme.of(sheet).textTheme.bodySmall),
              const SizedBox(height: 9),
              SizedBox(
                key: const ValueKey('electrical-board-section-draft'),
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final section in board.sections)
                      Container(
                        width: 103,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Theme.of(sheet).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Theme.of(sheet).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(section.label, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text(section.role, maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Text('Данные, необходимые для проекта щита',
                style: Theme.of(sheet).textTheme.titleMedium),
              for (final item in board.requiredChecks)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_box_outline_blank_rounded,
                        size: 17, color: Theme.of(sheet).colorScheme.outline),
                      const SizedBox(width: 7),
                      Expanded(child: Text(item,
                        style: Theme.of(sheet).textTheme.bodySmall)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text('Подбор автоматов и схема сборки щита',
                style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('Это предварительная ведомость, не готовая '
                'спецификация защитных аппаратов. Для подбора нужны '
                'сечение и материал жил, способ прокладки, длина линии, '
                'допустимый ток кабеля, ток короткого замыкания, '
                'система заземления, УЗО/дифзащита и действующие нормы. '
                'Номинал автомата только по сумме ватт выбирать нельзя.'),
            ],
          ),
        ),
      ),
    );
  }

  double _runLength(ElectricalRun r) {
    ElectricalPoint? a, b;
    for (final p in widget.floor.electricalPoints) {
      if (p.id == r.startPointId) a = p;
      if (p.id == r.endPointId) b = p;
    }
    if (a == null || b == null) return 0;
    final base = r.routeMode == 'orthogonal'
        ? (a.xMm - b.xMm).abs() + (a.yMm - b.yMm).abs()
        : math.sqrt(math.pow(a.xMm - b.xMm, 2) + math.pow(a.yMm - b.yMm, 2));
    return base / 1000 * (1 + r.reservePct / 100);
  }

  Future<void> _quickPointHeight(ElectricalPoint point) async {
    final oldProblem = ElectricalMountingService.problem(widget.floor, point);
    if (point.mounting != null && oldProblem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Сначала обнови монтажную базу: $oldProblem')));
      return;
    }
    final controller = TextEditingController(text: _mm(point.heightMm));
    final value = await showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Высота центра от чистого пола'),
        content: TextField(
          key: const ValueKey('electrical-quick-height-input'),
          autofocus: true,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'мм'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialog,
              double.tryParse(controller.text.replaceAll(',', '.'))),
              child: const Text('Применить')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final wall = point.wallId == null
        ? null : widget.floor.wallById(point.wallId!);
    final limit = wall?.heightOverrideMm ?? widget.floor.defaultHeightMm;
    if (!value.isFinite || value < 0 || value > limit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Высота должна быть от 0 до ${_mm(limit)} мм.')));
      return;
    }
    if ((point.heightMm - value).abs() < .001) return;
    final oldMount = point.mounting;
    ElectricalMounting? newMount;
    if (oldMount != null) {
      newMount = ElectricalMounting(
        wallId: oldMount.wallId,
        datumNodeId: oldMount.datumNodeId,
        datumName: oldMount.datumName,
        datumInsetMm: oldMount.datumInsetMm,
        distanceMm: oldMount.distanceMm,
        heightAboveFinishedFloorMm: value,
        wallSide: oldMount.wallSide,
        geometrySnapshot: oldMount.geometrySnapshot,
        source: oldMount.source,
        finishedFloorAboveSlabMm: oldMount.finishedFloorAboveSlabMm,
        measurementUncertaintyMm: oldMount.measurementUncertaintyMm,
      );
      try {
        ElectricalMountingService.apply(widget.floor,
            ElectricalPoint.fromJson(point.toJson()), newMount);
      } on FormatException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)));
        return;
      }
    }
    final proposed = ElectricalPoint.fromJson(point.toJson());
    if (newMount == null) {
      proposed.heightMm = value;
    } else {
      ElectricalMountingService.apply(widget.floor, proposed, newMount);
    }
    final frameIssue = ElectricalFrameGeometry.placementIssue(
        widget.floor, proposed) ??
        ElectricalFrameGeometry.conflictWithFrames(widget.floor, proposed);
    if (frameIssue != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(frameIssue)));
      return;
    }
    _pushUndo();
    if (newMount == null) {
      point.heightMm = value;
    } else {
      ElectricalMountingService.apply(widget.floor, point, newMount);
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _scrollFanOuter(double delta) {
    _fanScrollAccumulation += delta;
    if (_fanScrollAccumulation.abs() < 28) return;
    final step = _fanScrollAccumulation > 0 ? 1 : -1;
    _fanScrollAccumulation = 0;
    setState(() => _fanOuterIndex = (_fanOuterIndex + step + 6) % 6);
  }

  Offset? _planLocalFromGlobal(Offset global) {
    final render = _planCanvasKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    final local = render.globalToLocal(global);
    if (!(Offset.zero & render.size).contains(local)) return null;
    // A long press released on its own tool must not create a point
    // beneath the overlay controls.
    final fan = _fanGeometryKey.currentContext?.findRenderObject();
    if (fan is RenderBox && fan.hasSize &&
        (Offset.zero & fan.size).contains(fan.globalToLocal(global))) {
      return null;
    }
    return local;
  }

  void _fanLongPressMove(Offset global) {
    final local = _planLocalFromGlobal(global);
    if (_placingAt != local) setState(() => _placingAt = local);
  }

  void _fanLongPressDrop(ElectricalPointType type, Offset global) {
    final local = _planLocalFromGlobal(global);
    setState(() => _placingAt = null);
    if (local == null || _viewportSize.isEmpty) return;
    setState(() {
      _type = type;
      _mode = ElectricalMode.add;
      _addArcOpen = false;
    });
    _tap(TapUpDetails(kind: PointerDeviceKind.touch,
        localPosition: local), _viewportSize);
  }

  Future<void> _duplicatePoint(ElectricalPoint original) async {
    final raw = Map<String, dynamic>.from(original.toJson())
      ..['id'] = _id('ep')
      ..['mounting'] = null
      ..remove('datumAssignment');
    final copy = ElectricalPoint.fromJson(raw);
    final wallId = original.wallId;
    if (wallId != null && original.wallOffsetMm != null) {
      final wall = widget.floor.wallById(wallId);
      final a = wall == null ? null : widget.floor.nodeById(wall.startNodeId);
      final b = wall == null ? null : widget.floor.nodeById(wall.endNodeId);
      if (wall == null || a == null || b == null) return;
      final length = widget.floor.wallLengthMm(wall);
      final distance = ElectricalFrameGeometry.halfWidthMm(original) * 2 + 60;
      bool accepted = false;
      for (final signedDistance in <double>[distance, -distance]) {
        final station = original.wallOffsetMm! + signedDistance;
        if (station < 0 || station > length) continue;
        final t = station / length;
        copy.wallOffsetMm = station;
        copy.xMm = a.xMm + (b.xMm - a.xMm) * t;
        copy.yMm = a.yMm + (b.yMm - a.yMm) * t;
        if (ElectricalFrameGeometry.placementIssue(widget.floor, copy) ==
                null &&
            ElectricalFrameGeometry.conflictWithFrames(
                widget.floor, copy) == null) {
          accepted = true;
          break;
        }
      }
      if (!accepted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Нет свободного места для копии на стене.')));
        return;
      }
    } else {
      copy.xMm += 500;
      copy.yMm += 500;
    }
    _pushUndo();
    widget.floor.electricalPoints.add(copy);
    await widget.onChanged();
    if (mounted) setState(() => _selectedId = copy.id);
  }

  Future<void> _flipWallSide(ElectricalPoint point) async {
    final wallId = point.wallId;
    if (wallId == null) return;
    final roomSides = GeometryService.roomFaces(widget.floor)
        .expand((room) => room.edges)
        .where((edge) => edge.wallId == wallId).length;
    if (roomSides < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('У этой стены нет второй внутренней стороны.')));
      return;
    }
    final proposed = ElectricalPoint.fromJson(point.toJson())
      ..wallSide = -point.wallSide;
    final problem = ElectricalFrameGeometry.placementIssue(
        widget.floor, proposed) ??
        ElectricalFrameGeometry.conflictWithFrames(widget.floor, proposed);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(problem)));
      return;
    }
    _pushUndo();
    point.wallSide = proposed.wallSide;
    // Opposite face means the old named datum / mounting face is not valid.
    point.mounting = null;
    point.datumAssignment = null;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _deleteSelectedPoint(ElectricalPoint point) async {
    if (ElectricalJunctionEditService.pointInUse(
        widget.floor.electricalNetwork, point.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Точка подключена к сети. Сначала убери связи.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить электроточку?'),
        content: const Text('Ручные линии, подключённые к точке, будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _pushUndo();
    widget.floor.electricalRuns.removeWhere((run) =>
        run.startPointId == point.id || run.endPointId == point.id);
    widget.floor.electricalPoints.removeWhere((p) => p.id == point.id);
    await widget.onChanged();
    if (mounted) setState(() {
      _selectedId = null;
      _addArcOpen = false;
    });
  }

  Future<void> _showPointActions(ElectricalPoint point) async {
    final selectedId = point.id;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(point.label.isEmpty
                      ? point.type.label : point.label),
                  subtitle: const Text('Действия с электроточкой'),
                ),
                for (final action in const <(String, IconData, String)>[
                  ('properties', Icons.tune_rounded, 'Свойства и рамка'),
                  ('datum', Icons.straighten, 'Монтажная привязка'),
                  ('load', Icons.bolt_outlined, 'Группа и нагрузка'),
                  ('elevation', Icons.architecture_outlined, 'Развёртка стены'),
                  ('duplicate', Icons.copy_outlined, 'Создать копию'),
                  ('side', Icons.flip_outlined, 'Сторона стены'),
                  ('delete', Icons.delete_outline, 'Удалить'),
                ])
                  ListTile(
                    key: ValueKey('electrical-context-${action.$1}'),
                    leading: Icon(action.$2),
                    title: Text(action.$3),
                    onTap: () => Navigator.pop(sheet, action.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final current = widget.floor.electricalPoints
        .where((p) => p.id == selectedId).firstOrNull;
    if (current == null) return;
    switch (choice) {
      case 'properties': await _editPropertiesDirect(current); return;
      case 'datum': await _editMountingDirect(current); return;
      case 'load': await _editConsumerDraftDirect(current); return;
      case 'elevation': await _showWallElevation(); return;
      case 'duplicate': await _duplicatePoint(current); return;
      case 'side': await _flipWallSide(current); return;
      case 'delete': await _deleteSelectedPoint(current); return;
    }
  }

  Widget _quickFan() {
    final selected = widget.floor.electricalPoints
        .where((p) => p.id == _selectedId).firstOrNull;
    const inner = <(ElectricalPointType, IconData, String)>[
      (ElectricalPointType.socket, Icons.power_outlined, 'Розетка'),
      (ElectricalPointType.switchPoint, Icons.toggle_on_outlined, 'Выкл.'),
      (ElectricalPointType.ceilingLight, Icons.lightbulb_outline, 'Свет'),
      (ElectricalPointType.junctionBox, Icons.account_tree_outlined, 'Коробка'),
    ];
    const outer = <(ElectricalPointType, IconData, String)>[
      (ElectricalPointType.panel, Icons.electric_meter_outlined, 'Щит'),
      (ElectricalPointType.appliance, Icons.cable_outlined, 'Вывод'),
      (ElectricalPointType.frame, Icons.view_module_outlined, 'Рамка'),
      (ElectricalPointType.wallLight, Icons.wb_incandescent_outlined, 'Бра'),
      (ElectricalPointType.tvSocket, Icons.tv_outlined, 'ТВ'),
      (ElectricalPointType.dataSocket, Icons.wifi_outlined, 'Интернет'),
    ];
    const positions = <(double, double)>[
      (20, 149), (53, 79), (127, 21), (217, 2),
      (113, 146), (167, 96), (229, 67),
    ];
    final visibleTypes = <(ElectricalPointType, IconData, String)>[
      ...inner,
      for (var i = 0; i < 3; i++) outer[(_fanOuterIndex + i) % outer.length],
    ];
    final theme = Theme.of(context);
    Widget arcTile(String key, IconData icon, String label,
        VoidCallback action, int i, {bool active = false,
        ElectricalPointType? draggableType}) {
      return Positioned(
        left: positions[i].$1, top: positions[i].$2,
        child: Tooltip(
          message: draggableType == null ? label
              : '$label · удерживай и перетащи на план',
          child: Material(
            color: active ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: active ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant),
            ),
            child: GestureDetector(
              key: ValueKey(key),
              behavior: HitTestBehavior.opaque,
              onTap: action,
              onLongPressMoveUpdate: draggableType == null ? null
                  : (d) => _fanLongPressMove(d.globalPosition),
              onLongPressEnd: draggableType == null ? null
                  : (d) => _fanLongPressDrop(draggableType, d.globalPosition),
              child: SizedBox(
                width: 54, height: 55,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 21, color: theme.colorScheme.onSurface),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      key: _fanGeometryKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_addArcOpen && _mode == ElectricalMode.add)
          GestureDetector(
            onVerticalDragUpdate: _mode == ElectricalMode.add
                ? (details) => _scrollFanOuter(details.delta.dy) : null,
            child: SizedBox(
              key: ValueKey(_mode == ElectricalMode.add
                  ? 'electrical-two-ring-fan'
                  : 'electrical-context-fan'),
              width: 290, height: 212,
              child: CustomPaint(
                painter: _ElectricalFanArcs(
                    color: theme.colorScheme.primary.withValues(alpha: .35)),
                child: Stack(children: [
                  if (_mode == ElectricalMode.add)
                    for (var i = 0; i < visibleTypes.length; i++)
                      arcTile('electrical-add-${visibleTypes[i].$1.name}',
                          visibleTypes[i].$2, visibleTypes[i].$3, () {
                        setState(() {
                          _type = visibleTypes[i].$1;
                          _mode = ElectricalMode.add;
                          _addArcOpen = false;
                        });
                      }, i,
                      active: _type == visibleTypes[i].$1,
                      draggableType: visibleTypes[i].$1),
                ]),
              ),
            ),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected != null && _mode == ElectricalMode.select) ...[
            IconButton.filledTonal(
              key: const ValueKey('electrical-selection-actions'),
              tooltip: 'Действия с выбранной точкой',
              onPressed: () => _showPointActions(selected),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
            const SizedBox(width: 5),
          ],
          IconButton.filledTonal(
            key: const ValueKey('electrical-fan-select'),
            tooltip: 'Выбрать / перетащить',
            onPressed: () => setState(() {
              _mode = ElectricalMode.select;
              _addArcOpen = false;
                    }),
            icon: const Icon(Icons.touch_app_outlined)),
          const SizedBox(width: 5),
          IconButton.filledTonal(
            key: const ValueKey('electrical-fan-wire'),
            tooltip: 'Ручная линия',
            onPressed: () => setState(() {
              _mode = ElectricalMode.wire;
              _addArcOpen = false;
                      _wireStartId = null;
            }),
            icon: const Icon(Icons.polyline_outlined)),
          const SizedBox(width: 5),
          FloatingActionButton.small(
            key: const ValueKey('electrical-fan-add'),
            tooltip: 'Добавить электроточку',
            heroTag: 'zamer-electrical-point-add',
            onPressed: () => setState(() {
              _mode = ElectricalMode.add;
                      _addArcOpen = !_addArcOpen;
            }),
            child: const Icon(Icons.add_rounded),
          ),
        ]),
      ],
    );
  }

  Offset _placementPreview(Offset raw, Size size) {
    if (!_needsWall(_type)) return raw;
    final hit = _nearestWall(_screenToMm(raw, size),
        maxDistanceMm: ElectricalSnapService.captureMm(
            _activePlanScale(), capturePx: 32));
    if (hit == null) return raw;
    final snapped = _snapWallHit(hit);
    final tx = _tx(size);
    return tx.origin + Offset(snapped.point.x * tx.scale,
                             snapped.point.y * tx.scale);
  }

  void _placePanStart(DragStartDetails d) {
    if (_pinchingCamera || _touches.length > 1) return;
    setState(() => _placingAt = d.localPosition);
  }

  void _placePanUpdate(DragUpdateDetails d) {
    if (_pinchingCamera || _touches.length > 1) return;
    setState(() => _placingAt = d.localPosition);
  }

  Future<void> _placePanEnd(Size size) async {
    final at = _placingAt;
    setState(() => _placingAt = null);
    if (at == null || _pinchingCamera || _touches.length > 1) return;
    // Reuse the same validated placement path as tap-to-add.
    await _tap(TapUpDetails(kind: PointerDeviceKind.touch,
        localPosition: at), size);
  }

  Widget _workspaceTabs() {
    final theme = Theme.of(context);
    const labels = <(ElectricalWorkspaceView, String)>[
      (ElectricalWorkspaceView.pointsRoutes, 'Точки и трассы'),
      (ElectricalWorkspaceView.loads, 'Нагрузки'),
      (ElectricalWorkspaceView.board, 'Щит'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 3),
      child: Row(
        key: const ValueKey('electrical-three-modes'),
        children: [
          for (final (value, label) in labels)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  key: value == ElectricalWorkspaceView.loads
                      ? const ValueKey('electrical-load-inventory')
                      : ValueKey('electrical-view-${value.name}'),
                  onPressed: () => setState(() {
                    _workspaceView = value;
                    _addArcOpen = false;
                  }),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 9),
                    backgroundColor: _workspaceView == value
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainer,
                    foregroundColor: _workspaceView == value
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadWorkspace() {
    final draft = widget.floor.electricalDesignDraft;
    final result = draft == null
        ? null : ElectricalDesignEngine.calculate(widget.floor, draft);
    return ListView(
      key: const ValueKey('electrical-loads-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        Row(children: [
          Expanded(child: Text('Линии и нагрузки',
              style: Theme.of(context).textTheme.titleMedium)),
          OutlinedButton.icon(
            key: const ValueKey('electrical-design-settings'),
            onPressed: _editSupplySettings,
            icon: const Icon(Icons.tune, size: 17),
            label: const Text('Ввод'),
          ),
        ]),
        if (draft == null) ...[
          const Card(child: ListTile(
            title: Text('Инженерный расчёт не настроен'),
            subtitle: Text('Укажи параметры ввода и назначь приборам '
                'профили мощности в карточках точек.'),
          )),
          for (final circuit in ElectricalBoardDraftService.create(
              widget.floor).circuits)
            Card(child: ListTile(
              title: Text(circuit.load.name),
              subtitle: Text(
                '${circuit.load.connectedWatts.toStringAsFixed(0)} Вт '
                '(известные нагрузки) • предварительная группа'),
            )),
        ],
        if (result != null) ...[
          Card(child: ListTile(
            title: Text('Установленная: ${result.installedWatts == null ? 'неполная' :
                '${(result.installedWatts! / 1000).toStringAsFixed(2)} кВт'}'),
            subtitle: Text('Расчётная: ${result.demandWatts == null ? 'неполная' :
                '${(result.demandWatts! / 1000).toStringAsFixed(2)} кВт'} · '
                '${draft!.settings.phasesCount}Ф. '
                'Данные для проектирования, не допуск к монтажу.'),
          )),
          if (draft!.settings.phasesCount == 3)
            Card(child: ListTile(
              title: Text('Фазы • перекос ${result.imbalancePercent == null ?
                  'неизвестен' : '${result.imbalancePercent!.toStringAsFixed(1)}%'}'),
              subtitle: Text(
                'L1 ${result.phaseWatts[ElectricalPhase.l1]!.toStringAsFixed(0)} Вт • '
                'L2 ${result.phaseWatts[ElectricalPhase.l2]!.toStringAsFixed(0)} Вт • '
                'L3 ${result.phaseWatts[ElectricalPhase.l3]!.toStringAsFixed(0)} Вт'),
            )),
          for (final line in result.lines)
            Card(child: ListTile(
              title: Text(line.id, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${line.pointIds.length} точек • '
                '${line.demandWatts == null ? 'мощность не задана' :
                    '${line.demandWatts!.toStringAsFixed(0)} Вт'} • '
                '${line.phase.name.toUpperCase()}'
                '${draft.lineOverrides[line.id]?.locked('phase') == true ?
                    ' • закреплена' : ''}'),
              trailing: const Icon(Icons.lock_outline),
              onTap: () => _selectManualPhase(line),
            )),
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Проверки и недостающие исходные данные',
                style: Theme.of(context).textTheme.titleMedium),
            for (final issue in result.issues.take(12))
              ListTile(
                dense: true,
                leading: Icon(
                  issue.severity == ElectricalIssueSeverity.error
                      ? Icons.error_outline : Icons.info_outline,
                  color: issue.severity == ElectricalIssueSeverity.error
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.tertiary),
                title: Text(issue.message),
                subtitle: Text(issue.code),
              ),
          ],
        ],
      ],
    );
  }

  Widget _boardWorkspace() {
    final draft = ElectricalBoardDraftService.create(widget.floor);
    final design = widget.floor.electricalDesignDraft;
    final checks = design == null
        ? null : ElectricalDesignEngine.calculate(widget.floor, design);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            key: const ValueKey('electrical-board-three-tabs'),
            children: [
              for (final (view, label) in const [
                (ElectricalBoardView.layout, 'Компоновка'),
                (ElectricalBoardView.wiring, 'Схема'),
                (ElectricalBoardView.checks, 'Проверки'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      key: ValueKey('electrical-board-tab-${view.name}'),
                      onPressed: () => setState(() => _boardView = view),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        backgroundColor: _boardView == view
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            style: const TextStyle(fontSize: 12))),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('electrical-board-workspace'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              if (_boardView == ElectricalBoardView.layout) ...[
                Text('Щит • предварительная компоновка',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Пока это схема логических секций. DIN-размеры, '
                    'номиналы аппаратов, шины N/PE и клеммные подключения '
                    'не рассчитаны. По этому эскизу нельзя собирать щит.'),
                const SizedBox(height: 12),
                if (checks != null) ...[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.input_outlined),
                      title: Text('Ввод и защитные аппараты'),
                      subtitle: Text('Параметры и компоновка ещё не рассчитаны.'),
                    ),
                  ),
                  for (final line in checks.lines)
                    Card(
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          line.kind == ElectricalConsumerKind.lighting
                              ? Icons.lightbulb_outline
                              : Icons.power_outlined,
                        ),
                        title: Text(
                          line.kind == ElectricalConsumerKind.lighting
                              ? 'Свет • ${line.roomId}'
                              : line.kind == ElectricalConsumerKind.sockets
                                  ? 'Розетки • ${line.roomId}'
                                  : line.critical
                                      ? 'Неотключаемая • ${line.pointIds.first}'
                                      : 'Отдельная • ${line.pointIds.first}',
                        ),
                        subtitle: Text(
                          'Линия ${line.id} · ${line.phase.name.toUpperCase()} · '
                          '${line.demandWatts == null ? 'мощность неизвестна' :
                            '${line.demandWatts!.toStringAsFixed(0)} Вт'} · '
                          'номинал и DIN-место не подобраны'),
                      ),
                    ),
                ] else
                  for (final section in draft.sections)
                    Card(
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.view_module_outlined),
                        title: Text(section.label),
                        subtitle: Text(section.role),
                      ),
                    ),
              ],
              if (_boardView == ElectricalBoardView.wiring) ...[
                Text('Клеммная ведомость • не сформирована',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Монтажные подключения заблокированы'),
                    subtitle: Text('Пока не выбрана конкретная модель '
                        'защиты, не проверены шины, топология L/N/PE '
                        'и схема изготовителя, нельзя выдавать '
                        'инструкции к клеммам автоматов или УЗО.'),
                  ),
                ),
                if (checks != null)
                  Text('Открытых замечаний: ${checks.issues.length}'),
              ],
              if (_boardView == ElectricalBoardView.checks) ...[
                Text('Инженерные проверки',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (checks == null)
                  const Card(
                    child: ListTile(
                      title: Text('Нет исходных данных для проверок'),
                      subtitle: Text('Заполни параметры ввода и '
                          'потребителей во вкладке «Нагрузки».'),
                    ),
                  )
                else
                  for (final issue in checks.issues)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          issue.severity == ElectricalIssueSeverity.error
                              ? Icons.error_outline
                              : Icons.info_outline,
                          color: issue.severity == ElectricalIssueSeverity.error
                              ? Theme.of(context).colorScheme.error : null,
                        ),
                        title: Text(issue.message),
                        subtitle: Text(issue.code),
                      ),
                    ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Даже отсутствие найденных конфликтов '
                      'не означает, что проект согласован для монтажа.'),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _showCableJournal,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Кабельный журнал'),
              ),
              const SizedBox(height: 10),
              Text(draft.protectionStatus,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.floor.electricalPoints
        .where((p) => p.id == _selectedId).firstOrNull;
    final cableTotals = <String, double>{};
    for (final r in widget.floor.electricalRuns) {
      cableTotals[r.cable] = (cableTotals[r.cable] ?? 0) + _runLength(r);
    }
    return Column(
      children: [
        _workspaceTabs(),
        if (_workspaceView != ElectricalWorkspaceView.pointsRoutes)
          Expanded(child: _workspaceView == ElectricalWorkspaceView.loads
              ? _loadWorkspace() : _boardWorkspace()),
        if (_workspaceView == ElectricalWorkspaceView.pointsRoutes &&
            !widget.embedded)
          Row(
            children: [
              IconButton(
                tooltip: 'Назад', onPressed: _undo.isEmpty ? null : _undoAction,
                icon: const Icon(Icons.undo_rounded)),
              IconButton(
                tooltip: 'Вперёд', onPressed: _redo.isEmpty ? null : _redoAction,
                icon: const Icon(Icons.redo_rounded)),
              const Spacer(),
              IconButton(
                tooltip: 'Высоты по умолчанию',
                onPressed: _heightDefaults, icon: const Icon(Icons.height)),
            ],
          ),
        if (_workspaceView == ElectricalWorkspaceView.pointsRoutes)
          _routeControls(),
        if (_workspaceView == ElectricalWorkspaceView.pointsRoutes)
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              _viewportSize = size;
              final t = _tx(size);
              return Stack(key: _planCanvasKey, children: [Listener(
                onPointerDown: _touchDown,
                onPointerMove: _touchMove,
                onPointerUp: _touchEnd,
                onPointerCancel: _touchEnd,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d, size),
                onPanStart: _mode == ElectricalMode.select
                    ? (d) => _dragStart(d, size)
                    : _mode == ElectricalMode.add ? _placePanStart : null,
                onPanUpdate: _mode == ElectricalMode.select
                    ? (d) => _dragUpdate(d, size)
                    : _mode == ElectricalMode.add ? _placePanUpdate : null,
                onPanEnd: _mode == ElectricalMode.select ? _dragEnd
                    : _mode == ElectricalMode.add ? (_) => _placePanEnd(size)
                    : null,
                child: CustomPaint(
                  painter: widget.embedded ? CadPlanPainter(
                    floor: widget.floor,
                    mmToPx: t.scale,
                    origin: t.origin,
                    showDimensions: false,
                    showGrid: true,
                    visibleCategories: PlanDisplayLayer.values.toSet()
                      ..remove(PlanDisplayLayer.electrical),
                  ) : ElectricalPlanPainter(
                    floor: widget.floor,
                    scale: t.scale,
                    origin: t.origin,
                    selectedPointId: _selectedId,
                    wireStartPointId: _wireStartId,
                    showLegacyLines: _showLegacyLines || _mode == ElectricalMode.wire,
                    show3dRoutes: _show3dRoutes,
                    showCrossings: _showCrossings,
                    circuitFilterId: _routeCircuitFilterId,
                    visiblePointTypes: _visiblePointTypes,
                  ),
                  foregroundPainter: widget.embedded
                      ? ElectricalPlanPainter(
                          floor: widget.floor,
                          scale: t.scale,
                          origin: t.origin,
                          selectedPointId: _selectedId,
                          wireStartPointId: _wireStartId,
                          darkMode: true,
                          overlayOnly: true,
                          showLegacyLines: _showLegacyLines || _mode == ElectricalMode.wire,
                          show3dRoutes: _show3dRoutes,
                    showCrossings: _showCrossings,
                          circuitFilterId: _routeCircuitFilterId,
                    visiblePointTypes: _visiblePointTypes,
                        ) : null,
                  child: const SizedBox.expand(),
                ),
                ),
              ),
              if (_placingAt != null && _mode == ElectricalMode.add)
                Positioned(
                  left: (_placementPreview(_placingAt!, size).dx - 15)
                      .clamp(0.0, math.max(0.0, size.width - 30)),
                  top: (_placementPreview(_placingAt!, size).dy - 15)
                      .clamp(0.0, math.max(0.0, size.height - 30)),
                  child: IgnorePointer(
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _quickFan(),
              ),
            ]);
            },
          ),
        ),
        if (_workspaceView == ElectricalWorkspaceView.pointsRoutes &&
            selected != null)
          ElectricalCompactInspector(
            floor: widget.floor,
            point: selected,
            onDatum: () => _editMountingDirect(selected),
            onHeight: () => _quickPointHeight(selected),
            onLoad: () => _editConsumerDraftDirect(selected),
          ),
        if (_workspaceView == ElectricalWorkspaceView.pointsRoutes &&
            !widget.embedded && widget.floor.electricalPoints.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ведомость электрики',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Точек: ${widget.floor.electricalPoints.length} • линий: ${widget.floor.electricalRuns.length}',
                    ),
                    ...cableTotals.entries.map(
                      (e) => Text('${e.key}: ${e.value.toStringAsFixed(1)} м'),
                    ),
                    if (_wireStartId != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          'Выбери следующую точку для продолжения линии.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WallHit {
  const _WallHit({
    required this.wall,
    required this.point,
    required this.offsetMm,
    required this.distanceMm,
  });
  final PlanWall wall;
  final math.Point<double> point;
  final double offsetMm;
  final double distanceMm;
}

class _Tx {
  const _Tx({required this.scale, required this.origin});
  final double scale;
  final Offset origin;
}

/// Purely visual fan guides, no geometry or project state is changed here.
class _ElectricalFanArcs extends CustomPainter {
  const _ElectricalFanArcs({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color
        ..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final center = Offset(size.width - 3, size.height - 2);
    for (final radius in <double>[143, 220]) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          math.pi, math.pi / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricalFanArcs oldDelegate) =>
      oldDelegate.color != color;
}
