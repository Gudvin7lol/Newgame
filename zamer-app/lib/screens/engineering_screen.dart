import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/engineering_service.dart';
import '../services/geometry_service.dart';
import '../services/layout_service.dart';

enum _EngineeringTab { ceiling, warmFloor, routes }

class EngineeringScreen extends StatefulWidget {
  const EngineeringScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<EngineeringScreen> createState() => _EngineeringScreenState();
}

class _EngineeringScreenState extends State<EngineeringScreen> {
  _EngineeringTab _tab = _EngineeringTab.ceiling;
  String? _faceKey;
  String? _dragZoneId;
  String? _dragRunId;
  int? _dragVertex;
  bool _dragDirty = false;
  ServiceRunType _routeType = ServiceRunType.coldWater;
  bool _orthogonalRoutes = true;
  bool _showAllRoutes = false;
  final _draft = <ServiceVertex>[];

  Future<double?> _number(String label, double value, String unit) async {
    var raw = value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextFormField(
          initialValue: raw,
          onChanged: (value) => raw = value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(raw.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _editNumber(
    String label,
    double initial,
    String unit,
    bool Function(double) accept,
    void Function(double) assign,
  ) async {
    final value = await _number(label, initial, unit);
    if (value == null || !value.isFinite || !accept(value)) return;
    assign(value);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Widget _setting(String label, String value, VoidCallback edit) =>
      ListTile(title: Text(label), trailing: Text(value), onTap: edit);

  Widget _ceiling(RoomFace face, RoomMeta meta) {
    final spec = meta.ceiling;
    final baseHeight = GeometryService.roomHeightMm(widget.floor, face);
    final zoneArea = spec.zones.fold<double>(
      0,
      (sum, zone) => sum + EngineeringService.zoneAreaM2(face, zone),
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (widget.floor.planObjects.any(
          (o) => o.type == PlanObjectType.ceilingZone,
        ))
          FilledButton.tonalIcon(
            onPressed: () async {
              final moved = EngineeringService.migrateLegacyCeilingZones(
                widget.floor,
              );
              await widget.onChanged();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Перенесено потолочных зон: $moved')),
                );
              }
            },
            icon: const Icon(Icons.move_down_outlined),
            label: const Text('Перенести старые потолочные зоны'),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Потолок • ${face.areaM2.toStringAsFixed(2)} м²',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Чистая высота: ${(baseHeight - spec.dropMm).round()} мм'),
                Text('Зоны по помещению: ${zoneArea.toStringAsFixed(2)} м²'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: {'paint', 'drywall', 'stretch'}.contains(spec.finish)
              ? spec.finish
              : 'paint',
          decoration: const InputDecoration(labelText: 'Отделка потолка'),
          items: const [
            DropdownMenuItem(value: 'paint', child: Text('Покраска')),
            DropdownMenuItem(value: 'drywall', child: Text('ГКЛ')),
            DropdownMenuItem(value: 'stretch', child: Text('Натяжной')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            spec.finish = value;
            await widget.onChanged();
            if (mounted) setState(() {});
          },
        ),
        _setting(
          'Общее опускание',
          '${spec.dropMm.round()} мм',
          () => _editNumber(
            'Опускание потолка',
            spec.dropMm,
            'мм',
            (v) => v >= 0 && v <= 1200 && v < baseHeight - 1800,
            (v) => spec.dropMm = v,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              final tx = _PlanTransform.fromFloor(widget.floor, size);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  final p = tx.toModel(d.localPosition);
                  _dragZoneId = null;
                  for (final zone in spec.zones.reversed) {
                    if ((p.x - zone.xMm).abs() <= zone.widthMm / 2 + 100 &&
                        (p.y - zone.yMm).abs() <= zone.depthMm / 2 + 100) {
                      _dragZoneId = zone.id;
                      break;
                    }
                  }
                  _dragDirty = false;
                },
                onPanUpdate: (d) {
                  if (_dragZoneId == null) return;
                  final zone = spec.zones.firstWhere(
                    (z) => z.id == _dragZoneId,
                  );
                  zone.xMm += d.delta.dx / tx.scale;
                  zone.yMm += d.delta.dy / tx.scale;
                  _dragDirty = true;
                  setState(() {});
                },
                onPanEnd: (_) {
                  if (_dragDirty) widget.onChanged();
                  _dragZoneId = null;
                },
                child: CustomPaint(
                  painter: _EngineeringPainter(
                    floor: widget.floor,
                    face: face,
                    meta: meta,
                    tab: _EngineeringTab.ceiling,
                    tx: tx,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            spec.zones.add(
              CeilingZone(
                id: 'cz-${DateTime.now().microsecondsSinceEpoch}',
                xMm: face.centroid.x,
                yMm: face.centroid.y,
              ),
            );
            await widget.onChanged();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('Добавить потолочную зону'),
        ),
        const Text('Перетащи зону пальцем. Размеры и опускание задаются ниже.'),
        for (final zone in spec.zones)
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('Зона ${(spec.zones.indexOf(zone) + 1)}'),
                  subtitle: Text(
                    '${EngineeringService.zoneAreaM2(face, zone).toStringAsFixed(2)} м²',
                  ),
                  trailing: IconButton(
                    tooltip: 'Удалить зону',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      spec.zones.remove(zone);
                      await widget.onChanged();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () => _editNumber(
                        'Ширина зоны',
                        zone.widthMm,
                        'мм',
                        (v) => v >= 100 && v <= 10000,
                        (v) => zone.widthMm = v,
                      ),
                      child: Text('Ш ${zone.widthMm.round()}'),
                    ),
                    TextButton(
                      onPressed: () => _editNumber(
                        'Глубина зоны',
                        zone.depthMm,
                        'мм',
                        (v) => v >= 100 && v <= 10000,
                        (v) => zone.depthMm = v,
                      ),
                      child: Text('Г ${zone.depthMm.round()}'),
                    ),
                    TextButton(
                      onPressed: () => _editNumber(
                        'Дополнительное опускание',
                        zone.extraDropMm,
                        'мм',
                        (v) => v >= 0 && v <= 800,
                        (v) => zone.extraDropMm = v,
                      ),
                      child: Text('−${zone.extraDropMm.round()} мм'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _warmFloor(RoomFace face, RoomMeta meta) {
    final spec = meta.heating;
    final takeoff = EngineeringService.warmFloor(face, spec);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SwitchListTile.adaptive(
          title: const Text('Водяной тёплый пол'),
          subtitle: const Text('Расчёт трубы и контуров для помещения'),
          value: spec.enabled,
          onChanged: (value) async {
            spec.enabled = value;
            await widget.onChanged();
            if (mounted) setState(() {});
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Отапливаемая площадь: ${takeoff.areaM2.toStringAsFixed(2)} м²',
                ),
                Text('Труба с запасом: ${takeoff.pipeM.toStringAsFixed(1)} м'),
                Text('Контуры: ${takeoff.circuits}'),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 310,
          child: LayoutBuilder(
            builder: (context, c) => CustomPaint(
              painter: _EngineeringPainter(
                floor: widget.floor,
                face: face,
                meta: meta,
                tab: _EngineeringTab.warmFloor,
                tx: _PlanTransform.fromFloor(
                  widget.floor,
                  Size(c.maxWidth, c.maxHeight),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const Text(
          'Эскиз шага трубы. Зоны исключения и положение коллектора требуют отдельной монтажной схемы.',
        ),
        _setting(
          'Покрытие площади',
          '${spec.coveragePct.round()}%',
          () => _editNumber(
            'Покрытие площади',
            spec.coveragePct,
            '%',
            (v) => v >= 0 && v <= 100,
            (v) => spec.coveragePct = v,
          ),
        ),
        _setting(
          'Исключить под мебелью',
          '${spec.excludedAreaM2.toStringAsFixed(2)} м²',
          () => _editNumber(
            'Исключённая площадь',
            spec.excludedAreaM2,
            'м²',
            (v) => v >= 0 && v <= face.areaM2,
            (v) => spec.excludedAreaM2 = v,
          ),
        ),
        _setting(
          'Шаг укладки',
          '${spec.spacingMm.round()} мм',
          () => _editNumber(
            'Шаг трубы',
            spec.spacingMm,
            'мм',
            (v) => v >= 75 && v <= 300,
            (v) => spec.spacingMm = v,
          ),
        ),
        _setting(
          'Максимум на контур',
          '${spec.maxCircuitLengthM.round()} м',
          () => _editNumber(
            'Длина одного контура',
            spec.maxCircuitLengthM,
            'м',
            (v) => v >= 20 && v <= 150,
            (v) => spec.maxCircuitLengthM = v,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Площадь вводится как процент помещения за вычетом зон без отопления. '
          'Это расчёт количества, не схема трассы трубы.',
        ),
      ],
    );
  }

  Widget _routes(RoomFace face, RoomMeta meta) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ServiceRunType>(
              value: _routeType,
              decoration: const InputDecoration(labelText: 'Тип новой трассы'),
              items: ServiceRunType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: _draft.isNotEmpty
                  ? null
                  : (type) => setState(() => _routeType = type ?? _routeType),
            ),
          ),
          if (_draft.isNotEmpty)
            IconButton(
              tooltip: 'Отменить точку',
              onPressed: () => setState(() => _draft.removeLast()),
              icon: const Icon(Icons.undo),
            ),
          if (_draft.isNotEmpty)
            IconButton(
              tooltip: 'Очистить черновик трассы',
              onPressed: () => setState(_draft.clear),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      if (_draft.isNotEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Text('Сохрани или очисти черновик перед сменой типа трубы.'),
        ),
      SwitchListTile.adaptive(
        dense: true,
        title: const Text('Показать все трассы'),
        subtitle: Text(
          _showAllRoutes
              ? 'Все типы на плане'
              : 'На плане только выбранный тип',
        ),
        value: _showAllRoutes,
        onChanged: (value) => setState(() => _showAllRoutes = value),
      ),
      SwitchListTile.adaptive(
        title: const Text('Привязка трассы 90°'),
        subtitle: const Text('Углы добавляются как отдельные точки'),
        value: _orthogonalRoutes,
        onChanged: (value) => setState(() => _orthogonalRoutes = value),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'ХВС — синий · ГВС — красный · канализация — коричневый · отопление — оранжевый',
        ),
      ),
      FilledButton.icon(
        onPressed: _draft.length < 2
            ? null
            : () async {
                widget.floor.serviceRuns.add(
                  ServiceRun(
                    id: 'sr-${DateTime.now().microsecondsSinceEpoch}',
                    type: _routeType,
                    diameterMm: _routeType == ServiceRunType.drain ? 50 : 20,
                    slopePct: _routeType == ServiceRunType.drain ? 2 : 0,
                    points: _draft
                        .map((p) => ServiceVertex(p.xMm, p.yMm))
                        .toList(),
                  ),
                );
                _draft.clear();
                await widget.onChanged();
                if (mounted) setState(() {});
              },
        icon: const Icon(Icons.check),
        label: Text('Сохранить трассу (${_draft.length} точек)'),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 300,
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final tx = _PlanTransform.fromFloor(widget.floor, size);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final p = tx.toModel(d.localPosition);
                final snapped = EngineeringService.snapRoutePoint(
                  widget.floor,
                  p,
                );
                final target = math.Point<double>(
                  snapped?.x ?? (p.x / 50).round() * 50.0,
                  snapped?.y ?? (p.y / 50).round() * 50.0,
                );
                setState(() {
                  if (_orthogonalRoutes && _draft.isNotEmpty) {
                    _draft.addAll(
                      EngineeringService.orthogonalStep(_draft.last, target),
                    );
                  } else {
                    _draft.add(ServiceVertex(target.x, target.y));
                  }
                });
              },
              onPanStart: (d) {
                final p = tx.toModel(d.localPosition);
                _dragRunId = null;
                _dragVertex = null;
                for (final run in widget.floor.serviceRuns.reversed) {
                  if (!_showAllRoutes && run.type != _routeType) continue;
                  for (var i = 0; i < run.points.length; i++) {
                    final v = run.points[i];
                    if (math.sqrt(
                          math.pow(p.x - v.xMm, 2) + math.pow(p.y - v.yMm, 2),
                        ) <
                        140) {
                      _dragRunId = run.id;
                      _dragVertex = i;
                      break;
                    }
                  }
                  if (_dragRunId != null) break;
                }
                _dragDirty = false;
              },
              onPanUpdate: (d) {
                if (_dragRunId == null || _dragVertex == null) return;
                final run = widget.floor.serviceRuns.firstWhere(
                  (r) => r.id == _dragRunId,
                );
                final point = run.points[_dragVertex!];
                point.xMm += d.delta.dx / tx.scale;
                point.yMm += d.delta.dy / tx.scale;
                _dragDirty = true;
                setState(() {});
              },
              onPanEnd: (_) {
                if (_dragDirty) widget.onChanged();
                _dragRunId = null;
              },
              child: CustomPaint(
                painter: _EngineeringPainter(
                  floor: widget.floor,
                  face: face,
                  meta: meta,
                  tab: _EngineeringTab.routes,
                  tx: tx,
                  draft: _draft,
                  routeType: _routeType,
                  showAllRoutes: _showAllRoutes,
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Нажимай на плане для точек новой трассы. Узлы стен, точки воды, '
        'канализации и радиаторы привязываются; '
        'готовые точки можно перетаскивать.',
      ),
      for (final run in widget.floor.serviceRuns)
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(run.type.label),
                subtitle: Text(
                  '${run.lengthM.toStringAsFixed(2)} м • Ø${run.diameterMm.round()} мм'
                  '${run.type == ServiceRunType.drain ? ' • падение ${run.fallMm.round()} мм' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Удалить трассу',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    widget.floor.serviceRuns.remove(run);
                    await widget.onChanged();
                    if (mounted) setState(() {});
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _editNumber(
                      'Диаметр трубы',
                      run.diameterMm,
                      'мм',
                      (v) => v >= 10 && v <= 200,
                      (v) => run.diameterMm = v,
                    ),
                    child: Text('Ø ${run.diameterMm.round()} мм'),
                  ),
                  if (run.type == ServiceRunType.drain)
                    TextButton(
                      onPressed: () => _editNumber(
                        'Уклон канализации',
                        run.slopePct,
                        '%',
                        (v) => v >= 0 && v <= 15,
                        (v) => run.slopePct = v,
                      ),
                      child: Text('Уклон ${run.slopePct.toStringAsFixed(1)}%'),
                    ),
                ],
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty)
      return const Center(child: Text('Сначала создай помещение.'));
    final face = faces.firstWhere(
      (f) => f.key == _faceKey,
      orElse: () => faces.first,
    );
    final meta = widget.floor.roomMetaByKey(face.key)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: face.key,
                decoration: const InputDecoration(labelText: 'Помещение'),
                items: faces
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.key,
                        child: Text(
                          '${widget.floor.roomMetaByKey(f.key)?.name ?? 'Помещение'} • '
                          '${f.areaM2.toStringAsFixed(2)} м²',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _faceKey = value),
              ),
              const SizedBox(height: 8),
              SegmentedButton<_EngineeringTab>(
                segments: const [
                  ButtonSegment(
                    value: _EngineeringTab.ceiling,
                    label: Text('Потолок'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.warmFloor,
                    label: Text('Тёплый пол'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.routes,
                    label: Text('Трубы'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _EngineeringTab.ceiling => _ceiling(face, meta),
            _EngineeringTab.warmFloor => _warmFloor(face, meta),
            _EngineeringTab.routes => _routes(face, meta),
          },
        ),
      ],
    );
  }
}

class _PlanTransform {
  const _PlanTransform(this.scale, this.origin);
  final double scale;
  final Offset origin;
  factory _PlanTransform.fromFloor(FloorPlan floor, Size size) {
    if (floor.nodes.isEmpty) {
      return _PlanTransform(.08, Offset(size.width / 2, size.height / 2));
    }
    var minX = floor.nodes.first.xMm, maxX = minX;
    var minY = floor.nodes.first.yMm, maxY = minY;
    for (final n in floor.nodes.skip(1)) {
      minX = math.min(minX, n.xMm);
      maxX = math.max(maxX, n.xMm);
      minY = math.min(minY, n.yMm);
      maxY = math.max(maxY, n.yMm);
    }
    final scale = math.min(
      (size.width - 24) / math.max(1200, maxX - minX),
      (size.height - 24) / math.max(1200, maxY - minY),
    );
    return _PlanTransform(
      scale,
      Offset(
        size.width / 2 - (minX + maxX) / 2 * scale,
        size.height / 2 - (minY + maxY) / 2 * scale,
      ),
    );
  }
  Offset point(double x, double y) => origin + Offset(x * scale, y * scale);
  math.Point<double> toModel(Offset p) =>
      math.Point((p.dx - origin.dx) / scale, (p.dy - origin.dy) / scale);
}

class _EngineeringPainter extends CustomPainter {
  const _EngineeringPainter({
    required this.floor,
    required this.face,
    required this.meta,
    required this.tab,
    required this.tx,
    this.draft = const [],
    this.routeType = ServiceRunType.coldWater,
    this.showAllRoutes = false,
  });
  final FloorPlan floor;
  final RoomFace face;
  final RoomMeta meta;
  final _EngineeringTab tab;
  final _PlanTransform tx;
  final List<ServiceVertex> draft;
  final ServiceRunType routeType;
  final bool showAllRoutes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F7F7),
    );
    final polygon = LayoutService.finishPolygon(face);
    if (polygon.isEmpty) return;
    final path = Path()
      ..moveTo(
        tx.point(polygon.first.x, polygon.first.y).dx,
        tx.point(polygon.first.x, polygon.first.y).dy,
      );
    for (final p in polygon.skip(1)) {
      final q = tx.point(p.x, p.y);
      path.lineTo(q.dx, q.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(path);
    if (tab == _EngineeringTab.ceiling) {
      for (final zone in meta.ceiling.zones) {
        final center = tx.point(zone.xMm, zone.yMm);
        final rect = Rect.fromCenter(
          center: center,
          width: zone.widthMm * tx.scale,
          height: zone.depthMm * tx.scale,
        );
        canvas.drawRect(rect, Paint()..color = const Color(0xFFB8DCCC));
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0xFF247A5D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    } else if (tab == _EngineeringTab.warmFloor && meta.heating.enabled) {
      final b = path.getBounds();
      final spacing = math.max(8.0, meta.heating.spacingMm * tx.scale);
      final pipe = Paint()
        ..color = const Color(0xFFD46A43)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final inset = math.min(18.0, b.shortestSide * .07);
      final left = b.left + inset, right = b.right - inset;
      final top = b.top + inset, bottom = b.bottom - inset;
      if (right > left && bottom > top) {
        final contour = Path()..moveTo(left, top);
        var row = 0;
        for (var y = top; y <= bottom && row < 300; y += spacing, row++) {
          contour.lineTo(row.isEven ? right : left, y);
          if (y + spacing <= bottom) {
            contour.lineTo(row.isEven ? right : left, y + spacing);
          }
        }
        canvas.drawPath(contour, pipe);
        canvas.drawCircle(
          Offset(left, top),
          5,
          Paint()..color = const Color(0xFFD46A43),
        );
      }
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF26363A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (tab != _EngineeringTab.routes) return;
    final colors = {
      ServiceRunType.coldWater: const Color(0xFF3285D0),
      ServiceRunType.hotWater: const Color(0xFFD7574D),
      ServiceRunType.drain: const Color(0xFF83715A),
      ServiceRunType.heating: const Color(0xFFE6913A),
    };
    void draw(List<ServiceVertex> points, Color color) {
      if (points.isEmpty) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final route = Path();
      for (var i = 0; i < points.length; i++) {
        final q = tx.point(points[i].xMm, points[i].yMm);
        if (i == 0)
          route.moveTo(q.dx, q.dy);
        else
          route.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(route, paint);
      for (final p in points) {
        canvas.drawCircle(tx.point(p.xMm, p.yMm), 5, Paint()..color = color);
      }
    }

    for (final run in floor.serviceRuns) {
      if (showAllRoutes || run.type == routeType) {
        draw(run.points, colors[run.type]!);
      }
    }
    draw(draft, colors[routeType]!);
  }

  @override
  bool shouldRepaint(covariant _EngineeringPainter old) => true;
}
