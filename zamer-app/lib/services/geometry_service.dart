import 'dart:math' as math;

import '../models/models.dart';

enum NodeSnapKind { none, node, wall, ortho, angle45, alignX, alignY, grid }

extension NodeSnapKindLabel on NodeSnapKind {
  String get label => switch (this) {
    NodeSnapKind.none => 'Без привязки',
    NodeSnapKind.node => 'Узел',
    NodeSnapKind.wall => 'Стена',
    NodeSnapKind.ortho => '90°',
    NodeSnapKind.angle45 => '45°',
    NodeSnapKind.alignX => 'По вертикали',
    NodeSnapKind.alignY => 'По горизонтали',
    NodeSnapKind.grid => 'Сетка',
  };
}

class NodeSnapResult {
  const NodeSnapResult({
    required this.point,
    required this.kind,
    this.targetNodeId,
    this.targetWallId,
    this.distanceMm = 0,
  });

  final math.Point<double> point;
  final NodeSnapKind kind;
  final String? targetNodeId;
  final String? targetWallId;
  final double distanceMm;

  String get label => kind.label;
}

class GeometryService {
  static String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}';

  static double distance(PlanNode a, PlanNode b) {
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns the full logical length of the wall run that is actually
  /// opposite [start] in the room being measured.
  ///
  /// The search prefers walls from the same room face, checks which side of
  /// the new wall contains that room, and heavily penalizes parallel fragments
  /// that do not cross the perpendicular through the active corner. This is
  /// important for L-shaped plans where a nearer wall in the neighbouring wing
  /// used to win simply because it was physically closer.
  static double? parallelReferenceLength(
    FloorPlan floor,
    PlanNode start,
    double angle, {
    double angleToleranceDeg = 4,
    double minDistanceMm = 150,
    double maxDistanceMm = 8000,
  }) {
    final tolerance = angleToleranceDeg * math.pi / 180;
    final directionX = math.cos(angle);
    final directionY = math.sin(angle);
    final normalX = -directionY;
    final normalY = directionX;

    double wallAngle(PlanWall wall) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) return double.nan;
      return math.atan2(b.yMm - a.yMm, b.xMm - a.xMm);
    }

    double angleDiff(double a, double b) {
      var d = (a - b).abs() % math.pi;
      d = math.min(d, math.pi - d);
      return d;
    }

    double projectionGap(double a, double b) {
      final lo = math.min(a, b);
      final hi = math.max(a, b);
      if (lo <= 0 && hi >= 0) return 0;
      return math.min(lo.abs(), hi.abs());
    }

    bool corridorInside(RoomFace room, double normalDistance, double along) {
      if (room.innerPolygon.length < 3) return true;
      for (final t in const <double>[0.28, 0.5, 0.72]) {
        final point = math.Point<double>(
          start.xMm + directionX * along + normalX * normalDistance * t,
          start.yMm + directionY * along + normalY * normalDistance * t,
        );
        if (!_pointInPolygon(point, room.innerPolygon)) return false;
      }
      return true;
    }

    ({PlanWall wall, RoomFace? room, double score})? best;
    final faces = roomFaces(floor);
    final adjacentRooms = faces
        .where((room) => room.nodeIds.contains(start.id))
        .toList();

    void considerWalls(Iterable<PlanWall> walls, RoomFace? room) {
      final roomSide = room == null
          ? 0.0
          : (room.centroid.x - start.xMm) * normalX +
                (room.centroid.y - start.yMm) * normalY;

      for (final wall in walls) {
        if (wall.startNodeId == start.id ||
            wall.endNodeId == start.id ||
            wall.isCurved) {
          continue;
        }
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a == null || b == null) continue;

        final wa = wallAngle(wall);
        if (!wa.isFinite || angleDiff(wa, angle) > tolerance) continue;

        final dx = b.xMm - a.xMm;
        final dy = b.yMm - a.yMm;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 100) continue;

        final signedNormalA =
            (a.xMm - start.xMm) * normalX +
            (a.yMm - start.yMm) * normalY;
        final signedNormalB =
            (b.xMm - start.xMm) * normalX +
            (b.yMm - start.yMm) * normalY;
        final signedNormal = (signedNormalA + signedNormalB) / 2;
        final distanceMm = signedNormal.abs();
        if (distanceMm < minDistanceMm || distanceMm > maxDistanceMm) {
          continue;
        }

        if (room != null &&
            roomSide.abs() > 40 &&
            signedNormal * roomSide <= 0) {
          continue;
        }

        final alongA =
            (a.xMm - start.xMm) * directionX +
            (a.yMm - start.yMm) * directionY;
        final alongB =
            (b.xMm - start.xMm) * directionX +
            (b.yMm - start.yMm) * directionY;
        final gap = projectionGap(alongA, alongB);
        final lo = math.min(alongA, alongB);
        final hi = math.max(alongA, alongB);
        // The new wall is drawn in the positive [direction] from the active
        // corner. A candidate that only extends behind that corner is not the
        // wall the user is looking at.
        if (hi < 80) continue;

        var corridorAlong = 0.0.clamp(lo, hi).toDouble();
        // Move the room-interior probe away from the wall centre-line at the
        // corner. Otherwise a perfectly valid opposite wall can be rejected
        // because the clear-room polygon is inset by half the wall thickness.
        const interiorProbeMm = 240.0;
        if (lo <= interiorProbeMm && hi >= interiorProbeMm) {
          corridorAlong = interiorProbeMm;
        }

        if (room != null &&
            !corridorInside(room, signedNormal, corridorAlong)) {
          continue;
        }

        final score = distanceMm + gap * 4.0;
        if (best == null || score < best!.score) {
          best = (wall: wall, room: room, score: score);
        }
      }
    }

    if (adjacentRooms.isNotEmpty) {
      for (final room in adjacentRooms) {
        final ids = room.edges.map((edge) => edge.wallId).toSet();
        considerWalls(floor.walls.where((wall) => ids.contains(wall.id)), room);
      }
    }

    if (best == null) {
      considerWalls(floor.walls, null);
    }
    if (best == null) return null;

    final bestSeed = best!.wall;
    final selectedRoomIds = best!.room == null
        ? null
        : best!.room!.edges.map((edge) => edge.wallId).toSet();
    final seedA = floor.nodeById(bestSeed.startNodeId);
    final seedB = floor.nodeById(bestSeed.endNodeId);
    if (seedA == null || seedB == null) return floor.wallLengthMm(bestSeed);

    final sx = seedB.xMm - seedA.xMm;
    final sy = seedB.yMm - seedA.yMm;
    final sl = math.sqrt(sx * sx + sy * sy);
    if (sl < 1) return floor.wallLengthMm(bestSeed);
    final seedAngle = wallAngle(bestSeed);

    bool sameLogicalLine(PlanWall wall) {
      if (selectedRoomIds != null && !selectedRoomIds.contains(wall.id)) {
        return false;
      }
      if (wall.isCurved || angleDiff(wallAngle(wall), seedAngle) > tolerance) {
        return false;
      }
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) return false;
      final mx = (a.xMm + b.xMm) / 2;
      final my = (a.yMm + b.yMm) / 2;
      final lineDist =
          ((mx - seedA.xMm) * sy - (my - seedA.yMm) * sx).abs() / sl;
      return lineDist <= math.max(35.0, wall.thicknessMm * 0.45);
    }

    final byNode = <String, List<PlanWall>>{};
    for (final wall in floor.walls) {
      if (!sameLogicalLine(wall)) continue;
      byNode.putIfAbsent(wall.startNodeId, () => []).add(wall);
      byNode.putIfAbsent(wall.endNodeId, () => []).add(wall);
    }

    final queue = <PlanWall>[bestSeed];
    final seen = <String>{};
    var total = 0.0;
    while (queue.isNotEmpty) {
      final wall = queue.removeLast();
      if (!seen.add(wall.id)) continue;
      total += floor.wallLengthMm(wall);
      for (final nodeId in [wall.startNodeId, wall.endNodeId]) {
        for (final next in byNode[nodeId] ?? const <PlanWall>[]) {
          if (!seen.contains(next.id)) queue.add(next);
        }
      }
    }
    return total > 0 ? total : floor.wallLengthMm(bestSeed);
  }

  static bool _pointInPolygon(
    math.Point<double> point,
    List<math.Point<double>> polygon,
  ) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final dy = b.y - a.y;
      final safeDy = dy.abs() < 0.000001 ? 0.000001 : dy;
      final crosses =
          ((a.y > point.y) != (b.y > point.y)) &&
          (point.x < (b.x - a.x) * (point.y - a.y) / safeDy + a.x);
      if (crosses) inside = !inside;
    }
    return inside;
  }

  static PlanNode? nearestNode(
    FloorPlan floor,
    math.Point<double> p, {
    double thresholdMm = 120,
  }) {
    PlanNode? best;
    var bestD = thresholdMm;
    for (final n in floor.nodes) {
      final d = math.sqrt(math.pow(n.xMm - p.x, 2) + math.pow(n.yMm - p.y, 2));
      if (d < bestD) {
        best = n;
        bestD = d;
      }
    }
    return best;
  }

  static WallProjection? nearestWallProjection(
    FloorPlan floor,
    math.Point<double> p, {
    double thresholdMm = 120,
  }) {
    WallProjection? best;
    var bestD = thresholdMm;
    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pr = _projectPointToSegment(
        p,
        math.Point(a.xMm, a.yMm),
        math.Point(b.xMm, b.yMm),
      );
      if (pr.distanceMm < bestD) {
        bestD = pr.distanceMm;
        best = WallProjection(
          wall: wall,
          point: pr.point,
          t: pr.t,
          distanceMm: pr.distanceMm,
        );
      }
    }
    return best;
  }

  static PlanNode ensureAnchor(FloorPlan floor, math.Point<double> p) {
    final node = nearestNode(floor, p);
    if (node != null) return node;
    final wallHit = nearestWallProjection(floor, p);
    if (wallHit != null && wallHit.t > 0.02 && wallHit.t < 0.98) {
      return _splitWallAt(floor, wallHit.wall, wallHit.t, wallHit.point);
    }
    final created = PlanNode(
      id: _id('n'),
      xMm: _round5(p.x),
      yMm: _round5(p.y),
    );
    floor.nodes.add(created);
    return created;
  }

  static PlanNode addArcWallFromNode(
    FloorPlan floor, {
    required String startNodeId,
    required math.Point<double> endPoint,
    required double sagittaMm,
    required WallType type,
    required double thicknessMm,
    required WallMaterial material,
  }) {
    final start = floor.nodeById(startNodeId);
    if (start == null) throw StateError('Start node not found');
    final p0 = math.Point<double>(start.xMm, start.yMm);
    final p1 = endPoint;
    final dx = p1.x - p0.x;
    final dy = p1.y - p0.y;
    final chord = math.sqrt(dx * dx + dy * dy);
    final h = sagittaMm;
    if (chord < 50 || h.abs() < 1) {
      return addWallFromNode(
        floor,
        startNodeId: startNodeId,
        endPoint: endPoint,
        type: type,
        thicknessMm: thicknessMm,
        material: material,
      );
    }

    final absH = h.abs();
    final radius = chord * chord / (8 * absH) + absH / 2;
    final mid = math.Point<double>((p0.x + p1.x) / 2, (p0.y + p1.y) / 2);
    final nx = -dy / chord;
    final ny = dx / chord;
    final sign = h >= 0 ? 1.0 : -1.0;
    final center = math.Point<double>(
      mid.x - nx * sign * (radius - absH),
      mid.y - ny * sign * (radius - absH),
    );
    final desiredMid = math.Point<double>(mid.x + nx * h, mid.y + ny * h);
    final a0 = math.atan2(p0.y - center.y, p0.x - center.x);
    final a1 = math.atan2(p1.y - center.y, p1.x - center.x);
    double shortDelta = a1 - a0;
    while (shortDelta <= -math.pi) shortDelta += math.pi * 2;
    while (shortDelta > math.pi) shortDelta -= math.pi * 2;
    final longDelta = shortDelta > 0
        ? shortDelta - math.pi * 2
        : shortDelta + math.pi * 2;

    math.Point<double> midFor(double delta) {
      final a = a0 + delta / 2;
      return math.Point(
        center.x + math.cos(a) * radius,
        center.y + math.sin(a) * radius,
      );
    }

    final dShort = _pointDistance(midFor(shortDelta), desiredMid);
    final dLong = _pointDistance(midFor(longDelta), desiredMid);
    final delta = dShort <= dLong ? shortDelta : longDelta;
    final arcLen = radius * delta.abs();
    final segments = (arcLen / 80).ceil().clamp(8, 160);

    final groupId = _id('arc');
    var currentId = startNodeId;
    PlanNode current = start;
    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      final a = a0 + delta * t;
      final target = i == segments
          ? endPoint
          : math.Point<double>(
              center.x + math.cos(a) * radius,
              center.y + math.sin(a) * radius,
            );
      final fromNode = floor.nodeById(currentId);
      final beforeIds = floor.walls.map((w) => w.id).toSet();
      current = addWallFromNode(
        floor,
        startNodeId: currentId,
        endPoint: target,
        type: type,
        thicknessMm: thicknessMm,
        material: material,
      );
      if (fromNode != null) {
        final segA = math.Point<double>(fromNode.xMm, fromNode.yMm);
        final segB = math.Point<double>(current.xMm, current.yMm);
        for (final wall in floor.walls.where(
          (w) => !beforeIds.contains(w.id),
        )) {
          final wa = floor.nodeById(wall.startNodeId);
          final wb = floor.nodeById(wall.endNodeId);
          if (wa == null || wb == null) continue;
          final pa = _projectPointToSegment(
            math.Point<double>(wa.xMm, wa.yMm),
            segA,
            segB,
          );
          final pb = _projectPointToSegment(
            math.Point<double>(wb.xMm, wb.yMm),
            segA,
            segB,
          );
          if (pa.distanceMm <= 8 && pb.distanceMm <= 8) {
            wall.curveGroupId = groupId;
            wall.curveRadiusMm = radius;
            wall.curveSagittaMm = h;
            wall.curveArcLengthMm = arcLen;
          }
        }
      }
      currentId = current.id;
    }
    return current;
  }

  static PlanNode addWallFromNode(
    FloorPlan floor, {
    required String startNodeId,
    required math.Point<double> endPoint,
    required WallType type,
    required double thicknessMm,
    required WallMaterial material,
  }) {
    final start = floor.nodeById(startNodeId);
    if (start == null) throw StateError('Start node not found');

    final targetNear = nearestNode(floor, endPoint, thresholdMm: 80);
    late final PlanNode end;
    if (targetNear != null) {
      end = targetNear;
    } else {
      final wallHit = nearestWallProjection(floor, endPoint, thresholdMm: 80);
      if (wallHit != null && wallHit.t > 0.02 && wallHit.t < 0.98) {
        end = _splitWallAt(floor, wallHit.wall, wallHit.t, wallHit.point);
      } else {
        end = PlanNode(
          id: _id('n'),
          xMm: _round5(endPoint.x),
          yMm: _round5(endPoint.y),
        );
        floor.nodes.add(end);
      }
    }

    final p0 = math.Point<double>(start.xMm, start.yMm);
    final p1 = math.Point<double>(end.xMm, end.yMm);
    final newLen = _pointDistance(p0, p1);
    if (newLen < 20) return end;

    final hitsByWall = <String, List<_IntersectionHit>>{};
    final newCutPoints = <_NewCut>[_NewCut(0, start), _NewCut(1, end)];

    for (final wall in List<PlanWall>.from(floor.walls)) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final hit = _segmentIntersection(
        p0,
        p1,
        math.Point(a.xMm, a.yMm),
        math.Point(b.xMm, b.yMm),
      );
      if (hit == null) continue;
      if (hit.tNew <= 0.0005 || hit.tNew >= 0.9995) continue;
      if (hit.tWall <= 0.0005 || hit.tWall >= 0.9995) {
        final existingNode = hit.tWall <= 0.5 ? a : b;
        newCutPoints.add(_NewCut(hit.tNew, existingNode));
        continue;
      }
      hitsByWall.putIfAbsent(wall.id, () => []).add(hit);
    }

    for (final entry in hitsByWall.entries) {
      final wall = floor.wallById(entry.key);
      if (wall == null) continue;
      final hits = entry.value..sort((a, b) => a.tWall.compareTo(b.tWall));
      final splitNodes = _splitWallAtMany(floor, wall, hits);
      for (var i = 0; i < hits.length; i++) {
        newCutPoints.add(_NewCut(hits[i].tNew, splitNodes[i]));
      }
    }

    newCutPoints.sort((a, b) => a.t.compareTo(b.t));
    final compact = <_NewCut>[];
    for (final cut in newCutPoints) {
      if (compact.isEmpty || (cut.t - compact.last.t).abs() > 0.0005) {
        compact.add(cut);
      } else if (compact.last.node.id != cut.node.id) {
        compact[compact.length - 1] = cut;
      }
    }

    for (var i = 0; i < compact.length - 1; i++) {
      final a = compact[i].node;
      final b = compact[i + 1].node;
      if (a.id == b.id || distance(a, b) < 20) continue;
      if (_wallExists(floor, a.id, b.id)) continue;
      floor.walls.add(
        PlanWall(
          id: _id('w'),
          startNodeId: a.id,
          endNodeId: b.id,
          type: type,
          thicknessMm: thicknessMm,
          material: material,
        ),
      );
    }

    return compact.last.node;
  }

  static bool _wallExists(FloorPlan floor, String a, String b) {
    for (final w in floor.walls) {
      if ((w.startNodeId == a && w.endNodeId == b) ||
          (w.startNodeId == b && w.endNodeId == a))
        return true;
    }
    return false;
  }

  static PlanNode _splitWallAt(
    FloorPlan floor,
    PlanWall wall,
    double t,
    math.Point<double> point,
  ) {
    final existing = nearestNode(floor, point, thresholdMm: 25);
    if (existing != null) return existing;
    final hit = _IntersectionHit(point: point, tNew: 0, tWall: t);
    return _splitWallAtMany(floor, wall, [hit]).first;
  }

  static List<PlanNode> _splitWallAtMany(
    FloorPlan floor,
    PlanWall wall,
    List<_IntersectionHit> hits,
  ) {
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) return [];
    final wallLength = floor.wallLengthMm(wall);
    if (wallLength <= 0) return [];

    final sorted = List<_IntersectionHit>.from(hits)
      ..sort((a, b) => a.tWall.compareTo(b.tWall));
    final nodes = <PlanNode>[];
    for (final hit in sorted) {
      final near = nearestNode(floor, hit.point, thresholdMm: 25);
      if (near != null) {
        nodes.add(near);
      } else {
        final n = PlanNode(
          id: _id('n'),
          xMm: _round5(hit.point.x),
          yMm: _round5(hit.point.y),
        );
        floor.nodes.add(n);
        nodes.add(n);
      }
    }

    final chain = <PlanNode>[start, ...nodes, end];
    final breakDistances = <double>[0];
    for (final h in sorted) {
      breakDistances.add(
        (h.tWall * wallLength).clamp(0.0, wallLength).toDouble(),
      );
    }
    breakDistances.add(wallLength);

    floor.walls.removeWhere((w) => w.id == wall.id);
    for (var i = 0; i < chain.length - 1; i++) {
      final a = chain[i];
      final b = chain[i + 1];
      if (a.id == b.id || distance(a, b) < 20) continue;
      final segment = wall.copyWith(
        id: _id('w'),
        startNodeId: a.id,
        endNodeId: b.id,
      );
      segment.openings.clear();
      final d0 = breakDistances[i];
      final d1 = breakDistances[i + 1];
      for (final opening in wall.openings) {
        final center = opening.offsetFromStartMm + opening.widthMm / 2;
        if (center >= d0 - 1 && center <= d1 + 1) {
          final copy = WallOpening.fromJson(opening.toJson());
          copy.offsetFromStartMm = (opening.offsetFromStartMm - d0)
              .clamp(0, math.max(0, d1 - d0 - opening.widthMm))
              .toDouble();
          segment.openings.add(copy);
        }
      }
      floor.walls.add(segment);
    }
    return nodes;
  }

  static NodeSnapResult snapMoveTarget(
    FloorPlan floor, {
    required String movingNodeId,
    required math.Point<double> raw,
    bool enabled = true,
    double angleStepRadians = math.pi / 2,
    double nodeThresholdMm = 140,
    double wallThresholdMm = 100,
    double guideThresholdMm = 80,
    double gridMm = 10,
  }) {
    final moving = floor.nodeById(movingNodeId);
    if (moving == null || !enabled) {
      return NodeSnapResult(point: raw, kind: NodeSnapKind.none);
    }

    PlanNode? nearest;
    var nearestDistance = nodeThresholdMm;
    for (final node in floor.nodes) {
      if (node.id == movingNodeId) continue;
      final d = _pointDistance(raw, math.Point(node.xMm, node.yMm));
      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = node;
      }
    }
    if (nearest != null) {
      return NodeSnapResult(
        point: math.Point(nearest.xMm, nearest.yMm),
        kind: NodeSnapKind.node,
        targetNodeId: nearest.id,
        distanceMm: nearestDistance,
      );
    }

    WallProjection? wallSnap;
    var wallDistance = wallThresholdMm;
    for (final wall in floor.walls) {
      if (wall.startNodeId == movingNodeId || wall.endNodeId == movingNodeId)
        continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pr = _projectPointToSegment(
        raw,
        math.Point(a.xMm, a.yMm),
        math.Point(b.xMm, b.yMm),
      );
      if (pr.t <= 0.015 || pr.t >= 0.985) continue;
      if (pr.distanceMm < wallDistance) {
        wallDistance = pr.distanceMm;
        wallSnap = WallProjection(
          wall: wall,
          point: pr.point,
          t: pr.t,
          distanceMm: pr.distanceMm,
        );
      }
    }
    if (wallSnap != null) {
      return NodeSnapResult(
        point: wallSnap.point,
        kind: NodeSnapKind.wall,
        targetWallId: wallSnap.wall.id,
        distanceMm: wallSnap.distanceMm,
      );
    }

    NodeSnapResult? angular;
    var angularDistance = guideThresholdMm;
    if (angleStepRadians > 0) {
      final neighborIds = <String>{};
      for (final wall in floor.walls) {
        if (wall.startNodeId == movingNodeId) neighborIds.add(wall.endNodeId);
        if (wall.endNodeId == movingNodeId) neighborIds.add(wall.startNodeId);
      }
      final directionCount = math.max(1, (math.pi / angleStepRadians).round());
      for (final id in neighborIds) {
        final anchor = floor.nodeById(id);
        if (anchor == null) continue;
        final ap = math.Point<double>(anchor.xMm, anchor.yMm);
        for (var i = 0; i < directionCount; i++) {
          final angle = i * angleStepRadians;
          final ux = math.cos(angle);
          final uy = math.sin(angle);
          final vx = raw.x - ap.x;
          final vy = raw.y - ap.y;
          final t = vx * ux + vy * uy;
          final candidate = math.Point(ap.x + ux * t, ap.y + uy * t);
          final d = _pointDistance(raw, candidate);
          if (d < angularDistance) {
            angularDistance = d;
            angular = NodeSnapResult(
              point: candidate,
              kind: (angleStepRadians - math.pi / 4).abs() < 0.001
                  ? NodeSnapKind.angle45
                  : NodeSnapKind.ortho,
              distanceMm: d,
            );
          }
        }
      }
    }
    if (angular != null) return angular;

    NodeSnapResult? aligned;
    var alignDistance = math.min(guideThresholdMm, 65.0);
    for (final node in floor.nodes) {
      if (node.id == movingNodeId) continue;
      final dx = (raw.x - node.xMm).abs();
      if (dx < alignDistance) {
        alignDistance = dx;
        aligned = NodeSnapResult(
          point: math.Point(node.xMm, raw.y),
          kind: NodeSnapKind.alignX,
          distanceMm: dx,
        );
      }
      final dy = (raw.y - node.yMm).abs();
      if (dy < alignDistance) {
        alignDistance = dy;
        aligned = NodeSnapResult(
          point: math.Point(raw.x, node.yMm),
          kind: NodeSnapKind.alignY,
          distanceMm: dy,
        );
      }
    }
    if (aligned != null) return aligned;

    if (gridMm > 0) {
      final snapped = math.Point<double>(
        (raw.x / gridMm).round() * gridMm.toDouble(),
        (raw.y / gridMm).round() * gridMm.toDouble(),
      );
      return NodeSnapResult(
        point: snapped,
        kind: NodeSnapKind.grid,
        distanceMm: _pointDistance(raw, snapped),
      );
    }
    return NodeSnapResult(point: raw, kind: NodeSnapKind.none);
  }

  static PlanNode? finalizeNodeMove(
    FloorPlan floor, {
    required String movingNodeId,
    required NodeSnapResult snap,
  }) {
    var moving = floor.nodeById(movingNodeId);
    if (moving == null) return null;
    moving.xMm = _round5(snap.point.x);
    moving.yMm = _round5(snap.point.y);

    if (snap.targetNodeId != null && snap.targetNodeId != movingNodeId) {
      final target = floor.nodeById(snap.targetNodeId!);
      if (target != null) {
        _mergeNodeInto(floor, moving.id, target.id);
        moving = target;
      }
    } else if (snap.targetWallId != null) {
      final wall = floor.wallById(snap.targetWallId!);
      if (wall != null &&
          wall.startNodeId != moving.id &&
          wall.endNodeId != moving.id) {
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a != null && b != null) {
          final pr = _projectPointToSegment(
            math.Point(moving.xMm, moving.yMm),
            math.Point(a.xMm, a.yMm),
            math.Point(b.xMm, b.yMm),
          );
          moving.xMm = _round5(pr.point.x);
          moving.yMm = _round5(pr.point.y);
          if (pr.t > 0.001 && pr.t < 0.999) {
            _splitWallAtMany(floor, wall, [
              _IntersectionHit(
                point: math.Point(moving.xMm, moving.yMm),
                tNew: 0,
                tWall: pr.t,
              ),
            ]);
          }
        }
      }
    }

    normalizeIntersections(floor);
    _cleanupTopology(floor);
    return floor.nodeById(moving.id) ?? moving;
  }

  static void normalizeIntersections(FloorPlan floor) {
    for (var guard = 0; guard < 200; guard++) {
      final walls = List<PlanWall>.from(floor.walls);
      var changed = false;
      outer:
      for (var i = 0; i < walls.length; i++) {
        final w1 = floor.wallById(walls[i].id);
        if (w1 == null) continue;
        final a1 = floor.nodeById(w1.startNodeId);
        final b1 = floor.nodeById(w1.endNodeId);
        if (a1 == null || b1 == null) continue;
        for (var j = i + 1; j < walls.length; j++) {
          final w2 = floor.wallById(walls[j].id);
          if (w2 == null) continue;
          if (w1.startNodeId == w2.startNodeId ||
              w1.startNodeId == w2.endNodeId ||
              w1.endNodeId == w2.startNodeId ||
              w1.endNodeId == w2.endNodeId)
            continue;
          final a2 = floor.nodeById(w2.startNodeId);
          final b2 = floor.nodeById(w2.endNodeId);
          if (a2 == null || b2 == null) continue;
          final hit = _segmentIntersection(
            math.Point(a1.xMm, a1.yMm),
            math.Point(b1.xMm, b1.yMm),
            math.Point(a2.xMm, a2.yMm),
            math.Point(b2.xMm, b2.yMm),
          );
          if (hit == null) continue;
          final interior1 = hit.tNew > 0.001 && hit.tNew < 0.999;
          final interior2 = hit.tWall > 0.001 && hit.tWall < 0.999;
          if (!interior1 && !interior2) continue;

          PlanNode junction;
          if (!interior1) {
            junction = hit.tNew <= 0.5 ? a1 : b1;
          } else if (!interior2) {
            junction = hit.tWall <= 0.5 ? a2 : b2;
          } else {
            junction =
                nearestNode(floor, hit.point, thresholdMm: 20) ??
                PlanNode(
                  id: _id('n'),
                  xMm: _round5(hit.point.x),
                  yMm: _round5(hit.point.y),
                );
            if (floor.nodeById(junction.id) == null) floor.nodes.add(junction);
          }

          if (interior1) {
            _splitWallAtMany(floor, w1, [
              _IntersectionHit(
                point: math.Point(junction.xMm, junction.yMm),
                tNew: 0,
                tWall: hit.tNew,
              ),
            ]);
          }
          final liveW2 = floor.wallById(w2.id);
          if (interior2 && liveW2 != null) {
            _splitWallAtMany(floor, liveW2, [
              _IntersectionHit(
                point: math.Point(junction.xMm, junction.yMm),
                tNew: 0,
                tWall: hit.tWall,
              ),
            ]);
          }
          changed = true;
          break outer;
        }
      }
      if (!changed) break;
    }
  }

  static void _mergeNodeInto(
    FloorPlan floor,
    String sourceId,
    String targetId,
  ) {
    if (sourceId == targetId) return;
    for (final wall in floor.walls) {
      if (wall.startNodeId == sourceId) wall.startNodeId = targetId;
      if (wall.endNodeId == sourceId) wall.endNodeId = targetId;
    }
    for (final measure in floor.measures) {
      if (measure.startNodeId == sourceId) measure.startNodeId = targetId;
      if (measure.endNodeId == sourceId) measure.endNodeId = targetId;
    }
    floor.nodes.removeWhere((n) => n.id == sourceId);
    _cleanupTopology(floor);
  }

  static void _cleanupTopology(FloorPlan floor) {
    floor.walls.removeWhere((w) {
      if (w.startNodeId == w.endNodeId) return true;
      final a = floor.nodeById(w.startNodeId);
      final b = floor.nodeById(w.endNodeId);
      return a == null || b == null || distance(a, b) < 10;
    });

    final seen = <String, PlanWall>{};
    final duplicates = <PlanWall>[];
    for (final wall in floor.walls) {
      final a = wall.startNodeId.compareTo(wall.endNodeId) <= 0
          ? wall.startNodeId
          : wall.endNodeId;
      final b = a == wall.startNodeId ? wall.endNodeId : wall.startNodeId;
      final key = '$a|$b';
      final first = seen[key];
      if (first == null) {
        seen[key] = wall;
      } else {
        for (final opening in wall.openings) {
          if (!first.openings.any((o) => o.id == opening.id)) {
            first.openings.add(WallOpening.fromJson(opening.toJson()));
          }
        }
        duplicates.add(wall);
      }
    }
    for (final wall in duplicates) {
      floor.walls.removeWhere((w) => w.id == wall.id);
    }

    for (final wall in floor.walls) {
      final len = floor.wallLengthMm(wall);
      for (final opening in wall.openings) {
        if (len <= 0) continue;
        if (opening.widthMm > len) opening.widthMm = len;
        final maxOffset = math.max(0.0, len - opening.widthMm);
        opening.offsetFromStartMm = opening.offsetFromStartMm
            .clamp(0.0, maxOffset)
            .toDouble();
      }
    }

    floor.measures.removeWhere(
      (m) =>
          m.startNodeId == m.endNodeId ||
          floor.nodeById(m.startNodeId) == null ||
          floor.nodeById(m.endNodeId) == null,
    );
    _removeOrphanNodes(floor);
  }

  static void removeWall(FloorPlan floor, String wallId) {
    floor.walls.removeWhere((w) => w.id == wallId);
    _removeOrphanNodes(floor);
  }

  static void _removeOrphanNodes(FloorPlan floor) {
    final used = <String>{};
    for (final w in floor.walls) {
      used.add(w.startNodeId);
      used.add(w.endNodeId);
    }
    for (final m in floor.measures) {
      used.add(m.startNodeId);
      used.add(m.endNodeId);
    }
    floor.nodes.removeWhere((n) => !used.contains(n.id));
  }

  static void inferLegacyArcGroups(FloorPlan floor) {
    final assigned = <String>{
      for (final w in floor.walls.where((w) => w.isCurved)) w.id,
    };
    final candidates = floor.walls
        .where((w) => !assigned.contains(w.id) && floor.wallLengthMm(w) <= 380)
        .toList();
    final byNode = <String, List<PlanWall>>{};
    for (final w in candidates) {
      byNode.putIfAbsent(w.startNodeId, () => []).add(w);
      byNode.putIfAbsent(w.endNodeId, () => []).add(w);
    }
    final visited = <String>{};

    for (final seed in candidates) {
      if (visited.contains(seed.id)) continue;
      final component = <PlanWall>[];
      final queue = <PlanWall>[seed];
      visited.add(seed.id);
      while (queue.isNotEmpty) {
        final w = queue.removeLast();
        component.add(w);
        for (final nodeId in [w.startNodeId, w.endNodeId]) {
          for (final next in (byNode[nodeId] ?? const <PlanWall>[])) {
            if (visited.contains(next.id)) continue;
            if (next.type != seed.type ||
                (next.thicknessMm - seed.thicknessMm).abs() >= 1 ||
                next.material != seed.material)
              continue;
            visited.add(next.id);
            queue.add(next);
          }
        }
      }
      if (component.length < 4) continue;

      final compByNode = <String, List<PlanWall>>{};
      for (final w in component) {
        compByNode.putIfAbsent(w.startNodeId, () => []).add(w);
        compByNode.putIfAbsent(w.endNodeId, () => []).add(w);
      }
      if (compByNode.values.any((v) => v.length > 2)) continue;
      final endpoints = compByNode.entries
          .where((e) => e.value.length == 1)
          .map((e) => e.key)
          .toList();
      if (endpoints.length != 2) continue;

      final orderedPoints = <math.Point<double>>[];
      final orderedWalls = <PlanWall>[];
      var nodeId = endpoints.first;
      final firstNode = floor.nodeById(nodeId);
      if (firstNode == null) continue;
      orderedPoints.add(math.Point(firstNode.xMm, firstNode.yMm));
      final used = <String>{};
      for (var guard = 0; guard < component.length + 1; guard++) {
        PlanWall? next;
        for (final c in compByNode[nodeId] ?? const <PlanWall>[]) {
          if (!used.contains(c.id)) {
            next = c;
            break;
          }
        }
        if (next == null) break;
        used.add(next.id);
        orderedWalls.add(next);
        nodeId = next.startNodeId == nodeId ? next.endNodeId : next.startNodeId;
        final n = floor.nodeById(nodeId);
        if (n == null) break;
        orderedPoints.add(math.Point(n.xMm, n.yMm));
      }
      if (orderedWalls.length != component.length || orderedPoints.length < 5)
        continue;

      final turns = <double>[];
      for (var i = 1; i < orderedPoints.length - 1; i++) {
        final a = orderedPoints[i - 1];
        final b = orderedPoints[i];
        final c = orderedPoints[i + 1];
        final v1x = b.x - a.x;
        final v1y = b.y - a.y;
        final v2x = c.x - b.x;
        final v2y = c.y - b.y;
        var d = math.atan2(v1x * v2y - v1y * v2x, v1x * v2x + v1y * v2y);
        if (d.abs() > math.pi / 180) turns.add(d);
      }
      if (turns.length < 3) continue;
      final sign = turns.first.sign;
      if (turns.any((t) => t.sign != sign || t.abs() > math.pi / 5)) continue;

      final mid = orderedPoints[orderedPoints.length ~/ 2];
      final fit = _circleThrough(orderedPoints.first, mid, orderedPoints.last);
      if (fit == null || !fit.radius.isFinite || fit.radius < 100) continue;
      final groupId = 'legacy-arc-${seed.id}';
      final arcLength = component.fold<double>(
        0,
        (sum, w) => sum + floor.wallLengthMm(w),
      );
      for (final wall in component) {
        wall.curveGroupId = groupId;
        wall.curveRadiusMm = fit.radius;
        wall.curveArcLengthMm = arcLength;
      }
    }
  }

  static _CircleFit? _circleThrough(
    math.Point<double> a,
    math.Point<double> b,
    math.Point<double> c,
  ) {
    final d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
    if (d.abs() < 1e-6) return null;
    final a2 = a.x * a.x + a.y * a.y;
    final b2 = b.x * b.x + b.y * b.y;
    final c2 = c.x * c.x + c.y * c.y;
    final ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d;
    final uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d;
    final center = math.Point<double>(ux, uy);
    return _CircleFit(center, _pointDistance(center, a));
  }

  static List<ElevationRun> elevationRuns(FloorPlan floor, RoomFace face) {
    inferLegacyArcGroups(floor);
    if (face.edges.isEmpty) return const [];
    final groups = <ElevationRun>[];
    var current = <FaceEdge>[];
    String? currentCurve;

    void flush() {
      if (current.isEmpty) return;
      final firstWall = floor.wallById(current.first.wallId);
      final curved = currentCurve != null;
      final length = current.fold<double>(0, (sum, edge) {
        final inside = wallFaceLengthMm(face, edge);
        final wall = floor.wallById(edge.wallId);
        return sum +
            (inside > 0
                ? inside
                : wall == null
                ? 0
                : floor.wallLengthMm(wall));
      });
      groups.add(
        ElevationRun(
          id: curved ? currentCurve! : current.first.wallId,
          edges: List<FaceEdge>.from(current),
          lengthMm: length,
          isCurved: curved,
          radiusMm: firstWall?.curveRadiusMm,
        ),
      );
      current = <FaceEdge>[];
      currentCurve = null;
    }

    for (final edge in face.edges) {
      final wall = floor.wallById(edge.wallId);
      final curve = wall?.curveGroupId;
      if (curve != null) {
        if (current.isNotEmpty && currentCurve != curve) flush();
        currentCurve = curve;
        current.add(edge);
      } else {
        flush();
        current.add(edge);
        flush();
      }
    }
    flush();

    if (groups.length > 1 &&
        groups.first.isCurved &&
        groups.last.isCurved &&
        groups.first.id == groups.last.id) {
      final mergedEdges = [...groups.last.edges, ...groups.first.edges];
      final merged = ElevationRun(
        id: groups.first.id,
        edges: mergedEdges,
        lengthMm: groups.first.lengthMm + groups.last.lengthMm,
        isCurved: true,
        radiusMm: groups.first.radiusMm ?? groups.last.radiusMm,
      );
      groups[0] = merged;
      groups.removeLast();
    }
    return groups;
  }

  static List<RoomFace> roomFaces(FloorPlan floor) {
    if (floor.walls.length < 3) return const [];

    // A wall with no alternate route between its ends is a bridge, not a
    // boundary of a room. Remove it from the face graph before walking faces;
    // pruning adjacent reverse half-edges later misses longer dangling chains.
    final connected = <String, List<String>>{};
    for (final wall in floor.walls) {
      connected.putIfAbsent(wall.startNodeId, () => []).add(wall.id);
      connected.putIfAbsent(wall.endNodeId, () => []).add(wall.id);
    }
    final bridges = <String>{};
    for (final wall in floor.walls) {
      final seen = <String>{wall.startNodeId};
      final queue = <String>[wall.startNodeId];
      while (queue.isNotEmpty && !seen.contains(wall.endNodeId)) {
        final node = queue.removeLast();
        for (final id in connected[node] ?? const <String>[]) {
          if (id == wall.id) continue;
          final candidate = floor.wallById(id);
          if (candidate == null) continue;
          final next = candidate.startNodeId == node
              ? candidate.endNodeId
              : candidate.startNodeId;
          if (seen.add(next)) queue.add(next);
        }
      }
      if (!seen.contains(wall.endNodeId)) bridges.add(wall.id);
    }

    final adjacency = <String, List<_HalfEdge>>{};
    for (final wall in floor.walls) {
      if (bridges.contains(wall.id)) continue;
      if (floor.nodeById(wall.startNodeId) == null ||
          floor.nodeById(wall.endNodeId) == null)
        continue;
      adjacency
          .putIfAbsent(wall.startNodeId, () => [])
          .add(_HalfEdge(wall.id, wall.startNodeId, wall.endNodeId));
      adjacency
          .putIfAbsent(wall.endNodeId, () => [])
          .add(_HalfEdge(wall.id, wall.endNodeId, wall.startNodeId));
    }

    final visited = <String>{};
    final faces = <RoomFace>[];

    for (final wall in floor.walls) {
      if (bridges.contains(wall.id)) continue;
      for (final start in [
        _HalfEdge(wall.id, wall.startNodeId, wall.endNodeId),
        _HalfEdge(wall.id, wall.endNodeId, wall.startNodeId),
      ]) {
        if (visited.contains(start.key)) continue;
        final nodes = <String>[];
        final edges = <FaceEdge>[];
        var current = start;
        var closed = false;

        for (var guard = 0; guard < floor.walls.length * 4 + 20; guard++) {
          if (visited.contains(current.key) && current.key != start.key) break;
          visited.add(current.key);
          nodes.add(current.from);
          edges.add(
            FaceEdge(
              wallId: current.wallId,
              fromNodeId: current.from,
              toNodeId: current.to,
            ),
          );

          final fromNode = floor.nodeById(current.from);
          final atNode = floor.nodeById(current.to);
          if (fromNode == null || atNode == null) break;
          final options = adjacency[current.to] ?? const [];
          if (options.isEmpty) break;

          final backAngle = math.atan2(
            fromNode.yMm - atNode.yMm,
            fromNode.xMm - atNode.xMm,
          );
          _HalfEdge? next;
          var bestDelta = -1.0;
          for (final option in options) {
            if (option.to == current.from && options.length > 1) continue;
            final target = floor.nodeById(option.to);
            if (target == null) continue;
            final angle = math.atan2(
              target.yMm - atNode.yMm,
              target.xMm - atNode.xMm,
            );
            final delta = _normalizeAngle(angle - backAngle);
            if (delta > bestDelta) {
              bestDelta = delta;
              next = option;
            }
          }
          if (next == null) break;
          current = next;
          if (current.key == start.key) {
            closed = true;
            break;
          }
        }

        if (!closed || nodes.length < 3) continue;
        // A free-ended partition is a bridge of the wall graph. A face walk
        // visits the bridge in both directions, but it does not bound another
        // room. Keeping its two half-edges in the boundary creates a long,
        // razor-thin notch in the inner offset polygon and in ceiling/floor
        // drawings. The partition remains a wall; only the room boundary is
        // simplified here.
        for (var pass = 0; pass < edges.length / 2; pass++) {
          var removed = false;
          for (var i = 0; i < edges.length; i++) {
            final j = (i + 1) % edges.length;
            final a = edges[i], b = edges[j];
            if (a.wallId != b.wallId ||
                a.fromNodeId != b.toNodeId ||
                a.toNodeId != b.fromNodeId)
              continue;
            edges.removeAt(math.max(i, j));
            edges.removeAt(math.min(i, j));
            removed = true;
            break;
          }
          if (!removed || edges.length < 3) break;
        }
        if (edges.length < 3) continue;
        final boundaryNodes = edges.map((e) => e.fromNodeId).toList();
        final unique = boundaryNodes.toSet();
        if (unique.length < 3) continue;
        final signedArea = _signedAreaNodes(floor, boundaryNodes);
        if (signedArea <= 10000)
          continue; // positive faces are bounded rooms in screen coordinates

        final inner = _innerPolygon(floor, edges);
        if (inner.length < 3) continue;
        final keyParts = edges.map((e) => e.wallId).toList()..sort();
        final key = keyParts.join('|');
        faces.add(
          RoomFace(
            key: key,
            nodeIds: boundaryNodes,
            edges: edges,
            innerPolygon: inner,
            signedAreaMm2: signedArea,
          ),
        );
      }
    }

    faces.sort((a, b) {
      final ca = a.centroid;
      final cb = b.centroid;
      final y = ca.y.compareTo(cb.y);
      return y != 0 ? y : ca.x.compareTo(cb.x);
    });
    return faces;
  }

  static void syncRoomMetadata(FloorPlan floor) {
    final faces = roomFaces(floor);
    final unmatched = <RoomMeta>[...floor.roomMetas];
    final matched = <RoomMeta>[];

    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      RoomMeta? meta;
      for (final candidate in unmatched) {
        if (candidate.faceKey == face.key) {
          meta = candidate;
          break;
        }
      }
      meta ??= _nearestMeta(unmatched, face.centroid, 1200);
      if (meta == null) {
        meta = RoomMeta(
          id: _id('r'),
          faceKey: face.key,
          name: 'Помещение ${i + 1}',
          centroidX: face.centroid.x,
          centroidY: face.centroid.y,
        );
        floor.roomMetas.add(meta);
      } else {
        meta.faceKey = face.key;
        meta.centroidX = face.centroid.x;
        meta.centroidY = face.centroid.y;
        unmatched.remove(meta);
      }
      matched.add(meta);
    }
  }

  static RoomMeta? _nearestMeta(
    List<RoomMeta> metas,
    math.Point<double> p,
    double threshold,
  ) {
    RoomMeta? best;
    var bestD = threshold;
    for (final m in metas) {
      final dx = m.centroidX - p.x;
      final dy = m.centroidY - p.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  static double roomHeightMm(FloorPlan floor, RoomFace face) =>
      floor.roomMetaByKey(face.key)?.ceilingHeightMm ?? floor.defaultHeightMm;

  static double roomGrossWallAreaM2(FloorPlan floor, RoomFace face) {
    final h = roomHeightMm(floor, face) / 1000.0;
    return face.perimeterM * h;
  }

  static double roomOpeningsAreaM2(FloorPlan floor, RoomFace face) {
    var area = 0.0;
    for (final edge in face.edges) {
      final wall = floor.wallById(edge.wallId);
      if (wall == null) continue;
      for (final o in wall.openings) {
        area += o.widthMm * o.heightMm / 1000000.0;
      }
    }
    return area;
  }

  static double roomNetWallAreaM2(FloorPlan floor, RoomFace face) => math.max(
    0.0,
    roomGrossWallAreaM2(floor, face) - roomOpeningsAreaM2(floor, face),
  );

  static double roomSkirtingM(FloorPlan floor, RoomFace face) {
    var doorsM = 0.0;
    for (final edge in face.edges) {
      final wall = floor.wallById(edge.wallId);
      if (wall == null) continue;
      for (final o in wall.openings.where((e) => e.type == OpeningType.door)) {
        doorsM += o.widthMm / 1000.0;
      }
    }
    return math.max(0.0, face.perimeterM - doorsM);
  }

  static List<math.Point<double>> orderedCurvePoints(
    FloorPlan floor,
    String groupId,
  ) {
    inferLegacyArcGroups(floor);
    final walls = floor.walls.where((w) => w.curveGroupId == groupId).toList();
    if (walls.isEmpty) return const [];
    final adjacency = <String, List<PlanWall>>{};
    for (final w in walls) {
      adjacency.putIfAbsent(w.startNodeId, () => []).add(w);
      adjacency.putIfAbsent(w.endNodeId, () => []).add(w);
    }
    String startId = walls.first.startNodeId;
    final endCandidates = adjacency.entries
        .where((e) => e.value.length == 1)
        .map((e) => e.key)
        .toList();
    if (endCandidates.isNotEmpty) startId = endCandidates.first;
    final points = <math.Point<double>>[];
    final used = <String>{};
    var nodeId = startId;
    final firstNode = floor.nodeById(nodeId);
    if (firstNode == null) return const [];
    points.add(math.Point(firstNode.xMm, firstNode.yMm));
    for (var guard = 0; guard < walls.length + 2; guard++) {
      PlanWall? next;
      for (final candidate in (adjacency[nodeId] ?? const <PlanWall>[])) {
        if (!used.contains(candidate.id)) {
          next = candidate;
          break;
        }
      }
      if (next == null) break;
      used.add(next.id);
      nodeId = next.startNodeId == nodeId ? next.endNodeId : next.startNodeId;
      final n = floor.nodeById(nodeId);
      if (n == null) break;
      points.add(math.Point(n.xMm, n.yMm));
    }
    return points;
  }

  static List<math.Point<double>> smoothCurvePoints(
    FloorPlan floor,
    String groupId, {
    double stepMm = 70,
  }) {
    final pts = orderedCurvePoints(floor, groupId);
    if (pts.length < 3) return pts;
    final mid = pts[pts.length ~/ 2];
    final fit = _circleThrough(pts.first, mid, pts.last);
    if (fit == null || !fit.radius.isFinite || fit.radius < 1) return pts;
    final center = fit.center;
    final a0 = math.atan2(pts.first.y - center.y, pts.first.x - center.x);
    final a1 = math.atan2(pts.last.y - center.y, pts.last.x - center.x);
    final am = math.atan2(mid.y - center.y, mid.x - center.x);
    double short = a1 - a0;
    while (short <= -math.pi) short += math.pi * 2;
    while (short > math.pi) short -= math.pi * 2;
    final long = short > 0 ? short - math.pi * 2 : short + math.pi * 2;

    double angularDistance(double a, double b) {
      var d = (a - b).abs() % (math.pi * 2);
      if (d > math.pi) d = math.pi * 2 - d;
      return d;
    }

    double midDistance(double delta) {
      final expected = a0 + delta / 2;
      return angularDistance(expected, am);
    }

    final delta = midDistance(short) <= midDistance(long) ? short : long;
    final arcLen = fit.radius * delta.abs();
    final segments = (arcLen / math.max(25, stepMm))
        .ceil()
        .clamp(8, 220)
        .toInt();
    return List.generate(segments + 1, (i) {
      final a = a0 + delta * (i / segments);
      return math.Point<double>(
        center.x + math.cos(a) * fit.radius,
        center.y + math.sin(a) * fit.radius,
      );
    });
  }

  static double wallFaceLengthMm(RoomFace face, FaceEdge edge) {
    final index = face.edges.indexOf(edge);
    if (index < 0 || face.innerPolygon.length != face.edges.length) return 0;
    final a = face.innerPolygon[index];
    final b = face.innerPolygon[(index + 1) % face.innerPolygon.length];
    return _pointDistance(a, b);
  }

  static double wallFaceStartShiftMm(
    FloorPlan floor,
    RoomFace face,
    FaceEdge edge,
  ) {
    final index = face.edges.indexOf(edge);
    final a = floor.nodeById(edge.fromNodeId);
    final b = floor.nodeById(edge.toNodeId);
    if (index < 0 ||
        a == null ||
        b == null ||
        face.innerPolygon.length != face.edges.length)
      return 0;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return 0;
    final start = face.innerPolygon[index];
    return ((start.x - a.xMm) * dx + (start.y - a.yMm) * dy) / len;
  }

  static double openingOffsetFromFaceStart(
    FloorPlan floor,
    RoomFace face,
    FaceEdge edge,
    WallOpening opening,
  ) {
    final wall = floor.wallById(edge.wallId);
    if (wall == null) return opening.offsetFromStartMm;
    final sameDirection = wall.startNodeId == edge.fromNodeId;
    final wallOffset = sameDirection
        ? opening.offsetFromStartMm
        : floor.wallLengthMm(wall) -
              opening.offsetFromStartMm -
              opening.widthMm;
    return wallOffset - wallFaceStartShiftMm(floor, face, edge);
  }

  static List<math.Point<double>> _innerPolygon(
    FloorPlan floor,
    List<FaceEdge> edges,
  ) {
    if (edges.length < 3) return const [];
    final lines = <_Line>[];
    for (final edge in edges) {
      final a = floor.nodeById(edge.fromNodeId);
      final b = floor.nodeById(edge.toNodeId);
      final wall = floor.wallById(edge.wallId);
      if (a == null || b == null || wall == null) return const [];
      final dx = b.xMm - a.xMm;
      final dy = b.yMm - a.yMm;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) return const [];
      final nx = -dy / len; // right normal in screen coordinates
      final ny = dx / len;
      final off = wall.thicknessMm / 2;
      lines.add(
        _Line(
          math.Point(a.xMm + nx * off, a.yMm + ny * off),
          math.Point(b.xMm + nx * off, b.yMm + ny * off),
        ),
      );
    }

    final polygon = <math.Point<double>>[];
    for (var i = 0; i < lines.length; i++) {
      final prev = lines[(i - 1 + lines.length) % lines.length];
      final cur = lines[i];
      final intersection = _lineIntersection(prev.a, prev.b, cur.a, cur.b);
      final join = math.Point<double>(
        (prev.b.x + cur.a.x) / 2,
        (prev.b.y + cur.a.y) / 2,
      );
      if (intersection != null) {
        // Infinite offset lines can create a very long miter at T-junctions
        // and near-collinear turns. In finish layouts that appears as a sharp
        // triangular bite. Clamp such miters to a bevel around the real join.
        final gap = _pointDistance(prev.b, cur.a);
        final miter = _pointDistance(intersection, join);
        final miterLimit = math.max(350.0, gap * 3.0).toDouble();
        polygon.add(miter > miterLimit ? join : intersection);
      } else {
        polygon.add(join);
      }
    }
    return polygon;
  }

  static double _signedAreaNodes(FloorPlan floor, List<String> nodes) {
    var s = 0.0;
    for (var i = 0; i < nodes.length; i++) {
      final a = floor.nodeById(nodes[i]);
      final b = floor.nodeById(nodes[(i + 1) % nodes.length]);
      if (a == null || b == null) return 0;
      s += a.xMm * b.yMm - b.xMm * a.yMm;
    }
    return s / 2;
  }

  static _Projection _projectPointToSegment(
    math.Point<double> p,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) return _Projection(a, 0, _pointDistance(p, a));
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)
        .clamp(0.0, 1.0)
        .toDouble();
    final point = math.Point(a.x + dx * t, a.y + dy * t);
    return _Projection(point, t, _pointDistance(p, point));
  }

  static _IntersectionHit? _segmentIntersection(
    math.Point<double> p,
    math.Point<double> p2,
    math.Point<double> q,
    math.Point<double> q2,
  ) {
    final rx = p2.x - p.x;
    final ry = p2.y - p.y;
    final sx = q2.x - q.x;
    final sy = q2.y - q.y;
    final denom = _cross(rx, ry, sx, sy);
    if (denom.abs() < 1e-8) return null;
    final qpx = q.x - p.x;
    final qpy = q.y - p.y;
    final t = _cross(qpx, qpy, sx, sy) / denom;
    final u = _cross(qpx, qpy, rx, ry) / denom;
    if (t < -0.0001 || t > 1.0001 || u < -0.0001 || u > 1.0001) return null;
    return _IntersectionHit(
      point: math.Point(p.x + t * rx, p.y + t * ry),
      tNew: t,
      tWall: u,
    );
  }

  static math.Point<double>? _lineIntersection(
    math.Point<double> p,
    math.Point<double> p2,
    math.Point<double> q,
    math.Point<double> q2,
  ) {
    final rx = p2.x - p.x;
    final ry = p2.y - p.y;
    final sx = q2.x - q.x;
    final sy = q2.y - q.y;
    final denom = _cross(rx, ry, sx, sy);
    if (denom.abs() < 1e-8) return null;
    final qpx = q.x - p.x;
    final qpy = q.y - p.y;
    final t = _cross(qpx, qpy, sx, sy) / denom;
    return math.Point(p.x + t * rx, p.y + t * ry);
  }

  static double _cross(double ax, double ay, double bx, double by) =>
      ax * by - ay * bx;
  static double _normalizeAngle(double angle) {
    final twoPi = math.pi * 2;
    var a = angle % twoPi;
    if (a < 0) a += twoPi;
    return a;
  }

  static double _pointDistance(math.Point<double> a, math.Point<double> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _round5(double value) => (value / 5).round() * 5.0;
}

class ElevationRun {
  const ElevationRun({
    required this.id,
    required this.edges,
    required this.lengthMm,
    required this.isCurved,
    this.radiusMm,
  });

  final String id;
  final List<FaceEdge> edges;
  final double lengthMm;
  final bool isCurved;
  final double? radiusMm;

  int get openingCount => edges.length;
}

class _CircleFit {
  const _CircleFit(this.center, this.radius);
  final math.Point<double> center;
  final double radius;
}

class WallProjection {
  const WallProjection({
    required this.wall,
    required this.point,
    required this.t,
    required this.distanceMm,
  });
  final PlanWall wall;
  final math.Point<double> point;
  final double t;
  final double distanceMm;
}

class _Projection {
  const _Projection(this.point, this.t, this.distanceMm);
  final math.Point<double> point;
  final double t;
  final double distanceMm;
}

class _IntersectionHit {
  const _IntersectionHit({
    required this.point,
    required this.tNew,
    required this.tWall,
  });
  final math.Point<double> point;
  final double tNew;
  final double tWall;
}

class _NewCut {
  const _NewCut(this.t, this.node);
  final double t;
  final PlanNode node;
}

class _HalfEdge {
  const _HalfEdge(this.wallId, this.from, this.to);
  final String wallId;
  final String from;
  final String to;
  String get key => '$wallId:$from>$to';
}

class _Line {
  const _Line(this.a, this.b);
  final math.Point<double> a;
  final math.Point<double> b;
}
