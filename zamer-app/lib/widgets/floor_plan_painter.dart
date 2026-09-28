import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';

class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedWallId,
    this.activeNodeId,
    this.showDimensions = true,
    this.showNodes = true,
    this.showRoomLabels = true,
    Set<ProjectLayer>? visibleLayers,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet();

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final String? activeNodeId;
  final bool showDimensions;
  final bool showNodes;
  final bool showRoomLabels;
  final Set<ProjectLayer> visibleLayers;

  Offset p(PlanNode n) => origin + Offset(n.xMm * mmToPx, n.yMm * mmToPx);
  Offset fromPoint(math.Point<double> n) =>
      origin + Offset(n.x * mmToPx, n.y * mmToPx);

  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size);
    final faces = GeometryService.roomFaces(floor);
    _rooms(canvas, faces);
    _walls(canvas);
    _measures(canvas);
    if (showNodes) _nodes(canvas);
    if (showRoomLabels) _labels(canvas, faces);
  }

  void _grid(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEEF1F1),
    );
    final major = 500 * mmToPx;
    if (major < 14) return;
    final majorPaint = Paint()
      ..color = const Color(0xFFDDE3E3)
      ..strokeWidth = 0.7;
    for (double x = origin.dx % major; x < size.width; x += major) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }
    for (double y = origin.dy % major; y < size.height; y += major) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }
  }

  void _rooms(Canvas canvas, List<RoomFace> faces) {
    for (final face in faces) {
      if (face.innerPolygon.length < 3) continue;
      final path = Path()
        ..moveTo(
          fromPoint(face.innerPolygon.first).dx,
          fromPoint(face.innerPolygon.first).dy,
        );
      for (final point in face.innerPolygon.skip(1)) {
        final o = fromPoint(point);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFF7FAFF));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFD8E6FA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _walls(Canvas canvas) {
    final doneCurves = <String>{};
    for (final wall in floor.walls) {
      final layer = wall.demolition
          ? ProjectLayer.demolition
          : wall.projectLayer;
      if (!visibleLayers.contains(layer)) continue;

      if (wall.isCurved) {
        final groupId = wall.curveGroupId!;
        if (!doneCurves.add(groupId)) continue;
        final grouped = floor.walls
            .where((w) => w.curveGroupId == groupId)
            .toList();
        if (grouped.isEmpty) continue;
        final points = GeometryService.smoothCurvePoints(
          floor,
          groupId,
          stepMm: 18,
        );
        if (points.length < 2) continue;
        final selected = grouped.any((w) => w.id == selectedWallId);
        final demolition = grouped.any(
          (w) => w.demolition || w.projectLayer == ProjectLayer.demolition,
        );
        final proposed = grouped.any(
          (w) => w.projectLayer == ProjectLayer.proposed,
        );
        final width = math.max(3.0, grouped.first.thicknessMm * mmToPx);
        final path = Path();
        final q0 = fromPoint(points.first);
        path.moveTo(q0.dx, q0.dy);
        for (final point in points.skip(1)) {
          final q = fromPoint(point);
          path.lineTo(q.dx, q.dy);
        }
        final color = demolition
            ? const Color(0xFFD85B68)
            : selected
            ? const Color(0xFF56D6A3)
            : proposed
            ? const Color(0xFF55B98C)
            : grouped.first.type == WallType.exterior
            ? const Color(0xFF20242A)
            : const Color(0xFF4C5561);
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        if (demolition) {
          final dash = Paint()
            ..color = const Color(0xFFB33B49)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, width * 0.12)
            ..strokeCap = StrokeCap.round;
          for (final metric in path.computeMetrics()) {
            for (double d = 0; d < metric.length; d += 14) {
              canvas.drawPath(
                metric.extractPath(d, math.min(metric.length, d + 7)),
                dash,
              );
            }
          }
        }
        if (showDimensions) _curveDimension(canvas, grouped.first);
        continue;
      }

      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pa = p(a);
      final pb = p(b);
      final selected = wall.id == selectedWallId;
      final width = math.max(3.0, wall.thicknessMm * mmToPx);
      final isDemolition =
          wall.demolition || wall.projectLayer == ProjectLayer.demolition;
      final paint = Paint()
        ..color = isDemolition
            ? const Color(0xFFD85B68)
            : selected
            ? const Color(0xFF56D6A3)
            : wall.projectLayer == ProjectLayer.proposed
            ? const Color(0xFF55B98C)
            : wall.type == WallType.exterior
            ? const Color(0xFF20242A)
            : const Color(0xFF4C5561)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(pa, pb, paint);
      if (isDemolition) {
        final dash = Paint()
          ..color = const Color(0xFFB33B49)
          ..strokeWidth = math.max(1.5, width * 0.12)
          ..strokeCap = StrokeCap.round;
        final v = pb - pa;
        final len = v.distance;
        if (len > 1) {
          final u = v / len;
          for (double d = 4; d < len; d += 14) {
            canvas.drawLine(pa + u * d, pa + u * math.min(len, d + 7), dash);
          }
        }
      }
      _cutOpenings(canvas, wall, pa, pb, width);
      if (showDimensions) {
        _openingDimensions(canvas, wall, pa, pb, width);
        _dimension(canvas, wall, pa, pb, width);
      }
    }
  }

  void _cutOpenings(
    Canvas canvas,
    PlanWall wall,
    Offset pa,
    Offset pb,
    double wallWidth,
  ) {
    final length = floor.wallLengthMm(wall);
    if (length <= 0) return;
    final v = pb - pa;
    for (final opening in wall.openings) {
      final t1 = (opening.offsetFromStartMm / length)
          .clamp(0.0, 1.0)
          .toDouble();
      final t2 = ((opening.offsetFromStartMm + opening.widthMm) / length)
          .clamp(0.0, 1.0)
          .toDouble();
      final o1 = pa + v * t1;
      final o2 = pa + v * t2;
      canvas.drawLine(
        o1,
        o2,
        Paint()
          ..color = const Color(0xFFF5F7FA)
          ..strokeWidth = wallWidth + 3
          ..strokeCap = StrokeCap.square,
      );
      canvas.drawLine(
        o1,
        o2,
        Paint()
          ..color = opening.type == OpeningType.window
              ? const Color(0xFF5B9BFF)
              : const Color(0xFFC89A68)
          ..strokeWidth = math.max(2.0, wallWidth * 0.28)
          ..strokeCap = StrokeCap.square,
      );
    }
  }

  void _openingDimensions(
    Canvas canvas,
    PlanWall wall,
    Offset a,
    Offset b,
    double wallWidth,
  ) {
    if (wall.openings.isEmpty) return;
    final wallLength = floor.wallLengthMm(wall);
    if (wallLength <= 0) return;

    final v = b - a;
    final screenLength = v.distance;
    if (screenLength < 55) return;

    final unit = v / screenLength;
    final normal = Offset(-unit.dy, unit.dx);
    final chainOffset = -(wallWidth / 2 + 15);
    final baseA = a + normal * chainOffset;
    final linePaint = Paint()
      ..color = const Color(0xFF65707A)
      ..strokeWidth = 0.8;
    final tickPaint = Paint()
      ..color = const Color(0xFF65707A)
      ..strokeWidth = 0.8;

    final sorted = wall.openings.toList()
      ..sort((x, y) => x.offsetFromStartMm.compareTo(y.offsetFromStartMm));

    final marks = <double>[0];
    for (final opening in sorted) {
      final start = opening.offsetFromStartMm.clamp(0.0, wallLength).toDouble();
      final end = (opening.offsetFromStartMm + opening.widthMm)
          .clamp(0.0, wallLength)
          .toDouble();
      if ((start - marks.last).abs() > 0.5) marks.add(start);
      if ((end - marks.last).abs() > 0.5) marks.add(end);
    }
    if ((wallLength - marks.last).abs() > 0.5) marks.add(wallLength);

    WallOpening? openingAt(double middle) {
      for (final opening in sorted) {
        final start = opening.offsetFromStartMm;
        final end = start + opening.widthMm;
        if (middle > start + 0.5 && middle < end - 0.5) return opening;
      }
      return null;
    }

    Offset pointAt(double mm) => baseA + unit * (screenLength * mm / wallLength);

    final first = pointAt(marks.first);
    final last = pointAt(marks.last);
    canvas.drawLine(first, last, linePaint);

    for (final mark in marks) {
      final q = pointAt(mark);
      canvas.drawLine(q - normal * 3.2, q + normal * 3.2, tickPaint);
    }

    for (var i = 0; i < marks.length - 1; i++) {
      final from = marks[i];
      final to = marks[i + 1];
      final mm = to - from;
      if (mm < 40) continue;

      final px = screenLength * mm / wallLength;
      final opening = openingAt((from + to) / 2);
      if (px < (opening == null ? 22 : 28)) continue;

      final prefix = opening == null
          ? ''
          : opening.type == OpeningType.window
          ? 'О '
          : 'Д ';
      final tp = TextPainter(
        text: TextSpan(
          text: '$prefix${mm.round()}',
          style: TextStyle(
            color: opening == null
                ? const Color(0xFF46505A)
                : opening.type == OpeningType.window
                ? const Color(0xFF3879CF)
                : const Color(0xFF99662F),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            backgroundColor: const Color(0xEFFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(26.0, px + 12));

      final center = pointAt((from + to) / 2) + normal * -7;
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _dimension(
    Canvas canvas,
    PlanWall wall,
    Offset a,
    Offset b,
    double wallWidth,
  ) {
    final v = b - a;
    final d = v.distance;
    if (d < 35) return;
    final normal = Offset(-v.dy / d, v.dx / d);
    final center = (a + b) / 2 + normal * (wallWidth / 2 + 16);
    final tp = TextPainter(
      text: TextSpan(
        text: '${floor.wallLengthMm(wall).round()}',
        style: const TextStyle(
          color: Color(0xFF242930),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          backgroundColor: Color(0xEEFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _curveDimension(Canvas canvas, PlanWall wall) {
    final groupId = wall.curveGroupId;
    if (groupId == null) return;
    final pts = GeometryService.smoothCurvePoints(floor, groupId, stepMm: 180);
    if (pts.length < 2) return;
    final mid = pts[pts.length ~/ 2];
    final pos = fromPoint(mid);
    final arc =
        wall.curveArcLengthMm ??
        floor.walls
            .where((w) => w.curveGroupId == groupId)
            .fold<double>(0, (s, w) => s + floor.wallLengthMm(w));
    final tp = TextPainter(
      text: TextSpan(
        text: 'дуга ${arc.round()}',
        style: const TextStyle(
          color: Color(0xFF242930),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          backgroundColor: Color(0xEEFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  bool _internalCurveNode(PlanNode node) {
    final connected = floor.walls
        .where((w) => w.startNodeId == node.id || w.endNodeId == node.id)
        .toList();
    if (connected.length != 2) return false;
    final g = connected.first.curveGroupId;
    return g != null && g.isNotEmpty && connected.last.curveGroupId == g;
  }

  void _nodes(Canvas canvas) {
    for (final node in floor.nodes) {
      if (_internalCurveNode(node)) continue;
      final pos = p(node);
      final active = node.id == activeNodeId;
      canvas.drawCircle(
        pos,
        active ? 8 : 6,
        Paint()..color = active ? const Color(0xFF1769E8) : Colors.white,
      );
      canvas.drawCircle(
        pos,
        active ? 8 : 6,
        Paint()
          ..color = const Color(0xFF252A30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  void _labels(Canvas canvas, List<RoomFace> faces) {
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      final meta = floor.roomMetaByKey(face.key);
      final center = fromPoint(face.centroid);
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${meta?.name ?? 'Помещение ${i + 1}'}\n${face.areaM2.toStringAsFixed(2)} м²',
          style: const TextStyle(
            color: Color(0xFF20242A),
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _measures(Canvas canvas) {
    for (final m in floor.measures) {
      final a = floor.nodeById(m.startNodeId);
      final b = floor.nodeById(m.endNodeId);
      if (a == null || b == null) continue;
      final pa = p(a);
      final pb = p(b);
      final calc = GeometryService.distance(a, b);
      final delta = (m.measuredMm - calc).abs();
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = delta <= 5
              ? const Color(0xFF2E9D57)
              : const Color(0xFFE78A22)
          ..strokeWidth = 1.5,
      );
      final c = (pa + pb) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '${m.measuredMm.round()} / Δ${delta.round()}',
          style: const TextStyle(
            color: Color(0xFF2E6B45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            backgroundColor: Color(0xEEFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) => true;
}
