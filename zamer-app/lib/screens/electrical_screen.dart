import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../widgets/electrical_plan_painter.dart';

enum ElectricalMode { add, wire, select }

class ElectricalScreen extends StatefulWidget {
  const ElectricalScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

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
  String? _dragPointId;
  bool _dragUndoPushed = false;
  final _undo = <String>[];
  final _redo = <String>[];

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
    if (_needsWall(point.type)) {
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

  Future<void> _pointSheet(ElectricalPoint p) async {
    final label = TextEditingController(text: p.label);
    final circuit = TextEditingController(text: p.circuit);
    final height = TextEditingController(text: p.heightMm.round().toString());
    final power = TextEditingController(text: p.powerW.round().toString());
    var localModules = List<ElectricalModuleType>.of(p.modules);
    var frameVertical = p.frameVertical;
    var wallSide = p.wallSide;
    if (localModules.isEmpty && _needsWall(p.type))
      localModules = _defaultModules(p.type);

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
                  p.type.label,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (p.wallId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Привязано к стене • ${p.wallOffsetMm?.round() ?? 0} мм от начала',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (p.wallId != null)
                  SwitchListTile.adaptive(
                    title: const Text('Обратная сторона стены'),
                    subtitle: const Text(
                      'Перенести устройство на другую поверхность',
                    ),
                    value: wallSide == -1,
                    onChanged: (value) =>
                        setModal(() => wallSide = value ? -1 : 1),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Подпись'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: circuit,
                  decoration: const InputDecoration(
                    labelText: 'Группа / линия',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Высота установки',
                    suffixText: 'мм',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: power,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Мощность нагрузки',
                    suffixText: 'Вт',
                  ),
                ),
                if (_needsWall(p.type)) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Рамка',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DropdownButton<int>(
                        value: localModules.length.clamp(1, 5).toInt(),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} пост.'),
                          ),
                        ),
                        onChanged: (count) {
                          if (count == null) return;
                          setModal(() {
                            while (localModules.length < count)
                              localModules.add(ElectricalModuleType.socket220);
                            while (localModules.length > count)
                              localModules.removeLast();
                          });
                        },
                      ),
                    ],
                  ),
                  ...List.generate(
                    localModules.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: DropdownButtonFormField<ElectricalModuleType>(
                        value: localModules[i],
                        decoration: InputDecoration(
                          labelText: 'Модуль ${i + 1}',
                        ),
                        items: ElectricalModuleType.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.label),
                              ),
                            )
                            .toList(),
                        onChanged: (m) {
                          if (m != null) setModal(() => localModules[i] = m);
                        },
                      ),
                    ),
                  ),
                  if (localModules.length > 1)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: frameVertical,
                      onChanged: (v) => setModal(() => frameVertical = v),
                      title: const Text('Вертикальная рамка'),
                      subtitle: Text(
                        frameVertical
                            ? 'Модули расположены друг над другом'
                            : 'Модули расположены в ряд',
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: const Text('Сохранить'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Удалить точку'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == 'delete') {
      _pushUndo();
      widget.floor.electricalRuns.removeWhere(
        (r) => r.startPointId == p.id || r.endPointId == p.id,
      );
      widget.floor.electricalPoints.removeWhere((e) => e.id == p.id);
    } else if (result == 'save') {
      _pushUndo();
      p.label = label.text.trim();
      p.circuit = circuit.text.trim().isEmpty
          ? 'Группа 1'
          : circuit.text.trim();
      p.heightMm =
          double.tryParse(height.text.replaceAll(',', '.')) ?? p.heightMm;
      p.powerW = double.tryParse(power.text.replaceAll(',', '.')) ?? p.powerW;
      p.modules
        ..clear()
        ..addAll(localModules);
      p.frameVertical = frameVertical;
      p.wallSide = wallSide;
      if (localModules.length > 1) p.type = ElectricalPointType.frame;
    } else {
      return;
    }
    await widget.onChanged();
    if (mounted) setState(() => _selectedId = null);
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
        Padding(
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              final t = _tx(size);
              return GestureDetector(
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
                  painter: ElectricalPlanPainter(
                    floor: widget.floor,
                    scale: t.scale,
                    origin: t.origin,
                    selectedPointId: _selectedId,
                    wireStartPointId: _wireStartId,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        if (widget.floor.electricalPoints.isNotEmpty)
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
