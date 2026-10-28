import 'dart:math' as math;

import '../models/models.dart';
import '../models/cost_entry.dart';
import '../models/material_purchase.dart';
import '../models/work_board.dart';
import 'budget_service.dart';
import 'procurement_service.dart';
import 'work_value_service.dart';

/// Quantities and amounts are separate ledgers: a physical purchase is NOT an
/// expense until a CostEntry is recorded, and acceptance is NOT a payment.
class ReportPurchaseLine {
  const ReportPurchaseLine({
    required this.key, required this.name, required this.unit,
    required this.planned, required this.purchased,
    required this.unitPrice, required this.derivedPrice,
    required this.paidLinked,
  });
  final String key, name, unit;
  final double planned, purchased, unitPrice, paidLinked;
  final bool derivedPrice;
  double get remaining => (planned - purchased).clamp(0, double.infinity).toDouble();
  double get excess => (purchased - planned).clamp(0, double.infinity).toDouble();
}

class ReportWorkLine {
  const ReportWorkLine({
    required this.taskId, required this.title, required this.roomName,
    required this.unit, required this.planned, required this.done,
    required this.accepted, required this.paid,
    required this.unitRate, required this.needsReview,
  });
  final String taskId, title, roomName, unit;
  final double planned, done, accepted, paid;
  final double? unitRate;
  final bool needsReview;
  double? get acceptedValue => unitRate == null
      ? null
      : math.max(0.0, math.min(math.max(0.0, planned), accepted)) * unitRate!;
}

class ProjectFinancialReport {
  ProjectFinancialReport({
    required this.projectName, required this.projectAddress,
    required this.createdAt, required this.budget, required this.workValue,
    required List<ReportPurchaseLine> purchases,
    required List<ReportWorkLine> works,
    required List<CostEntry> cashEntries,
    required List<MaterialPurchase> purchaseEntries,
    required this.unlinkedActivePurchases,
    required this.openIssues,
  }) : purchases = List.unmodifiable(purchases),
       works = List.unmodifiable(works),
       cashEntries = List.unmodifiable(cashEntries),
       purchaseEntries = List.unmodifiable(purchaseEntries);

  final String projectName, projectAddress;
  final DateTime createdAt;
  final BudgetReview budget;
  final WorkValueReview workValue;
  final List<ReportPurchaseLine> purchases;
  final List<ReportWorkLine> works;
  final List<CostEntry> cashEntries;
  final List<MaterialPurchase> purchaseEntries;
  final int unlinkedActivePurchases, openIssues;

  /// Paid material costs with no link to a physical receipt. Not necessarily
  /// duplicates: a manual correction, advance or delivery may be legitimate.
  int get unlinkedMaterialPayments {
    final reversed = cashEntries
        .where((e) => e.isReversal).map((e) => e.reversesId).toSet();
    return cashEntries.where((e) =>
        e.category == CostCategory.materials &&
        e.purchaseId == null && !e.isReversal &&
        !reversed.contains(e.id)).length;
  }

  /// Cancelling quantities does not cancel a payment. Flag cash that remains
  /// linked to a cancelled receipt for explicit human reconciliation.
  int get cancelledPurchasesWithOutstandingPayment {
    final cancelledIds = purchaseEntries
        .where((p) => p.isReversal)
        .map((p) => p.reversesId).toSet();
    final paid = <String, double>{};
    for (final cost in cashEntries) {
      if (cost.purchaseId == null) continue;
      paid.update(cost.purchaseId!,
          (value) => value + cost.signedAmount,
          ifAbsent: () => cost.signedAmount);
    }
    return cancelledIds
        .where((id) => id != null && (paid[id] ?? 0) > 0.001).length;
  }

  int get underboughtPositions =>
      purchases.where((p) => p.remaining > 0.000001).length;
  int get overboughtPositions =>
      purchases.where((p) => p.excess > 0.000001).length;
  int get unpaidLinkedPurchases {
    final linked = <String, double>{};
    for (final entry in cashEntries) {
      if (entry.purchaseId != null) {
        linked.update(entry.purchaseId!,
            (sum) => sum + entry.signedAmount,
            ifAbsent: () => entry.signedAmount);
      }
    }
    final cancelled = purchaseEntries
        .where((entry) => entry.isReversal)
        .map((entry) => entry.reversesId).toSet();
    return purchaseEntries.where((entry) =>
      !entry.isReversal && !cancelled.contains(entry.id) &&
      (linked[entry.id] ?? 0) <= 0).length;
  }

  /// Semicolon-delimited UTF-8 with BOM for common Russian spreadsheet apps.
  /// All user-originating text is spreadsheet-formula escaped.
  String toCsv() {
    final rows = <List<String>>[];
    void add(List<String> cells) => rows.add(cells);
    String f(num n) => n.toStringAsFixed(2);
    String cash(CostEntry entry) => f(entry.signedAmount);

    add(['ЗАМЕР', 'Финансовый отчёт по объекту']);
    add(['Объект', projectName]);
    add(['Адрес', projectAddress]);
    add(['Дата формирования', createdAt.toIso8601String()]);
    add(['Статус бюджета',
      budget.completeEstimate ? 'Все позиции оценены по заданным ценам'
          : 'Предварительный: есть цены без подтверждения либо пустые позиции']);
    add(['Важно', 'Это пересчёт текущего проекта, не утверждённая версия сметы']);
    add(['Важно', 'Принято, оплачено и закуплено являются независимыми показателями']);
    add([]);

    add(['ПЛАН И ФАКТ', 'Сумма, ₽']);
    add(['План материалов (оценённые позиции)', f(budget.plannedMaterials)]);
    add(['План работ (оценённые позиции)', f(budget.plannedLabor)]);
    add(['План суммарный (оценённые позиции)', f(budget.plannedTotal)]);
    add(['Оплачено материалов', f(budget.actualMaterials)]);
    add(['Оплачено работ', f(budget.actualLabor)]);
    add(['Оплачено всего', f(budget.actualTotal)]);
    add(['Принято работ по известным ставкам', f(workValue.acceptedPricedValue)]);
    add(['Без цены в смете, позиций', '${budget.unpricedCount}']);
    add(['Производных цен упаковки, позиций', '${budget.derivedPackagePrices}']);
    add(['Принятых задач без расценки', '${workValue.unpricedAcceptedTasks}']);
    add(['Принятых задач на пересмотре', '${workValue.flaggedAcceptedTasks}']);
    add(['Непривязанных закупок старой спецификации',
        '${unlinkedActivePurchases}']);
    add(['Открытых замечаний', '${openIssues}']);
    add(['Материальные оплаты без связи с закупкой',
        '${unlinkedMaterialPayments}']);
    add(['Отменённых закупок с неотменённой оплатой',
        '${cancelledPurchasesWithOutstandingPayment}']);
    add(['Позиции закупки с недостачей', '${underboughtPositions}']);
    add(['Позиции закупки со сверхплановым количеством',
        '${overboughtPositions}']);
    add(['Действующих закупок без связанной оплаты',
        '${unpaidLinkedPurchases}']);
    if (budget.completeEstimate) {
      add(['Оценочная разница плана и платежей, НЕ прибыль и НЕ долг',
          f(budget.plannedTotal - budget.actualTotal)]);
    } else {
      add(['Оценочная разница плана и платежей', 'Не определена: смета неполная']);
    }
    add([]);

    add(['ЗАКУПКА ПО ПОЗИЦИЯМ', 'Наименование', 'Ед.', 'План', 'Куплено',
        'Осталось', 'Сверх плана', 'Оплачено, ₽', 'Цена за ед., ₽', 'Примечание']);
    for (final p in purchases) {
      add(['Закупка', p.name, p.unit, f(p.planned), f(p.purchased),
          f(p.remaining), f(p.excess), f(p.paidLinked),
          p.unitPrice > 0 ? f(p.unitPrice) : '',
          p.derivedPrice ? 'Расчётная цена упаковки' : '']);
    }
    add([]);

    add(['КОНТРОЛЬ РАБОТ', 'Работа', 'Помещение', 'Ед.', 'План',
        'Сделано', 'Принято', 'Оплачено, ₽', 'Оценка принятого']);
    for (final w in works) {
      add([w.taskId, w.title, w.roomName, w.unit, f(w.planned),
        f(w.done), f(w.accepted), f(w.paid),
        w.unitRate == null ? 'Без цены' : f(w.acceptedValue!)]);
      if (w.needsReview) {
        add(['ПРОВЕРИТЬ', w.title, 'Принятый объём требует сверки после правки геометрии']);
      }
    }
    add([]);

    add(['ЖУРНАЛ ОПЛАТ', 'Дата', 'Раздел', 'Описание', 'Сумма, ₽',
        'Работа ID', 'Закупка ID', 'Корректирует запись']);
    for (final e in cashEntries) {
      add([e.id, e.at.toIso8601String(),
        e.category == CostCategory.materials ? 'Материалы' : 'Работы',
        e.description, cash(e), e.taskId ?? '', e.purchaseId ?? '',
        e.reversesId ?? '']);
    }
    add([]);

    add(['ЖУРНАЛ КОЛИЧЕСТВ', 'Дата', 'Сметный ключ', 'Ед.',
      'Кол-во с учётом корректировки', 'Примечание', 'Корректирует запись']);
    for (final e in purchaseEntries) {
      add([e.id, e.at.toIso8601String(), e.estimateKey, e.unit,
        f(e.signedQuantity), e.note, e.reversesId ?? '']);
    }
    return '\uFEFF${rows.map((row) => row.map(_cell).join(';')).join('\n')}';
  }

  static String _cell(String value) {
    // Numbers (including legitimate negative values) stay numeric.
    final numeric = RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value);
    final trimmed = value.trimLeft();
    final unsafe = !numeric && trimmed.isNotEmpty &&
        ('=+-@'.contains(trimmed[0]));
    final safe = unsafe ? "'$value" : value;
    if (safe.contains(';') || safe.contains('"') || safe.contains('\n') ||
        safe.contains('\r')) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }
}

class ProjectFinancialReportService {
  static ProjectFinancialReport build(MeasureProject project, {DateTime? at}) {
    final coverage = ProcurementService.coverage(project);
    final budget = BudgetService.review(project);
    final workValue = WorkValueService.review(project);
    // A linked financial entry is attributed using its historical receipt
    // key. Do not infer paid amounts from physical quantities or rates.
    final receiptsById = {
      for (final p in project.materialPurchases)
        if (!p.isReversal) p.id: p,
    };
    final paidPerKey = <String, double>{};
    for (final cost in project.costEntries) {
      final receipt = receiptsById[cost.purchaseId];
      if (receipt == null || cost.category != CostCategory.materials) continue;
      paidPerKey.update(receipt.estimateKey,
          (value) => value + cost.signedAmount,
          ifAbsent: () => cost.signedAmount);
    }

    final purchaseLines = [
      for (final p in coverage)
        ReportPurchaseLine(
          key: p.line.key, name: p.line.name,
          unit: p.line.unit, planned: p.line.quantity,
          purchased: p.purchased, unitPrice: p.line.unitPrice,
          derivedPrice: p.line.derivedPrice,
          paidLinked: paidPerKey[p.line.key] ?? 0,
        ),
    ];
    final workLines = [
      for (final task in project.workBoard.tasks)
        ReportWorkLine(
          taskId: task.id, title: task.title, roomName: task.roomName,
          unit: task.unit, planned: task.quantity,
          done: task.done, accepted: task.accepted,
          paid: BudgetService.actualForTask(project, task.id),
          unitRate: WorkValueService.rateFor(project, task),
          needsReview: task.needsQuantityReview ||
              task.accepted > task.quantity + 0.0001 ||
              task.accepted < -0.0001,
        ),
    ];
    // Reversals don't count as additional purchases still needing review.
    final unmatched = ProcurementService.unlinked(project);
    final reversed = project.materialPurchases
        .where((entry) => entry.isReversal)
        .map((entry) => entry.reversesId).toSet();
    final unmatchedActive = unmatched.where((entry) =>
        !entry.isReversal && !reversed.contains(entry.id)).length;

    return ProjectFinancialReport(
      projectName: project.name, projectAddress: project.address,
      createdAt: at ?? DateTime.now(), budget: budget, workValue: workValue,
      purchases: purchaseLines, works: workLines,
      cashEntries: project.costEntries,
      purchaseEntries: project.materialPurchases,
      unlinkedActivePurchases: unmatchedActive,
      openIssues: project.workBoard.issues.where((issue) => issue.open).length,
    );
  }
}
