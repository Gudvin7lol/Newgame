import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_wall_elevation_service.dart';
import 'electrical_wall_elevation_painter.dart';

/// Read-only, dimensioned wall development. Does not mutate project data.
class ElectricalWallElevationScreen extends StatefulWidget {
  const ElectricalWallElevationScreen({
    super.key, required this.floor, this.initialCircuitId,
  });
  final FloorPlan floor;
  final String? initialCircuitId;

  @override
  State<ElectricalWallElevationScreen> createState() =>
      _ElectricalWallElevationScreenState();
}

class _ElectricalWallElevationScreenState
    extends State<ElectricalWallElevationScreen> {
  String? wallId;
  String? circuitId;

  @override
  void initState() {
    super.initState();
    wallId = widget.floor.walls
        .where((w) => !w.demolition &&
            w.projectLayer != ProjectLayer.demolition)
        .firstOrNull?.id;
    circuitId = widget.initialCircuitId;
  }

  String numMm(double mm) => mm.toStringAsFixed(0) + ' мм';

  @override
  Widget build(BuildContext context) {
    final walls = widget.floor.walls.where((w) =>
        !w.demolition && w.projectLayer != ProjectLayer.demolition).toList();
    final circuits = widget.floor.electricalNetwork?.circuits ?? [];
    if (wallId != null && !walls.any((w) => w.id == wallId)) {
      wallId = walls.firstOrNull?.id;
    }
    if (circuitId != null && !circuits.any((c) => c.id == circuitId)) {
      circuitId = null;
    }
    ElectricalWallElevationData? data;
    String? problem;
    if (wallId != null) {
      try {
        data = ElectricalWallElevationService.build(
            widget.floor, wallId!, circuitId: circuitId);
      } on FormatException catch (e) {
        problem = e.message;
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final drawWidth = data == null ? 640.0 :
        math.max(640.0, math.min(1900.0, data.lengthMm * .16 + 130));
    final drawHeight = data == null ? 390.0 :
        math.max(380.0, math.min(580.0,
          data.heightMm * ((drawWidth - 94) / data.lengthMm) + 115));

    return Scaffold(
      appBar: AppBar(title: const Text('Развёртка электрики')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('electrical-wall-elevation-screen'),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            Text('Монтажная геометрия',
                style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Размеры в миллиметрах от начала выбранной стены и чистого '
              'пола. Чертёж не заменяет обмер и проверку конструкции.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (walls.isEmpty)
              const Text('В плане пока нет прямых стен для развёртки.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('wall-elevation-wall-' + (wallId ?? 'none')),
                isExpanded: true,
                initialValue: wallId,
                decoration: const InputDecoration(labelText: 'Стена'),
                items: [
                  for (var i = 0; i < walls.length; i++)
                    DropdownMenuItem(
                      value: walls[i].id,
                      child: Text('Стена ' + (i + 1).toString() +
                          ' · ' + walls[i].id,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() => wallId = id),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('wall-elevation-group-' + (circuitId ?? 'all')),
                isExpanded: true,
                initialValue: circuitId ?? '__all__',
                decoration: const InputDecoration(labelText: 'Группа кабеля'),
                items: [
                  const DropdownMenuItem(value: '__all__',
                      child: Text('Все группы')),
                  for (final c in circuits)
                    DropdownMenuItem(
                      value: c.id, child: Text(c.name,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() =>
                    circuitId = value == '__all__' ? null : value),
              ),
              const SizedBox(height: 14),
              if (problem != null)
                Text(problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
              else if (data != null) ...[
                Row(children: [
                  Expanded(child: _Datum(
                    label: 'Длина', value: numMm(data.lengthMm),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _Datum(
                    label: 'Высота', value: numMm(data.heightMm),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _Datum(
                    label: 'Точек', value: data.points.length.toString(),
                  )),
                ]),
                const SizedBox(height: 12),
                Text('Развёртка по оси стены',
                    style: textTheme.titleMedium),
                const SizedBox(height: 7),
                const Text('Чертёж прокручивается горизонтально. '
                    'Показаны только точки, явно закреплённые за стеной, '
                    'и участки трасс на её оси.'),
                const SizedBox(height: 8),
                SizedBox(
                  height: drawHeight,
                  child: SingleChildScrollView(
                    key: const ValueKey('wall-elevation-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: drawWidth,
                      height: drawHeight,
                      child: CustomPaint(
                        key: const ValueKey('wall-elevation-drawing'),
                        painter: ElectricalWallElevationPainter(
                          data: data, dark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Привязки электроточек',
                    style: textTheme.titleMedium),
                if (data.points.isEmpty)
                  const Text('На эту стену электроточки не назначены.')
                else
                  for (final p in data.points)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      key: ValueKey('wall-elevation-device-' + p.pointId),
                      title: Text(p.label),
                      subtitle: Text(
                        'От начала стены: ' + numMm(p.uMm) +
                        ' · Высота центра: ' + numMm(p.zMm) + '\n' +
                        'Смещение относительно оси: ' +
                        numMm(p.offsetFromAxisMm),
                      ),
                      isThreeLine: true,
                    ),
                const Divider(height: 24),
                Text('Проёмы стены', style: textTheme.titleMedium),
                if (data.openings.isEmpty)
                  const Text('Подтверждённых геометрией проёмов нет.')
                else
                  for (final o in data.openings)
                    ListTile(
                      dense: true,
                      title: Text(o.kind + ' · ' + o.id),
                      subtitle: Text(
                        'От начала: ' + numMm(o.fromUMm) +
                        ' · ширина ' + numMm(o.toUMm - o.fromUMm) + '\n' +
                        'Низ ' + numMm(o.bottomMm) +
                        ' · верх ' + numMm(o.topMm),
                      ),
                      isThreeLine: true,
                    ),
                const Divider(height: 24),
                Text('Кабель на оси стены',
                    style: textTheme.titleMedium),
                if (data.segments.isEmpty)
                  const Text('Явных участков 3D-трасс на оси стены нет. '
                      'Пересечение стены не означает кабель вдоль неё.')
                else
                  for (final s in data.segments)
                    ListTile(
                      dense: true,
                      key: ValueKey('wall-elevation-segment-' +
                          s.cableId + '-' + s.fromUMm.toStringAsFixed(0)),
                      title: Text('Кабель ' + s.cableId),
                      subtitle: Text(
                        'От ' + numMm(s.fromUMm) +
                        ' до ' + numMm(s.toUMm) +
                        ' · Z ' + numMm(s.fromZMm) +
                        ' → ' + numMm(s.toZMm) + '\n' +
                        'Основание: ' + switch (s.source) {
                          ElectricalPathSource.drawing => 'проектная геометрия',
                          ElectricalPathSource.measured => 'введённый обмер',
                          ElectricalPathSource.unspecified => 'не подтверждено',
                        },
                      ),
                    ),
                const Divider(height: 24),
                Text('Проверка пересечений',
                    style: textTheme.titleMedium),
                if (data.crossings.isEmpty)
                  const Text('На оси выбранной стены пересечений не найдено '
                      'по доступной геометрии. Это не проверка толщины стены.')
                else
                  for (final n in data.crossings)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline),
                      title: Text('Кабель ' + n.cableId),
                      subtitle: Text(n.message + '\n' +
                          'Высота: ' + numMm(n.zMm)),
                    ),
                if (data.warnings.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text('Необходимо уточнить',
                      style: textTheme.titleMedium),
                  for (final note in data.warnings)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber_rounded),
                      title: Text(note),
                    ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Развёртка строится по оси стены, не по её лицевой '
                  'поверхности. Толщина стены, глубина штробы и реальные '
                  'места кабельных вводов требуют отдельной проверки.',
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Datum extends StatelessWidget {
  const _Datum({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Column(
      children: [
        Text(value,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
