import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/estimate_service.dart';

class EstimateScreen extends StatefulWidget {
  const EstimateScreen({
    super.key,
    required this.project,
    required this.onChanged,
  });
  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  bool _work = false;
  Future<void> _price(EstimateLine line) async {
    var raw = line.unitPrice == 0 ? '' : line.unitPrice.toStringAsFixed(2);
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.name),
        content: TextFormField(
          initialValue: raw,
          onChanged: (value) => raw = value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Цена за ${line.unit}',
            suffixText: '₽',
          ),
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
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null || value < 0 || !value.isFinite || value > 100000000)
      return;
    (_work ? widget.project.workRates : widget.project.unitPrices)[line.key] =
        value;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  String _export(ProjectEstimate materials, ProjectEstimate works) => [
    '\uFEFFРаздел;Наименование;Количество;Ед.;Цена за ед., ₽;Сумма, ₽',
    for (final section in [('Материалы', materials), ('Работы', works)]) ...[
      for (final line in section.$2.lines)
        '${section.$1};${line.name};${line.quantity.toStringAsFixed(2)};${line.unit};'
            '${line.unitPrice <= 0 ? 'цена не задана' : line.unitPrice.toStringAsFixed(2)};'
            '${line.unitPrice <= 0 ? 'цена не задана' : line.total.toStringAsFixed(2)}',
      '${section.$1};Итого оценённые;;;;${section.$2.pricedTotal.toStringAsFixed(2)}',
    ],
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final materials = EstimateService.build(widget.project);
    final works = EstimateService.buildWork(widget.project);
    final estimate = _work ? works : materials;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Автосмета'),
        actions: [
          IconButton(
            tooltip: 'Скопировать смету',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _export(materials, works)),
              );
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Смета скопирована')),
                );
            },
          ),
          IconButton(
            tooltip: 'Поделиться сметой',
            icon: const Icon(Icons.share),
            onPressed: () => Share.shareXFiles(
              [
                XFile.fromData(
                  Uint8List.fromList(utf8.encode(_export(materials, works))),
                  mimeType: 'text/csv',
                ),
              ],
              fileNameOverrides: ['zamer-estimate.csv'],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Материалы')),
              ButtonSegment(value: true, label: Text('Работы')),
            ],
            selected: {_work},
            onSelectionChanged: (value) => setState(() => _work = value.first),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _work
                        ? 'Работы по всем этажам'
                        : 'Материалы по всем этажам',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Стоимость: ${estimate.pricedTotal.toStringAsFixed(2)} ₽',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Без цены: ${estimate.unpricedCount} позиций. '
                    'Общий итог с ценами: ${(materials.pricedTotal + works.pricedTotal).toStringAsFixed(2)} ₽.',
                  ),
                  const Text(
                    'Нажми на позицию, чтобы задать свою цену за единицу.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (estimate.lines.isEmpty) const Text('Сначала построй помещения.'),
          for (final line in estimate.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Card(
                child: ListTile(
                  title: Text(line.name),
                  subtitle: Text(
                    '${line.quantity.toStringAsFixed(2)} ${line.unit} × '
                    '${line.unitPrice == 0 ? 'цена не задана' : '${line.unitPrice.toStringAsFixed(2)} ₽'}',
                  ),
                  trailing: Text('${line.total.toStringAsFixed(0)} ₽'),
                  onTap: () => _price(line),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
