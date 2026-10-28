import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/project_financial_report_service.dart';
import '../services/report_service.dart';

class ProjectFinancialReportScreen extends StatelessWidget {
  const ProjectFinancialReportScreen({super.key, required this.project});

  final MeasureProject project;

  Future<void> _copy(BuildContext context, ProjectFinancialReport report) async {
    await Clipboard.setData(ClipboardData(text: report.toCsv()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отчёт CSV скопирован')));
  }

  void _shareCsv(ProjectFinancialReport report) {
    final safe = project.name.replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9_-]+'), '_');
    Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode(report.toCsv())),
        mimeType: 'text/csv',
      ),
    ], fileNameOverrides: ['zamer-$safe-finance.csv']);
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      await ReportService.shareFinancialPdf(project);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать PDF-отчёт')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ProjectFinancialReportService.build(project);
    final budget = report.budget;
    final works = report.workValue;

    return Scaffold(
      appBar: AppBar(title: const Text('Отчёт по объекту')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZamerSpace.md, ZamerSpace.md, ZamerSpace.md, ZamerSpace.xxl),
        children: [
          ZCard(
            backgroundColor: ZamerColors.surfaceLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: ZamerTypography.sectionTitle),
                if (project.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(project.address, style: ZamerTypography.caption),
                ],
                const SizedBox(height: 12),
                Text('Оплачено всего: ${budget.actualTotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: ZamerColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    )),
                const SizedBox(height: 8),
                Text(
                  'Материалы: ${budget.actualMaterials.toStringAsFixed(0)} ₽'
                  ' · Работы: ${budget.actualLabor.toStringAsFixed(0)} ₽',
                  style: ZamerTypography.caption,
                ),
                const Divider(height: 24),
                Text(
                  'Плановая оценка: ${budget.plannedTotal.toStringAsFixed(0)} ₽',
                  style: ZamerTypography.sectionTitle,
                ),
                const SizedBox(height: 5),
                Text(
                  budget.completeEstimate
                      ? 'Все позиции оценены. План остаётся расчётным '
                        'и пересчитывается при изменении проекта.'
                      : 'План неполный: ${budget.unpricedCount} позиций без цены '
                        'и ${budget.derivedPackagePrices} расчётных цен упаковок.',
                  style: TextStyle(
                    color: budget.completeEstimate
                        ? ZamerColors.textSecondary : ZamerColors.warning,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZamerSpace.md),
                Wrap(
                  spacing: ZamerSpace.xs,
                  runSpacing: ZamerSpace.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy(context, report),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Копировать'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _shareCsv(report),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('CSV'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _sharePdf(context),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZamerSpace.md),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Закупки', style: ZamerTypography.sectionTitle),
                const SizedBox(height: 8),
                Text('Позиции с недостачей: ${report.underboughtPositions}',
                    style: ZamerTypography.bodySmall),
                Text('Позиции сверх плана: ${report.overboughtPositions}',
                    style: ZamerTypography.bodySmall),
                Text('Без привязанного платежа: '
                    '${report.unpaidLinkedPurchases}',
                    style: ZamerTypography.bodySmall),
                if (report.unlinkedMaterialPayments > 0)
                  Text(
                    'Оплат без связи с закупками: '
                    '${report.unlinkedMaterialPayments}',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12,
                    ),
                  ),
                if (report.cancelledPurchasesWithOutstandingPayment > 0)
                  Text(
                    'Отменённые закупки с оплатой: '
                    '${report.cancelledPurchasesWithOutstandingPayment}',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12,
                    ),
                  ),
                if (report.unlinkedActivePurchases > 0)
                  Text(
                    'Нужно сверить закупки прежней спецификации: '
                    '${report.unlinkedActivePurchases}',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                for (final item in report.purchases.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item.name}: ${item.purchased.toStringAsFixed(2)}'
                      ' из ${item.planned.toStringAsFixed(2)} ${item.unit}; '
                      'оплачено ${item.paidLinked.toStringAsFixed(0)} ₽',
                      style: ZamerTypography.caption,
                    ),
                  ),
                if (report.purchases.length > 12)
                  const Text(
                    'Остальные позиции включены в CSV и PDF.',
                    style: ZamerTypography.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZamerSpace.md),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Принятые работы',
                    style: ZamerTypography.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  'Принято по известным ставкам: '
                  '${works.acceptedPricedValue.toStringAsFixed(0)} ₽',
                  style: ZamerTypography.bodySmall,
                ),
                Text(
                  'Оплачено мастерам: ${works.paidLabor.toStringAsFixed(0)} ₽',
                  style: ZamerTypography.bodySmall,
                ),
                if (works.unpricedAcceptedTasks > 0)
                  Text(
                    'Принятых задач без ставки: '
                    '${works.unpricedAcceptedTasks}',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12,
                    ),
                  ),
                if (works.flaggedAcceptedTasks > 0)
                  Text(
                    'Объёмы на повторной проверке: '
                    '${works.flaggedAcceptedTasks}',
                    style: const TextStyle(
                      color: ZamerColors.warning, fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Открытых замечаний: ${report.openIssues}',
                    style: ZamerTypography.caption),
                const SizedBox(height: 8),
                const Text(
                  'Разница между оценкой принятых работ и выплатами '
                  'не является автоматическим долгом.',
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZamerSpace.md),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Детализация', style: ZamerTypography.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  'Записей оплат: ${report.cashEntries.length} · '
                  'записей закупок: ${report.purchaseEntries.length} · '
                  'работ: ${report.works.length}',
                  style: ZamerTypography.caption,
                ),
                const SizedBox(height: 8),
                const Text(
                  'PDF содержит сводку и журналы. CSV сохраняет '
                  'полные идентификаторы, количества, цены и суммы '
                  'для дальнейшей сверки в таблицах.',
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
