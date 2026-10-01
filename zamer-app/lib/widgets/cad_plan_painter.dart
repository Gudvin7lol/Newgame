import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';

/// Rich 2D renderer used by the UI KIT 02 Measure workspace.
/// It deliberately favors a legible interior-plan look over the older
/// engineering-only preview: room finishes, openings, furniture and labels are
/// all visible in the same canvas.
class CadPlanPainter extends CustomPainter {
  CadPlanPainter({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedWallId,
    this.showGrid = true,
    this.showDimensions = true,
    Set<ProjectLayer>? visibleLayers,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet();

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final bool showGrid;
  final bool showDimensions;
  final Set<ProjectLayer> visibleLayers;

  Offset _p(PlanNode n) => origin + Offset(n.xMm * mmToPx, n.yMm * mmToPx);
  Offset _q(math.Point<double> n) =>
      origin + Offset(n.x * mmToPx, n.y * mmToPx);

  @override
  void paint(Canvas canvas, Size size) {
    _background(canvas, size);
    final faces = GeometryService.roomFaces(floor);
    _rooms(canvas, faces);
    _walls(canvas);
    _objects(canvas);
    _roomLabels(canvas, faces);
    if (showDimensions) _outerDimensions(canvas);
  }

  void _background(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ZamerColors.background);
    if (!showGrid) return;
    final minor = 250 * mmToPx;
    final major = 1000 * mmToPx;
    if (minor < 10) return;
    final minorPaint = Paint()
      ..color = const Color(0xFF15313A).withValues(alpha: .42)
      ..strokeWidth = .55;
    final majorPaint = Paint()
      ..color = const Color(0xFF1E3A43).withValues(alpha: .62)
      ..strokeWidth = .8;
    for (double x = origin.dx % minor; x < size.width; x += minor) {
      final isMajor = ((x - origin.dx) / major).abs() % 1 < .02;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }
    for (double y = origin.dy % minor; y < size.height; y += minor) {
      final isMajor = ((y - origin.dy) / major).abs() % 1 < .02;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  RoomMeta? _metaFor(RoomFace face) {
    for (final meta in floor.roomMetas) {
      if (meta.faceKey == face.key) return meta;
    }
    return null;
  }

  void _rooms(Canvas canvas, List<RoomFace> faces) {
    for (final face in faces) {
      if (face.innerPolygon.length < 3) continue;
      final path = Path();
      final first = _q(face.innerPolygon.first);
      path.moveTo(first.dx, first.dy);
      for (final point in face.innerPolygon.skip(1)) {
        final p = _q(point);
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      final meta = _metaFor(face);
      final preset = meta == null
          ? null
          : MaterialCatalog.byId(meta.materials.floorMaterialId);
      final base = preset?.color ?? const Color(0xFF6B5B4B);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(base, const Color(0xFF182126), .30)!,
      );
      _finishPattern(canvas, path.getBounds(), preset?.pattern ?? 'solid', base);
      canvas.restore();
    }
  }

  void _finishPattern(Canvas canvas, Rect bounds, String pattern, Color base) {
    final stroke = Paint()
      ..color = Color.lerp(base, Colors.black, .45)!.withValues(alpha: .34)
      ..strokeWidth = .8;
    if (pattern == 'wood') {
      final boardH = math.max(9.0, 190 * mmToPx);
      final boardW = math.max(36.0, 1200 * mmToPx);
      var row = 0;
      for (double y = bounds.top - boardH; y < bounds.bottom + boardH; y += boardH) {
        canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), stroke);
        final shift = row.isEven ? 0.0 : boardW / 2;
        for (double x = bounds.left - boardW + shift;
            x < bounds.right + boardW;
            x += boardW) {
          canvas.drawLine(Offset(x, y), Offset(x, y + boardH), stroke);
        }
        row++;
      }
    } else if (pattern == 'tile') {
      final tile = math.max(24.0, 600 * mmToPx);
      for (double x = bounds.left; x < bounds.right; x += tile) {
        canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), stroke);
      }
      for (double y = bounds.top; y < bounds.bottom; y += tile) {
        canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), stroke);
      }
    }
  }

  void _walls(Canvas canvas) {
    for (final wall in floor.walls) {
      final layer = wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
      if (!visibleLayers.contains(layer) || wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pa = _p(a);
      final pb = _p(b);
      final width = math.max(3.5, wall.thicknessMm * mmToPx);
      final selected = wall.id == selectedWallId;
      final color = wall.demolition || wall.projectLayer == ProjectLayer.demolition
          ? ZamerColors.danger
          : selected
              ? ZamerColors.accent
              : wall.projectLayer == ProjectLayer.proposed
                  ? ZamerColors.success
                  : const Color(0xFFF1F2F0);
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.square,
      );
      _openings(canvas, wall, pa, pb, width);
    }
  }

  void _openings(
    Canvas canvas,
    PlanWall wall,
    Offset a,
    Offset b,
    double wallWidth,
  ) {
    final length = floor.wallLengthMm(wall);
    if (length <= 0) return;
    final v = b - a;
    final d = v.distance;
    if (d < 1) return;
    final unit = v / d;
    final normal = Offset(-unit.dy, unit.dx);

    for (final opening in wall.openings) {
      final startT = (opening.offsetFromStartMm / length).clamp(0.0, 1.0);
      final endT = ((opening.offsetFromStartMm + opening.widthMm) / length)
          .clamp(0.0, 1.0);
      final p1 = a + v * startT;
      final p2 = a + v * endT;
      final gap = Paint()
        ..color = ZamerColors.background
        ..strokeWidth = wallWidth + 4
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(p1, p2, gap);

      if (opening.type == OpeningType.window) {
        final blue = Paint()
          ..color = const Color(0xFF28A8FF)
          ..strokeWidth = math.max(2.0, wallWidth * .22)
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(p1 + normal * wallWidth * .20, p2 + normal * wallWidth * .20, blue);
        canvas.drawLine(p1 - normal * wallWidth * .20, p2 - normal * wallWidth * .20, blue);
      } else {
        final hinge = p1;
        final widthPx = (p2 - p1).distance;
        final side = opening.doorSwing == DoorSwing.leftOut ||
                opening.doorSwing == DoorSwing.rightOut
            ? -1.0
            : 1.0;
        final leaf = hinge + normal * widthPx * side;
        final doorPaint = Paint()
          ..color = const Color(0xFFE9E8E3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15;
        canvas.drawLine(hinge, leaf, doorPaint);
        final angle = math.atan2(unit.dy, unit.dx);
        final startAngle = side > 0 ? angle - math.pi / 2 : angle;
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: widthPx),
          startAngle,
          math.pi / 2,
          false,
          doorPaint,
        );
      }
    }
  }

  void _objects(Canvas canvas) {
    for (final object in floor.planObjects) {
      if (!visibleLayers.contains(object.layer) || object.elevationMm > 1200) continue;
      _object(canvas, object);
    }
  }

  void _object(Canvas canvas, PlanObject o) {
    final c = origin + Offset(o.xMm * mmToPx, o.yMm * mmToPx);
    final w = math.max(8.0, o.widthMm * mmToPx);
    final d = math.max(8.0, o.depthMm * mmToPx);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: d);
    final fill = Paint()..color = const Color(0xFFB79271).withValues(alpha: .78);
    final pale = Paint()..color = const Color(0xFFD7D3C9).withValues(alpha: .88);
    final dark = Paint()..color = const Color(0xFF657078).withValues(alpha: .72);
    final stroke = Paint()
      ..color = const Color(0xFFEAE8E3).withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(o.rotationDeg * math.pi / 180);
    final id = o.catalogId;

    if (id.startsWith('bed-')) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), pale);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), stroke);
      final pillowW = w * .32;
      final pillowH = d * .16;
      for (final x in [-w * .38, w * .06]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, -d * .42, pillowW, pillowH),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFF0ECE4),
        );
      }
      canvas.drawLine(Offset(-w / 2, -d * .26), Offset(w / 2, -d * .26), stroke);
    } else if (id.startsWith('sofa-')) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(math.min(w, d) * .12));
      canvas.drawRRect(rr, pale);
      canvas.drawRRect(rr, stroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * .43, -d * .40, w * .86, d * .18),
          const Radius.circular(2),
        ),
        dark,
      );
      final seats = id == 'sofa-2' ? 2 : 3;
      for (var i = 1; i < seats; i++) {
        final x = -w * .4 + w * .8 * i / seats;
        canvas.drawLine(Offset(x, -d * .16), Offset(x, d * .38), stroke);
      }
    } else if (id == 'table-round') {
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
      canvas.drawCircle(Offset.zero, math.min(w, d) * .07, stroke);
    } else if (id == 'table-rect') {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), stroke);
    } else if (id == 'chair') {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), pale);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), stroke);
      canvas.drawLine(Offset(-w / 2, -d * .27), Offset(w / 2, -d * .27), stroke);
    } else if (id.startsWith('wardrobe-') ||
        id.startsWith('kitchen-') ||
        id == 'fridge') {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      final divisions = id == 'wardrobe-3' ? 3 : (id.startsWith('wardrobe') ? 2 : 1);
      for (var i = 1; i < divisions; i++) {
        final x = -w / 2 + w * i / divisions;
        canvas.drawLine(Offset(x, -d / 2), Offset(x, d / 2), stroke);
      }
      if (id == 'kitchen-sink') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w * .62, height: d * .55),
            const Radius.circular(2),
          ),
          dark,
        );
      }
      if (id == 'kitchen-oven') {
        for (final dx in [-.24, .24]) {
          for (final dy in [-.22, .22]) {
            canvas.drawCircle(Offset(w * dx, d * dy), math.min(w, d) * .08, dark);
          }
        }
      }
    } else if (id == 'toilet') {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, d * .10), width: w * .72, height: d * .66),
        pale,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, d * .10), width: w * .72, height: d * .66),
        stroke,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -d * .34), width: w * .72, height: d * .22),
        pale,
      );
    } else if (id == 'sink') {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .9, height: d * .8),
        pale,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .9, height: d * .8),
        stroke,
      );
      canvas.drawCircle(Offset(0, -d * .12), math.min(w, d) * .05, dark);
    } else if (id == 'shower') {
      canvas.drawRect(r, Paint()..color = const Color(0xFF8A969A).withValues(alpha: .38));
      canvas.drawRect(r, stroke);
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: w * .84, height: d * .84),
        0,
        math.pi / 2,
        false,
        stroke,
      );
      canvas.drawCircle(Offset(-w * .27, -d * .27), math.min(w, d) * .05, stroke);
    } else if (id == 'tv') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1)),
        dark,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1)), stroke);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), stroke);
    }
    canvas.restore();
  }

  void _roomLabels(Canvas canvas, List<RoomFace> faces) {
    for (final face in faces) {
      final meta = _metaFor(face);
      final c = _q(face.centroid);
      final title = meta?.name.isNotEmpty == true ? meta!.name : 'Помещение';
      final lines = ['$title', '${face.areaM2.toStringAsFixed(1)} м²'];
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${lines[0]}\n',
              style: const TextStyle(
                color: Color(0xFF1B1E20),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            TextSpan(
              text: lines[1],
              style: const TextStyle(
                color: Color(0xFF242729),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      final box = Rect.fromCenter(
        center: c,
        width: painter.width + 12,
        height: painter.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()..color = const Color(0xFFEAE7E0).withValues(alpha: .86),
      );
      painter.paint(canvas, Offset(c.dx - painter.width / 2, c.dy - painter.height / 2));
    }
  }

  void _outerDimensions(Canvas canvas) {
    for (final wall in floor.walls) {
      if (wall.type != WallType.exterior || wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pa = _p(a);
      final pb = _p(b);
      final v = pb - pa;
      final d = v.distance;
      if (d < 26) continue;
      final unit = v / d;
      final normal = Offset(-unit.dy, unit.dx);
      final offset = 14.0 + wall.thicknessMm * mmToPx / 2;
      final p1 = pa - normal * offset;
      final p2 = pb - normal * offset;
      final paint = Paint()
        ..color = const Color(0xFFE5E5DF).withValues(alpha: .88)
        ..strokeWidth = .8;
      canvas.drawLine(p1, p2, paint);
      canvas.drawLine(p1 - normal * 4, p1 + normal * 4, paint);
      canvas.drawLine(p2 - normal * 4, p2 + normal * 4, paint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${floor.wallLengthMm(wall).round()}',
          style: const TextStyle(
            color: Color(0xFFF2F2ED),
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final mid = (p1 + p2) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: mid, width: tp.width + 8, height: tp.height + 4),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF071218).withValues(alpha: .92),
      );
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CadPlanPainter oldDelegate) =>
      oldDelegate.floor != floor ||
      oldDelegate.selectedWallId != selectedWallId ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showDimensions != showDimensions ||
      oldDelegate.visibleLayers != visibleLayers;
}
