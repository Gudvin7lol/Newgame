import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_mounting.dart';
import '../services/electrical_mounting_service.dart';
import '../widgets/electrical_mounting_editor.dart';
import '../widgets/electrical_point_properties.dart';
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
  ElectricalPointType _type = ElectricalPointType.socket;
  String _cable = 'ВВГнг-LS 3×1.5';
  String _routeMode = 'orthogonal';
  String? _wireStartId;
  String? _selectedId;
  /// Physical cable routes and sketch lines are hidden by default.
  bool _show3dRoutes = false;
  bool _showCrossings = false;
  bool _showLegacyLines = false;
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
      if (mounted) setState(() {});
      if (_type == ElectricalPointType.frame && mounted)
        await _pointSheet(created);
      return;
    }

    final point = _near(mm, (180 / math.max(0.25, t.scale / 0.08)).toDouble());
    if (point == null) return;
    if (_mode == ElectricalMode.select) {
      setState(() => _selectedId = point.id);
      await _pointSheet(point);
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
      final next = await Navigator.of(context).push<ElectricalMounting>(
        MaterialPageRoute(
          builder: (_) =>
              ElectricalMountingEditor(floor: widget.floor, point: p),
        ),
      );
      if (!mounted || next == null) return;
      // Validate a detached copy before adding an undo entry or changing the project.
      try {
        ElectricalMountingService.apply(
          widget.floor,
          ElectricalPoint.fromJson(p.toJson()),
          next,
        );
      } on FormatException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      _pushUndo();
      ElectricalMountingService.apply(widget.floor, p, next);
    } else if (action == 'properties') {
      final next = await showModalBottomSheet<ElectricalPoint>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ElectricalPointProperties(
          point: p,
          circuits: widget.floor.electricalPoints
              .map((e) => e.circuit)
              .toSet()
              .toList(),
        ),
      );
      if (!mounted || next == null) return;
      _pushUndo();
      p.label = next.label;
      p.circuit = next.circuit;
      p.powerW = next.powerW;
      p.heightMm = next.heightMm;
      p.modules
        ..clear()
        ..addAll(next.modules);
      p.frameVertical = next.frameVertical;
      p.type = next.type;
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
          IconButton(
            key: const ValueKey('electrical-toggle-physical-routes'),
            tooltip: _show3dRoutes
                ? 'Скрыть 3D-трассы' : 'Показать 3D-трассы',
            icon: Icon(_show3dRoutes ? Icons.route : Icons.alt_route),
            color: _show3dRoutes ? Theme.of(context).colorScheme.primary : null,
            onPressed: () => setState(() => _show3dRoutes = !_show3dRoutes),
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
                if (choice == 'crossings') _showCrossings = !_showCrossings;
                if (choice == 'all') _routeCircuitFilterId = null;
              });
            },
            itemBuilder: (_) => [
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

  @override
  Widget build(BuildContext context) {
    final cableTotals = <String, double>{};
    for (final r in widget.floor.electricalRuns) {
      cableTotals[r.cable] = (cableTotals[r.cable] ?? 0) + _runLength(r);
    }
    return Column(
      children: [
        if (!widget.embedded) Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: _undo.isEmpty ? null : _undoAction,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        tooltip: 'Вперёд',
                        onPressed: _redo.isEmpty ? null : _redoAction,
                        icon: const Icon(Icons.redo),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _heightDefaults,
                        icon: const Icon(Icons.height),
                        label: const Text('Высоты'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ElectricalMode>(
                    segments: const [
                      ButtonSegment(
                        value: ElectricalMode.add,
                        icon: Icon(Icons.add_circle_outline),
                        label: Text('Точка'),
                      ),
                      ButtonSegment(
                        value: ElectricalMode.wire,
                        icon: Icon(Icons.polyline_outlined),
                        label: Text('Проводка'),
                      ),
                      ButtonSegment(
                        value: ElectricalMode.select,
                        icon: Icon(Icons.touch_app_outlined),
                        label: Text('Правка'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() {
                      _mode = v.first;
                      _wireStartId = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  if (_mode == ElectricalMode.add)
                    DropdownButtonFormField<ElectricalPointType>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Что поставить на план',
                      ),
                      items: ElectricalPointType.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    ),
                  if (_mode == ElectricalMode.select)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Перетаскивай точки пальцем. Потолочные светильники автоматически цепляются к общей прямой.',
                      ),
                    ),
                  if (_mode == ElectricalMode.wire)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _cable,
                            decoration: const InputDecoration(
                              labelText: 'Кабель',
                            ),
                            items:
                                const [
                                      'ВВГнг-LS 3×1.5',
                                      'ВВГнг-LS 3×2.5',
                                      'ВВГнг-LS 5×4',
                                      'UTP Cat.6',
                                      'Коаксиал TV',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => _cable = v ?? _cable),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _routeMode,
                          items: const [
                            DropdownMenuItem(
                              value: 'orthogonal',
                              child: Text('90°'),
                            ),
                            DropdownMenuItem(
                              value: 'direct',
                              child: Text('Прямая'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _routeMode = v ?? _routeMode),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.embedded)
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              TextButton.icon(
                key: const ValueKey('electrical-load-inventory'),
                onPressed: _showLoadInventory,
                icon: const Icon(Icons.electric_bolt_outlined, size: 16),
                label: const Text('Нагрузки / щит'),
              ),
              IconButton(
                tooltip: 'Высоты точек',
                onPressed: _heightDefaults,
                icon: const Icon(Icons.height),
              ),
              IconButton(
                key: const ValueKey('electrical-wall-elevation'),
                tooltip: 'Развёртка стены',
                onPressed: _showWallElevation,
                icon: const Icon(Icons.architecture_outlined),
              ),
              IconButton(
                key: const ValueKey('electrical-cable-journal'),
                tooltip: 'Кабельный журнал',
                onPressed: _showCableJournal,
                icon: const Icon(Icons.inventory_2_outlined),
              ),
              IconButton(
                key: const ValueKey('electrical-toggle-physical-routes'),
                tooltip: _show3dRoutes ? 'Скрыть 3D-трассы' : 'Показать 3D-трассы',
                onPressed: () => setState(() => _show3dRoutes = !_show3dRoutes),
                icon: Icon(_show3dRoutes ? Icons.route : Icons.alt_route),
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
                    if (choice == 'crossings') _showCrossings = !_showCrossings;
                    if (choice == 'all') _routeCircuitFilterId = null;
                  });
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: 'legacy', checked: _showLegacyLines,
                    child: const Text('Черновые линии'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'crossings', checked: _showCrossings,
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
                  if (_routeCircuitFilterId != null)
                    const PopupMenuItem(value: 'all',
                        child: Text('Все группы')),
                ],
              ),
            ],
          ),
        if (!widget.embedded)
          _routeControls(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              _viewportSize = size;
              final t = _tx(size);
              return Listener(
                onPointerDown: _touchDown,
                onPointerMove: _touchMove,
                onPointerUp: _touchEnd,
                onPointerCancel: _touchEnd,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d, size),
                onPanStart: _mode == ElectricalMode.select
                    ? (d) => _dragStart(d, size)
                    : null,
                onPanUpdate: _mode == ElectricalMode.select
                    ? (d) => _dragUpdate(d, size)
                    : null,
                onPanEnd: _mode == ElectricalMode.select ? _dragEnd : null,
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
                        ) : null,
                  child: const SizedBox.expand(),
                ),
                ),
              );
            },
          ),
        ),
        if (!widget.embedded && widget.floor.electricalPoints.isNotEmpty)
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
