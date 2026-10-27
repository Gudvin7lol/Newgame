import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/electrical_wall_elevation_service.dart';
import '../models/electrical_route_3d.dart';

/// A separate dimensional drawing. It does NOT replace approved plan icons.
class ElectricalWallElevationPainter extends CustomPainter {
  const ElectricalWallElevationPainter({
    required this.data,
    required this.dark,
  });
  final ElectricalWallElevationData data;
  final bool dark;

  static const double marginLeft = 64;
  static const double marginRight = 30;
  static const double marginTop = 48;
  static const double marginBottom = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = dark ? const Color(0xFF121821) : const Color(0xFFF9FAFC);
    final panel = dark ? const Color(0xFF222B36) : const Color(0xFFE5EAF1);
    final primary = dark ? const Color(0xFFF1F3F6) : const Color(0xFF2B343F);
    final secondary = dark ? const Color(0xFF8998AA) : const Color(0xFF637287);
    const peach = Color(0xFFF1AF91);
    const mint = Color(0xFF9BD9C5);
    const amber = Color(0xFFF2AF83);
    final box = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(14)),
      Paint()..color = bg,
    );
    if (!data.supported || data.lengthMm <= 0 || data.heightMm <= 0) {
      _text(canvas, 'Развёртка этой стены не рассчитана', const Offset(16, 24),
          color: secondary, fontSize: 13);
      return;
    }
    final chartW = math.max(1.0, size.width - marginLeft - marginRight);
    final chartH = math.max(1.0, size.height - marginTop - marginBottom);
    final x0 = marginLeft, yFloor = marginTop + chartH;
    double x(double u) => x0 + u / data.lengthMm * chartW;
    double y(double z) => yFloor - z / data.heightMm * chartH;

    final bounds = Rect.fromLTRB(x0, marginTop, x0 + chartW, yFloor);
    canvas.drawRect(bounds, Paint()..color = panel);
    final grid = Paint()..color = secondary.withValues(alpha: .19)
      ..strokeWidth = 1;
    for (var n = 0; n <= 4; n++) {
      final z = data.heightMm * n / 4;
      canvas.drawLine(Offset(x(0), y(z)), Offset(x(data.lengthMm), y(z)), grid);
      _text(canvas, z.toStringAsFixed(0), Offset(6, y(z) - 7),
          color: secondary, fontSize: 10);
    }
    final axis = Paint()..color = secondary..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, axis);
    // Openings are drawn at explicit wall-axis offsets, NOT inferred widths.
    for (final opening in data.openings) {
      final rect = Rect.fromLTRB(
        x(opening.fromUMm), y(opening.topMm),
        x(opening.toUMm), y(opening.bottomMm),
      );
      canvas.drawRect(rect, Paint()..color = bg);
      canvas.drawRect(rect, Paint()
        ..color = mint.withValues(alpha: .75)
        ..strokeWidth = 1.6..style = PaintingStyle.stroke);
      _text(canvas, opening.kind, Offset(rect.left + 5, rect.top + 4),
          color: mint, fontSize: 10);
      final width = (opening.toUMm - opening.fromUMm).toStringAsFixed(0);
      _dimension(canvas, x(opening.fromUMm), x(opening.toUMm),
          math.max(marginTop + 3, rect.top - 10), width,
          mint, topLabel: true);
    }
    // Separate geometric route lines from device markers.
    const routeColors = <Color>[
      Color(0xFFF1AF91), Color(0xFF7BBEE5), Color(0xFFB49BE7),
      Color(0xFF87C6B4), Color(0xFFE4C77A), Color(0xFFA2C98B),
    ];
    for (final section in data.segments) {
      var hash = 0;
      for (final rune in section.circuitId.runes) {
        hash = (hash * 31 + rune) & 0x7fffffff;
      }
      final color = routeColors[hash % routeColors.length];
      final a = Offset(x(section.fromUMm), y(section.fromZMm));
      final b = Offset(x(section.toUMm), y(section.toZMm));
      final paint = Paint()
        ..color = section.source == ElectricalPathSource.unspecified
            ? color.withValues(alpha: .64) : color
        ..strokeWidth = 3..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
      canvas.drawCircle(a, 2.5, Paint()..color = color);
      canvas.drawCircle(b, 2.5, Paint()..color = color);
    }
    // Perpendicular crossing points remain in the details list; a crossing
    // must never be painted as an on-wall cable run in this elevation.
    // Points only if assigned to this exact wall by an explicit wallId.
    for (var i = 0; i < data.points.length; i++) {
      final point = data.points[i];
      final px = x(point.uMm), py = y(point.zMm);
      canvas.drawCircle(Offset(px, py), 6.8,
          Paint()..color = bg);
      canvas.drawCircle(Offset(px, py), 6.8,
          Paint()..color = peach..style = PaintingStyle.stroke
            ..strokeWidth = 2.3);
      canvas.drawCircle(Offset(px, py), 2.4, Paint()..color = peach);
      final label = point.label.length > 17
          ? point.label.substring(0, 16) + '…' : point.label;
      // Alternate rows so closely spaced points remain navigable in a list.
      final labelY = (py - 30 - (i % 2) * 16)
          .clamp(marginTop + 4, yFloor - 20).toDouble();
      _text(canvas, label, Offset(px + 9, labelY),
          color: primary, fontSize: 10, maxWidth: 125);
      final dashed = Paint()..color = peach.withValues(alpha: .45)
        ..strokeWidth = 1;
      _dashes(canvas, Offset(px, py + 8),
          Offset(px, yFloor), dashed);
      _text(canvas, point.uMm.toStringAsFixed(0),
          Offset(px - 13, yFloor + 14 + (i % 2) * 15),
          color: peach, fontSize: 9);
    }
    _dimension(canvas, x(0), x(data.lengthMm), marginTop - 20,
        data.lengthMm.toStringAsFixed(0) + ' мм', primary,
        topLabel: true);
    _text(canvas, '0 · начало стены', Offset(x0, yFloor + 44),
        color: secondary, fontSize: 10);
    _text(canvas, 'конец', Offset(x(data.lengthMm) - 35, yFloor + 44),
        color: secondary, fontSize: 10);
    _text(canvas, 'Z от чистого пола, мм', const Offset(7, 7),
        color: secondary, fontSize: 10);
  }

  void _dashes(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final total = d.distance;
    if (total < 1) return;
    final unit = d / total;
    for (var t = 0.0; t < total; t += 9) {
      canvas.drawLine(a + unit * t,
          a + unit * math.min(t + 4, total), paint);
    }
  }

  void _dimension(Canvas canvas, double left, double right, double atY,
      String label, Color color, {bool topLabel = false}) {
    final line = Paint()..color = color.withValues(alpha: .65)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, atY), Offset(right, atY), line);
    canvas.drawLine(Offset(left, atY - 4), Offset(left, atY + 4), line);
    canvas.drawLine(Offset(right, atY - 4), Offset(right, atY + 4), line);
    final span = right - left;
    if (span > 43) {
      _text(canvas, label, Offset((left + right) / 2 - 18,
          atY + (topLabel ? -16 : 4)), color: color, fontSize: 10);
    }
  }

  void _text(Canvas canvas, String string, Offset position, {
    required Color color, double fontSize = 11, double maxWidth = 230,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: string, style: TextStyle(
        color: color, fontSize: fontSize, fontWeight: FontWeight.w500,
      )),
      maxLines: 1, ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant ElectricalWallElevationPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.dark != dark;
}
