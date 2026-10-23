import 'dart:math' as math;

import '../models/models.dart';

enum SpaceIssueKind { objectWall, objectObject, doorClearance, doorDoor }

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
    final parts = _collisionParts(object);
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
        for (final part in parts) {
          if (part.topMm <= 0 || part.bottomMm >=
              (wall.heightOverrideMm ?? floor.defaultHeightMm)) continue;
          if (_overlap(part.outline, wallCorners)) return true;
        }
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

  /// Lightweight 3D collision representation. Unlike a whole-object
  /// bounding box this distinguishes table legs/top and chair legs/seat/back.
  /// Unknown catalog entries conservatively keep the whole-volume fallback.
  static List<_CollisionVolume> _collisionParts(PlanObject o) {
    final parts = <_CollisionVolume>[];
    void add(double cx, double cy, double w, double d,
        double zBottom, double zTop) {
      if (w <= 0 || d <= 0 || zTop <= zBottom) return;
      final radians = o.rotationDeg * math.pi / 180;
      final x = o.xMm + cx * math.cos(radians) - cy * math.sin(radians);
      final y = o.yMm + cx * math.sin(radians) + cy * math.cos(radians);
      parts.add(_CollisionVolume(
        _corners(x, y, w, d, o.rotationDeg),
        o.elevationMm + zBottom, o.elevationMm + zTop,
      ));
    }
    final id = o.catalogId.toLowerCase();
    final table = {
      'table-rect', 'table-round', 'dining-table-6',
      'dining-table-1800', 'desk', 'office-desk-1400',
      'coffee-table', 'coffee-table-marble', 'coffee-table-oval',
      'coffee-table-dark',
    }.contains(id);
    final chair = {
      'chair', 'dining-chair-upholstered', 'office-chair',
      'bar-stool',
    }.contains(id);
    if (table) {
      final topThickness = math.min(55.0, math.max(24.0, o.heightMm * .07));
      final legWidth = math.min(65.0, o.widthMm * .09);
      final legDepth = math.min(65.0, o.depthMm * .09);
      add(0, 0, o.widthMm, o.depthMm,
          math.max(0.0, o.heightMm - topThickness), o.heightMm);
      for (final x in [-1.0, 1.0]) {
        for (final y in [-1.0, 1.0]) {
          add(x * (o.widthMm / 2 - legWidth / 2 - 40),
              y * (o.depthMm / 2 - legDepth / 2 - 40),
              legWidth, legDepth, 0,
              math.max(0.0, o.heightMm - topThickness));
        }
      }
    } else if (chair) {
      final seat = math.min(480.0, o.heightMm * .61);
      final leg = math.min(50.0, o.widthMm * .11);
      // Match the approved top-view orientation: the chair's backrest is
      // at NEGATIVE local Y (the top of its preview), not behind the seat.
      // Only the seat/legs fit under a table; the raised backrest does not.
      add(0, o.depthMm * .09, o.widthMm * .88, o.depthMm * .69,
          seat - 65, seat);
      add(0, -o.depthMm * .42, o.widthMm, o.depthMm * .16,
          seat - 25, o.heightMm);
      for (final x in [-1.0, 1.0]) {
        for (final y in [-1.0, 1.0]) {
          add(x * (o.widthMm / 2 - leg / 2),
              y * (o.depthMm * .39), leg, leg, 0, seat - 65);
        }
      }
    } else {
      add(0, 0, o.widthMm, o.depthMm, 0, o.heightMm);
    }
    return parts;
  }

  /// Actual top-view outlines of intersecting *vertical* volumes, not
  /// the full furniture rectangles. Used for precise red collision shading:
  /// a chair seat under a tabletop is not a conflict, while its backrest can
  /// physically intersect the table at a higher elevation.
  static List<(List<math.Point<double>>, List<math.Point<double>>)>
      overlappingVolumePairs(PlanObject a, PlanObject b) {
    final results = <(List<math.Point<double>>, List<math.Point<double>>)>[];
    for (final partA in _collisionParts(a)) {
      for (final partB in _collisionParts(b)) {
        if (_volumesOverlap(partA, partB)) {
          results.add((partA.outline, partB.outline));
        }
      }
    }
    return results;
  }

  static bool _volumesOverlap(_CollisionVolume a, _CollisionVolume b) =>
      a.bottomMm < b.topMm - 3 && b.bottomMm < a.topMm - 3 &&
      _overlap(a.outline, b.outline);

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
      final av = _collisionParts(a);
      for (var j = i + 1; j < objects.length; j++) {
        final b = objects[j];
        if (a.elevationMm >= b.elevationMm + b.heightMm ||
            b.elevationMm >= a.elevationMm + a.heightMm) {
          continue;
        }
        final bv = _collisionParts(b);
        if (av.any((one) => bv.any((two) =>
            _volumesOverlap(one, two)))) {
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
          if (_collisionParts(object).any((part) =>
              part.topMm > 0 && part.bottomMm < opening.heightMm &&
              _polygonsOverlap(sector, part.outline))) {
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
    // Door-to-door sweep overlap: identical 2D sectors are only a conflict
    // when the real vertical spans overlap as well.
    final allDoors = <({PlanWall wall, WallOpening door})>[];
    for (final wall in floor.walls) {
      if (wall.demolition || wall.projectLayer == ProjectLayer.demolition) continue;
      for (final door in wall.openings) {
        if (door.type == OpeningType.door) allDoors.add((wall: wall, door: door));
      }
    }
    for (var i = 0; i < allDoors.length; i++) {
      final a = allDoors[i];
      final sectorA = doorSwingZone(floor, a.wall, a.door);
      if (sectorA.length < 3) continue;
      for (var j = i + 1; j < allDoors.length; j++) {
        final b = allDoors[j];
        if (a.wall.id == b.wall.id &&
            a.door.id == b.door.id) continue;
        final bottomA = a.door.sillHeightMm, topA = bottomA + a.door.heightMm;
        final bottomB = b.door.sillHeightMm, topB = bottomB + b.door.heightMm;
        if (topA <= bottomB || topB <= bottomA) continue;
        final sectorB = doorSwingZone(floor, b.wall, b.door);
        if (sectorB.length < 3 || !_polygonsOverlap(sectorA, sectorB)) continue;
        final ca = sectorA.first, cb = sectorB.first;
        issues.add(SpaceIssue(
          'Зоны открывания двух дверей пересекаются',
          kind: SpaceIssueKind.doorDoor,
          position: math.Point<double>((ca.x + cb.x) / 2, (ca.y + cb.y) / 2),
        ));
      }
    }
    return issues;
  }
}

class _CollisionVolume {
  const _CollisionVolume(this.outline, this.bottomMm, this.topMm);
  final List<math.Point<double>> outline;
  final double bottomMm;
  final double topMm;
}
