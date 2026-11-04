import 'package:flutter/material.dart';
import '../models/electrical_route_exclusion_zone.dart';

/// Persisted zones are edited explicitly, independently of route previews.
class ElectricalRouteExclusionsSheet extends StatefulWidget {
  const ElectricalRouteExclusionsSheet({
    super.key,
    required this.zones,
    required this.onAdd,
    required this.onRemove,
  });
  final List<ElectricalRouteExclusionZone> Function() zones;
  final Future<void> Function(ElectricalRouteExclusionZone) onAdd;
  final Future<void> Function(String) onRemove;

  @override
  State<ElectricalRouteExclusionsSheet> createState() =>
      _ElectricalRouteExclusionsSheetState();
}

class _ElectricalRouteExclusionsSheetState
    extends State<ElectricalRouteExclusionsSheet> {
  Future<void> addZone() async {
    final values = <String,String>{};
    String? message;
    final result = await showDialog<ElectricalRouteExclusionZone>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: const Text('Новая запретная зона'),
          scrollable: true,
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Координаты в мм от осей проекта. '
                    'Объём недоступен для предлагаемых маршрутов.'),
                for (final field in <(String,String)>[
                  ('name','Название'),
                  ('minXMm','X от'), ('maxXMm','X до'),
                  ('minYMm','Y от'), ('maxYMm','Y до'),
                  ('minZMm','Z от'), ('maxZMm','Z до'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      key: ValueKey('zone-${field.$1}'),
                      initialValue: values[field.$1] ?? '',
                      keyboardType: field.$1 == 'name'
                          ? TextInputType.text
                          : const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                      decoration: InputDecoration(
                        labelText: field.$2,
                        suffixText: field.$1 == 'name' ? null : 'мм',
                      ),
                      onChanged: (v) => values[field.$1] = v,
                    ),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(message!, style: TextStyle(
                        color: Theme.of(dialog).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Отмена')),
            FilledButton(
              key: const ValueKey('zone-save'),
              onPressed: () {
                try {
                  double num(String k) => double.parse(
                      (values[k] ?? '').trim().replaceAll(',', '.'));
                  final zone = ElectricalRouteExclusionZone(
                    id: 'no-go-${DateTime.now().microsecondsSinceEpoch}',
                    name: (values['name'] ?? '').trim(),
                    minXMm: num('minXMm'), maxXMm: num('maxXMm'),
                    minYMm: num('minYMm'), maxYMm: num('maxYMm'),
                    minZMm: num('minZMm'), maxZMm: num('maxZMm'),
                  );
                  zone.validate();
                  Navigator.pop(dialog, zone);
                } catch (_) {
                  refresh(() => message = 'Проверьте название и все '
                      'границы зоны X/Y/Z в миллиметрах.');
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    try {
      await widget.onAdd(result);
      if (mounted) setState(() {});
    } on FormatException catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> deleteZone(ElectricalRouteExclusionZone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить запретную зону?'),
        content: Text('«${zone.name}». Это изменит условия '
            'последующего автоматического расчёта трасс.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onRemove(zone.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .78,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text('Запретные зоны кабеля',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          const Text('Запретная зона ограничивает только известный '
              'трёхмерный объём. Неотмеченные коммуникации всё равно '
              'потребуют проверки на объекте.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('route-zone-add'),
            onPressed: addZone, icon: const Icon(Icons.add),
            label: const Text('Добавить запретный объём'),
          ),
          if (widget.zones().isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('Нет сохранённых запретных зон.'),
            ),
          for (final zone in widget.zones())
            Card(
              child: ListTile(
                title: Text(zone.name),
                subtitle: Text('X ${zone.minXMm.round()}–${zone.maxXMm.round()}'
                    ' · Y ${zone.minYMm.round()}–${zone.maxYMm.round()}'
                    ' · Z ${zone.minZMm.round()}–${zone.maxZMm.round()} мм'),
                trailing: IconButton(
                  tooltip: 'Удалить запретную зону',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deleteZone(zone),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
