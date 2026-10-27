import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/cost_entry.dart';
import '../models/models.dart';
import '../services/budget_service.dart';

/// Separate drill-down rather than another crowded tab on the estimate screen.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.project,
    required this.onChanged,
  });

  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  Future<void> _add() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var category = CostCategory.materials;
    String? taskId;
    final input = await showDialog<
        ({String description, double amount, CostCategory category,
          String? taskId})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, changeDialog) => AlertDialog(
          title: const Text('Добавить фактический расход'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CostCategory>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Раздел'),
                  items: const [
                    DropdownMenuItem(
                      value: CostCategory.materials,
                      child: Text('Материалы'),
                    ),
                    DropdownMenuItem(
                      value: CostCategory.labor,
                      child: Text('Работы'),
                    ),
                  ],
                  onChanged: (value) => changeDialog(() {
                    category = value ?? CostCategory.materials;
                    if (category == CostCategory.materials) taskId = null;
                  }),
                ),
                TextField(
                  key: const Key('budget-title'),
                  controller: title,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'На что потрачено',
                    hintText: 'Например, оплата укладки плитки',
                  ),
                ),
                TextField(
                  key: const Key('budget-amount'),
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Оплаченная сумма, ₽',
                  ),
                ),
                if (category == CostCategory.labor &&
                    widget.project.workBoard.tasks.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: taskId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Связать с работой (необязательно)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null, child: Text('Без привязки')),
                      for (final task in widget.project.workBoard.tasks)
                        DropdownMenuItem<String>(
                          value: task.id,
                          child: Text(
                            '${task.title} · ${task.roomName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        changeDialog(() => taskId = value),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Факт фиксирует оплату. Приёмка объёмов работ и '
                  'геометрия помещения не изменяются.',
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                    amount.text.trim().replaceAll(',', '.'));
                final description = title.text.trim();
                if (value == null || !value.isFinite || value <= 0 ||
                    value > 1000000000000 || description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content:
                        Text('Введите описание и положительную сумму')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, (
                  description: description, amount: value,
                  category: category, taskId: taskId,
                ));
              },
              child: const Text('Записать'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    amount.dispose();
    if (input == null) return;
    BudgetService.record(
      widget.project,
      category: input.category,
      description: input.description,
      amount: input.amount,
      taskId: input.taskId,
    );
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _voidEntry(CostEntry entry) async {
    if (entry.isReversal || widget.project.costEntries.any(
        (other) => other.reversesId == entry.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: const Text(
          'Расход останется в истории. Будет добавлена '
          'компенсирующая запись с отрицательной суммой.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Отменить расход'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    BudgetService.voidRecord(widget.project, entry.id);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final review = BudgetService.review(widget.project);
    final entries = widget.project.costEntries.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджет и факт'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Записать расход'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZamerSpace.md, ZamerSpace.md, ZamerSpace.md, 110),
        children: [
          ZCard(
            backgroundColor: ZamerColors.surfaceLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Контроль бюджета',
                    style: ZamerTypography.sectionTitle),
                const SizedBox(height: 14),
                Text('Факт: ${review.actualTotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: ZamerColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 8),
                Text(
                  'Материалы: ${review.actualMaterials.toStringAsFixed(0)} ₽'
                  ' · Работы: ${review.actualLabor.toStringAsFixed(0)} ₽',
                  style: ZamerTypography.caption,
                ),
                const Divider(height: 24),
                Text('Расчётный план: ${review.plannedTotal.toStringAsFixed(0)} ₽',
                    style: ZamerTypography.sectionTitle),
                const SizedBox(height: 6),
                if (review.plannedPositions == 0)
                  const Text(
                    'Смета ещё пуста. Построй помещения и рассчитай '
                    'объёмы, прежде чем сравнивать бюджет.',
                    style: ZamerTypography.caption,
                  )
                else if (review.completeEstimate)
                  Text(
                    'Остаток плана: '
                    '${review.remainingIfFullyPriced!.toStringAsFixed(0)} ₽',
                    style: ZamerTypography.caption,
                  )
                else
                  Text(
                    'План неполный: без цен ${review.unpricedCount}, '
                    'расчётных цен упаковок ${review.derivedPackagePrices}. '
                    'Остаток бюджета пока не определён.',
                    style: const TextStyle(
                      color: ZamerColors.warning,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('История расходов (${entries.length})',
              style: ZamerTypography.sectionTitle),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const ZEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Фактических расходов нет',
              subtitle: 'Добавь оплату материалов или выполненных работ.',
            ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ZCard(
                child: Row(
                  children: [
                    Icon(
                      entry.category == CostCategory.materials
                          ? Icons.inventory_2_outlined
                          : Icons.handyman_outlined,
                      color: entry.isReversal
                          ? ZamerColors.warning : ZamerColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.description,
                              style: ZamerTypography.sectionTitle),
                          Text(
                            '${entry.at.day.toString().padLeft(2, '0')}.'
                            '${entry.at.month.toString().padLeft(2, '0')}.'
                            '${entry.at.year}'
                            '${entry.taskId != null ? ' · работа привязана' : ''}',
                            style: ZamerTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.isReversal ? '−' : ''}'
                      '${entry.amount.toStringAsFixed(0)} ₽',
                      style: ZamerTypography.measurement,
                    ),
                    if (!entry.isReversal &&
                        !widget.project.costEntries.any(
                            (other) => other.reversesId == entry.id))
                      IconButton(
                        tooltip: 'Отменить расход',
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () => _voidEntry(entry),
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
