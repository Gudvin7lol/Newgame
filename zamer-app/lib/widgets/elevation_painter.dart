import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../services/object_catalog.dart';

class ElevationPainter extends CustomPainter {
  ElevationPainter({
    required this.floor,
    required this.face,
    required this.run,
    required this.heightMm,
    required this.settings,
  });

  final FloorPlan floor;
  final RoomFace face;
  final ElevationRun run;
  final double heightMm;
  final RoomMaterialSettings settings;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final runLen = run.lengthMm;
    if (runLen <= 0) return;

    // On a narrow phone the inline canvas used to be barely taller than
    // twice the old 52 px margin, shrinking a 2.7 m wall to a tiny square.
    final horizontalMargin = math.min(38.0, size.width * .09);
    final verticalMargin = math.min(34.0, size.height * .12);
    final scale = math.min(
      (size.width - horizontalMargin * 2) / runLen,
      (size.height - verticalMargin * 2) / heightMm,
    );
    final drawW = runLen * scale;
    final drawH = heightMm * scale;
    final left = (size.width - drawW) / 2;
    final top = (size.height - drawH) / 2;
    final rect = Rect.fromLTWH(left, top, drawW, drawH);

    canvas.drawRect(rect, Paint()..color = const Color(0xFFF5F6F8));
    if (settings.wallTileEnabledFor(run.id))
      _drawWallTiles(canvas, rect, scale);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF20242A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final openingSpans = <_ElevationOpeningSpan>[];
    var accumulated = 0.0;
    for (final edge in run.edges) {
      final wall = floor.wallById(edge.wallId);
      if (wall == null) continue;
      final segmentLen = GeometryService.wallFaceLengthMm(face, edge);
      for (final opening in wall.openings) {
        final faceOffset = GeometryService.openingOffsetFromFaceStart(
          floor,
          face,
          edge,
          opening,
        );
        final totalOffset = accumulated + faceOffset;
        openingSpans.add(
          _ElevationOpeningSpan(
            startMm: totalOffset,
            endMm: totalOffset + opening.widthMm,
            type: opening.type,
          ),
        );
        final x = left + totalOffset * scale;
        final w = opening.widthMm * scale;
        final yBottom = rect.bottom - opening.sillHeightMm * scale;
        final h = opening.heightMm * scale;
        final oRect = Rect.fromLTWH(x, yBottom - h, w, h);
        canvas.drawRect(
          oRect,
          Paint()
            ..color = opening.type == OpeningType.window
                ? const Color(0xFFD8E9FF)
                : const Color(0xFFFFE7D2),
        );
        canvas.drawRect(
          oRect,
          Paint()
            ..color = const Color(0xFF59616D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _label(
          canvas,
          opening.type == OpeningType.window
              ? 'Окно\n${opening.widthMm.round()}×${opening.heightMm.round()}'
              : 'Дверь\n${opening.widthMm.round()}×${opening.heightMm.round()}',
          oRect.center,
          11,
        );
      }
      _drawElectricalForEdge(
        canvas,
        rect,
        scale,
        accumulated,
        edge,
        wall,
        segmentLen,
      );
      _drawMountedObjectsForEdge(
        canvas,
        rect,
        scale,
        accumulated,
        edge,
        wall,
      );
      accumulated += segmentLen;
    }

    final wallFinish = MaterialCatalog.byId(
      settings.wallTileEnabledFor(run.id)
          ? settings.wallTileMaterialId
          : settings.wallMaterialId,
    );
    _materialBadge(
      canvas,
      rect.topLeft + const Offset(8, 8),
      wallFinish.name,
      wallFinish.color,
    );
    _drawDimensionChain(canvas, rect, scale, openingSpans, runLen);

    _dimensionLine(
      canvas,
      Offset(left, top - 22),
      Offset(rect.right, top - 22),
      '${runLen.round()} мм${run.isCurved ? ' по дуге' : ''}',
    );
    _dimensionLine(
      canvas,
      Offset(left - 28, top),
      Offset(left - 28, rect.bottom),
      '${heightMm.round()} мм',
      vertical: true,
    );
  }

  void _drawWallTiles(Canvas canvas, Rect rect, double scale) {
    final from = settings.wallTileFromMm.clamp(0, heightMm).toDouble();
    final to = settings.wallTileToMm.clamp(from, heightMm).toDouble();
    if (to <= from) return;
    final topY = rect.bottom - to * scale;
    final bottomY = rect.bottom - from * scale;
    final tileRect = Rect.fromLTRB(rect.left, topY, rect.right, bottomY);
    canvas.save();
    canvas.clipRect(tileRect);
    canvas.drawRect(tileRect, Paint()..color = const Color(0xFFF1F3F5));
    if (settings.wallTileMirroredFor(run.id)) {
      canvas.translate(tileRect.left + tileRect.right, 0);
      canvas.scale(-1, 1);
    }
    final tw = math.max(1.0, settings.wallTileWidthMm * scale);
    final th = math.max(1.0, settings.wallTileHeightMm * scale);
    final offX =
        (settings.wallTileXFor(run.id) % settings.wallTileWidthMm) * scale;
    final offY =
        (settings.wallTileYFor(run.id) % settings.wallTileHeightMm) * scale;
    final stroke = Paint()
      ..color = const Color(0xFFB0B7C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, settings.wallTileGroutMm * scale);
    var row = 0;
    for (
      double y = tileRect.top - th + offY;
      y < tileRect.bottom + th;
      y += th
    ) {
      final rowOffset = settings.wallTilePattern == 'half' && row.isOdd
          ? tw / 2
          : 0.0;
      for (
        double x = tileRect.left - tw + offX + rowOffset;
        x < tileRect.right + tw;
        x += tw
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, tw, th), stroke);
      }
      row++;
    }
    canvas.restore();
    canvas.drawRect(
      tileRect,
      Paint()
        ..color = const Color(0xFF8D98A5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawDimensionChain(
    Canvas canvas,
    Rect rect,
    double scale,
    List<_ElevationOpeningSpan> spans,
    double runLengthMm,
  ) {
    final sorted = [...spans]
      ..sort((a, b) => a.startMm.compareTo(b.startMm));
    var cursor = 0.0;
    final y = rect.bottom + 18;
    for (final span in sorted) {
      final start = span.startMm.clamp(cursor, runLengthMm).toDouble();
      final end = span.endMm.clamp(start, runLengthMm).toDouble();
      if (start - cursor > 1) {
        _dimensionChainSegment(
          canvas,
          rect.left + cursor * scale,
          rect.left + start * scale,
          y,
          '${(start - cursor).round()}',
          false,
        );
      }
      if (end - start > 1) {
        _dimensionChainSegment(
          canvas,
          rect.left + start * scale,
          rect.left + end * scale,
          y,
          '${span.type == OpeningType.window ? 'О' : 'Д'} ${(end - start).round()}',
          true,
        );
      }
      cursor = math.max(cursor, end);
    }
    if (runLengthMm - cursor > 1) {
      _dimensionChainSegment(
        canvas,
        rect.left + cursor * scale,
        rect.right,
        y,
        '${(runLengthMm - cursor).round()}',
        false,
      );
    }
  }

  void _dimensionChainSegment(
    Canvas canvas,
    double x1,
    double x2,
    double y,
    String text,
    bool opening,
  ) {
    final p = Paint()
      ..color = opening ? const Color(0xFF3E8F75) : const Color(0xFF6D7580)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), p);
    canvas.drawLine(Offset(x1, y - 4), Offset(x1, y + 4), p);
    canvas.drawLine(Offset(x2, y - 4), Offset(x2, y + 4), p);
    _dimensionText(canvas, text, Offset((x1 + x2) / 2, y - 7));
  }

  void _materialBadge(Canvas canvas, Offset origin, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF252A30),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    final rect = Rect.fromLTWH(origin.dx, origin.dy, tp.width + 28, tp.height + 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 6, origin.dy + 6, 10, 10),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(origin.dx + 21, origin.dy + 5));
  }

  void _drawMountedObjectsForEdge(
    Canvas canvas,
    Rect rect,
    double scale,
    double accumulated,
    FaceEdge edge,
    PlanWall wall,
  ) {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final wallLength = math.sqrt(dx * dx + dy * dy);
    if (wallLength < 1) return;

    for (final object in floor.planObjects) {
      if (object.catalogId.isEmpty || object.layer == ProjectLayer.demolition) continue;
      final item = ObjectCatalog.byId(object.catalogId);
      if (item.mount != CatalogMount.wall) continue;
      final hit = GeometryService.nearestWallProjection(
        floor,
        math.Point(object.xMm, object.yMm),
        thresholdMm: 500,
      );
      if (hit == null || hit.wall.id != wall.id) continue;
      final t = ((hit.point.x - a.xMm) * dx + (hit.point.y - a.yMm) * dy) /
          (wallLength * wallLength);
      var offset = t.clamp(0.0, 1.0).toDouble() * wallLength;
      if (edge.fromNodeId != wall.startNodeId) offset = wallLength - offset;
      offset -= GeometryService.wallFaceStartShiftMm(floor, face, edge);
      final x = rect.left + (accumulated + offset) * scale;
      final w = math.max(8.0, object.widthMm * scale);
      final h = math.max(8.0, object.heightMm * scale);
      final y = rect.bottom - (object.elevationMm + object.heightMm) * scale;
      final objectRect = Rect.fromLTWH(x - w / 2, y, w, h);
      final isLight = object.type == PlanObjectType.lighting;
      canvas.drawRRect(
        RRect.fromRectAndRadius(objectRect, const Radius.circular(3)),
        Paint()..color = isLight ? const Color(0xFFFFE7A8) : const Color(0xFFE5E8EB),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(objectRect, const Radius.circular(3)),
        Paint()
          ..color = isLight ? const Color(0xFFB67A16) : const Color(0xFF68717D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      _label(canvas, object.label.isEmpty ? item.name : object.label, objectRect.center, 8);
      _dimensionText(
        canvas,
        '${object.elevationMm.round()} мм',
        Offset(objectRect.right + 18, objectRect.bottom),
      );
    }
  }

  void _drawElectricalForEdge(
    Canvas canvas,
    Rect rect,
    double scale,
    double accumulated,
    FaceEdge edge,
    PlanWall wall,
    double segmentLen,
  ) {
    for (final point in floor.electricalPoints) {
      if (point.wallId != wall.id || !point.isWallDevice) continue;
      final insideSide = edge.fromNodeId == wall.startNodeId ? 1 : -1;
      if (point.wallSide != insideSide) continue;
      var offset = point.wallOffsetMm ?? 0;
      if (edge.fromNodeId != wall.startNodeId) {
        offset = floor.wallLengthMm(wall) - offset;
      }
      offset -= GeometryService.wallFaceStartShiftMm(floor, face, edge);
      final x = rect.left + (accumulated + offset) * scale;
      final y =
          rect.bottom - point.heightMm.clamp(0, heightMm).toDouble() * scale;
      _electricalSymbol(canvas, Offset(x, y), point);
      _dimensionText(canvas, '${point.heightMm.round()}', Offset(x + 18, y));
    }
  }

  void _electricalSymbol(Canvas canvas, Offset c, ElectricalPoint p) {
    final stroke = Paint()
      ..color = const Color(0xFFB24D2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    if (p.type == ElectricalPointType.wallLight) {
      canvas.drawCircle(c, 7, fill);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 6),
        -math.pi / 2,
        math.pi,
        false,
        stroke,
      );
      return;
    }
    final count = math.max(1, p.modules.length);
    final w = math.max(18.0, count * 15.0);
    final r = Rect.fromCenter(center: c, width: w, height: 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      stroke,
    );
    final moduleW = w / count;
    for (var i = 1; i < count; i++) {
      final x = r.left + moduleW * i;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), stroke);
    }
    for (var i = 0; i < count; i++) {
      final module = i < p.modules.length
          ? p.modules[i]
          : ElectricalModuleType.socket220;
      final text = switch (module) {
        ElectricalModuleType.socket220 => '○',
        ElectricalModuleType.switch1 => 'S',
        ElectricalModuleType.switch2 => 'S2',
        ElectricalModuleType.tv => 'TV',
        ElectricalModuleType.data => 'RJ',
        ElectricalModuleType.blank => '·',
      };
      final center = Offset(r.left + moduleW * (i + 0.5), c.dy);
      _label(canvas, text, center, text.length > 1 ? 7 : 10);
    }
  }

  void _dimensionLine(
    Canvas canvas,
    Offset a,
    Offset b,
    String text, {
    bool vertical = false,
  }) {
    final p = Paint()
      ..color = const Color(0xFF6D7580)
      ..strokeWidth = 1;
    canvas.drawLine(a, b, p);
    if (vertical) {
      canvas.drawLine(a + const Offset(-5, 0), a + const Offset(5, 0), p);
      canvas.drawLine(b + const Offset(-5, 0), b + const Offset(5, 0), p);
      _dimensionText(
        canvas,
        text,
        (a + b) / 2 + const Offset(-18, 0),
        rotate: true,
      );
    } else {
      canvas.drawLine(a + const Offset(0, -5), a + const Offset(0, 5), p);
      canvas.drawLine(b + const Offset(0, -5), b + const Offset(0, 5), p);
      _dimensionText(canvas, text, (a + b) / 2 + const Offset(0, -10));
    }
  }

  void _dimensionText(
    Canvas canvas,
    String text,
    Offset center, {
    bool rotate = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF3A414A),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotate) canvas.rotate(-math.pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF2A3038),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 130);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant ElevationPainter oldDelegate) => true;
}


class _ElevationOpeningSpan {
  const _ElevationOpeningSpan({
    required this.startMm,
    required this.endMm,
    required this.type,
  });
  final double startMm;
  final double endMm;
  final OpeningType type;
}
