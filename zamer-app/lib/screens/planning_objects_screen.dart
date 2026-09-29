import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/angle_snap_service.dart';
import '../services/object_catalog.dart';
import '../services/geometry_service.dart';
import '../services/space_check_service.dart';
import '../widgets/model_thumbnail.dart';

enum _ObjectMode { add, select }

enum _AddSource { catalog, engineering }

class PlanningObjectsScreen extends StatefulWidget {
  const PlanningObjectsScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<PlanningObjectsScreen> createState() => _PlanningObjectsScreenState();
}

class _PlanningObjectsScreenState extends State<PlanningObjectsScreen> {
  _ObjectMode _mode = _ObjectMode.add;
  _AddSource _source = _AddSource.catalog;
  ProjectLayer _layer = ProjectLayer.proposed;
  String? _selectedId;
  String? _gestureObjectId;
  double _gestureBaseRotation = 0;
  double? _gestureSnapAngleDeg;
  Offset _gestureGrabOffset = Offset.zero;
  bool _gestureDirty = false;

  String _group = 'Мягкая мебель';
  String _catalogId = 'sofa-3';
  PlanObjectType _engineeringType = PlanObjectType.waterPoint;

  String _id() => 'obj-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var changed = false;
      final liveFixtureIds = <String>{};
      for (final object in widget.floor.planObjects) {
        if (_isFixedLightingObject(object)) {
          liveFixtureIds.add(_fixtureElectricalId(object));
          changed |= _syncLightingElectricalPoint(object);
        }
      }
      final before = widget.floor.electricalPoints.length;
      widget.floor.electricalPoints.removeWhere(
        (point) =>
            point.id.startsWith('fixture:') &&
            !liveFixtureIds.contains(point.id),
      );
      changed |= before != widget.floor.electricalPoints.length;
      if (changed) await widget.onChanged();
      if (mounted) setState(() {});
    });
  }

  String _fixtureElectricalId(PlanObject object) => 'fixture:${object.id}';

  bool _isFixedLightingObject(PlanObject object) {
    if (object.catalogId.isEmpty || object.type != PlanObjectType.lighting) {
      return false;
    }
    final mount = ObjectCatalog.byId(object.catalogId).mount;
    return mount == CatalogMount.wall || mount == CatalogMount.ceiling;
  }

  bool _removeLightingElectricalPoint(PlanObject object) {
    final before = widget.floor.electricalPoints.length;
    widget.floor.electricalPoints.removeWhere(
      (point) => point.id == _fixtureElectricalId(object),
    );
    return before != widget.floor.electricalPoints.length;
  }

  bool _syncLightingElectricalPoint(PlanObject object) {
    if (!_isFixedLightingObject(object)) {
      return _removeLightingElectricalPoint(object);
    }
    final item = ObjectCatalog.byId(object.catalogId);
    final id = _fixtureElectricalId(object);
    final isWall = item.mount == CatalogMount.wall;

    var x = object.xMm;
    var y = object.yMm;
    String? wallId;
    double? wallOffsetMm;
    var wallSide = 1;
    if (isWall) {
      final hit = GeometryService.nearestWallProjection(
        widget.floor,
        math.Point<double>(object.xMm, object.yMm),
        thresholdMm: 1600,
      );
      if (hit != null) {
        x = hit.point.x;
        y = hit.point.y;
        wallId = hit.wall.id;
        wallOffsetMm = widget.floor.wallLengthMm(hit.wall) * hit.t;
        final a = widget.floor.nodeById(hit.wall.startNodeId);
        final b = widget.floor.nodeById(hit.wall.endNodeId);
        if (a != null && b != null) {
          final dx = b.xMm - a.xMm;
          final dy = b.yMm - a.yMm;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len > 1) {
            final nx = -dy / len;
            final ny = dx / len;
            final sideValue =
                (object.xMm - hit.point.x) * nx +
                (object.yMm - hit.point.y) * ny;
            wallSide = sideValue >= 0 ? 1 : -1;
          }
        }
      }
    }

    final type = isWall
        ? ElectricalPointType.wallLight
        : ElectricalPointType.ceilingLight;
    final height = isWall
        ? object.elevationMm + object.heightMm / 2
        : widget.floor.defaultHeightMm;

    ElectricalPoint? point;
    for (final candidate in widget.floor.electricalPoints) {
      if (candidate.id == id) {
        point = candidate;
        break;
      }
    }
    if (point == null) {
      widget.floor.electricalPoints.add(
        ElectricalPoint(
          id: id,
          type: type,
          xMm: x,
          yMm: y,
          label: item.name,
          heightMm: height,
          circuit: 'Освещение',
          powerW: isWall ? 12 : 24,
          wallId: wallId,
          wallOffsetMm: wallOffsetMm,
          wallSide: wallSide,
        ),
      );
      return true;
    }

    var changed = false;
    void assign(bool condition, void Function() update) {
      if (!condition) return;
      update();
      changed = true;
    }

    assign(point.type != type, () => point!.type = type);
    assign((point.xMm - x).abs() > 0.01, () => point!.xMm = x);
    assign((point.yMm - y).abs() > 0.01, () => point!.yMm = y);
    assign(point.label != item.name, () => point!.label = item.name);
    assign(
      (point.heightMm - height).abs() > 0.01,
      () => point!.heightMm = height,
    );
    assign(point.circuit != 'Освещение', () => point!.circuit = 'Освещение');
    assign(
      (point.powerW - (isWall ? 12 : 24)).abs() > 0.01,
      () => point!.powerW = isWall ? 12 : 24,
    );
    assign(point.wallId != wallId, () => point!.wallId = wallId);
    assign(
      point.wallOffsetMm != wallOffsetMm,
      () => point!.wallOffsetMm = wallOffsetMm,
    );
    assign(point.wallSide != wallSide, () => point!.wallSide = wallSide);
    return changed;
  }

  _ObjTx _tx(Size size) {
    final pts = <math.Point<double>>[];
    for (final n in widget.floor.nodes) pts.add(math.Point(n.xMm, n.yMm));
    // The viewport must be based on the fixed room geometry. Including the
    // dragged object's position rescales the plan on every touch update.
    if (pts.isEmpty)
      return _ObjTx(
        scale: 0.08,
        origin: Offset(size.width / 2, size.height / 2),
      );
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
    final w = math.max(1800.0, maxX - minX + 1200);
    final h = math.max(1800.0, maxY - minY + 1200);
    final scale = math.min(size.width / w, size.height / h);
    return _ObjTx(
      scale: scale,
      origin: Offset(
        size.width / 2 - (minX + maxX) / 2 * scale,
        size.height / 2 - (minY + maxY) / 2 * scale,
      ),
    );
  }

  math.Point<double> _screenToMm(Offset p, Size size) {
    final tx = _tx(size);
    return math.Point<double>(
      (p.dx - tx.origin.dx) / tx.scale,
      (p.dy - tx.origin.dy) / tx.scale,
    );
  }

  PlanObject? _objectById(String? id) {
    if (id == null) return null;
    for (final o in widget.floor.planObjects) {
      if (o.id == id) return o;
    }
    return null;
  }

  void _snapObjectGuides(PlanObject o) {
    var bestX = 120.0;
    var bestY = 120.0;
    double? sx;
    double? sy;
    for (final other in widget.floor.planObjects) {
      if (other.id == o.id) continue;
      final dx = (other.xMm - o.xMm).abs();
      final dy = (other.yMm - o.yMm).abs();
      if (dx < bestX) {
        bestX = dx;
        sx = other.xMm;
      }
      if (dy < bestY) {
        bestY = dy;
        sy = other.yMm;
      }
    }
    if (sx != null) o.xMm = sx;
    if (sy != null) o.yMm = sy;
  }

  void _alignKitchenPlane(PlanObject o) {
    if (!o.catalogId.startsWith('kitchen-')) return;
    PlanObject? best;
    var bestDistance = 1500.0;
    for (final other in widget.floor.planObjects) {
      if (other.id == o.id || !other.catalogId.startsWith('kitchen-')) continue;
      final dx = other.xMm - o.xMm;
      final dy = other.yMm - o.yMm;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestDistance) {
        bestDistance = d;
        best = other;
      }
    }
    if (best == null) return;
    o.rotationDeg = best.rotationDeg;
    final a = best.rotationDeg * math.pi / 180;
    final nx = -math.sin(a);
    final ny = math.cos(a);
    final targetPlane = best.xMm * nx + best.yMm * ny - best.depthMm / 2;
    final ownPlane = o.xMm * nx + o.yMm * ny - o.depthMm / 2;
    final delta = targetPlane - ownPlane;
    if (delta.abs() <= 220) {
      o.xMm += nx * delta;
      o.yMm += ny * delta;
    }
    final tx = math.cos(a), ty = math.sin(a);
    final along = (o.xMm - best.xMm) * tx + (o.yMm - best.yMm) * ty;
    final endToStart = (best.widthMm + o.widthMm) / 2;
    final snapped = along >= 0 ? endToStart : -endToStart;
    if ((along - snapped).abs() <= 220) {
      o.xMm += tx * (snapped - along);
      o.yMm += ty * (snapped - along);
    }
  }

  void _snapRadiatorToWall(PlanObject o) {
    if (o.type != PlanObjectType.radiator && o.catalogId != 'radiator') return;
    final hit = GeometryService.nearestWallProjection(
      widget.floor,
      math.Point(o.xMm, o.yMm),
      thresholdMm: 600,
    );
    if (hit == null) return;
    final a = widget.floor.nodeById(hit.wall.startNodeId);
    final b = widget.floor.nodeById(hit.wall.endNodeId);
    if (a == null || b == null) return;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return;
    final nx = -dy / length, ny = dx / length;
    final side = (o.xMm - hit.point.x) * nx + (o.yMm - hit.point.y) * ny >= 0
        ? 1.0
        : -1.0;
    final clearance = hit.wall.thicknessMm / 2 + o.depthMm / 2 + 8;
    o.xMm = hit.point.x + nx * side * clearance;
    o.yMm = hit.point.y + ny * side * clearance;
    o.rotationDeg = math.atan2(dy, dx) * 180 / math.pi;
  }

  void _snapCatalogMount(PlanObject o) {
    if (o.catalogId.isEmpty) return;
    final item = ObjectCatalog.byId(o.catalogId);
    if (item.mount == CatalogMount.ceiling) {
      o.elevationMm = math.max(0.0, widget.floor.defaultHeightMm - o.heightMm);
      return;
    }
    if (item.mount != CatalogMount.wall) return;

    final hit = GeometryService.nearestWallProjection(
      widget.floor,
      math.Point(o.xMm, o.yMm),
      thresholdMm: 900,
    );
    if (hit == null) return;
    final a = widget.floor.nodeById(hit.wall.startNodeId);
    final b = widget.floor.nodeById(hit.wall.endNodeId);
    if (a == null || b == null) return;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return;
    final nx = -dy / length, ny = dx / length;
    final side = (o.xMm - hit.point.x) * nx + (o.yMm - hit.point.y) * ny >= 0
        ? 1.0
        : -1.0;
    final clearance = hit.wall.thicknessMm / 2 + o.depthMm / 2 + 6;
    o.xMm = hit.point.x + nx * side * clearance;
    o.yMm = hit.point.y + ny * side * clearance;
    o.rotationDeg = math.atan2(dy, dx) * 180 / math.pi;
  }

  void _objectScaleStart(ScaleStartDetails d, Size size) {
    final o = _near(_screenToMm(d.localFocalPoint, size));
    final tx = _tx(size);
    setState(() {
      _gestureObjectId = o?.id;
      _selectedId = o?.id;
      _gestureBaseRotation = o?.rotationDeg ?? 0;
      _gestureSnapAngleDeg = null;
      _gestureGrabOffset = o == null
          ? Offset.zero
          : d.localFocalPoint - (tx.origin + Offset(o.xMm, o.yMm) * tx.scale);
      _gestureDirty = false;
    });
  }

  void _objectScaleUpdate(ScaleUpdateDetails d, Size size) {
    final o = _objectById(_gestureObjectId);
    if (o == null) return;
    final previousX = o.xMm, previousY = o.yMm;
    final previousAngle = o.rotationDeg;
    final target = _screenToMm(d.localFocalPoint - _gestureGrabOffset, size);
    o.xMm = target.x;
    o.yMm = target.y;
    if (d.pointerCount >= 2) {
      final rawRotation = _gestureBaseRotation + d.rotation * 180 / math.pi;
      final snap = AngleSnapService.snapQuarterTurnWithLock(
        rawRotation,
        lockedAngleDeg: _gestureSnapAngleDeg,
      );
      o.rotationDeg = snap.angleDeg;
      _gestureSnapAngleDeg = snap.lockedAngleDeg;
    } else {
      _gestureSnapAngleDeg = null;
      _snapObjectGuides(o);
      _snapRadiatorToWall(o);
      _snapCatalogMount(o);
    }
    final mount = o.catalogId.isEmpty
        ? CatalogMount.floor
        : ObjectCatalog.byId(o.catalogId).mount;
    if (SpaceCheckService.intersectsWall(widget.floor, o) &&
        mount != CatalogMount.wall) {
      // A snap must not glue an object to a wall. Retry at the finger,
      // then slide along either axis when a corner blocks the diagonal.
      o.xMm = target.x;
      o.yMm = target.y;
      if (SpaceCheckService.intersectsWall(widget.floor, o)) {
        o.yMm = previousY;
        if (SpaceCheckService.intersectsWall(widget.floor, o)) {
          o.xMm = previousX;
          o.yMm = target.y;
          if (SpaceCheckService.intersectsWall(widget.floor, o)) {
            o.xMm = previousX;
            o.yMm = previousY;
          }
        }
      }
      if (SpaceCheckService.intersectsWall(widget.floor, o)) {
        o.rotationDeg = previousAngle;
      }
    }
    _gestureDirty |=
        o.xMm != previousX ||
        o.yMm != previousY ||
        o.rotationDeg != previousAngle;
    setState(() {});
  }

  Future<void> _objectScaleEnd(ScaleEndDetails d) async {
    if (_gestureObjectId == null) return;
    final object = _objectById(_gestureObjectId);
    if (object != null && object.catalogId.startsWith('kitchen-')) {
      final x = object.xMm, y = object.yMm, angle = object.rotationDeg;
      _alignKitchenPlane(object);
      if (SpaceCheckService.intersectsWall(widget.floor, object)) {
        object.xMm = x;
        object.yMm = y;
        object.rotationDeg = angle;
      }
      _gestureDirty |=
          object.xMm != x || object.yMm != y || object.rotationDeg != angle;
    }
    if (object != null) {
      _gestureDirty |= _syncLightingElectricalPoint(object);
    }
    if (_gestureDirty) await widget.onChanged();
    if (mounted)
      setState(() {
        _gestureObjectId = null;
        _gestureSnapAngleDeg = null;
        _gestureDirty = false;
      });
  }

  PlanObject? _near(math.Point<double> p) {
    PlanObject? best;
    var distance = double.infinity;
    for (final o in widget.floor.planObjects.reversed) {
      final dx = o.xMm - p.x, dy = o.yMm - p.y;
      final a = o.rotationDeg * math.pi / 180;
      final localX = dx * math.cos(a) + dy * math.sin(a);
      final localY = -dx * math.sin(a) + dy * math.cos(a);
      if (localX.abs() > o.widthMm / 2 + 100 ||
          localY.abs() > o.depthMm / 2 + 100)
        continue;
      final dd = math.sqrt(dx * dx + dy * dy);
      if (dd < distance) {
        distance = dd;
        best = o;
      }
    }
    return best;
  }

  ({double w, double d, double h, double elevation}) _engineeringDefaults(
    PlanObjectType t,
  ) => switch (t) {
    PlanObjectType.ceilingZone => (
      w: 2400,
      d: 1800,
      h: 100,
      elevation: widget.floor.defaultHeightMm - 120,
    ),
    PlanObjectType.waterPoint => (w: 120, d: 120, h: 120, elevation: 550),
    PlanObjectType.drainPoint => (w: 150, d: 150, h: 100, elevation: 100),
    PlanObjectType.radiator => (w: 900, d: 120, h: 600, elevation: 120),
    PlanObjectType.furniture => (w: 1200, d: 600, h: 800, elevation: 0),
    PlanObjectType.sanitary => (w: 700, d: 700, h: 850, elevation: 0),
    PlanObjectType.beam => (
      w: 2000,
      d: 300,
      h: 400,
      elevation: widget.floor.defaultHeightMm - 400,
    ),
    PlanObjectType.column => (
      w: 300,
      d: 300,
      h: widget.floor.defaultHeightMm,
      elevation: 0,
    ),
    PlanObjectType.box => (
      w: 500,
      d: 300,
      h: widget.floor.defaultHeightMm,
      elevation: 0,
    ),
    PlanObjectType.niche => (w: 800, d: 150, h: 1200, elevation: 500),
    PlanObjectType.lighting => (
      w: 500,
      d: 500,
      h: 200,
      elevation: math.max(0.0, widget.floor.defaultHeightMm - 200),
    ),
  };

  Future<void> _tap(TapUpDetails d, Size size) async {
    final tx = _tx(size);
    final p = math.Point<double>(
      (d.localPosition.dx - tx.origin.dx) / tx.scale,
      (d.localPosition.dy - tx.origin.dy) / tx.scale,
    );
    final existing = _near(p);
    if (existing != null) {
      setState(() => _selectedId = existing.id);
      await _edit(existing);
      return;
    }

    late PlanObject o;
    if (_source == _AddSource.catalog) {
      final item = ObjectCatalog.byId(_catalogId);
      o = PlanObject(
        id: _id(),
        type: item.type,
        xMm: (p.x / 10).round() * 10.0,
        yMm: (p.y / 10).round() * 10.0,
        widthMm: item.widthMm,
        depthMm: item.depthMm,
        heightMm: item.heightMm,
        elevationMm: item.elevationMm,
        label: item.name,
        layer: _layer,
        catalogId: item.id,
      );
    } else {
      final def = _engineeringDefaults(_engineeringType);
      o = PlanObject(
        id: _id(),
        type: _engineeringType,
        xMm: (p.x / 10).round() * 10.0,
        yMm: (p.y / 10).round() * 10.0,
        widthMm: def.w,
        depthMm: def.d,
        heightMm: def.h,
        elevationMm: def.elevation,
        layer: _layer,
      );
    }
    _snapObjectGuides(o);
    _alignKitchenPlane(o);
    _snapRadiatorToWall(o);
    _snapCatalogMount(o);
    if (SpaceCheckService.intersectsWall(widget.floor, o) &&
        ObjectCatalog.byId(o.catalogId).mount != CatalogMount.wall) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Предмет пересекает стену. Выбери свободное место.'),
        ),
      );
      return;
    }
    widget.floor.planObjects.add(o);
    _syncLightingElectricalPoint(o);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _edit(PlanObject o) async {
    final width = TextEditingController(text: o.widthMm.round().toString());
    final depth = TextEditingController(text: o.depthMm.round().toString());
    final height = TextEditingController(text: o.heightMm.round().toString());
    final elevation = TextEditingController(
      text: o.elevationMm.round().toString(),
    );
    final rotation = TextEditingController(
      text: o.rotationDeg.round().toString(),
    );
    final slope = TextEditingController(text: o.slopePct.toStringAsFixed(1));
    final label = TextEditingController(text: o.label);
    var layer = o.layer;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  o.catalogId.isEmpty
                      ? o.type.label
                      : ObjectCatalog.byId(o.catalogId).name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Подпись'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: width,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ширина',
                          suffixText: 'мм',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: depth,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Глубина',
                          suffixText: 'мм',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Высота',
                          suffixText: 'мм',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: elevation,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Отметка низа',
                          suffixText: 'мм',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rotation,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Поворот',
                          suffixText: '°',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: slope,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Уклон',
                          suffixText: '%',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ProjectLayer>(
                  value: layer,
                  decoration: const InputDecoration(labelText: 'Слой проекта'),
                  items: ProjectLayer.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                      )
                      .toList(),
                  onChanged: (v) => setModal(() => layer = v ?? layer),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: const Text('Сохранить'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'delete') {
      _removeLightingElectricalPoint(o);
      widget.floor.planObjects.removeWhere((e) => e.id == o.id);
    } else if (result == 'save') {
      o.label = label.text.trim();
      o.widthMm = double.tryParse(width.text.replaceAll(',', '.')) ?? o.widthMm;
      o.depthMm = double.tryParse(depth.text.replaceAll(',', '.')) ?? o.depthMm;
      o.heightMm =
          double.tryParse(height.text.replaceAll(',', '.')) ?? o.heightMm;
      o.elevationMm =
          double.tryParse(elevation.text.replaceAll(',', '.')) ?? o.elevationMm;
      o.rotationDeg =
          double.tryParse(rotation.text.replaceAll(',', '.')) ?? o.rotationDeg;
      o.slopePct =
          double.tryParse(slope.text.replaceAll(',', '.')) ?? o.slopePct;
      o.layer = layer;
      _snapCatalogMount(o);
      _syncLightingElectricalPoint(o);
    } else {
      return;
    }
    await widget.onChanged();
    if (mounted) setState(() => _selectedId = null);
  }

  List<PlanObjectType> get _engineeringTypes => const [
    PlanObjectType.waterPoint,
    PlanObjectType.drainPoint,
    PlanObjectType.beam,
    PlanObjectType.column,
    PlanObjectType.box,
    PlanObjectType.niche,
  ];

  Widget _modelPreview(ObjectCatalogItem item, double size) {
    final preview = FloorPlan(
      id: 'preview',
      name: 'preview',
      planObjects: [
        PlanObject(
          id: item.id,
          type: item.type,
          xMm: 0,
          yMm: 0,
          widthMm: item.widthMm,
          depthMm: item.depthMm,
          heightMm: item.heightMm,
          catalogId: item.id,
        ),
      ],
    );
    final scale = math.min(
      (size - 12) / item.widthMm,
      (size - 12) / item.depthMm,
    );
    final fallback = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlanningPainter(
            floor: preview,
            scale: scale,
            origin: Offset(size / 2, size / 2),
            darkPreview: true,
          ),
        ),
      ),
    );
    return ZamerModelThumbnail(
      catalogId: item.id,
      size: size,
      fallback: fallback,
    );
  }

  Future<void> _chooseModel() async {
    var group = _group;
    var query = '';
    var showcase = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1517),
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .90,
        child: StatefulBuilder(
          builder: (context, refresh) {
            final normalizedQuery = query.trim().toLowerCase();
            final sourceItems = normalizedQuery.isEmpty
                ? ObjectCatalog.inGroup(group)
                : ObjectCatalog.items;
            final items = sourceItems
                .where(
                  (item) =>
                      normalizedQuery.isEmpty ||
                      item.name.toLowerCase().contains(normalizedQuery) ||
                      item.group.toLowerCase().contains(normalizedQuery) ||
                      item.mountLabel.toLowerCase().contains(normalizedQuery),
                )
                .toList(growable: false);

            void choose(ObjectCatalogItem item) {
              setState(() {
                _group = item.group;
                _catalogId = item.id;
              });
              Navigator.pop(sheetContext);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Оснащение',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.grid_view_outlined),
                              label: Text('Витрина'),
                            ),
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.view_list_outlined),
                              label: Text('Список'),
                            ),
                          ],
                          selected: {showcase},
                          onSelectionChanged: (value) =>
                              refresh(() => showcase = value.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Поиск мебели, сантехники, техники…',
                      ),
                      onChanged: (value) => refresh(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: showcase
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: ListView.separated(
                                    itemCount: ObjectCatalog.groups.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 4),
                                    itemBuilder: (context, index) {
                                      final candidate =
                                          ObjectCatalog.groups[index];
                                      final selected = candidate == group;
                                      return Material(
                                        color: selected
                                            ? const Color(0xFF3B3028)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => refresh(() {
                                            group = candidate;
                                            query = '';
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 11,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  candidate,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: selected
                                                        ? FontWeight.w800
                                                        : FontWeight.w500,
                                                    color: selected
                                                        ? const Color(
                                                            0xFFF1C79E,
                                                          )
                                                        : Colors.white70,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${ObjectCatalog.inGroup(candidate).length} моделей',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: selected
                                                        ? const Color(
                                                            0xFFF1C79E,
                                                          ).withValues(
                                                            alpha: .75,
                                                          )
                                                        : Colors.white38,
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
                                const VerticalDivider(width: 14),
                                Expanded(
                                  child: items.isEmpty
                                      ? const Center(
                                          child: Text('Ничего не найдено'),
                                        )
                                      : GridView.builder(
                                          itemCount: items.length,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 8,
                                                crossAxisSpacing: 8,
                                                childAspectRatio: .64,
                                              ),
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            final selected =
                                                item.id == _catalogId;
                                            return InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: () => choose(item),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  9,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF172125,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: selected
                                                        ? const Color(
                                                            0xFFF1C79E,
                                                          )
                                                        : const Color(
                                                            0xFF29373B,
                                                          ),
                                                    width: selected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      child: Center(
                                                        child: _modelPreview(
                                                          item,
                                                          118,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      item.name,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item.group,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Color(
                                                          0xFF77BFA4,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${item.widthMm.round()} × '
                                                      '${item.depthMm.round()} × '
                                                      '${item.heightMm.round()} мм',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 7,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF233036,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        item.mountLabel,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Color(
                                                            0xFF9DE6C8,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  leading: _modelPreview(item, 54),
                                  title: Text(item.name),
                                  subtitle: Text(
                                    '${item.widthMm.round()} × '
                                    '${item.depthMm.round()} × '
                                    '${item.heightMm.round()} мм • ${item.mountLabel}',
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () => choose(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupItems = ObjectCatalog.inGroup(_group);
    final spaceIssues = SpaceCheckService.inspect(widget.floor);
    if (!groupItems.any((e) => e.id == _catalogId) && groupItems.isNotEmpty)
      _catalogId = groupItems.first.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  const Text(
                    'Объекты: добавление и перемещение',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...[
                    const SizedBox(height: 8),
                    SegmentedButton<_AddSource>(
                      segments: const [
                        ButtonSegment(
                          value: _AddSource.catalog,
                          icon: Icon(Icons.chair_alt_outlined),
                          label: Text('Библиотека'),
                        ),
                        ButtonSegment(
                          value: _AddSource.engineering,
                          icon: Icon(Icons.engineering_outlined),
                          label: Text('Инженерия'),
                        ),
                      ],
                      selected: {_source},
                      onSelectionChanged: (v) =>
                          setState(() => _source = v.first),
                    ),
                    const SizedBox(height: 8),
                    if (_source == _AddSource.catalog) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _modelPreview(
                          ObjectCatalog.byId(_catalogId),
                          52,
                        ),
                        title: Text(ObjectCatalog.byId(_catalogId).name),
                        subtitle: Text(
                          '$_group · '
                          '${ObjectCatalog.byId(_catalogId).widthMm.round()} × '
                          '${ObjectCatalog.byId(_catalogId).depthMm.round()} × '
                          '${ObjectCatalog.byId(_catalogId).heightMm.round()} мм',
                        ),
                        trailing: const Icon(Icons.grid_view_outlined),
                        onTap: _chooseModel,
                      ),
                    ] else
                      DropdownButtonFormField<PlanObjectType>(
                        value: _engineeringType,
                        decoration: const InputDecoration(
                          labelText: 'Инженерный / конструктивный элемент',
                        ),
                        items: _engineeringTypes
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _engineeringType = v ?? _engineeringType,
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProjectLayer>(
                      value: _layer,
                      decoration: const InputDecoration(labelText: 'Слой'),
                      items: ProjectLayer.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _layer = v ?? _layer),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              final tx = _tx(size);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d, size),
                onScaleStart: (d) => _objectScaleStart(d, size),
                onScaleUpdate: (d) => _objectScaleUpdate(d, size),
                onScaleEnd: _objectScaleEnd,
                child: CustomPaint(
                  painter: _PlanningPainter(
                    floor: widget.floor,
                    scale: tx.scale,
                    origin: tx.origin,
                    selectedId: _selectedId,
                    snapAngleDeg: _gestureSnapAngleDeg,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        if (widget.floor.planObjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Text(
                          'Коллизии и проходы',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (spaceIssues.isEmpty)
                          const Text(
                            'Пересечений объектов и перекрытых дверных проходов не найдено.',
                          ),
                        for (final issue in spaceIssues)
                          ListTile(
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(issue.description),
                          ),
                        const SizedBox(height: 10),
                        const Text(
                          'Для дверей проверяется зона глубиной 600 мм с каждой стороны. Сложные маршруты прохода требуют отдельной проверки.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: Icon(
                spaceIssues.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              label: Text('Проходы и пересечения: ${spaceIssues.length}'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Text(
            'Нажми на свободное место для установки. Потяни объект одним пальцем; двумя — поверни. Возле 0/90/180/270° включается магнитная привязка.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PlanningPainter extends CustomPainter {
  const _PlanningPainter({
    required this.floor,
    required this.scale,
    required this.origin,
    this.selectedId,
    this.snapAngleDeg,
    this.darkPreview = false,
  });
  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedId;
  final double? snapAngleDeg;
  final bool darkPreview;
  Offset p(double x, double y) => origin + Offset(x * scale, y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = darkPreview
            ? const Color(0xFF10181B)
            : const Color(0xFFF7F8FA),
    );
    for (final w in floor.walls) {
      final a = floor.nodeById(w.startNodeId), b = floor.nodeById(w.endNodeId);
      if (a == null || b == null) continue;
      final color = w.demolition || w.projectLayer == ProjectLayer.demolition
          ? const Color(0xFFD85B68)
          : w.projectLayer == ProjectLayer.proposed
          ? const Color(0xFF55B98C)
          : const Color(0xFF3B4148);
      canvas.drawLine(
        p(a.xMm, a.yMm),
        p(b.xMm, b.yMm),
        Paint()
          ..color = color
          ..strokeWidth = math.max(2, w.thicknessMm * scale)
          ..strokeCap = StrokeCap.square,
      );
    }
    if (selectedId != null && snapAngleDeg != null) {
      PlanObject? active;
      for (final object in floor.planObjects) {
        if (object.id == selectedId) {
          active = object;
          break;
        }
      }
      if (active != null) {
        final c = p(active.xMm, active.yMm);
        final guide = Paint()
          ..color = const Color(0xFF18A979).withValues(alpha: .48)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), guide);
        canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), guide);
      }
    }
    for (final o in floor.planObjects) _object(canvas, o, size);
  }

  void _object(Canvas canvas, PlanObject o, Size size) {
    final c = p(o.xMm, o.yMm);
    final selected = o.id == selectedId;
    final color = switch (o.layer) {
      ProjectLayer.existing => const Color(0xFF64717D),
      ProjectLayer.demolition => const Color(0xFFC04E5A),
      ProjectLayer.proposed => const Color(0xFF4E68A7),
    };
    final fill = Paint()..color = color.withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = selected ? const Color(0xFF0D5BD7) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.5 : 1.5;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(o.rotationDeg * math.pi / 180);
    final w = math.max(12.0, o.widthMm * scale),
        d = math.max(12.0, o.depthMm * scale);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: d);
    final id = o.catalogId;

    if (id.startsWith('bed-')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        stroke,
      );
      final pillowW = w * .34, pillowH = d * .16;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * .42, -d * .42, pillowW, pillowH),
          const Radius.circular(3),
        ),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .08, -d * .42, pillowW, pillowH),
          const Radius.circular(3),
        ),
        stroke,
      );
      canvas.drawLine(
        Offset(-w / 2, -d * .30),
        Offset(w / 2, -d * .30),
        stroke,
      );
    } else if (id.startsWith('sofa-')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, d) * .12)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, d) * .12)),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * .45, -d * .42, w * .90, d * .18),
          const Radius.circular(3),
        ),
        stroke,
      );
      final seats = id == 'sofa-2' ? 2 : 3;
      for (var i = 1; i < seats; i++) {
        final x = -w * .40 + w * .80 * i / seats;
        canvas.drawLine(Offset(x, -d * .18), Offset(x, d * .40), stroke);
      }
    } else if (id == 'armchair') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, d) * .18)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(math.min(w, d) * .18)),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * .32, -d * .28, w * .64, d * .55),
          const Radius.circular(4),
        ),
        stroke,
      );
    } else if (id == 'kitchen-sink') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      final basin = Rect.fromCenter(
        center: const Offset(0, 2),
        width: w * .68,
        height: d * .58,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(basin, Radius.circular(math.min(w, d) * .08)),
        stroke,
      );
      canvas.drawCircle(Offset(0, d * .10), math.min(w, d) * .045, stroke);
      canvas.drawCircle(Offset(0, -d * .35), math.min(w, d) * .025, stroke);
    } else if (id == 'kitchen-oven') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, d * .08),
          width: w * .75,
          height: d * .58,
        ),
        stroke,
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(
          Offset(i * w * .23, -d * .34),
          math.min(w, d) * .045,
          stroke,
        );
      }
    } else if (id == 'washer' || id == 'dryer' || id == 'dishwasher') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        stroke,
      );
      if (id == 'dishwasher') {
        canvas.drawLine(
          Offset(-w * .4, -d * .3),
          Offset(w * .4, -d * .3),
          stroke,
        );
        canvas.drawCircle(
          Offset(w * .3, -d * .4),
          math.min(w, d) * .025,
          stroke,
        );
      } else {
        canvas.drawCircle(Offset(0, d * .05), math.min(w, d) * .32, stroke);
        canvas.drawCircle(Offset(0, d * .05), math.min(w, d) * .24, stroke);
        canvas.drawLine(
          Offset(-w * .4, -d * .35),
          Offset(w * .4, -d * .35),
          stroke,
        );
      }
    } else if (id.startsWith('wardrobe-') ||
        id == 'fridge' ||
        id.startsWith('kitchen-base') ||
        id == 'kitchen-tall' ||
        id == 'kitchen-upper') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      final doors = id == 'wardrobe-3'
          ? 3
          : (id.startsWith('wardrobe') ? 2 : 1);
      for (var i = 1; i < doors; i++) {
        final x = -w / 2 + w * i / doors;
        canvas.drawLine(Offset(x, -d / 2), Offset(x, d / 2), stroke);
      }
      if (id == 'fridge')
        canvas.drawLine(
          Offset(-w / 2, -d * .10),
          Offset(w / 2, -d * .10),
          stroke,
        );
      if (id.startsWith('wardrobe-') || id.startsWith('kitchen-')) {
        for (var i = 0; i < doors; i++) {
          final x = -w / 2 + w * (i + .5) / doors;
          canvas.drawLine(Offset(x, d * .21), Offset(x, d * .38), stroke);
        }
      }
    } else if (id == 'table-round') {
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
      canvas.drawCircle(Offset.zero, math.min(w, d) * .08, stroke);
    } else if (id == 'table-rect') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        stroke,
      );
    } else if (id == 'chair') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        stroke,
      );
      canvas.drawLine(
        Offset(-w / 2, -d * .28),
        Offset(w / 2, -d * .28),
        stroke,
      );
    } else if (id == 'toilet') {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, d * .10),
          width: w * .72,
          height: d * .66,
        ),
        fill,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, d * .10),
          width: w * .72,
          height: d * .66,
        ),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -d * .34),
            width: w * .75,
            height: d * .25,
          ),
          const Radius.circular(3),
        ),
        stroke,
      );
    } else if (id == 'sink') {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .92, height: d * .82),
        fill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .92, height: d * .82),
        stroke,
      );
      canvas.drawCircle(Offset(0, -d * .16), math.min(w, d) * .06, stroke);
    } else if (id == 'bath') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(d * .35)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(d * .35)),
        stroke,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w * .84, height: d * .64),
          Radius.circular(d * .28),
        ),
        stroke,
      );
    } else if (id == 'shower') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      canvas.drawCircle(
        Offset(-w * .30, -d * .30),
        math.min(w, d) * .06,
        stroke,
      );
      canvas.drawArc(
        Rect.fromLTWH(-w * .42, -d * .42, w * .84, d * .84),
        0,
        math.pi / 2,
        false,
        stroke,
      );
      canvas.drawLine(
        Offset(w * .42, -d * .42),
        Offset(w * .42, d * .42),
        stroke,
      );
    } else if (id == 'radiator') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      for (var i = 1; i < 7; i++) {
        final x = -w / 2 + w * i / 7;
        canvas.drawLine(Offset(x, -d / 2), Offset(x, d / 2), stroke);
      }
    } else if ({
      PlanObjectType.waterPoint,
      PlanObjectType.drainPoint,
    }.contains(o.type)) {
      canvas.drawCircle(Offset.zero, 9, fill);
      canvas.drawCircle(Offset.zero, 9, stroke);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        stroke,
      );
    }
    canvas.restore();

    if (!selected) return;
    final name = o.label.isEmpty ? o.type.label : o.label;
    final snapped = snapAngleDeg != null;
    final label = snapped
        ? '$name • ${o.rotationDeg.round()}° • 90°'
        : '$name • ${o.rotationDeg.round()}°';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: snapped ? const Color(0xFF087A5B) : const Color(0xFF30363D),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.min(160.0, math.max(80.0, size.width - 24)));
    final x = (c.dx - tp.width / 2)
        .clamp(8.0, math.max(8.0, size.width - tp.width - 8))
        .toDouble();
    final y = (c.dy - d / 2 - 25)
        .clamp(8.0, math.max(8.0, size.height - tp.height - 8))
        .toDouble();
    final labelRect = Rect.fromLTWH(x - 4, y - 2, tp.width + 8, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()
        ..color = snapAngleDeg != null
            ? const Color(0xFFE5F7F0)
            : const Color(0xFFF7F8FA),
    );
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _PlanningPainter oldDelegate) => true;
}

class _ObjTx {
  const _ObjTx({required this.scale, required this.origin});
  final double scale;
  final Offset origin;
}
