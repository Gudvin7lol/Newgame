import '../models/models.dart';
import '../models/material_purchase.dart';
import '../models/cost_entry.dart';
import 'budget_service.dart';
import 'estimate_service.dart';

class PurchaseCoverage {
  const PurchaseCoverage({
    required this.line,
    required this.purchased,
  });
  final EstimateLine line;
  final double purchased;
  double get remaining =>
      (line.quantity - purchased).clamp(0, double.infinity).toDouble();
  double get extra =>
      (purchased - line.quantity).clamp(0, double.infinity).toDouble();
  bool get complete => purchased >= line.quantity - 0.000001;
}

/// Tracks physically purchased material independently of money paid,
/// stock consumption and acceptance of construction work.
class ProcurementService {
  static const _packUnits = {'пач.', 'кор.', 'меш.', 'рул.', 'вед.'};

  static double purchasedFor(MeasureProject project, String estimateKey) =>
      project.materialPurchases
          .where((entry) => entry.estimateKey == estimateKey)
          .fold<double>(0, (sum, entry) => sum + entry.signedQuantity);

  static List<PurchaseCoverage> coverage(MeasureProject project) => [
    for (final line in EstimateService.buildPurchases(project).lines)
      PurchaseCoverage(
        line: line, purchased: purchasedFor(project, line.key),
      ),
  ];

  /// Purchases referencing an old pack specification remain in history,
  /// even when that specification is no longer part of the current estimate.
  static List<MaterialPurchase> unlinked(MeasureProject project) {
    final keys = EstimateService.buildPurchases(project)
        .lines.map((line) => line.key).toSet();
    return project.materialPurchases.where(
        (entry) => !keys.contains(entry.estimateKey)).toList();
  }

  static String _uniqueId(MeasureProject project, DateTime date) {
    final ids = project.materialPurchases.map((entry) => entry.id).toSet();
    var index = 0;
    var id = 'purchase-${date.microsecondsSinceEpoch}-0';
    while (ids.contains(id)) {
      id = 'purchase-${date.microsecondsSinceEpoch}-${++index}';
    }
    return id;
  }

  static MaterialPurchase record(
    MeasureProject project, {
    required String estimateKey,
    required double quantity,
    String note = '',
    DateTime? at,
  }) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 1000000000) {
      throw ArgumentError.value(
          quantity, 'quantity', 'Некорректное количество закупки');
    }
    final line = EstimateService.buildPurchases(project).lines
        .where((line) => line.key == estimateKey).firstOrNull;
    if (line == null) {
      throw ArgumentError.value(estimateKey, 'estimateKey',
          'Позиция больше не существует в текущей ведомости закупок');
    }
    if (_packUnits.contains(line.unit) &&
        (quantity - quantity.roundToDouble()).abs() > 1e-8) {
      throw ArgumentError.value(quantity, 'quantity',
          'Упаковки закупаются целыми штуками');
    }
    if (note.length > 250) {
      throw ArgumentError.value(note, 'note', 'Слишком длинное примечание');
    }
    final date = at ?? DateTime.now();
    final entry = MaterialPurchase(
      id: _uniqueId(project, date),
      at: date,
      estimateKey: line.key,
      unit: line.unit,
      quantity: quantity,
      note: note.trim(),
    );
    project.materialPurchases.add(entry);
    return entry;
  }

  /// The actual payment belongs to the materials cost ledger, not a second
  /// balance. One form can capture quantity and optional paid amount together.
  /// A missing amount means the material was received without a recorded payment.
  static MaterialPurchase recordWithPayment(
    MeasureProject project, {
    required String estimateKey,
    required double quantity,
    double? paidAmount,
    String note = '',
    DateTime? at,
  }) {
    if (paidAmount != null &&
        (!paidAmount.isFinite || paidAmount <= 0 ||
            paidAmount > 1000000000000)) {
      throw ArgumentError.value(
          paidAmount, 'paidAmount', 'Неверная оплаченная сумма');
    }
    final date = at ?? DateTime.now();
    final purchase = record(
      project,
      estimateKey: estimateKey,
      quantity: quantity,
      note: note,
      at: date,
    );
    if (paidAmount != null) {
      try {
        final lineName = EstimateService.buildPurchases(project).lines
            .firstWhere((line) => line.key == estimateKey).name;
        BudgetService.record(
          project,
          category: CostCategory.materials,
          description: 'Закупка: ${lineName.length > 230 ? lineName.substring(0, 230) : lineName}',
          amount: paidAmount,
          purchaseId: purchase.id,
          estimateKey: estimateKey,
          at: date,
        );
      } catch (_) {
        // Keep both journals consistent when validation fails.
        project.materialPurchases.remove(purchase);
        rethrow;
      }
    }
    return purchase;
  }

  /// Only payments linked to this physical purchase are shown. An independent
  /// payment recorded in the budget is not implicitly matched by name.
  static double paidForPurchase(MeasureProject project, String id) =>
      project.costEntries
          .where((entry) => entry.purchaseId == id)
          .fold<double>(0, (sum, entry) => sum + entry.signedAmount);

  static MaterialPurchase voidRecord(MeasureProject project, String id,
      {DateTime? at}) {
    final matches = project.materialPurchases.where((entry) => entry.id == id);
    if (matches.isEmpty) throw StateError('Закупка не найдена');
    final original = matches.single;
    if (original.isReversal || project.materialPurchases.any(
        (entry) => entry.reversesId == id)) {
      throw StateError('Закупка уже отменена');
    }
    final date = at ?? DateTime.now();
    final correction = MaterialPurchase(
      id: _uniqueId(project, date),
      at: date,
      estimateKey: original.estimateKey,
      unit: original.unit,
      quantity: original.quantity,
      note: 'Отмена: ${original.note}',
      reversesId: original.id,
    );
    project.materialPurchases.add(correction);
    return correction;
  }
}
