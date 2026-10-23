import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/wall_topology_diagnostics.dart';

/// A diagnostic overlay in the same virtual CAD world as walls and furniture.
/// Markers are visual-only and cannot intercept wall or camera gestures.
class WallTopologyGapPainter extends CustomPainter {
  const WallTopologyGapPainter({
    required this.floor,
    required this.gaps,
    required this.origin,
    required this.mmToPx,
    required this.zoom,
  });

  final FloorPlan floor;
  final List<WallTopologyGap> gaps;
  final Offset origin;
  final double mmToPx;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (gaps.isEmpty || !mmToPx.isFinite || mmToPx <= 0) return;
    // Keep markers legible when the user zooms far out without making them
    // scale into huge red disks at maximum zoom.
    final px = 1 / math.max(.22, zoom);
    final outline = Paint()
      ..color = const Color(0xFFE84B52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1 * px
      ..isAntiAlias = true;
    final centerPaint = Paint()
      ..color = const Color(0xFFE84B52)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    Offset convert(math.Point<double> point) =>
        origin + Offset(point.x * mmToPx, point.y * mmToPx);

    for (final gap in gaps) {
      final node = floor.nodeById(gap.sourceNodeId);
      if (node == null) continue;
      final p = convert(math.Point<double>(node.xMm, node.yMm));
      final q = convert(gap.target);
      canvas.drawCircle(p, 10 * px, outline);
      canvas.drawCircle(p, 2.5 * px, centerPaint);
      // The connector is important at close zoom: two disconnected
      // vertices must remain recognizable as distinct CAD junctions.
      if ((p - q).distance >= .75 * px) {
        canvas.drawLine(p, q, outline);
        canvas.drawCircle(q, 3.7 * px, outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WallTopologyGapPainter oldDelegate) =>
      oldDelegate.floor != floor ||
      oldDelegate.gaps != gaps ||
      oldDelegate.origin != origin ||
      oldDelegate.mmToPx != mmToPx ||
      oldDelegate.zoom != zoom;
}
