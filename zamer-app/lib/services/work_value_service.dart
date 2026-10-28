import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';
import 'budget_service.dart';

/// A valuation of accepted and completed physical work, not cash flow.
/// All rates come from explicitly entered project work rates. Unpriced
/// acceptance is reported separately and must never be valued as zero.
class WorkValueReview {
  const WorkValueReview({
    required this.acceptedPricedValue,
    required this.completedPricedValue,
    required this.paidLabor,
    required this.unpricedAcceptedTasks,
    required this.flaggedAcceptedTasks,
    required this.acceptedTaskCount,
  });

  final double acceptedPricedValue, completedPricedValue, paidLabor;
  final int unpricedAcceptedTasks, flaggedAcceptedTasks, acceptedTaskCount;
  bool get allAcceptedPriced => unpricedAcceptedTasks == 0;
  /// Informational only; advances and retainers make this NOT a debt figure.
  double? get acceptedMinusPayments =>
      allAcceptedPriced ? acceptedPricedValue - paidLabor : null;
}

class WorkValueService {
  /// WorkGenerationService titles and EstimateService legacy price labels
  /// sometimes differ. Resolve those deliberate aliases by operation code.
  static const _legacyEstimateNames = <String, String>{
    'floor_laminate': 'Укладка ламината',
    'floor_tile': 'Укладка плитки пола',
    'floor_underlay': 'Укладка подложки',
    'wall_plaster': 'Штукатурка стен',
    'wall_putty': 'Шпаклёвка стен',
    'wall_paint': 'Покраска стен',
    'wall_tile': 'Укладка плитки стен',
    'ceiling_gkl': 'Монтаж потолка ГКЛ',
    'ceiling_stretch': 'Монтаж натяжного потолка',
    'ceiling_paint': 'Покраска потолка',
    'warm_floor': 'Монтаж водяного тёплого пола',
  };

  static double? rateFor(MeasureProject project, WorkTask task) {
    final candidateKeys = [
      'task:${task.id}|${task.unit}',
      if (task.operationCode != null)
        'operation:${task.operationCode}|${task.unit}',
      '${task.title}|${task.unit}',
      if (task.operationCode != null &&
          _legacyEstimateNames.containsKey(task.operationCode))
        '${_legacyEstimateNames[task.operationCode]}|${task.unit}',
    ];
    for (final key in candidateKeys) {
      final price = project.workRates[key];
      if (price != null && price.isFinite && price > 0) return price;
    }
    return null;
  }

  static WorkValueReview review(MeasureProject project) {
    var acceptedValue = 0.0;
    var doneValue = 0.0;
    var unpricedAccepted = 0;
    var flagged = 0;
    var acceptedTasks = 0;
    for (final task in project.workBoard.tasks) {
      final scope = task.quantity;
      if (!scope.isFinite || scope <= 0) continue;
      final accepted = math.max(0.0, math.min(scope, task.accepted));
      final done = math.max(0.0, math.min(scope, task.done));
      if (accepted <= 0 && done <= 0) continue;
      final rate = rateFor(project, task);
      if (accepted > 0) {
        acceptedTasks++;
        if (task.needsQuantityReview || task.accepted > scope + 0.0001 ||
            task.accepted < 0) flagged++;
        if (rate == null) unpricedAccepted++;
      }
      if (rate != null) {
        acceptedValue += accepted * rate;
        doneValue += done * rate;
      }
    }
    return WorkValueReview(
      acceptedPricedValue: acceptedValue,
      completedPricedValue: doneValue,
      paidLabor: BudgetService.review(project).actualLabor,
      unpricedAcceptedTasks: unpricedAccepted,
      flaggedAcceptedTasks: flagged,
      acceptedTaskCount: acceptedTasks,
    );
  }
}
