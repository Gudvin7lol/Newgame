import 'dart:math' as math;

import '../models/models.dart';

class SpaceIssue {
  const SpaceIssue(this.description, {this.objectIds = const []});
  final String description;
  final List<String> objectIds;
}

class SpaceCheckService {
  static bool intersectsWall(FloorPlan floor, PlanObject object) {
    if (!_occupiesFloor(object) || object.type == PlanObjectType.radiator) {
      return false;
    }
    final corners = _corners(
      object.xMm,
      object.yMm,
      object.widthMm,
      object.depthMm,
      object.rotationDeg,
    );
    for (final wall in floor.walls) {
      if (wall.demolition ||
          wall.projectLayer == ProjectLayer.demolition ||
          object.elevationMm >=
              (wall.heightOverrideMm ?? floor.defaultHeightMm)) {
        continue;
      }
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;
      final angle = math.atan2(dy, dx) * 180 / math.pi;
      final wallCorners = _corners(
        (a.xMm + b.xMm) / 2,
        (a.yMm + b.yMm) / 2,
        length,
        wall.thicknessMm,
        angle,
      );
      if (_overlap(corners, wallCorners)) return true;
    }
    return false;
  }

  static bool _occupiesFloor(PlanObject object) =>
      object.layer != ProjectLayer.demolition &&
      object.widthMm > 0 &&
      object.depthMm > 0 &&
      object.heightMm > 0 &&
      object.elevationMm < 2000 &&
      {
        PlanObjectType.furniture,
        PlanObjectType.sanitary,
        PlanObjectType.column,
        PlanObjectType.box,
        PlanObjectType.radiator,
      }.contains(object.type);

  static String _name(PlanObject object) =>
      object.label.isEmpty ? object.type.label : object.label;

  static List<math.Point<double>> _corners(
    double x,
    double y,
    double w,
    double d,
    double angle,
  ) {
    final a = angle * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    return [
      for (final xx in [-w / 2, w / 2])
        for (final yy in [-d / 2, d / 2])
          math.Point<double>(x + xx * c - yy * s, y + xx * s + yy * c),
    ];
  }

  static bool _overlap(
    List<math.Point<double>> one,
    List<math.Point<double>> two,
  ) {
    for (final polygon in [one, two]) {
      final x = polygon[2] - polygon[0];
      final y = polygon[1] - polygon[0];
      for (final axis in [x, y]) {
        final minA = one
            .map((p) => p.x * axis.x + p.y * axis.y)
            .reduce(math.min);
        final maxA = one
            .map((p) => p.x * axis.x + p.y * axis.y)
            .reduce(math.max);
        final minB = two
            .map((p) => p.x * axis.x + p.y * axis.y)
            .reduce(math.min);
        final maxB = two
            .map((p) => p.x * axis.x + p.y * axis.y)
            .reduce(math.max);
        // Touching edges and rounding within 5 mm are acceptable.
        if (maxA <= minB + 5 || maxB <= minA + 5) return false;
      }
    }
    return true;
  }

  static List<SpaceIssue> inspect(FloorPlan floor) {
    final issues = <SpaceIssue>[];
    final objects = floor.planObjects.where(_occupiesFloor).toList();
    for (final object in objects) {
      if (intersectsWall(floor, object))
        issues.add(
          SpaceIssue(
            '${_name(object)} пересекает стену',
            objectIds: [object.id],
          ),
        );
    }
    for (var i = 0; i < objects.length; i++) {
      final a = objects[i];
      final ac = _corners(a.xMm, a.yMm, a.widthMm, a.depthMm, a.rotationDeg);
      for (var j = i + 1; j < objects.length; j++) {
        final b = objects[j];
        if (a.elevationMm >= b.elevationMm + b.heightMm ||
            b.elevationMm >= a.elevationMm + a.heightMm) {
          continue;
        }
        final bc = _corners(b.xMm, b.yMm, b.widthMm, b.depthMm, b.rotationDeg);
        if (_overlap(ac, bc)) {
          issues.add(
            SpaceIssue(
              'Пересечение: ${_name(a)} и ${_name(b)}',
              objectIds: [a.id, b.id],
            ),
          );
        }
      }
    }
    for (final wall in floor.walls) {
      final from = floor.nodeById(wall.startNodeId);
      final to = floor.nodeById(wall.endNodeId);
      if (from == null || to == null) continue;
      final dx = to.xMm - from.xMm, dy = to.yMm - from.yMm;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;
      for (final opening in wall.openings.where(
        (o) => o.type == OpeningType.door,
      )) {
        if (opening.widthMm <= 0 ||
            opening.offsetFromStartMm < 0 ||
            opening.offsetFromStartMm + opening.widthMm > length + 5)
          continue;
        final t = (opening.offsetFromStartMm + opening.widthMm / 2) / length;
        // A 600 mm deep strip on each side of the doorway is checked.
        final clearance = _corners(
          from.xMm + dx * t,
          from.yMm + dy * t,
          opening.widthMm,
          1200,
          math.atan2(dy, dx) * 180 / math.pi,
        );
        for (final object in objects) {
          if (object.elevationMm >= opening.heightMm) continue;
          final oc = _corners(
            object.xMm,
            object.yMm,
            object.widthMm,
            object.depthMm,
            object.rotationDeg,
          );
          if (_overlap(clearance, oc)) {
            issues.add(
              SpaceIssue(
                'Проход у двери перекрывает ${_name(object)}',
                objectIds: [object.id],
              ),
            );
          }
        }
      }
    }
    return issues;
  }
}
