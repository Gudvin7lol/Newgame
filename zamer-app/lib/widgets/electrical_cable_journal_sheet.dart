import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/electrical_cable_journal_service.dart';

class ElectricalCableJournalSheet extends StatefulWidget {
  const ElectricalCableJournalSheet({
    super.key, required this.floor,
    required this.initialCircuitId, required this.onCircuitChanged,
  });
  final FloorPlan floor;
  final String? initialCircuitId;
  final ValueChanged<String?> onCircuitChanged;

  @override
  State<ElectricalCableJournalSheet> createState() =>
      _ElectricalCableJournalSheetState();
}

class _ElectricalCableJournalSheetState extends State<ElectricalCableJournalSheet> {
  String? circuitId;

  @override
  void initState() {
    super.initState();
    circuitId = widget.initialCircuitId;
  }

  String meters(double? mm) => mm == null
      ? 'не определено'
      : (mm / 1000).toStringAsFixed(2) + ' м';

  @override
  Widget build(BuildContext context) {
    final network = widget.floor.electricalNetwork;
    final circuits = network?.circuits ?? [];
    if (circuitId != null && !circuits.any((c) => c.id == circuitId)) {
      circuitId = null;
    }
    final journal = ElectricalCableJournalService.create(
        widget.floor, circuitId: circuitId);
    final t = journal.totals;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .87,
        child: ListView(
          key: const ValueKey('cable-journal-list'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            Text('Кабельный журнал',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text('Только кабели из явно созданных электрических связей. '
                'Старые линии и их условные проценты запаса не учитываются.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('cable-journal-group-' + (circuitId ?? 'all')),
              isExpanded: true,
              initialValue: circuitId ?? '__all__',
              decoration: const InputDecoration(labelText: 'Группа'),
              items: [
                const DropdownMenuItem(value: '__all__',
                    child: Text('Все группы')),
                for (final c in circuits)
                  DropdownMenuItem(value: c.id,
                      child: Text(c.name.isEmpty ? c.id : c.name,
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) {
                final selected = value == '__all__' ? null : value;
                setState(() => circuitId = selected);
                widget.onCircuitChanged(selected);
              },
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Tag(label: 'Кабелей', value: t.cableCount.toString()),
              _Tag(label: 'С трассой', value: t.routedCount.toString()),
              _Tag(label: 'Без трассы', value: t.unknownRouteCount.toString()),
              _Tag(label: 'Ошибка', value: t.invalidRouteCount.toString()),
            ]),
            const SizedBox(height: 12),
            Text('Известная длина по маршрутам: ' +
                meters(t.knownGeometricMm)),
            Text('С учтённым запасом только для полностью '
                'заданных кабелей: ' + meters(t.knownWithReserveMm)),
            if (!t.complete)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Итоговая потребность неизвестна. '
                  'Нет маршрутов: ' + t.unknownRouteCount.toString() +
                  ', маршруты с ошибками: ' + t.invalidRouteCount.toString() +
                  ', не указан запас: ' + t.unknownReserveCount.toString() + '.',
                  key: const ValueKey('cable-journal-incomplete'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Сумма известных длин с явно заданным запасом: ' +
                    meters(t.knownWithReserveMm) +
                    '. Требует проверки вводов, выпусков и фактической трассы.',
                  key: const ValueKey('cable-journal-complete'),
                ),
              ),
            const SizedBox(height: 8),
            if (network == null)
              const Text('Физическая схема кабелей пока не создана.')
            else if (journal.rows.isEmpty)
              const Text('В выбранной группе нет физических кабелей.')
            else
              for (final group in journal.groups.entries) ...[
                const Divider(height: 28),
                Text(
                  network.circuits
                      .where((c) => c.id == group.key)
                      .firstOrNull?.name ?? 'Цепь отсутствует',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final row in group.value)
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      key: ValueKey('journal-cable-' + row.cable.id),
                      contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      title: Text(row.cable.description.isEmpty
                          ? row.cable.id : row.cable.description),
                      subtitle: Text(
                        row.fromLabel + ' → ' + row.toLabel + '\n' +
                        'Жил: ' + row.cable.cores.length.toString() +
                        ' · Геометрия: ' + meters(row.geometricMm) + '\n' +
                        'Запас: ' + (row.reserveMm == null
                            ? 'не задан' : meters(row.reserveMm)) +
                        ' · С запасом: ' + meters(row.withReserveMm) +
                        (row.problem == null ? '' : '\n' + row.problem!),
                      ),
                      isThreeLine: true,
                      trailing: row.hasRoute
                          ? const Icon(Icons.route)
                          : const Icon(Icons.warning_amber_rounded),
                    ),
                  ),
              ],
            const SizedBox(height: 12),
            Text(
              'Это не закупочная спецификация. Марка, сечение, '
              'допуски прокладки, реальные выводы из коробок и запас '
              'должны проверяться отдельно.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]),
  );
}
