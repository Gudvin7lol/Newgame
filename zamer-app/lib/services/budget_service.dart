import '../models/models.dart';
import '../models/cost_entry.dart';
import 'estimate_service.dart';

/// Missing prices must never be shown as a fully approved project budget.
class BudgetReview {
  const BudgetReview({
    required this.plannedMaterials,
    required this.plannedLabor,
    required this.actualMaterials,
    required this.actualLabor,
    required this.unpricedMaterials,
    required this.unpricedLabor,
    required this.derivedPackagePrices,
    required this.plannedPositions,
  });

  final double plannedMaterials, plannedLabor;
  final double actualMaterials, actualLabor;
  final int unpricedMaterials, unpricedLabor, derivedPackagePrices;
  final int plannedPositions;
  double get plannedTotal => plannedMaterials + plannedLabor;
  double get actualTotal => actualMaterials + actualLabor;
  int get unpricedCount => unpricedMaterials + unpricedLabor;
  bool get completeEstimate => plannedPositions > 0 &&
      unpricedCount == 0 && derivedPackagePrices == 0;
  double? get remainingIfFullyPriced =>
      completeEstimate ? plannedTotal - actualTotal : null;
}

class BudgetService {
  static BudgetReview review(MeasureProject project) {
    final materials = EstimateService.buildPurchases(project);
    final labor = EstimateService.buildWork(project);
    var spentMaterials = 0.0;
    var spentLabor = 0.0;
    for (final entry in project.costEntries) {
      if (entry.category == CostCategory.materials) {
        spentMaterials += entry.signedAmount;
      } else {
        spentLabor += entry.signedAmount;
      }
    }
    return BudgetReview(
      plannedMaterials: materials.pricedTotal,
      plannedLabor: labor.pricedTotal,
      actualMaterials: spentMaterials,
      actualLabor: spentLabor,
      unpricedMaterials: materials.unpricedCount,
      unpricedLabor: labor.unpricedCount,
      derivedPackagePrices: materials.derivedPriceCount,
      plannedPositions: materials.lines.length + labor.lines.length,
    );
  }

  static double actualForTask(MeasureProject project, String taskId) =>
      project.costEntries
          .where((entry) => entry.taskId == taskId)
          .fold<double>(0, (sum, entry) => sum + entry.signedAmount);

  static String _uniqueId(MeasureProject project, DateTime at) {
    var suffix = 0;
    final used = project.costEntries.map((item) => item.id).toSet();
    var id = 'cost-${at.microsecondsSinceEpoch}-${suffix}';
    while (used.contains(id)) {
      id = 'cost-${at.microsecondsSinceEpoch}-${++suffix}';
    }
    return id;
  }

  static CostEntry record(
    MeasureProject project, {
    required CostCategory category,
    required String description,
    required double amount,
    String? taskId,
    String? estimateKey,
    DateTime? at,
  }) {
    if (!amount.isFinite || amount <= 0 || amount > 1000000000000) {
      throw ArgumentError.value(amount, 'amount',
          'Сумма расхода должна быть положительной и конечной');
    }
    final title = description.trim();
    if (title.isEmpty || title.length > 240) {
      throw ArgumentError.value(description, 'description',
          'Укажите краткое описание расхода');
    }
    if (taskId != null &&
        !project.workBoard.tasks.any((task) => task.id == taskId)) {
      throw ArgumentError.value(taskId, 'taskId',
          'Связанная работа не найдена в проекте');
    }
    final date = at ?? DateTime.now();
    final entry = CostEntry(
      id: _uniqueId(project, date), at: date, category: category,
      description: title, amount: amount,
      taskId: taskId, estimateKey: estimateKey,
    );
    project.costEntries.add(entry);
    return entry;
  }

  /// Reverses an entry without deleting its historical payment fact.
  static CostEntry voidRecord(MeasureProject project, String id,
      {DateTime? at}) {
    final existing = project.costEntries.where((entry) => entry.id == id);
    if (existing.isEmpty) throw StateError('Расход не найден');
    final entry = existing.single;
    if (entry.isReversal || project.costEntries.any(
        (other) => other.reversesId == id)) {
      throw StateError('Запись уже отменена');
    }
    final date = at ?? DateTime.now();
    final correction = CostEntry(
      id: _uniqueId(project, date), at: date,
      category: entry.category, amount: entry.amount,
      description: 'Отмена: ${entry.description}',
      taskId: entry.taskId, estimateKey: entry.estimateKey,
      reversesId: id,
    );
    project.costEntries.add(correction);
    return correction;
  }
}
