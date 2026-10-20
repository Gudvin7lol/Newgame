import 'dart:math' as math;

import '../models/models.dart';

enum SpaceIssueKind { objectWall, objectObject, doorClearance }

class SpaceIssue {
  const SpaceIssue(this.description, {
    this.objectIds = const [],
    this.kind = SpaceIssueKind.objectObject,
    this.position,
  });
  final String description;
  final List<String> objectIds;
  final SpaceIssueKind kind;
  final math.Point<double>? position;
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
      // A low door opening is a real opening in the solid wall. Check only
      // intact wall segments so furniture can pass between rooms through it.
      final blocked = <(double, double)>[];
      var cursor = 0.0;
      final passable = wall.openings.where((o) =>
          o.type == OpeningType.door && o.sillHeightMm <= 35 &&
          object.elevationMm >= 0 &&
          object.elevationMm + object.heightMm <= o.heightMm)
          .toList()
        ..sort((a, b) => a.offsetFromStartMm.compareTo(b.offsetFromStartMm));
      for (final opening in passable) {
        final first = opening.offsetFromStartMm.clamp(0.0, length).toDouble();
        final last = (opening.offsetFromStartMm + opening.widthMm)
            .clamp(0.0, length).toDouble();
        if (first > cursor) blocked.add((cursor, first));
        cursor = math.max(cursor, last);
      }
      if (cursor < length) blocked.add((cursor, length));
      for (final (first, last) in blocked) {
        final segmentLength = last - first;
        if (segmentLength < 1) continue;
        final mid = (first + last) / 2 / length;
        final wallCorners = _corners(
          a.xMm + dx * mid,
          a.yMm + dy * mid,
          segmentLength,
          wall.thicknessMm,
          angle,
        );
        if (_overlap(corners, wallCorners)) return true;
      }
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

  static bool _polygonsOverlap(
    List<math.Point<double>> a,
    List<math.Point<double>> b,
  ) {
    // Separating-axis theorem for convex polygons (door quarter circle
    // approximated by a convex 25-point arc fan).
    for (final polygon in [a, b]) {
      for (var i = 0; i < polygon.length; i++) {
        final p = polygon[i], q = polygon[(i + 1) % polygon.length];
        final ax = -(q.y - p.y), ay = q.x - p.x;
        final length = math.sqrt(ax * ax + ay * ay);
        if (length < 1e-6) continue;
        final nx = ax / length, ny = ay / length;
        final aMin = a.map((v) => v.x * nx + v.y * ny).reduce(math.min);
        final aMax = a.map((v) => v.x * nx + v.y * ny).reduce(math.max);
        final bMin = b.map((v) => v.x * nx + v.y * ny).reduce(math.min);
        final bMax = b.map((v) => v.x * nx + v.y * ny).reduce(math.max);
        if (aMax <= bMin + 3 || bMax <= aMin + 3) return false;
      }
    }
    return true;
  }

  /// Swept region of the door leaf on the plan, in millimetres. Shared by
  /// collision detection and the displayed clearance overlay.
  static List<math.Point<double>> doorSwingZone(
    FloorPlan floor, PlanWall wall, WallOpening opening,
  ) {
    if (opening.type != OpeningType.door || opening.widthMm <= 0) {
      return const [];
    }
    final from = floor.nodeById(wall.startNodeId);
    final to = floor.nodeById(wall.endNodeId);
    if (from == null || to == null) return const [];
    final dx = to.xMm - from.xMm, dy = to.yMm - from.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return const [];
    final alongX = dx / length;
    final alongY = dy / length;
    final isRight = opening.doorSwing == DoorSwing.rightIn ||
        opening.doorSwing == DoorSwing.rightOut;
    final hingeDistance = opening.offsetFromStartMm +
        (isRight ? opening.widthMm : 0.0);
    final hinge = math.Point<double>(
      from.xMm + alongX * hingeDistance,
      from.yMm + alongY * hingeDistance,
    );
    final positive = opening.doorSwing == DoorSwing.leftIn ||
        opening.doorSwing == DoorSwing.rightIn;
    final closedAngle = math.atan2(
      isRight ? -alongY : alongY,
      isRight ? -alongX : alongX,
    );
    final openAngle = math.atan2(
      positive ? alongX : -alongX,
      positive ? -alongY : alongY,
    );
    var sweep = openAngle - closedAngle;
    while (sweep > math.pi) { sweep -= 2 * math.pi; }
    while (sweep < -math.pi) { sweep += 2 * math.pi; }
    final sector = <math.Point<double>>[hinge];
    for (var step = 0; step <= 24; step++) {
      final a = closedAngle + sweep * step / 24;
      sector.add(math.Point<double>(
        hinge.x + math.cos(a) * opening.widthMm,
        hinge.y + math.sin(a) * opening.widthMm,
      ));
    }

    return sector;
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
            kind: SpaceIssueKind.objectWall,
            position: math.Point<double>(object.xMm, object.yMm),
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
              kind: SpaceIssueKind.objectObject,
              position: math.Point<double>((a.xMm + b.xMm) / 2, (a.yMm + b.yMm) / 2),
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
        // Check the actual 90-degree swept area of the opening leaf,
        // not a generic 1200 mm box on both sides of the wall.
        final sector = doorSwingZone(floor, wall, opening);
        if (sector.isEmpty) continue;
        for (final object in objects) {
          if (object.elevationMm >= opening.heightMm ||
              object.elevationMm + object.heightMm <= 0) continue;
          final oc = _corners(
            object.xMm, object.yMm, object.widthMm,
            object.depthMm, object.rotationDeg,
          );
          if (_polygonsOverlap(sector, oc)) {
            issues.add(
              SpaceIssue(
                'Проход у двери перекрыт (зона открывания): ${_name(object)}',
                objectIds: [object.id],
                kind: SpaceIssueKind.doorClearance,
                position: math.Point<double>(object.xMm, object.yMm),
              ),
            );
          }
        }
      }
    }
    return issues;
  }
}
