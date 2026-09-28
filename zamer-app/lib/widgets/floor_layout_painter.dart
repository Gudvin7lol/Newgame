import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/layout_service.dart';
import '../services/floor_continuity_service.dart';

enum FloorLayoutKind { laminate, underlay, tile }

class FloorLayoutPainter extends CustomPainter {
  FloorLayoutPainter({
    required this.face,
    required this.settings,
    required this.kind,
    this.selectedFaces,
    this.worldAnchor,
    this.floor,
  });

  final RoomFace face;
  final RoomMaterialSettings settings;
  final FloorLayoutKind kind;
  final List<RoomFace>? selectedFaces;
  final math.Point<double>? worldAnchor;
  final FloorPlan? floor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF6F7F9),
    );
    final roomPolygons = (selectedFaces ?? [face])
        .map(LayoutService.finishPolygon)
        .where((points) => points.length >= 3)
        .toList();
    final polygons = <List<math.Point<double>>>[
      ...roomPolygons,
      if (floor != null)
        ...FloorContinuityService.doorThresholds(
          floor!,
          selectedFaces ?? [face],
        ),
    ];
    if (polygons.isEmpty) return;
    final all = polygons.expand((points) => points).toList();

    var minX = all.first.x;
    var maxX = minX;
    var minY = all.first.y;
    var maxY = minY;
    for (final p in all.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final modelW = math.max(1.0, maxX - minX);
    final modelH = math.max(1.0, maxY - minY);
    final scale = math.min(
      (size.width - 36) / modelW,
      (size.height - 36) / modelH,
    );
    final origin = Offset(
      (size.width - modelW * scale) / 2 - minX * scale,
      (size.height - modelH * scale) / 2 - minY * scale,
    );
    Offset map(math.Point<double> p) =>
        origin + Offset(p.x * scale, p.y * scale);

    final paths = <Path>[];
    for (final polygon in polygons) {
      final path = Path()..moveTo(map(polygon.first).dx, map(polygon.first).dy);
      for (final p in polygon.skip(1)) {
        final q = map(p);
        path.lineTo(q.dx, q.dy);
      }
      path.close();
      paths.add(path);
    }
    // Merge the doorway with the rooms before clipping and outlining. An
    // outline on each polygon creates a visible seam across the threshold.
    var surface = paths.first;
    for (final path in paths.skip(1)) {
      surface = Path.combine(PathOperation.union, surface, path);
    }
    canvas.drawPath(surface, Paint()..color = Colors.white);
    // One anchor in floor coordinates keeps the pattern phase continuous
    // across selected rooms, including when their previews are inspected.
    final center = map(worldAnchor ?? face.centroid);
    final direction = kind == FloorLayoutKind.tile
        ? LayoutService.tileDirection(settings)
        : settings.floorDirectionDeg;
    for (final path in [surface]) {
      canvas.save();
      canvas.clipPath(path);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(direction * math.pi / 180);
      switch (kind) {
        case FloorLayoutKind.laminate:
          _drawLaminate(canvas, size, scale);
          break;
        case FloorLayoutKind.underlay:
          _drawUnderlay(canvas, size, scale);
          break;
        case FloorLayoutKind.tile:
          _drawTile(canvas, size, scale);
          break;
      }
      canvas.restore();
    }
    canvas.drawPath(
      surface,
      Paint()
        ..color = const Color(0xFF28313A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Edge cuts are shown below the drawing; labels on a small plan overlap.
  }

  void _drawLaminate(Canvas canvas, Size size, double scale) {
    if (settings.laminatePattern == 'herringbone') {
      _drawHerringbone(canvas, size, scale);
      return;
    }
    final plankW = math.max(0.5, settings.laminatePlankWidthMm * scale);
    final plankL = math.max(0.5, settings.laminatePlankLengthMm * scale);
    final offX =
        (settings.laminateOffsetXMm % settings.laminatePlankLengthMm) * scale;
    final offY =
        (settings.laminateOffsetYMm % settings.laminatePlankWidthMm) * scale;
    final paint = Paint()
      ..color = const Color(0xFF98A4AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final fill = Paint()..color = const Color(0xFFE5E1DA);
    final clip = canvas.getLocalClipBounds().inflate(math.max(plankL, plankW));
    for (
      double y = ((clip.top - offY) / plankW).floor() * plankW + offY;
      y < clip.bottom;
      y += plankW
    ) {
      final row = ((y - offY) / plankW).round();
      double rowOffset = 0;
      if (settings.laminateOffsetMode == 'half')
        rowOffset = row.isOdd ? plankL / 2 : 0;
      if (settings.laminateOffsetMode == 'third')
        rowOffset = (row % 3) * plankL / 3;
      for (
        double x =
            ((clip.left - offX - rowOffset) / plankL).floor() * plankL +
            offX +
            rowOffset;
        x < clip.right;
        x += plankL
      ) {
        final r = Rect.fromLTWH(x, y, plankL, plankW);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, paint);
      }
    }
  }

  void _drawHerringbone(Canvas canvas, Size size, double scale) {
    final boardL = math.max(0.5, settings.laminatePlankLengthMm * scale);
    final boardW = math.max(0.5, settings.laminatePlankWidthMm * scale);
    final offX =
        (settings.laminateOffsetXMm % settings.laminatePlankLengthMm) * scale;
    final offY =
        (settings.laminateOffsetYMm % settings.laminatePlankWidthMm) * scale;
    final clip = canvas.getLocalClipBounds().inflate(boardL + boardW);
    final outline = Paint()
      ..color = const Color(0xFF9B9286)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.72;
    final fillA = Paint()..color = const Color(0xFFE4DDD2);
    final fillB = Paint()..color = const Color(0xFFDDD5C9);

    // Continuous mitred chevrons. Parallel zigzag boundaries are exactly one
    // plank width apart, so the pattern fills the room with no intersections.
    final run = boardL / math.sqrt2;
    final pitch = boardW * math.sqrt2;
    final firstRow = ((clip.top - run - offY) / pitch).floor();
    final lastRow = ((clip.bottom - offY) / pitch).ceil();
    final firstColumn = ((clip.left - offX) / (2 * run)).floor() * 2;
    final lastColumn = ((clip.right - offX) / run).ceil();
    for (var row = firstRow; row <= lastRow; row++) {
      final y = row * pitch + offY;
      for (var column = firstColumn; column <= lastColumn; column++) {
        final x = column * run + offX;
        final y0 = y + (column.isOdd ? run : 0);
        final y1 = y + (column.isOdd ? 0 : run);
        final board = Path()
          ..moveTo(x, y0)
          ..lineTo(x + run, y1)
          ..lineTo(x + run, y1 + pitch)
          ..lineTo(x, y0 + pitch)
          ..close();
        canvas.drawPath(board, column.isOdd ? fillA : fillB);
        canvas.drawPath(board, outline);
      }
    }
  }

  void _drawUnderlay(Canvas canvas, Size size, double scale) {
    final clip = canvas.getLocalClipBounds();
    final moduleX = settings.underlayMode == 'sheet'
        ? settings.underlaySheetWidthMm
        : settings.underlayRollWidthMm;
    final moduleY = settings.underlayMode == 'sheet'
        ? settings.underlaySheetHeightMm
        : settings.underlayRollWidthMm;
    final offX = (settings.underlayOffsetXMm % moduleX) * scale;
    final offY = (settings.underlayOffsetYMm % moduleY) * scale;
    final p1 = Paint()..color = const Color(0xFFE7F0EC);
    final p2 = Paint()..color = const Color(0xFFD9E7E0);
    final line = Paint()
      ..color = const Color(0xFF7A9085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (settings.underlayMode == 'sheet') {
      final sw = math.max(0.5, settings.underlaySheetWidthMm * scale);
      final sh = math.max(0.5, settings.underlaySheetHeightMm * scale);
      for (
        double y = ((clip.top - offY) / sh).floor() * sh + offY;
        y < clip.bottom;
        y += sh
      ) {
        final row = ((y - offY) / sh).round();
        var col = 0;
        final rowShift = row.isOdd ? sw / 2 : 0.0;
        for (
          double x =
              ((clip.left - offX - rowShift) / sw).floor() * sw +
              offX +
              rowShift;
          x < clip.right;
          x += sw
        ) {
          final r = Rect.fromLTWH(x, y, sw, sh);
          canvas.drawRect(r, (row + col).isEven ? p1 : p2);
          canvas.drawRect(r, line);
          col++;
        }
      }
      return;
    }
    final rollW = math.max(0.5, settings.underlayRollWidthMm * scale);
    var i = 0;
    for (
      double x = ((clip.left - offX) / rollW).floor() * rollW + offX;
      x < clip.right;
      x += rollW
    ) {
      final r = Rect.fromLTWH(x, clip.top, rollW, clip.height);
      canvas.drawRect(r, i.isEven ? p1 : p2);
      canvas.drawLine(Offset(x, clip.top), Offset(x, clip.bottom), line);
      i++;
    }
  }

  void _drawTile(Canvas canvas, Size size, double scale) {
    final tw = math.max(0.5, settings.tileWidthMm * scale);
    final th = math.max(0.5, settings.tileHeightMm * scale);
    final offsetX = (settings.tileOffsetXMm % settings.tileWidthMm) * scale;
    final offsetY = (settings.tileOffsetYMm % settings.tileHeightMm) * scale;
    final clip = canvas.getLocalClipBounds().inflate(math.max(tw, th));
    final stroke = Paint()
      ..color = const Color(0xFF8E99A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..color = const Color(0xFFF1F2F4);
    for (
      double y = ((clip.top - offsetY) / th).floor() * th + offsetY;
      y < clip.bottom;
      y += th
    ) {
      final row = ((y - offsetY) / th).round();
      final rowOffset = settings.tilePattern == 'half' && row.isOdd
          ? tw / 2
          : 0.0;
      for (
        double x =
            ((clip.left - offsetX - rowOffset) / tw).floor() * tw +
            offsetX +
            rowOffset;
        x < clip.right;
        x += tw
      ) {
        final r = Rect.fromLTWH(x, y, tw, th);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, stroke);
      }
    }
  }

  void _drawCutBadges(Canvas canvas, Rect bounds, TileCutSummary cuts) {
    void badge(String text, Offset center) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF38414B),
            backgroundColor: Color(0xEEFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    badge(
      '${cuts.leftMm.round()} мм',
      Offset(bounds.left + 32, bounds.center.dy),
    );
    badge(
      '${cuts.rightMm.round()} мм',
      Offset(bounds.right - 32, bounds.center.dy),
    );
    badge(
      '${cuts.topMm.round()} мм',
      Offset(bounds.center.dx, bounds.top + 16),
    );
    badge(
      '${cuts.bottomMm.round()} мм',
      Offset(bounds.center.dx, bounds.bottom - 16),
    );
  }

  @override
  bool shouldRepaint(covariant FloorLayoutPainter oldDelegate) => true;
}
