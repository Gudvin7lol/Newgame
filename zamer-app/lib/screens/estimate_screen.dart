import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
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
      builder: (dialogContext) => AlertDialog(
        title: Text(line.name),
        content: TextFormField(
          initialValue: raw,
          onChanged: (value) => raw = value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Цена за ${line.unit}',
            suffixText: '₽',
            prefixIcon: const Icon(Icons.currency_ruble_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(raw.replaceAll(',', '.')),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null || value < 0 || !value.isFinite || value > 100000000) {
      return;
    }
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

  Future<void> _copy(ProjectEstimate materials, ProjectEstimate works) async {
    await Clipboard.setData(
      ClipboardData(text: _export(materials, works)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Смета скопирована')));
  }

  void _share(ProjectEstimate materials, ProjectEstimate works) {
    Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(_export(materials, works))),
          mimeType: 'text/csv',
        ),
      ],
      fileNameOverrides: ['zamer-estimate.csv'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final materials = EstimateService.build(widget.project);
    final works = EstimateService.buildWork(widget.project);
    final estimate = _work ? works : materials;
    final combined = materials.pricedTotal + works.pricedTotal;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Автосмета'),
            Text(widget.project.name, style: ZamerTypography.caption),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Скопировать смету',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(materials, works),
          ),
          IconButton(
            tooltip: 'Поделиться сметой',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _share(materials, works),
          ),
          const SizedBox(width: ZamerSpace.xs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('Материалы'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.handyman_outlined),
                    label: Text('Работы'),
                  ),
                ],
                selected: {_work},
                onSelectionChanged: (value) =>
                    setState(() => _work = value.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.md),
            child: ZCard(
              backgroundColor: ZamerColors.surfaceLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ZamerColors.accent.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(ZamerRadius.md),
                        ),
                        child: Icon(
                          _work
                              ? Icons.handyman_outlined
                              : Icons.inventory_2_outlined,
                          color: ZamerColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: ZamerSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _work
                                  ? 'Работы по всем этажам'
                                  : 'Материалы по всем этажам',
                              style: ZamerTypography.sectionTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${estimate.lines.length} позиций',
                              style: ZamerTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      if (estimate.unpricedCount > 0)
                        ZStatusChip(
                          icon: Icons.warning_amber_rounded,
                          label: 'Без цены: ${estimate.unpricedCount}',
                        ),
                    ],
                  ),
                  const SizedBox(height: ZamerSpace.lg),
                  Text(
                    '${estimate.pricedTotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: ZamerColors.textPrimary,
                      fontSize: 27,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: ZamerSpace.xs),
                  Text(
                    'Оценённая стоимость текущего раздела',
                    style: ZamerTypography.caption,
                  ),
                  const SizedBox(height: ZamerSpace.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZamerSpace.sm,
                      vertical: ZamerSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: ZamerColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(ZamerRadius.sm),
                      border: Border.all(color: ZamerColors.outlineSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calculate_outlined,
                          size: 16,
                          color: ZamerColors.textMuted,
                        ),
                        const SizedBox(width: ZamerSpace.xs),
                        const Expanded(
                          child: Text(
                            'Материалы + работы',
                            style: ZamerTypography.caption,
                          ),
                        ),
                        Text(
                          '${combined.toStringAsFixed(0)} ₽',
                          style: ZamerTypography.measurement,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZamerSpace.sm),
          Expanded(
            child: estimate.lines.isEmpty
                ? const ZEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Смета пока пустая',
                    subtitle:
                        'Сначала создай помещения и назначь материалы. Позиции появятся автоматически.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      ZamerSpace.md,
                      ZamerSpace.sm,
                      ZamerSpace.md,
                      ZamerSpace.xxl,
                    ),
                    itemCount: estimate.lines.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ZamerSpace.sm),
                    itemBuilder: (context, index) {
                      final line = estimate.lines[index];
                      return _EstimateLineCard(
                        line: line,
                        onTap: () => _price(line),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EstimateLineCard extends StatelessWidget {
  const _EstimateLineCard({required this.line, required this.onTap});

  final EstimateLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priced = line.unitPrice > 0;
    return ZCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(ZamerSpace.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: priced
                    ? ZamerColors.success.withValues(alpha: .10)
                    : ZamerColors.warning.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
              ),
              child: Icon(
                priced
                    ? Icons.check_circle_outline_rounded
                    : Icons.price_change_outlined,
                size: 19,
                color: priced ? ZamerColors.success : ZamerColors.warning,
              ),
            ),
            const SizedBox(width: ZamerSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZamerColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priced
                        ? '${line.quantity.toStringAsFixed(2)} ${line.unit} × ${line.unitPrice.toStringAsFixed(2)} ₽'
                        : '${line.quantity.toStringAsFixed(2)} ${line.unit} • нажми, чтобы задать цену',
                    style: TextStyle(
                      color: priced
                          ? ZamerColors.textMuted
                          : ZamerColors.warning,
                      fontSize: 10.5,
                      fontWeight: priced ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZamerSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priced ? '${line.total.toStringAsFixed(0)} ₽' : 'Без цены',
                  style: TextStyle(
                    color: priced
                        ? ZamerColors.textPrimary
                        : ZamerColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: ZamerColors.textFaint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
