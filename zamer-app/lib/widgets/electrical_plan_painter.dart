import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_mounting_service.dart';
import '../services/electrical_route_service.dart';
import '../services/electrical_route_exclusion_service.dart';
import '../services/electrical_crossing_service.dart';
import '../models/electrical_route_3d.dart';
import '../models/electrical_route_exclusion_zone.dart';

class ElectricalPlanPainter extends CustomPainter {
  ElectricalPlanPainter({
    required this.floor,
    required this.scale,
    required this.origin,
    this.selectedPointId,
    this.wireStartPointId,
    this.darkMode = false,
    this.overlayOnly = false,
    this.interactiveDimensions = false,
    this.showLegacyLines = true,
    this.show3dRoutes = false,
    this.showCrossings = false,
    this.diagnosticRouteId,
    this.circuitFilterId,
    this.visiblePointTypes,
  });

  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedPointId;
  final String? wireStartPointId;
  final bool darkMode;
  /// Retain CAD flooring, furniture, walls below electrical layer.
  final bool overlayOnly;
  /// The Flutter overlay owns editable labels; canvas draws witness lines.
  final bool interactiveDimensions;
  /// Legacy drawing is never a proof of physical cable connectivity.
  final bool showLegacyLines;
  final bool show3dRoutes;
  final bool showCrossings;
  /// A fault-focused trace is never drawn as a validated installation.
  final String? diagnosticRouteId;
  final String? circuitFilterId;
  /// Visual-only filter: hidden points remain in the project model.
  final Set<ElectricalPointType>? visiblePointTypes;

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

    // No-go zones are persistent project geometry, not a decorative layer.
    // Their Z range appears in the caption; a plan rectangle alone is not
    // a complete three-dimensional safety envelope.
    for (final zone in floor.electricalNetwork?.routeExclusionZones ??
        const <ElectricalRouteExclusionZone>[]) {
      try {
        zone.validate();
      } on FormatException {
        continue;
      }
      final leftTop = p(zone.minXMm, zone.minYMm);
      final rightBottom = p(zone.maxXMm, zone.maxYMm);
      final rect = Rect.fromPoints(leftTop, rightBottom);
      canvas.drawRect(rect, Paint()..color =
          const Color(0xFFE76C67).withValues(alpha: .16));
      canvas.drawRect(rect, Paint()
        ..color = const Color(0xFFE76C67)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke);
      final tp = TextPainter(
        text: TextSpan(
          text: '${zone.name} · Z ${zone.minZMm.round()}–${zone.maxZMm.round()}',
          style: const TextStyle(
            color: Color(0xFFE76C67),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ), textDirection: TextDirection.ltr,
      )..layout(maxWidth: 195);
      tp.paint(canvas, rect.topLeft + const Offset(3, 3));
    }

    if (show3dRoutes) _drawPhysicalRoutes(canvas, size);
    if (diagnosticRouteId != null) _drawDiagnosticRoute(canvas, size);
    if (showCrossings) _drawCrossings(canvas, size);

    for (final point in floor.electricalPoints) {
      if (visiblePointTypes != null && !visiblePointTypes!.contains(point.type)) continue;
      final pos = p(point.xMm, point.yMm);
      final selected = point.id == selectedPointId || point.id == wireStartPointId;
      var angle = 0.0;
      final wall = point.wallId == null ? null : floor.wallById(point.wallId!);
      if (wall != null) {
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a != null && b != null) angle = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm);
      }
      // Model coordinates stay on the wall axis. Offset only the symbol
      // toward its mounted room so the wall face is obvious at a glance.
      var iconPos = pos;
      if (wall != null && point.isWallDevice) {
        final halfDepth = (point.type == ElectricalPointType.frame ||
                point.modules.length > 1) ? 8.5 : 6.5;
        final shift = halfDepth * point.wallSide;
        iconPos = pos + Offset(-math.sin(angle) * shift,
                               math.cos(angle) * shift);
      }
      _symbol(canvas, iconPos, point, selected, angle: angle);
      if (point.id == selectedPointId) {
        // Show the exact wall-axis anchor without moving any CAD geometry.
        canvas.drawCircle(pos, 2, Paint()
          ..color = const Color(0xFFF2B69B));
        _mountingDimension(canvas, point, size);
      }
      if (point.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: point.label, style: TextStyle(fontSize: 10,
            color: darkMode ? const Color(0xFFF0E6D8) : const Color(0xFF1E2329),
            fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(canvas, iconPos + const Offset(9, -18));
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
      if (routeId == null || routeId == diagnosticRouteId) continue;
      final route = routes[routeId];
      if (route == null) continue;
      try {
        ElectricalRouteService.measureCable(floor, cable);
        ElectricalRouteExclusionService.requireClear(floor, route);
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
      // A route proposed from an unverified drawing must not look identical
      // to a surveyed geometric path. Neither is an installation approval.
      final tentative = route.source != ElectricalPathSource.measured;
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
          if (tentative) {
            _drawDraftLine(canvas, pa, pb, stroke);
          } else {
            canvas.drawLine(pa, pb, stroke);
            if (index < points.length - 1) canvas.drawCircle(pb, 2.4, dot);
          }
        }
      }
    }
    canvas.restore();
  }

  /// Draw ONLY a specifically requested faulty route as an explicit
  /// inspection trace. The routine does not certify or repair its geometry;
  /// it avoids projecting missing/nonfinite vertices or inventing new links.
  void _drawDiagnosticRoute(Canvas canvas, Size size) {
    final route = floor.electricalNetwork?.routes3d
        .where((r) => r.id == diagnosticRouteId).firstOrNull;
    if (route == null || route.vertices.length < 2 ||
        route.vertices.any((v) => !v.finite ||
          v.xMm.abs() > 10000000 || v.yMm.abs() > 10000000 ||
          v.zMm.abs() > 10000000)) return;

    final red = Paint()
      ..color = const Color(0xFFFF6969)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 1; i < route.vertices.length; i++) {
      final start = route.vertices[i - 1];
      final end = route.vertices[i];
      final pa = p(start.xMm, start.yMm);
      final pb = p(end.xMm, end.yMm);
      if ((pa - pb).distance < .1) {
        canvas.drawCircle(pa, 7, red); // vertical segment in plan view
      } else {
        _drawDraftLine(canvas, pa, pb, red);
      }
    }
    final first = route.vertices.first;
    final badge = p(first.xMm, first.yMm);
    canvas.drawCircle(badge, 11, Paint()
      ..color = darkMode ? const Color(0xFF301417) : Colors.white);
    canvas.drawCircle(badge, 11, red);
    final label = TextPainter(
      text: const TextSpan(text: '!', style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w800,
        color: Color(0xFFFF6969),
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, badge - Offset(label.width/2, label.height/2));
    canvas.restore();
  }

  /// Deliberate visual distinction: dashed = route geometry not surveyed.
  void _drawDraftLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len < .001) return;
    final unit = d / len;
    const dash = 7.0, gap = 5.0;
    var distance = 0.0;
    while (distance < len) {
      final finish = math.min(distance + dash, len);
      canvas.drawLine(a + unit * distance, a + unit * finish, paint);
      distance += dash + gap;
    }
  }

  void _drawCrossings(Canvas canvas, Size size) {
    final report = ElectricalCrossingService.inspect(
      floor, circuitId: circuitFilterId,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Avoid overprinting shared cable routes with indistinguishable markers.
    final plotted = <String>{};
    for (final notice in report.notices) {
      final key = notice.wallId + '/' + notice.kind.name + '/' +
          notice.xMm.toStringAsFixed(1) + '/' +
          notice.yMm.toStringAsFixed(1);
      if (!plotted.add(key)) continue;
      if (notice.kind == ElectricalCrossingKind.unsupportedWall) continue;
      final at = p(notice.xMm, notice.yMm);
      const warning = Color(0xFFFFA578);
      const info = Color(0xFF8BD7BC);
      final color = notice.needsReview ? warning : info;
      final outer = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(at, 8.5, Paint()
        ..color = darkMode ? const Color(0xFF18222C) : Colors.white);
      canvas.drawCircle(at, 8.5, outer);
      final tp = TextPainter(
        text: TextSpan(
          text: notice.needsReview ? '!' : 'i',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color, fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }

  /// A selected wall point always has a readable station and height
  /// even before the optional named mounting datum has been configured.
  /// The axis station is not a finished-surface dimension.
  void _axisStationDimension(
      Canvas canvas, ElectricalPoint point, Size size) {
    final wall = point.wallId == null
        ? null : floor.wallById(point.wallId!);
    final start = wall == null
        ? null : floor.nodeById(wall.startNodeId);
    final end = wall == null
        ? null : floor.nodeById(wall.endNodeId);
    if (start == null || end == null || point.wallOffsetMm == null) return;
    final dx = end.xMm - start.xMm, dy = end.yMm - start.yMm;
    final len = math.sqrt(dx * dx + dy * dy);
    if (!len.isFinite || len <= 0) return;
    final a = p(start.xMm, start.yMm);
    final b = p(point.xMm, point.yMm);
    final side = point.wallSide == -1 ? -1.0 : 1.0;
    // Draw dimensions opposite the mounted face so the symbol is clear.
    final normal = Offset(dy / len, -dx / len) * side;
    final lift = normal * 26;
    final color = darkMode
        ? const Color(0xFFF2B69B) : const Color(0xFF784A32);
    final line = Paint()..color = color..strokeWidth = 1.2;
    canvas.drawLine(a, a + lift + normal * 5, line);
    canvas.drawLine(b, b + lift + normal * 5, line);
    canvas.drawLine(a + lift, b + lift, line);
    if (interactiveDimensions) return;
    final caption = '${point.wallOffsetMm!.round()} мм от начала стены'
        ' · H ${point.heightMm.round()} мм';
    final tp = TextPainter(
      text: TextSpan(text: caption, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: color,
        backgroundColor: darkMode
            ? const Color(0xFF142027) : Colors.white,
      )),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 210);
    final centre = (a + b) / 2 + lift + normal * 7;
    tp.paint(canvas, Offset(
      (centre.dx - tp.width / 2)
          .clamp(4.0, math.max(4.0, size.width - tp.width - 4)).toDouble(),
      (centre.dy - tp.height / 2)
          .clamp(4.0, math.max(4.0, size.height - tp.height - 4)).toDouble(),
    ));
  }

  void _mountingDimension(Canvas canvas, ElectricalPoint point, Size size) {
    final m = point.mounting;
    if (m == null) {
      _axisStationDimension(canvas, point, size);
      return;
    }
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
    if (interactiveDimensions) return;
    final tp = TextPainter(text: TextSpan(text: caption,
      style: TextStyle(fontSize: 11, color: color, backgroundColor: darkMode ? const Color(0xFF142027) : Colors.white)),
      textDirection: TextDirection.ltr)..layout(maxWidth: 235);
    final anchor = p(point.xMm, point.yMm) + const Offset(12, 18);
    tp.paint(canvas, Offset(anchor.dx.clamp(4, math.max(4, size.width - tp.width - 4)).toDouble(),
      anchor.dy.clamp(4, math.max(4, size.height - tp.height - 4)).toDouble()));
  }

  void _symbol(Canvas canvas, Offset c, ElectricalPoint point, bool selected, {double angle = 0}) {
    // Preserve the six approved symbol shapes and their role colours.
    // Selection changes the stroke weight, not the semantic colour.
    final iconColor = switch (point.type) {
      ElectricalPointType.socket || ElectricalPointType.frame =>
        const Color(0xFF6C9EF8),
      ElectricalPointType.switchPoint => const Color(0xFF72C49B),
      ElectricalPointType.ceilingLight || ElectricalPointType.wallLight =>
        const Color(0xFFF0A36B),
      ElectricalPointType.tvSocket => const Color(0xFFB59AED),
      ElectricalPointType.dataSocket => const Color(0xFF68D1CB),
      ElectricalPointType.panel => const Color(0xFFE98181),
      ElectricalPointType.junctionBox => const Color(0xFFD0C48C),
      ElectricalPointType.appliance => const Color(0xFFAAB2BC),
    };
    final stroke = Paint()..color = iconColor
      ..strokeWidth = selected ? 2.8 : 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = darkMode
        ? const Color(0xFF202631) : const Color(0xFFFDFDFD);
    final type = point.type;

    if (type == ElectricalPointType.frame || point.modules.length > 1) {
      final count = point.modules.length.clamp(1, 5).toInt();
      // Keep symbols legible when zoomed out, but honour real CAD pitch
      // as soon as the scale supports it. Exact millimetres live in the model.
      final moduleStep = (point.modulePitchMm * scale)
          .clamp(12.0, 36.0).toDouble();
      final vertical = point.frameVertical;
      // Vertically stacked devices share the SAME U in plan and differ in Z.
      // Do not fake a floor-plane footprint extending through the wall.
      final visibleCount = vertical ? 1 : count;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: visibleCount * moduleStep + 6,
        height: 18,
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final housing = RRect.fromRectAndRadius(
        rect, const Radius.circular(5));
      canvas.drawRRect(housing, Paint()..color = darkMode ? const Color(0xFF202631) : const Color(0xFFF9F9F5));
      canvas.drawRRect(housing, stroke);
      for (var i = 1; i < visibleCount; i++) {
        final x = rect.left + 3 + moduleStep * i;
        canvas.drawLine(Offset(x, rect.top + 2),
            Offset(x, rect.bottom - 2), stroke);
      }
      for (var i = 0; i < visibleCount; i++) {
        final module = point.modules[i];
        final mc = Offset(rect.left + 3 + moduleStep * (i + .5), 0);
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
      if (vertical) _text(canvas, '×$count',
          Offset(rect.right + 13, rect.top + 2), 9);
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
