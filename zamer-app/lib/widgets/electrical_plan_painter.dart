import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_plan_dimension.dart';
import 'electrical_icon_assets.dart';
import '../services/electrical_route_service.dart';
import '../services/electrical_crossing_service.dart';
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
    this.showCrossings = false,
    this.circuitFilterId,
    this.visiblePointTypes,
    this.iconAssets,
    this.showMountingDimensions = false,
    this.reservedRect,
  });

  final ElectricalIconAssets? iconAssets;
  final bool showMountingDimensions;
  final Rect? reservedRect;
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
  final bool showCrossings;
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

    if (show3dRoutes) _drawPhysicalRoutes(canvas, size);
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
      _symbol(canvas, pos, point, selected, angle: angle);

      if (point.label.isNotEmpty && point.id != selectedPointId && !showMountingDimensions) {
        final tp = TextPainter(
          text: TextSpan(text: point.label, style: TextStyle(fontSize: 10,
            color: darkMode ? const Color(0xFFF0E6D8) : const Color(0xFF1E2329),
            fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(canvas, pos + const Offset(9, -18));
      }
    }
    _drawDimensions(canvas, size);
  }

  /// Shared by painting and tap handling: the visible number is the hit target.
  List<ElectricalDimensionLayout> dimensionLayouts(Size size) {
    final result = <ElectricalDimensionLayout>[];
    final occupied = <Rect>[if (reservedRect != null) reservedRect!];
    final points = floor.electricalPoints.toList()
      ..sort((a, b) => a.id == selectedPointId ? -1 : b.id == selectedPointId ? 1 : 0);
    for (final point in points) {
      if (point.id != selectedPointId && !showMountingDimensions) continue;
      if (visiblePointTypes != null && !visiblePointTypes!.contains(point.type)) continue;
      final d = ElectricalPlanDimension.resolve(floor, point);
      final center = p(point.xMm, point.yMm);
      final a = d == null ? center : p(d.base.dx, d.base.dy);
      final b = d == null ? center : p(d.center.dx, d.center.dy);
      final delta = b - a;
      final normal = delta.distance < .01 ? const Offset(0, -1)
          : Offset(delta.dy, -delta.dx) / delta.distance;
      final shift = normal * 42;
      Rect place(Offset at, double width) {
        final w = math.min(width, math.max(1.0, size.width - 8));
        Rect fit(Offset pos) => Rect.fromLTWH(
          (pos.dx - w / 2).clamp(4.0, math.max(4.0, size.width - w - 4)).toDouble(),
          (pos.dy - 12).clamp(4.0, math.max(4.0, size.height - 28)).toDouble(), w, 24);
        var rect = fit(at);
        for (var step = 0; step < 24 && occupied.any((r) => r.overlaps(rect.inflate(3))); step++) {
          final direction = step.isEven ? -1.0 : 1.0;
          rect = fit(at + Offset(0, direction * ((step ~/ 2) + 1) * 29));
        }
        if (occupied.any((r) => r.overlaps(rect.inflate(3)))) return Rect.zero;
        occupied.add(rect);
        return rect;
      }
      final valid = d != null && d.problem == null;
      final distanceText = valid ? '${d.distanceMm.round()} мм'
          : d?.problem != null ? 'Привязка устарела' : 'Задать привязку';
      final name = point.label.isEmpty ? point.id : point.label;
      final target = point.modules.length > 1 ? 'центр рамки' : 'центр';
      result.add(ElectricalDimensionLayout(pointId: point.id, a: a, b: b,
        lineA: a + shift, lineB: b + shift, valid: valid,
        distanceText: distanceText,
        distanceRect: place((a + b) / 2 + shift, valid ? 96 : 170),
        heightText: 'h = ${point.heightMm.round()} мм · ЧП',
        heightRect: place(center + const Offset(0, 36), 150),
        baseText: valid ? '$name · ${d.baseName} → $target${d.finished ? " · чистовая" : " · ось"}' : '$name · $target',
        baseRect: place(center + const Offset(0, 66), 235)));
    }
    return result;
  }

  void _drawDimensions(Canvas canvas, Size size) {
    for (final d in dimensionLayouts(size)) {
      final color = d.valid ? const Color(0xFFFFC28C) : const Color(0xFFFF967C);
      final stroke = Paint()..color = color..strokeWidth = 1.3;
      if (d.valid) {
        canvas.drawLine(d.a, d.lineA, stroke);
        canvas.drawLine(d.b, d.lineB, stroke);
        canvas.drawLine(d.lineA, d.lineB, stroke);
        for (final at in [d.lineA, d.lineB]) {
          canvas.drawLine(at + const Offset(-3, 4), at + const Offset(3, -4), stroke);
        }
        canvas.drawCircle(d.b, 3, Paint()..color = color);
        if (d.distanceRect != Rect.zero) {
          final mid = (d.lineA + d.lineB) / 2;
          if ((d.distanceRect.center - mid).distance > 30) {
            canvas.drawLine(mid, d.distanceRect.center, stroke..color = color.withValues(alpha: .5));
          }
        }
      }
      for (final label in [(d.distanceRect, d.distanceText),
          (d.heightRect, d.heightText), (d.baseRect, d.baseText)]) {
        if (label.$1 == Rect.zero) continue;
        final rr = RRect.fromRectAndRadius(label.$1, const Radius.circular(7));
        canvas.drawRRect(rr, Paint()..color = const Color(0xF0222428));
        canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: .5)
          ..style = PaintingStyle.stroke..strokeWidth = .7);
        final tp = TextPainter(text: TextSpan(text: label.$2,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
          ..layout(maxWidth: label.$1.width - 12);
        tp.paint(canvas, label.$1.center - Offset(tp.width / 2, tp.height / 2));
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

  void _symbol(Canvas canvas, Offset c, ElectricalPoint point, bool selected, {double angle = 0}) {
    // Preserve the six approved symbol shapes and their role colours.
    // Selection changes the stroke weight, not the semantic colour.
    final iconColor = switch (point.type) {
      ElectricalPointType.socket || ElectricalPointType.frame =>
        const Color(0xFF0760FD),
      ElectricalPointType.switchPoint => const Color(0xFF00BB6D),
      ElectricalPointType.ceilingLight || ElectricalPointType.wallLight =>
        const Color(0xFFFF9E0D),
      ElectricalPointType.tvSocket => const Color(0xFF7030FC),
      ElectricalPointType.dataSocket => const Color(0xFF02BED1),
      ElectricalPointType.panel => const Color(0xFFFF3435),
      ElectricalPointType.junctionBox => const Color(0xFFB8BCC4),
      ElectricalPointType.appliance => const Color(0xFFDDB58C),
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

    final image = iconAssets?.images[electricIconKind(type)];
    if (image != null) {
      if (selected) canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 34, height: 34), const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFC28C)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: c, width: 28, height: 28), Paint()..filterQuality = FilterQuality.high);
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


class ElectricalDimensionLayout {
  const ElectricalDimensionLayout({required this.pointId, required this.a,
    required this.b, required this.lineA, required this.lineB, required this.valid,
    required this.distanceText, required this.distanceRect, required this.heightText,
    required this.heightRect, required this.baseText, required this.baseRect});
  final String pointId, distanceText, heightText, baseText;
  final Offset a, b, lineA, lineB;
  final Rect distanceRect, heightRect, baseRect;
  final bool valid;
}
