import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../models/material_purchase.dart';
import '../services/estimate_service.dart';
import '../services/procurement_service.dart';

class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({
    super.key,
    required this.project,
    required this.onChanged,
  });

  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  Future<void> _record(EstimateLine line) async {
    var raw = '';
    var paidRaw = '';
    final result = await showDialog<({double quantity, double? paid})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Закупка: ${line.name}'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Потребность по проекту: '
                '${line.quantity.toStringAsFixed(2)} ${line.unit}',
                style: ZamerTypography.caption),
            const SizedBox(height: 12),
            TextField(
              key: const Key('purchase-quantity'),
              autofocus: true,
              onChanged: (value) => raw = value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Куплено, ${line.unit}',
                hintText: 'Количество по чеку',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('purchase-paid'),
              onChanged: (value) => paidRaw = value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Оплачено по чеку, ₽ (необязательно)',
                hintText: 'Оставь пустым, если ещё не оплачено',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Количество учитывается в закупках. Указанная оплата '
              'один раз попадёт в «Бюджет и факт».',
              style: ZamerTypography.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(raw.trim().replaceAll(',', '.'));
              if (value == null || !value.isFinite || value <= 0 ||
                  value > 1000000000) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Укажите количество больше нуля')),
                );
                return;
              }
              if (const {'кор.', 'пач.', 'рул.', 'меш.', 'вед.'}
                  .contains(line.unit) &&
                  (value - value.roundToDouble()).abs() > 0.00000001) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Нужны целые упаковки')),
                );
                return;
              }
              final paidText = paidRaw.trim();
              final paid = paidText.isEmpty
                  ? null
                  : double.tryParse(paidText.replaceAll(',', '.'));
              if (paidText.isNotEmpty && (paid == null ||
                  !paid.isFinite || paid <= 0 || paid > 1000000000000)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Проверь оплаченную сумму')),
                );
                return;
              }
              Navigator.pop(dialogContext, (quantity: value, paid: paid));
            },
            child: const Text('Записать'),
          ),
        ],
      ),
    );
    if (result == null) return;
    ProcurementService.recordWithPayment(
      widget.project,
      estimateKey: line.key,
      quantity: result.quantity,
      paidAmount: result.paid,
    );
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _void(MaterialPurchase entry) async {
    if (entry.isReversal || widget.project.materialPurchases.any(
        (other) => other.reversesId == entry.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить запись закупки?'),
        content: const Text(
          'Исходная запись останется в истории. '
          'Количество будет скорректировано обратной записью. '
          'Связанная оплата останется в финансовом журнале. '
          'Если деньги возвращены или запись ошибочна, '
          'отмени оплату отдельно в «Бюджет и факт».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Отменить запись'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ProcurementService.voidRecord(widget.project, entry.id);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final coverage = ProcurementService.coverage(widget.project);
    final unlinked = ProcurementService.unlinked(widget.project);
    final completed = coverage.where((row) => row.complete).length;
    final labels = {
      for (final row in coverage) row.line.key: row.line.name,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Учёт закупок')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZamerSpace.md, ZamerSpace.md, ZamerSpace.md, ZamerSpace.xxl),
        children: [
          ZCard(
            backgroundColor: ZamerColors.surfaceLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Закупка по смете',
                    style: ZamerTypography.sectionTitle),
                const SizedBox(height: 8),
                Text('$completed из ${coverage.length} позиций обеспечено',
                    style: ZamerTypography.caption),
                if (unlinked.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Есть ${unlinked.length} записей от старой спецификации. '
                    'Они сохранены в истории и требуют сверки.',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ZamerSpace.md),
          if (coverage.isEmpty)
            const ZEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Ведомость пока пуста',
              subtitle: 'Создай помещения и назначь материалы в проекте.',
            ),
          for (final row in coverage)
            Padding(
              padding: const EdgeInsets.only(bottom: ZamerSpace.sm),
              child: ZCard(
                child: Row(
                  children: [
                    Icon(
                      row.complete
                          ? Icons.check_circle_outline
                          : Icons.shopping_basket_outlined,
                      color: row.complete
                          ? ZamerColors.success : ZamerColors.accent,
                    ),
                    const SizedBox(width: ZamerSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.line.name,
                              style: ZamerTypography.sectionTitle),
                          const SizedBox(height: 4),
                          Text(
                            'По плану: ${row.line.quantity.toStringAsFixed(2)} '
                            '${row.line.unit} · Куплено: '
                            '${row.purchased.toStringAsFixed(2)} ${row.line.unit}',
                            style: ZamerTypography.caption,
                          ),
                          Text(
                            row.extra > 0
                                ? 'Сверх плана: ${row.extra.toStringAsFixed(2)} '
                                  '${row.line.unit}'
                                : 'Осталось купить: '
                                  '${row.remaining.toStringAsFixed(2)} '
                                  '${row.line.unit}',
                            style: TextStyle(
                              color: row.extra > 0
                                  ? ZamerColors.warning
                                  : ZamerColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Учесть закупку: ${row.line.name}',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _record(row.line),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: ZamerSpace.sm),
          Text(
            'История количеств (${widget.project.materialPurchases.length})',
            style: ZamerTypography.sectionTitle,
          ),
          const SizedBox(height: ZamerSpace.xs),
          for (final entry in widget.project.materialPurchases.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: ZamerSpace.xs),
              child: ZCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels[entry.estimateKey] ??
                              'Позиция прежней спецификации',
                            style: ZamerTypography.sectionTitle,
                          ),
                          Text(
                            '${entry.at.day.toString().padLeft(2, '0')}.'
                            '${entry.at.month.toString().padLeft(2, '0')}.'
                            '${entry.at.year}',
                            style: ZamerTypography.caption,
                          ),
                          if (!entry.isReversal &&
                              ProcurementService.paidForPurchase(
                                  widget.project, entry.id) > 0)
                            Text(
                              'Оплачено: '
                              '${ProcurementService.paidForPurchase(widget.project, entry.id).toStringAsFixed(0)} ₽',
                              style: ZamerTypography.caption,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.isReversal ? '−' : '+'}'
                      '${entry.quantity.toStringAsFixed(2)} ${entry.unit}',
                      style: ZamerTypography.measurement,
                    ),
                    if (!entry.isReversal &&
                        !widget.project.materialPurchases.any(
                            (other) => other.reversesId == entry.id))
                      IconButton(
                        tooltip: 'Отменить закупку',
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () => _void(entry),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
