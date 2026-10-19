import 'dart:math' as math;

import '../models/models.dart';
import 'measurement_review_service.dart';
import 'plan_view_layers.dart';
import 'space_check_service.dart';

/// Read-only union of existing geometry and spatial checks. Does not claim
/// unimplemented cable/piping clearance, 3D headroom or accessibility checks.
class PlanClashIssue {
  const PlanClashIssue({
    required this.category,
    required this.description,
    required this.position,
    this.objectIds = const [],
  });

  final PlanClashCategory category;
  final String description;
  final math.Point<double> position;
  final List<String> objectIds;
}

class PlanCollisionService {
  static List<PlanClashIssue> inspect(FloorPlan floor) {
    final issues = <PlanClashIssue>[];
    for (final item in MeasurementReviewService.review(floor)) {
      if (item.kind != MeasurementIssueKind.intersection) continue;
      issues.add(PlanClashIssue(
        category: PlanClashCategory.wallIntersection,
        description: item.description,
        position: item.position,
      ));
    }

    for (final issue in SpaceCheckService.inspect(floor)) {
      final category = switch (issue.type) {
        SpaceIssueType.objectWall => PlanClashCategory.objectWall,
        SpaceIssueType.objectObject => PlanClashCategory.objectObject,
        SpaceIssueType.doorClearance => PlanClashCategory.doorPassage,
      };
      final objects = issue.objectIds
          .map((id) {
            for (final object in floor.planObjects) {
              if (object.id == id) return object;
            }
            return null;
          })
          .whereType<PlanObject>()
          .toList();
      if (objects.isEmpty) continue;
      final x = objects.map((o) => o.xMm).reduce((a, b) => a + b) /
          objects.length;
      final y = objects.map((o) => o.yMm).reduce((a, b) => a + b) /
          objects.length;
      issues.add(PlanClashIssue(
        category: category,
        description: issue.description,
        position: math.Point<double>(x, y),
        objectIds: issue.objectIds,
      ));
    }
    return issues;
  }

  static List<PlanClashIssue> visible(
    List<PlanClashIssue> issues,
    PlanViewLayers settings,
    FloorPlan floor,
  ) {
    if (!settings.showClashes) return const [];
    return issues.where((issue) {
      if (!settings.clashTypes.contains(issue.category)) return false;
      if (issue.category == PlanClashCategory.wallIntersection) {
        return settings.content.contains(PlanContentLayer.walls);
      }
      return issue.objectIds.every((id) {
        for (final object in floor.planObjects) {
          if (object.id == id) return settings.visibleObject(object);
        }
        return false;
      });
    }).toList();
  }
}
