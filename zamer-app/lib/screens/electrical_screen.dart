import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_mounting.dart';
import '../services/electrical_mounting_service.dart';
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
  bool _addArcOpen = false;
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

  math.Point<double> _snapLightGuide(
    ElectricalPoint? moving,
    math.Point<double> raw,
  ) {
    var x = raw.x;
    var y = raw.y;
    var bestX = 240.0;
    var bestY = 240.0;
    for (final p in widget.floor.electricalPoints) {
      if (moving != null && p.id == moving.id) continue;
      if (p.type != ElectricalPointType.ceilingLight &&
          p.type != ElectricalPointType.wallLight)
        continue;
      final dx = (p.xMm - raw.x).abs();
      final dy = (p.yMm - raw.y).abs();
      if (dx < bestX) {
        bestX = dx;
        x = p.xMm;
      }
      if (dy < bestY) {
        bestY = dy;
        y = p.yMm;
      }
    }
    return math.Point<double>(x, y);
  }

  void _movePoint(ElectricalPoint point, math.Point<double> raw) {
    if (_needsWall(point.type) || (point.type == ElectricalPointType.junctionBox && point.wallId != null)) {
      final rawHit = _nearestWall(raw, maxDistanceMm: 700);
      final hit = rawHit == null
          ? null
          : _clearOfDoor(rawHit, _hasSwitch(point.type, point.modules));
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
        ? _snapLightGuide(point, raw)
        : raw;
    point.xMm = (guided.x / 10).round() * 10.0;
    point.yMm = (guided.y / 10).round() * 10.0;
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
    });
  }

  void _dragUpdate(DragUpdateDetails d, Size size) {
    if (_pinchingCamera) return;
    if (_mode != ElectricalMode.select || _dragPointId == null) return;
    ElectricalPoint? point;
    for (final p in widget.floor.electricalPoints) {
      if (p.id == _dragPointId) point = p;
    }
    if (point == null) return;
    if (!_dragUndoPushed) {
      _pushUndo();
      _dragUndoPushed = true;
    }
    _movePoint(point, _screenToMm(d.localPosition, size));
    setState(() {});
  }

  Future<void> _dragEnd(DragEndDetails d) async {
    if (_mode != ElectricalMode.select || _dragPointId == null) return;
    if (_dragUndoPushed) await widget.onChanged();
    if (mounted)
      setState(() {
        _dragPointId = null;
        _dragUndoPushed = false;
      });
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

  bool _canJoinFrame(ElectricalPointType type) => {
    ElectricalPointType.socket,
    ElectricalPointType.switchPoint,
    ElectricalPointType.tvSocket,
    ElectricalPointType.dataSocket,
    ElectricalPointType.frame,
  }.contains(type);

  ElectricalPoint? _frameNeighbor(String wallId, double offsetMm, int side) {
    ElectricalPoint? best;
    var distance = 400.0;
    for (final p in widget.floor.electricalPoints) {
      if (p.wallId != wallId || p.wallSide != side || !_canJoinFrame(p.type))
        continue;
      final d = ((p.wallOffsetMm ?? 0) - offsetMm).abs();
      if (d < distance && p.modules.length < 5) {
        best = p;
        distance = d;
      }
    }
    return best;
  }

  Future<void> _tap(TapUpDetails d, Size size) async {
    if (_pinchingCamera) return;
    final t = _tx(size);
    final mm = math.Point<double>(
      (d.localPosition.dx - t.origin.dx) / t.scale,
      (d.localPosition.dy - t.origin.dy) / t.scale,
    );
    if (_mode == ElectricalMode.add) {
      final guided = _type == ElectricalPointType.ceilingLight
          ? _snapLightGuide(null, mm)
          : mm;
      var x = ((guided.x / 10).round() * 10).toDouble();
      var y = ((guided.y / 10).round() * 10).toDouble();
      String? wallId;
      double? wallOffset;
      var wallSide = 1;
      if (_needsWall(_type)) {
        final rawHit = _nearestWall(mm);
        final hit = rawHit == null
            ? null
            : _clearOfDoor(rawHit, _hasSwitch(_type, _defaultModules(_type)));
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
      _pushUndo();
      if (wallId != null &&
          wallOffset != null &&
          _canJoinFrame(_type) &&
          _type != ElectricalPointType.frame) {
        final neighbor = _frameNeighbor(wallId, wallOffset, wallSide);
        if (neighbor != null) {
          neighbor.modules.addAll(_defaultModules(_type));
          while (neighbor.modules.length > 5) neighbor.modules.removeLast();
          neighbor.type = neighbor.modules.length > 1
              ? ElectricalPointType.frame
              : _type;
          neighbor.xMm = (neighbor.xMm + x) / 2;
          neighbor.yMm = (neighbor.yMm + y) / 2;
          neighbor.wallOffsetMm =
              ((neighbor.wallOffsetMm ?? wallOffset) + wallOffset) / 2;
          await widget.onChanged();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Устройство добавлено в общую рамку.'),
              ),
            );
            setState(() {});
          }
          return;
        }
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
      widget.floor.electricalPoints.add(created);
      await widget.onChanged();
      if (mounted) setState(() => _selectedId = created.id);
      if (_type == ElectricalPointType.frame && mounted)
        await _pointSheet(created);
      return;
    }

    final point = _near(mm, (180 / math.max(0.25, t.scale / 0.08)).toDouble());
    if (point == null) return;
    if (_mode == ElectricalMode.select) {
      setState(() => _selectedId = point.id);
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
    _pushUndo();
    point.label = next.label;
    point.circuit = next.circuit;
    point.powerW = next.powerW;
    point.heightMm = next.heightMm;
    point.modules
      ..clear()
      ..addAll(next.modules);
    point.frameVertical = next.frameVertical;
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
    _pushUndo();
    if (newMount == null) {
      point.heightMm = value;
    } else {
      ElectricalMountingService.apply(widget.floor, point, newMount);
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Widget _quickFan() {
    final selected = widget.floor.electricalPoints
        .where((p) => p.id == _selectedId).firstOrNull;
    const types = <(ElectricalPointType, IconData, String)>[
      (ElectricalPointType.socket, Icons.power_outlined, 'Розетка'),
      (ElectricalPointType.switchPoint, Icons.toggle_on_outlined, 'Выключатель'),
      (ElectricalPointType.ceilingLight, Icons.lightbulb_outline, 'Свет'),
      (ElectricalPointType.junctionBox, Icons.account_tree_outlined, 'Коробка'),
      (ElectricalPointType.panel, Icons.electric_meter_outlined, 'Щит'),
      (ElectricalPointType.appliance, Icons.cable_outlined, 'Вывод'),
    ];
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_addArcOpen && _mode == ElectricalMode.add)
          Container(
            constraints: const BoxConstraints(maxWidth: 275),
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3),
                  blurRadius: 14)],
            ),
            child: Wrap(spacing: 4, runSpacing: 4,
              children: [
                for (final (type, icon, label) in types)
                  ActionChip(
                    key: ValueKey('electrical-add-${type.name}'),
                    label: Text(label,
                        style: const TextStyle(fontSize: 11)),
                    avatar: Icon(icon, size: 16),
                    backgroundColor: _type == type
                        ? theme.colorScheme.primaryContainer : null,
                    onPressed: () => setState(() {
                      _type = type;
                      _mode = ElectricalMode.add;
                      _addArcOpen = false;
                    }),
                  ),
              ]),
          ),
        if (selected != null && _mode == ElectricalMode.select)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: FilledButton.tonalIcon(
              key: const ValueKey('electrical-selected-edit'),
              onPressed: () => _pointSheet(selected),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Свойства точки'),
            ),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filledTonal(
            key: const ValueKey('electrical-fan-select'),
            tooltip: 'Выбрать / перетащить',
            onPressed: () => setState(() {
              _mode = ElectricalMode.select; _addArcOpen = false;
            }),
            icon: const Icon(Icons.touch_app_outlined)),
          const SizedBox(width: 5),
          IconButton.filledTonal(
            key: const ValueKey('electrical-fan-wire'),
            tooltip: 'Ручная линия',
            onPressed: () => setState(() {
              _mode = ElectricalMode.wire; _addArcOpen = false;
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
    final hit = _nearestWall(_screenToMm(raw, size), maxDistanceMm: 550);
    if (hit == null) return raw;
    final tx = _tx(size);
    return tx.origin + Offset(hit.point.x * tx.scale,
                             hit.point.y * tx.scale);
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
    final draft = ElectricalBoardDraftService.create(widget.floor);
    return ListView(
      key: const ValueKey('electrical-loads-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        Text('Группы и нагрузки',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Известно: ${draft.knownConnectedWatts.toStringAsFixed(0)} Вт • '
            '${draft.circuits.length} групп. Не является подбором автоматов.'),
        if (draft.unratedLoads > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Не указана мощность у ${draft.unratedLoads} точек. '
              'Суммарная нагрузка неполная.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (draft.circuits.isEmpty)
          const ListTile(title: Text('Групп пока нет'),
              subtitle: Text('Назначь точки группам на плане.')),
        for (final circuit in draft.circuits)
          Card(
            child: ListTile(
              title: Text(circuit.load.name),
              subtitle: Text(
                '${circuit.load.loadCount} точек • '
                '${circuit.load.connectedWatts.toStringAsFixed(0)} Вт • '
                '≈${circuit.load.estimatedAmps.toStringAsFixed(1)} А\n'
                '${circuit.protectiveDeviceStatus}',
              ),
              isThreeLine: true,
              trailing: circuit.incomplete
                  ? const Icon(Icons.warning_amber_rounded)
                  : const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _workspaceView = ElectricalWorkspaceView.pointsRoutes;
                _routeCircuitFilterId = widget.floor.electricalNetwork?.circuits
                    .where((c) => c.name == circuit.load.name)
                    .firstOrNull?.id;
                _show3dRoutes = true;
              }),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Ток указан только для известных нагрузок. '
              'Одновременность, фазы и защита требуют отдельных исходных данных.'),
        ),
      ],
    );
  }

  Widget _boardWorkspace() {
    final draft = ElectricalBoardDraftService.create(widget.floor);
    return ListView(
      key: const ValueKey('electrical-board-workspace'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        Text('Щит • предварительная компоновка',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Пока это схема логических секций. DIN-размеры, '
            'номиналы аппаратов, шины N/PE и клеммные подключения '
            'не рассчитаны. По этому эскизу нельзя собирать щит.'),
        const SizedBox(height: 12),
        for (final section in draft.sections)
          Card(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.view_module_outlined),
              title: Text(section.label),
              subtitle: Text(section.role),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _showCableJournal,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Кабельный журнал'),
        ),
        const SizedBox(height: 10),
        Text(draft.protectionStatus,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
              return Stack(children: [Listener(
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
            onLoad: () => _editPropertiesDirect(selected),
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
