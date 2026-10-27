import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_wall_datum_service.dart';

/// Read-only reference station catalog. A structural opening edge is never
/// presented as a measured finished jamb or as an installation approval.
class ElectricalWallDatumScreen extends StatefulWidget {
  const ElectricalWallDatumScreen({
    super.key,
    required this.floor,
    required this.wallId,
    required this.wallSide,
  });

  final FloorPlan floor;
  final String wallId;
  final int wallSide;

  @override
  State<ElectricalWallDatumScreen> createState() =>
      _ElectricalWallDatumScreenState();
}

class _ElectricalWallDatumScreenState extends State<ElectricalWallDatumScreen> {
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    ElectricalWallDatumCatalog? catalog;
    String? error;
    try {
      catalog = ElectricalWallDatumService.catalog(
          widget.floor, widget.wallId, widget.wallSide);
    } on FormatException catch (e) {
      error = e.message;
    }
    final datum = catalog?.datums
        .where((d) => d.id == selectedId).firstOrNull ??
        catalog?.datums.firstOrNull;
    final datums = catalog?.datums ?? [];
    List<ElectricalDatumDimension> dimensions = [];
    if (catalog != null && datum != null) {
      try {
        dimensions = ElectricalWallDatumService.dimensions(
            widget.floor, catalog, datum);
      } on FormatException catch (e) {
        error = e.message;
      }
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Базы монтажной разметки')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('wall-datum-screen'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Стена ' + widget.wallId +
                ' · сторона ' +
                (widget.wallSide == 1 ? 'левая' : 'правая'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Расстояния вдоль оси стены в мм. '
                'Расчётный чистовой угол и черновая грань проёма '
                'не являются подтверждёнными точками разметки '
                'на объекте.'),
            const SizedBox(height: 16),
            if (error != null)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            if (catalog != null) ...[
              if (datums.isEmpty)
                const Text('Для выбранной стороны нет определённых баз. '
                    'Сначала уточните геометрию и отделку смежных стен.'),
              if (datums.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('datum-selector-' + (datum?.id ?? 'none')),
                  isExpanded: true,
                  initialValue: datum?.id,
                  decoration: const InputDecoration(
                    labelText: 'База отсчёта',
                  ),
                  items: [
                    for (final item in datums)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(item.title,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() => selectedId = id),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(datum!.title,
                          style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text('Координата базы от начала стены: ' +
                            datum.uMm.toStringAsFixed(1) + ' мм',
                            key: const ValueKey('datum-base-position')),
                        const SizedBox(height: 6),
                        Text(datum.description),
                        if (!datum.finishedReference) ...[
                          const SizedBox(height: 6),
                          Text('Не чистовая грань: до монтажной '
                              'разметки нужен обмер откоса или коробки.',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              )),
                        ],
                        if (datum.finishedReference) ...[
                          const SizedBox(height: 6),
                          const Text('Чистовые плоскости заданы, но '
                              'фактическое пересечение не обмерено.'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text('Размеры до центров точек',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 5),
                const Text('«+» означает движение от начального '
                    'узла стены к конечному, «−» в обратную сторону.'),
                if (dimensions.isEmpty)
                  const Text('На этой стороне нет электроточек с '
                      'допустимыми координатами.'),
                for (final d in dimensions)
                  Card(
                    child: ListTile(
                      key: ValueKey('datum-dimension-' + d.pointId),
                      title: Text(d.pointName),
                      subtitle: Text('От базы: ' +
                          (d.fromDatumMm >= 0 ? '+' : '') +
                          d.fromDatumMm.toStringAsFixed(1) +
                          ' мм\nВысота центра: ' +
                          d.heightMm.toStringAsFixed(1) + ' мм' +
                          (d.mountingProblem == null ? '' :
                              '\nМонтажная привязка: ' +
                                  d.mountingProblem!)),
                      isThreeLine: true,
                    ),
                  ),
              ],
              if (catalog.issues.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Требует уточнения',
                    style: theme.textTheme.titleMedium),
                for (final issue in catalog.issues)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(issue),
                  ),
              ],
              const SizedBox(height: 12),
              Text('Привязки сформированы по сохранённой '
                  'проектной геометрии. Без обмера помещения, '
                  'толщины стен и реальных граней запрещено считать '
                  'их готовыми размерами для сверления и монтажа.',
                style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
