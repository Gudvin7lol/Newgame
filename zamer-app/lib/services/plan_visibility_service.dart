import 'dart:math' as math;

import '../models/models.dart';
import 'measurement_review_service.dart';
import 'space_check_service.dart';

/// Display-only filters. These must never remove elements from FloorPlan or
/// affect the exported document: hiding an element is not deleting it.
enum PlanDisplayLayer {
  floorFinishes,
  walls,
  openings,
  furniture,
  sanitary,
  electrical,
  engineering,
  structures,
  dimensions,
  axisDimensions,
  roomLabels,
}

extension PlanDisplayLayerLabel on PlanDisplayLayer {
  String get label => switch (this) {
    PlanDisplayLayer.floorFinishes => 'Покрытия пола',
    PlanDisplayLayer.walls => 'Стены и перегородки',
    PlanDisplayLayer.openings => 'Двери и окна',
    PlanDisplayLayer.furniture => 'Мебель',
    PlanDisplayLayer.sanitary => 'Сантехника',
    PlanDisplayLayer.electrical => 'Электрика',
    PlanDisplayLayer.engineering => 'Инженерные сети',
    PlanDisplayLayer.structures => 'Конструкции и прочие объекты',
    PlanDisplayLayer.dimensions => 'Размеры внутри помещений',
    PlanDisplayLayer.axisDimensions => 'Конструктивные размеры по осям',
    PlanDisplayLayer.roomLabels => 'Подписи помещений',
  };
}

/// Filterable 2D conflicts. Electrical/pipe spatial collision detection
/// is not included here: those categories only control asset visibility.
enum PlanCollisionKind {
  wallIntersection,
  objectWall,
  objectObject,
  doorClearance,
}

extension PlanCollisionKindLabel on PlanCollisionKind {
  String get label => switch (this) {
    PlanCollisionKind.wallIntersection => 'Пересечения стен',
    PlanCollisionKind.objectWall => 'Объекты со стенами',
    PlanCollisionKind.objectObject => 'Пересечения объектов',
    PlanCollisionKind.doorClearance => 'Перекрытые дверные проходы',
  };
}

class PlanCollisionMark {
  const PlanCollisionMark({
    required this.kind,
    required this.description,
    required this.position,
  });

  final PlanCollisionKind kind;
  final String description;
  final math.Point<double> position;
}

class PlanCollisionService {
  /// Reports collisions already covered by the project's geometry and space
  /// validators, with a coordinate on the same CAD canvas.
  static List<PlanCollisionMark> inspect(FloorPlan floor) {
    final issues = <PlanCollisionMark>[];
    for (final issue in MeasurementReviewService.review(floor)) {
      if (issue.kind != MeasurementIssueKind.intersection) continue;
      issues.add(PlanCollisionMark(
        kind: PlanCollisionKind.wallIntersection,
        description: issue.description,
        position: issue.position,
      ));
    }
    for (final issue in SpaceCheckService.inspect(floor)) {
      final kind = switch (issue.kind) {
        SpaceIssueKind.objectWall => PlanCollisionKind.objectWall,
        SpaceIssueKind.objectObject => PlanCollisionKind.objectObject,
        SpaceIssueKind.doorClearance => PlanCollisionKind.doorClearance,
      };
      final position = issue.position;
      if (position == null) continue;
      issues.add(PlanCollisionMark(
        kind: kind,
        description: issue.description,
        position: position,
      ));
    }
    return issues;
  }
}
