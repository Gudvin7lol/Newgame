import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_wall_datum_service.dart';
import '../services/electrical_datum_assignment_service.dart';

/// Read-only reference station catalog. A structural opening edge is never
/// presented as a measured finished jamb or as an installation approval.
class ElectricalWallDatumScreen extends StatefulWidget {
  const ElectricalWallDatumScreen({
    super.key,
    required this.floor,
    required this.wallId,
    required this.wallSide,
    this.onAssign,
  });

  final FloorPlan floor;
  final String wallId;
  final int wallSide;
  /// Parent owns validation, one undo boundary and persistence.
  final Future<void> Function(String pointId, String wallId, int side,
      String? datumId)? onAssign;

  @override
  State<ElectricalWallDatumScreen> createState() =>
      _ElectricalWallDatumScreenState();
}

class _ElectricalWallDatumScreenState extends State<ElectricalWallDatumScreen> {
  String? selectedId;
  String? pendingPointId;

  Future<void> _assign(String pointId, String? datumId) async {
    final callback = widget.onAssign;
    if (callback == null || pendingPointId != null) return;
    setState(() => pendingPointId = pointId);
    try {
      await callback(pointId, widget.wallId, widget.wallSide, datumId);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => pendingPointId = null);
    }
  }

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
                  _dimensionTile(d, datum),
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
  Widget _dimensionTile(
      ElectricalDatumDimension d, ElectricalWallDatum datum) {
    final point = widget.floor.electricalPoints
        .where((p) => p.id == d.pointId).firstOrNull;
    final saved = point?.datumAssignment;
    final valid = point != null &&
        saved != null &&
        ElectricalDatumAssignmentService.problem(
            widget.floor, point) == null;
    final selected = valid && saved.datumId == datum.id &&
        saved.wallId == widget.wallId &&
        saved.wallSide == widget.wallSide;
    return Card(
      child: ListTile(
        key: ValueKey('datum-dimension-' + d.pointId),
        title: Text(d.pointName),
        subtitle: Text(
          'От выбранной базы: ' +
          (d.fromDatumMm >= 0 ? '+' : '') +
          d.fromDatumMm.toStringAsFixed(1) + ' мм' +
          '\nВысота центра: ' +
          d.heightMm.toStringAsFixed(1) + ' мм' +
          (saved == null
              ? '\nБаза пока не закреплена'
              : valid
                  ? '\nЗакреплена: ' + saved.datumTitle
                  : '\nЗакреплённая база устарела, требуется проверка') +
          (d.mountingProblem == null
              ? ''
              : '\nБаза P1: ' + d.mountingProblem!),
        ),
        isThreeLine: true,
        trailing: widget.onAssign == null
            ? null
            : IconButton(
                key: ValueKey('datum-assign-' + d.pointId),
                icon: Icon(selected
                    ? Icons.link_off_outlined : Icons.add_link_outlined),
                tooltip: selected ? 'Снять привязку'
                    : datum.finishedReference
                        ? 'Закрепить выбранную базу'
                        : 'Черновую грань закреплять нельзя',
                onPressed: pendingPointId != null ||
                        (!selected && !datum.finishedReference)
                    ? null
                    : () => _assign(
                        d.pointId, selected ? null : datum.id),
              ),
      ),
    );
  }

}
