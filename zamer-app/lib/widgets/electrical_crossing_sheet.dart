import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/electrical_crossing_service.dart';

/// Read-only review of projected wall-axis intersections.
/// Not a regulatory or construction-permission check.
class ElectricalCrossingSheet extends StatefulWidget {
  const ElectricalCrossingSheet({
    super.key, required this.floor,
    this.initialCircuitId,
    required this.onCircuitChanged,
  });
  final FloorPlan floor;
  final String? initialCircuitId;
  final ValueChanged<String?> onCircuitChanged;

  @override
  State<ElectricalCrossingSheet> createState() => _ElectricalCrossingSheetState();
}

class _ElectricalCrossingSheetState extends State<ElectricalCrossingSheet> {
  String? circuitId;

  @override
  void initState() {
    super.initState();
    circuitId = widget.initialCircuitId;
  }

  String _label(ElectricalCrossingKind kind) => switch (kind) {
    ElectricalCrossingKind.wallAxis => 'Проход через стену',
    ElectricalCrossingKind.opening => 'Пересечение проёма',
    ElectricalCrossingKind.alongWall => 'Вдоль оси стены',
    ElectricalCrossingKind.wallEndpoint => 'Касание стены',
    ElectricalCrossingKind.outsideWallHeight => 'Высота вне стены',
    ElectricalCrossingKind.unsupportedWall => 'Не проверено',
  };

  @override
  Widget build(BuildContext context) {
    final circuits = widget.floor.electricalNetwork?.circuits ?? [];
    if (circuitId != null && !circuits.any((c) => c.id == circuitId)) {
      circuitId = null;
    }
    final report = ElectricalCrossingService.inspect(
      widget.floor, circuitId: circuitId,
    );
    final names = {
      for (final c in widget.floor.electricalNetwork?.cables ?? [])
        c.id: c.description.trim().isEmpty ? c.id : c.description,
    };
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .85,
        child: ListView(
          key: const ValueKey('crossings-list'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('Пересечения трасс',
                style: textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Геометрический анализ осей стен и проектных проёмов. '
                'Толщина стены, конструкция проходки и допустимость '
                'прокладки пока не проверяются.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('crossings-group-' + (circuitId ?? 'all')),
              isExpanded: true,
              initialValue: circuitId ?? '__all__',
              decoration: const InputDecoration(labelText: 'Группа'),
              items: [
                const DropdownMenuItem(
                    value: '__all__', child: Text('Все группы')),
                for (final c in circuits)
                  DropdownMenuItem(value: c.id,
                    child: Text(c.name,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                final next = v == '__all__' ? null : v;
                setState(() => circuitId = next);
                widget.onCircuitChanged(next);
              },
            ),
            const SizedBox(height: 14),
            Text('Замечаний для проверки: ' +
                report.needsReview.toString(),
                key: const ValueKey('crossings-review-count'),
                style: textTheme.titleMedium),
            Text('Без трассы: ' + report.missingRoutes.toString() +
                ' · Трасса с ошибкой: ' + report.invalidRoutes.toString()),
            const SizedBox(height: 10),
            if (report.notices.isEmpty)
              const Text('По введённым геометрическим данным пересечений '
                  'не найдено. Это не подтверждение отсутствия коллизий.')
            else
              for (final n in report.notices)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: ValueKey('crossing-' + n.cableId + '-' +
                        n.wallId + '-' + n.routeSegment.toString()),
                    leading: Icon(
                      n.kind == ElectricalCrossingKind.opening
                          ? Icons.info_outline
                          : Icons.warning_amber_rounded,
                      color: n.needsReview
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(_label(n.kind)),
                    subtitle: Text(
                      (names[n.cableId] ?? n.cableId) +
                      ' · стена ' + n.wallId + '\n' +
                      n.message + '\n' +
                      'X ' + n.xMm.toStringAsFixed(0) +
                      ', Y ' + n.yMm.toStringAsFixed(0) +
                      ', Z ' + n.zMm.toStringAsFixed(0) + ' мм',
                    ),
                    isThreeLine: true,
                  ),
                ),
            const SizedBox(height: 14),
            Text('Проверка не охватывает объём стены и проёма, '
                'скрытые конструкции, трубы, существующую проводку, '
                'перекрытия и требования СП/ПУЭ. '
                'Участки не изменяются автоматически.',
                style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
