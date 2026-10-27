import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_mounting_service.dart';
import '../services/electrical_route_service.dart';
import '../models/electrical_route_3d.dart';

class ElectricalPlanPainter extends CustomPainter {
  ElectricalPlanPainter({
    required this.floor,
    required this.scale,
    required this.origin,
    this.selectedPointId,
    this.wireStartPointId,
    this.darkMode = false,
    this.overlayOnly = false,
    this.showLegacyLines = true,
    this.show3dRoutes = false,
    this.circuitFilterId,
  });

  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedPointId;
  final String? wireStartPointId;
  final bool darkMode;
  /// Retain CAD flooring, furniture, walls below electrical layer.
  final bool overlayOnly;
  /// Legacy drawing is never a proof of physical cable connectivity.
  final bool showLegacyLines;
  final bool show3dRoutes;
  final String? circuitFilterId;

  Offset p(double x, double y) => origin + Offset(x * scale, y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (!overlayOnly) canvas.drawRect(Offset.zero & size, Paint()
      ..color = darkMode ? const Color(0xFF09151B) : const Color(0xFFF7F8FA));

    if (!overlayOnly) for (final wall in floor.walls) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final paint = Paint()
        ..color = wall.demolition ? const Color(0xFFE89AA1) :
            (darkMode ? const Color(0xFFCFDBD8) : const Color(0xFF31363C))
        ..strokeWidth = math.max(2, wall.thicknessMm * scale)
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(p(a.xMm, a.yMm), p(b.xMm, b.yMm), paint);
    }

    final byId = {for (final e in floor.electricalPoints) e.id: e};
    if (showLegacyLines) for (final run in floor.electricalRuns) {
      final a = byId[run.startPointId];
      final b = byId[run.endPointId];
      if (a == null || b == null) continue;
      final pa = p(a.xMm, a.yMm);
      final pb = p(b.xMm, b.yMm);
      final paint = Paint()
        ..color = darkMode ? const Color(0xFF6BBDED) : const Color(0xFF3867A8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pa.dx, pa.dy);
      if (run.routeMode == 'orthogonal') path.lineTo(pb.dx, pa.dy);
      path.lineTo(pb.dx, pb.dy);
      canvas.drawPath(path, paint);
    }

    if (show3dRoutes) _drawPhysicalRoutes(canvas, size);

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
      if (point.id == selectedPointId) _mountingDimension(canvas, point, size);
      if (point.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: point.label, style: TextStyle(fontSize: 10,
            color: darkMode ? const Color(0xFFF0E6D8) : const Color(0xFF1E2329),
            fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(canvas, pos + const Offset(9, -18));
      }
    }
  }

  void _drawPhysicalRoutes(Canvas canvas, Size size) {
    final network = floor.electricalNetwork;
    if (network == null) return;
    final routes = {for (final r in network.routes3d) r.id: r};
    final drawn = <String>{};
    const colors = <Color>[
      Color(0xFFF2AA88), Color(0xFF75BCEF), Color(0xFF9CD5C7),
      Color(0xFFC7A8EA), Color(0xFFE4C77A), Color(0xFFABCC87),
    ];
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final cable in network.cables) {
      if (circuitFilterId != null && cable.circuitId != circuitFilterId) {
        continue;
      }
      final routeId = cable.route3dId;
      if (routeId == null) continue;
      final route = routes[routeId];
      if (route == null) continue;
      try {
        ElectricalRouteService.measureCable(floor, cable);
      } on FormatException {
        // Invalid, stale or unverified geometry must not masquerade as a valid
        // physical route on the installation plan.
        continue;
      }
      final dedup = routeId + '/' + cable.circuitId;
      if (!drawn.add(dedup)) continue;
      var hash = 0;
      for (final code in cable.circuitId.codeUnits) {
        hash = (hash * 31 + code) & 0x7fffffff;
      }
      final color = colors[hash % colors.length];
      final stroke = Paint()
        ..color = color
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = color;
      final points = route.vertices;
      for (var index = 1; index < points.length; index++) {
        final a = points[index - 1], b = points[index];
        final pa = p(a.xMm, a.yMm);
        final pb = p(b.xMm, b.yMm);
        if ((pa - pb).distance <= .01) {
          // Concentric circle: strictly vertical cable leg in XY projection.
          canvas.drawCircle(pb, 6, stroke);
          canvas.drawCircle(pb, 2.1, dot);
        } else {
          canvas.drawLine(pa, pb, stroke);
          if (index < points.length - 1) canvas.drawCircle(pb, 2.4, dot);
        }
      }
    }
    canvas.restore();
  }

  void _mountingDimension(Canvas canvas, ElectricalPoint point, Size size) {
    final m = point.mounting;
    if (m == null) return;
    final issue = ElectricalMountingService.problem(floor, point);
    final color = issue == null
        ? (darkMode ? const Color(0xFFFFBD88) : const Color(0xFF6A3E1C))
        : const Color(0xFFE16F52);
    String caption;
    if (issue != null) {
      caption = issue;
    } else {
      final resolved = ElectricalMountingService.resolve(floor, m);
      final a = p(resolved.datumXMm, resolved.datumYMm);
      final b = p(resolved.xMm, resolved.yMm);
      final delta = b - a;
      final normal = delta.distance < .001 ? const Offset(0, -1) : Offset(delta.dy, -delta.dx) / delta.distance;
      final lift = normal * 36;
      final paint = Paint()..color = color..strokeWidth = 1.3;
      canvas.drawLine(a, a + lift + normal * 4, paint);
      canvas.drawLine(b, b + lift + normal * 4, paint);
      canvas.drawLine(a + lift, b + lift, paint);
      caption = '${point.label.isEmpty ? point.id : point.label} · ${m.datumName} → центр: ${m.distanceMm} мм · h ${point.heightMm} от ЧП';
    }
    final tp = TextPainter(text: TextSpan(text: caption,
      style: TextStyle(fontSize: 11, color: color, backgroundColor: darkMode ? const Color(0xFF142027) : Colors.white)),
      textDirection: TextDirection.ltr)..layout(maxWidth: 235);
    final anchor = p(point.xMm, point.yMm) + const Offset(12, 18);
    tp.paint(canvas, Offset(anchor.dx.clamp(4, math.max(4, size.width - tp.width - 4)).toDouble(),
      anchor.dy.clamp(4, math.max(4, size.height - tp.height - 4)).toDouble()));
  }

  void _symbol(Canvas canvas, Offset c, ElectricalPoint point, bool selected, {double angle = 0}) {
    final stroke = Paint()
      ..color = selected ? const Color(0xFF0D5BD7) :
        switch (point.type) {
          ElectricalPointType.ceilingLight ||
          ElectricalPointType.wallLight => const Color(0xFF317C9A),
          ElectricalPointType.panel => const Color(0xFF7567AB),
          ElectricalPointType.switchPoint => const Color(0xFF90622A),
          _ => const Color(0xFFB24D2B),
        }
      ..strokeWidth = selected ? 2.8 : 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFFFDFDFD);
    final type = point.type;

    if (type == ElectricalPointType.frame || point.modules.length > 1) {
      final count = point.modules.length.clamp(1, 5).toInt();
      const moduleStep = 15.0;
      final vertical = point.frameVertical;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: vertical ? 18 : count * moduleStep + 6,
        height: vertical ? count * moduleStep + 6 : 18,
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final housing = RRect.fromRectAndRadius(
        rect, const Radius.circular(5));
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFF9F9F5));
      canvas.drawRRect(housing, stroke);
      for (var i = 1; i < count; i++) {
        if (vertical) {
          final y = rect.top + 3 + moduleStep * i;
          canvas.drawLine(Offset(rect.left + 2, y),
              Offset(rect.right - 2, y), stroke);
        } else {
          final x = rect.left + 3 + moduleStep * i;
          canvas.drawLine(Offset(x, rect.top + 2),
              Offset(x, rect.bottom - 2), stroke);
        }
      }
      for (var i = 0; i < count; i++) {
        final module = point.modules[i];
        final mc = vertical
            ? Offset(0, rect.top + 3 + moduleStep * (i + .5))
            : Offset(rect.left + 3 + moduleStep * (i + .5), 0);
        switch (module) {
          case ElectricalModuleType.socket220:
            _socket(canvas, mc, stroke);
            break;
          case ElectricalModuleType.switch1:
            canvas.drawLine(mc + const Offset(-3, 3),
                mc + const Offset(4, -4), stroke);
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
