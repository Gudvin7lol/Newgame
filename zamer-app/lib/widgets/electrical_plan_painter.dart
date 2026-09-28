import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';

class ElectricalPlanPainter extends CustomPainter {
  ElectricalPlanPainter({
    required this.floor,
    required this.scale,
    required this.origin,
    this.selectedPointId,
    this.wireStartPointId,
  });

  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedPointId;
  final String? wireStartPointId;

  Offset p(double x, double y) => origin + Offset(x * scale, y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F8FA));

    for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final paint = Paint()
        ..color = wall.demolition ? const Color(0xFFE89AA1) : const Color(0xFF31363C)
        ..strokeWidth = math.max(2, wall.thicknessMm * scale)
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(p(a.xMm, a.yMm), p(b.xMm, b.yMm), paint);
    }

    final byId = {for (final e in floor.electricalPoints) e.id: e};
    for (final run in floor.electricalRuns) {
      final a = byId[run.startPointId];
      final b = byId[run.endPointId];
      if (a == null || b == null) continue;
      final pa = p(a.xMm, a.yMm);
      final pb = p(b.xMm, b.yMm);
      final paint = Paint()
        ..color = const Color(0xFF3867A8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pa.dx, pa.dy);
      if (run.routeMode == 'orthogonal') path.lineTo(pb.dx, pa.dy);
      path.lineTo(pb.dx, pb.dy);
      canvas.drawPath(path, paint);
    }

    for (final point in floor.electricalPoints) {
      final pos = p(point.xMm, point.yMm);
      final selected = point.id == selectedPointId || point.id == wireStartPointId;
      var angle = 0.0;
      final wall = point.wallId == null ? null : floor.wallById(point.wallId!);
      if (wall != null) {
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a != null && b != null) angle = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm);
      }
      _symbol(canvas, pos, point, selected, angle: angle);
      if (point.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: point.label, style: const TextStyle(fontSize: 10, color: Color(0xFF1E2329), fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(canvas, pos + const Offset(9, -18));
      }
    }
  }

  void _symbol(Canvas canvas, Offset c, ElectricalPoint point, bool selected, {double angle = 0}) {
    final stroke = Paint()
      ..color = selected ? const Color(0xFF0D5BD7) : const Color(0xFFB24D2B)
      ..strokeWidth = selected ? 2.8 : 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFFFDFDFD);
    final type = point.type;

    if (type == ElectricalPointType.frame || point.modules.length > 1) {
      final count = point.modules.length.clamp(1, 5);
      final moduleW = 15.0;
      final rect = Rect.fromCenter(center: Offset.zero, width: count * moduleW + 6, height: 18);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
      for (var i = 1; i < count; i++) {
        final x = rect.left + 3 + moduleW * i;
        canvas.drawLine(Offset(x, rect.top + 2), Offset(x, rect.bottom - 2), stroke);
      }
      for (var i = 0; i < count; i++) {
        final module = point.modules[i];
        final mc = Offset(rect.left + 3 + moduleW * (i + 0.5), 0);
        switch (module) {
          case ElectricalModuleType.socket220:
            _socket(canvas, mc, stroke);
            break;
          case ElectricalModuleType.switch1:
            canvas.drawLine(mc + const Offset(-3, 3), mc + const Offset(4, -4), stroke);
            break;
          case ElectricalModuleType.switch2:
            _text(canvas, 'S2', mc, 6.5);
            break;
          case ElectricalModuleType.tv:
            _text(canvas, 'TV', mc, 6.2);
            break;
          case ElectricalModuleType.data:
            _text(canvas, 'RJ', mc, 6.2);
            break;
          case ElectricalModuleType.blank:
            canvas.drawCircle(mc, 1.2, stroke);
            break;
        }
      }
      canvas.restore();
      return;
    }

    final radius = 7.0;
    canvas.drawCircle(c, selected ? radius + 2 : radius, fill);
    canvas.drawCircle(c, selected ? radius + 2 : radius, stroke);
    switch (type) {
      case ElectricalPointType.panel:
        canvas.drawRect(Rect.fromCenter(center: c, width: 12, height: 16), stroke);
        canvas.drawLine(c + const Offset(-3, -3), c + const Offset(3, -3), stroke);
        canvas.drawLine(c + const Offset(-3, 2), c + const Offset(3, 2), stroke);
        break;
      case ElectricalPointType.junctionBox:
        canvas.drawRect(Rect.fromCenter(center: c, width: 12, height: 12), stroke);
        canvas.drawLine(c + const Offset(-4, -4), c + const Offset(4, 4), stroke);
        canvas.drawLine(c + const Offset(4, -4), c + const Offset(-4, 4), stroke);
        break;
      case ElectricalPointType.ceilingLight:
        canvas.drawLine(c + const Offset(-5, 0), c + const Offset(5, 0), stroke);
        canvas.drawLine(c + const Offset(0, -5), c + const Offset(0, 5), stroke);
        break;
      case ElectricalPointType.wallLight:
        canvas.drawArc(Rect.fromCircle(center: c, radius: 5), -math.pi / 2, math.pi, false, stroke);
        break;
      case ElectricalPointType.switchPoint:
        canvas.drawLine(c + const Offset(-3, 3), c + const Offset(4, -4), stroke);
        break;
      case ElectricalPointType.socket:
        _socket(canvas, c, stroke);
        break;
      case ElectricalPointType.tvSocket:
        _text(canvas, 'TV', c, 7.5);
        break;
      case ElectricalPointType.dataSocket:
        _text(canvas, 'RJ', c, 7.2);
        break;
      case ElectricalPointType.frame:
        break;
      case ElectricalPointType.appliance:
        canvas.drawLine(c + const Offset(-4, -4), c + const Offset(4, 4), stroke);
        break;
    }
  }

  void _socket(Canvas canvas, Offset c, Paint stroke) {
    canvas.drawCircle(c + const Offset(-2.5, 0), 1.2, stroke);
    canvas.drawCircle(c + const Offset(2.5, 0), 1.2, stroke);
  }

  void _text(Canvas canvas, String text, Offset c, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: const Color(0xFF9B4327), fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant ElectricalPlanPainter oldDelegate) => true;
}
