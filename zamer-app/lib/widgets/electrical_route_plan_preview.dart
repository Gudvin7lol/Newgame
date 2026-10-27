import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/electrical_route_3d.dart';

/// Preview only: the world-mm geometry is the source of truth, not the pixels.
/// Vertical legs are indicated at a point; they cannot be inferred from XY.
class ElectricalRoutePlanPreview extends StatelessWidget {
  const ElectricalRoutePlanPreview({
    super.key,
    required this.vertices,
    required this.target,
    this.height = 170,
  });
  final List<ElectricalRouteVertex> vertices;
  final ElectricalRouteVertex target;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _ElectricalRoutePreviewPainter(
        vertices: vertices,
        target: target,
        lineColor: Theme.of(context).colorScheme.primary,
        targetColor: Theme.of(context).colorScheme.error,
        background: Theme.of(context).colorScheme.surfaceContainerHighest,
        textColor: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class _ElectricalRoutePreviewPainter extends CustomPainter {
  const _ElectricalRoutePreviewPainter({
    required this.vertices, required this.target,
    required this.lineColor, required this.targetColor,
    required this.background, required this.textColor,
  });
  final List<ElectricalRouteVertex> vertices;
  final ElectricalRouteVertex target;
  final Color lineColor, targetColor, background, textColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()..color = background,
    );
    if (vertices.isEmpty || size.isEmpty) return;
    final positions = [...vertices, target];
    var minX = positions.first.xMm, maxX = minX;
    var minY = positions.first.yMm, maxY = minY;
    for (final v in positions) {
      minX = math.min(minX, v.xMm);
      maxX = math.max(maxX, v.xMm);
      minY = math.min(minY, v.yMm);
      maxY = math.max(maxY, v.yMm);
    }
    const margin = 26.0;
    final rangeX = math.max(200, maxX - minX);
    final rangeY = math.max(200, maxY - minY);
    final sx = math.max(1, size.width - 2 * margin) / rangeX;
    final sy = math.max(1, size.height - 2 * margin) / rangeY;
    final scale = math.min(sx, sy);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    Offset p(ElectricalRouteVertex v) => Offset(
      size.width / 2 + (v.xMm - cx) * scale,
      size.height / 2 + (v.yMm - cy) * scale,
    );
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < vertices.length; i++) {
      final a = p(vertices[i - 1]);
      final b = p(vertices[i]);
      if ((a - b).distance < .01) {
        // Vertical section: concentric ring at its plan position.
        canvas.drawCircle(b, 7, line);
      } else {
        canvas.drawLine(a, b, line);
      }
      canvas.drawCircle(b, 3.5, Paint()..color = lineColor);
    }
    final origin = p(vertices.first);
    canvas.drawCircle(origin, 5, Paint()..color = lineColor);
    final dest = p(target);
    canvas.drawCircle(dest, 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = targetColor);
    canvas.drawLine(dest + const Offset(-9, 0),
        dest + const Offset(9, 0), Paint()..color = targetColor);
    canvas.drawLine(dest + const Offset(0, -9),
        dest + const Offset(0, 9), Paint()..color = targetColor);
    final text = TextPainter(
      text: TextSpan(text: 'Вид сверху · Z отдельными участками',
          style: TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    text.paint(canvas, const Offset(10, 7));
  }

  @override
  bool shouldRepaint(covariant _ElectricalRoutePreviewPainter old) => true;
}
