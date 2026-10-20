import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/geometry_service.dart';

/// CAD overlay for the *in-progress* wall, drawn on the same scene as the
/// furniture, materials, walls and electrical routes. Does not change FloorPlan
/// or intercept any pointer gesture.
class WallDraftGuidePainter extends CustomPainter {
  const WallDraftGuidePainter({
    required this.from,
    required this.to,
    required this.mmToPx,
    required this.zoom,
    required this.wallThicknessMm,
    required this.snapKind,
    required this.snapLabel,
    this.facePoint,
    this.oppositeCorner,
    this.drawFaces = true,
  });

  final Offset from;
  final Offset to;
  final double mmToPx;
  final double zoom;
  final double wallThicknessMm;
  final NodeSnapKind snapKind;
  final String snapLabel;
  final Offset? facePoint;
  /// A real, more distant corner on the construction axis. Guide only.
  final Offset? oppositeCorner;
  final bool drawFaces;

  @override
  void paint(Canvas canvas, Size size) {
    final delta = to - from;
    final lengthPx = delta.distance;
    if (!lengthPx.isFinite || lengthPx < 0.05 || mmToPx <= 0) return;
    final screenZoom = zoom.clamp(.28, 6.0);
    final inv = 1 / screenZoom;
    final ux = delta.dx / lengthPx;
    final uy = delta.dy / lengthPx;
    final normal = Offset(-uy, ux);
    const peach = Color(0xFFFFD0A0);
    const guideBlue = Color(0xFF63C6FF);
    const dark = Color(0xFF08181D);

    final draftPaint = Paint()
      ..color = peach
      ..strokeWidth = 2 * inv
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw the two expected finished wall faces, not a single fat gesture
    // stroke. Distinguishes an actual 300-mm wall from a 100-mm partition.
    if (drawFaces) {
      final faceOffset = normal * (wallThicknessMm * mmToPx / 2);
      final facePaint = Paint()
        ..color = peach.withValues(alpha: .6)
        ..strokeWidth = 1 * inv
        ..style = PaintingStyle.stroke;
      _dash(canvas, from + faceOffset, to + faceOffset, facePaint, 6 * inv);
      _dash(canvas, from - faceOffset, to - faceOffset, facePaint, 6 * inv);
    }
    _dash(canvas, from, to, draftPaint, 11 * inv);

    final startPaint = Paint()..color = dark;
    canvas.drawCircle(from, 6.2 * inv, startPaint);
    canvas.drawCircle(from, 4.7 * inv, Paint()..color = guideBlue);

    // The touch point may be at the visible face of a thick wall. Explain
    // how the topological T-junction uses the host axis rather than
    // accidentally storing a free endpoint on the finish boundary.
    if (facePoint != null) {
      final hitPaint = Paint()
        ..color = guideBlue.withValues(alpha: .85)
        ..strokeWidth = 1.7 * inv
        ..style = PaintingStyle.stroke;
      _dash(canvas, facePoint!, to, hitPaint, 4 * inv);
      canvas.drawCircle(facePoint!, 4 * inv, hitPaint);
    }

    // A dashed alignment guide shows the actual opposite room corner,
    // without pulling the endpoint to a far-away node unexpectedly.
    if (oppositeCorner case final corner?) {
      final hintPaint = Paint()
        ..color = guideBlue.withValues(alpha: .58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8 * inv;
      _dash(canvas, to, corner, hintPaint, 7 * inv);
      canvas.drawCircle(corner, 5 * inv, hintPaint);
    }

    // Snap shapes are deliberately different: circle=node, diamond=middle,
    // square=wall, crosshair=axis. The text still names the same target.
    canvas.drawCircle(to, 10 * inv, Paint()..color = dark.withValues(alpha: .9));
    final symbolPaint = Paint()
      ..color = snapKind == NodeSnapKind.none ? peach : guideBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * inv;
    switch (snapKind) {
      case NodeSnapKind.node:
        canvas.drawCircle(to, 6 * inv, symbolPaint);
      case NodeSnapKind.midpoint:
        final r = 7 * inv;
        final path = Path()
          ..moveTo(to.dx, to.dy - r)
          ..lineTo(to.dx + r, to.dy)
          ..lineTo(to.dx, to.dy + r)
          ..lineTo(to.dx - r, to.dy)
          ..close();
        canvas.drawPath(path, symbolPaint);
      case NodeSnapKind.wall:
        canvas.drawRect(
          Rect.fromCenter(center: to, width: 11 * inv, height: 11 * inv),
          symbolPaint,
        );
      default:
        final r = 7 * inv;
        canvas.drawLine(to + Offset(-r, 0), to + Offset(r, 0), symbolPaint);
        canvas.drawLine(to + Offset(0, -r), to + Offset(0, r), symbolPaint);
    }

    final millimetres = lengthPx / mmToPx;
    final angle = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    final degrees = ((angle % 360) + 360) % 360;
    final extra = oppositeCorner == null ? '' :
        ' · угол напротив ${((oppositeCorner! - to).distance / mmToPx).round()} мм';
    final label = '${millimetres.round()} мм  ·  '
        '${degrees.round()}°  ·  $snapLabel$extra';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFF2FAFC),
          fontSize: 11 * inv,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    // Offset away from fingertip; limit within the finite CAD canvas.
    final pad = 7 * inv;
    final labelWidth = textPainter.width + 2 * pad;
    final labelHeight = textPainter.height + 2 * (4 * inv);
    final proposedX = to.dx + 15 * inv;
    final proposedY = to.dy - labelHeight - 15 * inv;
    final x = proposedX + labelWidth > size.width
        ? math.max(0.0, to.dx - labelWidth - 13 * inv)
        : math.max(0.0, proposedX);
    final y = proposedY < 0
        ? to.dy + 15 * inv
        : proposedY;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, labelWidth, labelHeight),
      Radius.circular(5 * inv),
    );
    canvas.drawRRect(box, Paint()..color = dark.withValues(alpha: .94));
    canvas.drawRRect(
      box,
      Paint()
        ..color = peach.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8 * inv,
    );
    textPainter.paint(canvas, Offset(x + pad, y + 4 * inv));
  }

  static void _dash(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashPx,
  ) {
    final delta = end - start;
    final length = delta.distance;
    if (length < 0.001 || dashPx <= 0) return;
    final vector = delta / length;
    final step = dashPx + dashPx * .65;
    for (var distance = 0.0; distance < length; distance += step) {
      final endDistance = math.min(length, distance + dashPx);
      canvas.drawLine(
        start + vector * distance,
        start + vector * endDistance,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WallDraftGuidePainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.zoom != zoom ||
      oldDelegate.mmToPx != mmToPx ||
      oldDelegate.wallThicknessMm != wallThicknessMm ||
      oldDelegate.snapKind != snapKind ||
      oldDelegate.snapLabel != snapLabel ||
      oldDelegate.facePoint != facePoint ||
      oldDelegate.oppositeCorner != oppositeCorner ||
      oldDelegate.drawFaces != drawFaces;
}
