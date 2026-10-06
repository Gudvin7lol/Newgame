import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/herringbone_layout.dart';
import '../services/material_catalog.dart';
import 'top_view_object_renderer.dart';

/// UI KIT 02 CAD renderer for +78.
///
/// Floor finishes use the same room material parameters that feed 3D: plank
/// sizes, tile sizes, offsets, direction and layout mode. Furniture is rendered
/// by [TopViewObjectRenderer] with detailed top-view symbols instead of generic
/// rectangles.
class CadPlanPainterV2 extends CustomPainter {
  CadPlanPainterV2({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedWallId,
    this.showGrid = true,
    this.showDimensions = true,
    Set<ProjectLayer>? visibleLayers,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet();

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final bool showGrid;
  final bool showDimensions;
  final Set<ProjectLayer> visibleLayers;

  Offset _p(PlanNode n) => origin + Offset(n.xMm * mmToPx, n.yMm * mmToPx);
  Offset _q(math.Point<double> p) => origin + Offset(p.x * mmToPx, p.y * mmToPx);

  @override
  void paint(Canvas canvas, Size size) {
    _background(canvas, size);
    final faces = GeometryService.roomFaces(floor);
    _rooms(canvas, faces);
    _walls(canvas);
    _objects(canvas);
    _roomLabels(canvas, faces);
    if (showDimensions) _outerDimensions(canvas);
  }

  void _background(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ZamerColors.background);
    if (!showGrid) return;

    final minor = 250 * mmToPx;
    final major = 1000 * mmToPx;
    if (minor < 8) return;

    final minorPaint = Paint()
      ..color = const Color(0xFF183039).withValues(alpha: .32)
      ..strokeWidth = .48;
    final majorPaint = Paint()
      ..color = const Color(0xFF29434A).withValues(alpha: .46)
      ..strokeWidth = .72;

    for (double x = origin.dx % minor; x < size.width; x += minor) {
      final index = ((x - origin.dx) / minor).round().abs();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 4 == 0 ? majorPaint : minorPaint,
      );
    }
    for (double y = origin.dy % minor; y < size.height; y += minor) {
      final index = ((y - origin.dy) / minor).round().abs();
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 4 == 0 ? majorPaint : minorPaint,
      );
    }
  }

  RoomMeta? _metaFor(RoomFace face) {
    for (final meta in floor.roomMetas) {
      if (meta.faceKey == face.key) return meta;
    }
    return null;
  }

  Path _roomPath(RoomFace face) {
    final path = Path();
    if (face.innerPolygon.isEmpty) return path;
    final first = _q(face.innerPolygon.first);
    path.moveTo(first.dx, first.dy);
    for (final point in face.innerPolygon.skip(1)) {
      final p = _q(point);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _rooms(Canvas canvas, List<RoomFace> faces) {
    for (final face in faces) {
      if (face.innerPolygon.length < 3) continue;
      final path = _roomPath(face);
      final meta = _metaFor(face);
      final settings = meta?.materials ?? RoomMaterialSettings();
      final preset = MaterialCatalog.byId(settings.floorMaterialId);
      final base = Color.lerp(preset.color, const Color(0xFF11181B), .16)!;

      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, Paint()..color = base);
      _drawFinish(canvas, path.getBounds(), settings, preset);
      canvas.restore();
    }
  }

  void _drawFinish(
    Canvas canvas,
    Rect bounds,
    RoomMaterialSettings settings,
    VisualMaterialPreset preset,
  ) {
    final center = bounds.center;
    final direction = settings.floorDirectionDeg * math.pi / 180;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(direction);
    canvas.translate(-center.dx, -center.dy);

    final pattern = settings.floorMode == 'tile' ? 'tile' : preset.pattern;
    if (settings.laminatePattern == 'herringbone' && pattern == 'wood') {
      _herringbone(canvas, bounds, settings, preset.color);
    } else if (pattern == 'wood') {
      _wood(canvas, bounds, settings, preset.color);
    } else if (pattern == 'tile') {
      _tile(canvas, bounds, settings, preset);
    } else if (pattern == 'brick') {
      _brick(canvas, bounds, preset.color);
    } else if (pattern == 'concrete') {
      _concrete(canvas, bounds, preset.color);
    } else {
      _surfaceNoise(canvas, bounds, preset.color, density: .45);
    }
    canvas.restore();
  }

  void _wood(
    Canvas canvas,
    Rect bounds,
    RoomMaterialSettings settings,
    Color base,
  ) {
    final plankW = math.max(8.0, settings.laminatePlankWidthMm * mmToPx);
    final plankL = math.max(28.0, settings.laminatePlankLengthMm * mmToPx);
    final offsetX = settings.laminateOffsetXMm * mmToPx;
    final offsetY = settings.laminateOffsetYMm * mmToPx;
    final joint = Paint()
      ..color = Color.lerp(base, Colors.black, .56)!.withValues(alpha: .42)
      ..strokeWidth = .55;
    final grain = Paint()
      ..color = Color.lerp(base, Colors.white, .42)!.withValues(alpha: .13)
      ..strokeWidth = .45;

    var row = 0;
    for (double y = bounds.top - plankW + offsetY;
        y <= bounds.bottom + plankW;
        y += plankW) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), joint);
      final halfShift = settings.laminateOffsetMode == 'half' && row.isOdd
          ? plankL / 2
          : 0.0;
      for (double x = bounds.left - plankL + offsetX + halfShift;
          x <= bounds.right + plankL;
          x += plankL) {
        canvas.drawLine(Offset(x, y), Offset(x, y + plankW), joint);
        final seed = ((x * .07 + y * .11).round().abs() % 5) / 5;
        final gy = y + plankW * (.28 + seed * .42);
        canvas.drawLine(
          Offset(x + plankL * .08, gy),
          Offset(x + plankL * .88, gy + plankW * .04),
          grain,
        );
      }
      row++;
    }
  }

  void _herringbone(
    Canvas canvas,
    Rect bounds,
    RoomMaterialSettings settings,
    Color base,
  ) {
    final plankLength = math.max(
      28.0,
      settings.laminatePlankLengthMm * mmToPx,
    );
    final plankWidth = math.max(
      7.0,
      settings.laminatePlankWidthMm * mmToPx,
    );
    final padding = plankLength + plankWidth * 2;
    final boards = buildHerringboneBoards(
      minX: bounds.left - padding,
      minY: bounds.top - padding,
      maxX: bounds.right + padding,
      maxY: bounds.bottom + padding,
      plankLength: plankLength,
      plankWidth: plankWidth,
      offsetX: settings.laminateOffsetXMm * mmToPx,
      offsetY: settings.laminateOffsetYMm * mmToPx,
    );
    final joint = Paint()
      ..color = Color.lerp(base, Colors.black, .60)!.withValues(alpha: .44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55;
    final shades = <Paint>[
      Paint()..color = Color.lerp(base, Colors.white, .06)!,
      Paint()..color = Color.lerp(base, Colors.black, .035)!,
      Paint()..color = base,
    ];

    var index = 0;
    for (final board in boards) {
      if (board.points.length != 4) continue;
      final path = Path()
        ..moveTo(board.points[0].x, board.points[0].y)
        ..lineTo(board.points[1].x, board.points[1].y)
        ..lineTo(board.points[2].x, board.points[2].y)
        ..lineTo(board.points[3].x, board.points[3].y)
        ..close();
      canvas.drawPath(path, shades[index % shades.length]);
      canvas.drawPath(path, joint);
      index++;
    }
  }

  void _tile(
    Canvas canvas,
    Rect bounds,
    RoomMaterialSettings settings,
    VisualMaterialPreset preset,
  ) {
    final tileW = math.max(16.0, settings.tileWidthMm * mmToPx);
    final tileH = math.max(16.0, settings.tileHeightMm * mmToPx);
    final offsetX = settings.tileOffsetXMm * mmToPx;
    final offsetY = settings.tileOffsetYMm * mmToPx;
    final grout = math.max(.45, settings.floorTileGroutMm * mmToPx);
    final line = Paint()
      ..color = const Color(0xFF777B7C).withValues(alpha: .54)
      ..strokeWidth = grout;

    for (double x = bounds.left - tileW + offsetX;
        x <= bounds.right + tileW;
        x += tileW) {
      canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), line);
    }
    for (double y = bounds.top - tileH + offsetY;
        y <= bounds.bottom + tileH;
        y += tileH) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), line);
    }

    if (preset.id.contains('marble')) {
      _marbleVeins(canvas, bounds, preset.color);
    } else if (preset.id.contains('terrazzo')) {
      _terrazzo(canvas, bounds, preset.color);
    } else if (preset.id.contains('stone') || preset.id.contains('travertine')) {
      _surfaceNoise(canvas, bounds, preset.color, density: .9);
    } else if (preset.id.contains('concrete')) {
      _surfaceNoise(canvas, bounds, preset.color, density: .65);
    }
  }

  void _brick(Canvas canvas, Rect bounds, Color base) {
    final h = math.max(9.0, 70 * mmToPx);
    final w = math.max(24.0, 240 * mmToPx);
    final line = Paint()
      ..color = Color.lerp(base, Colors.black, .55)!.withValues(alpha: .38)
      ..strokeWidth = .55;
    var row = 0;
    for (double y = bounds.top; y <= bounds.bottom; y += h) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), line);
      final shift = row.isOdd ? w / 2 : 0.0;
      for (double x = bounds.left - w + shift; x <= bounds.right + w; x += w) {
        canvas.drawLine(Offset(x, y), Offset(x, y + h), line);
      }
      row++;
    }
  }

  void _concrete(Canvas canvas, Rect bounds, Color base) {
    _surfaceNoise(canvas, bounds, base, density: 1.1);
    final wash = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < 6; i++) {
      final y = bounds.top + bounds.height * (i + 1) / 7;
      final path = Path()..moveTo(bounds.left, y);
      for (var j = 1; j <= 5; j++) {
        final x = bounds.left + bounds.width * j / 5;
        path.lineTo(x, y + math.sin(i * 1.7 + j) * 3.0);
      }
      canvas.drawPath(path, wash);
    }
  }

  void _surfaceNoise(
    Canvas canvas,
    Rect bounds,
    Color base, {
    required double density,
  }) {
    final area = (bounds.width * bounds.height / 900).clamp(8, 120).round();
    final count = (area * density).round();
    for (var i = 0; i < count; i++) {
      final sx = math.sin(i * 12.9898) * 43758.5453;
      final sy = math.sin(i * 78.233 + 3.7) * 24634.6345;
      final fx = sx - sx.floorToDouble();
      final fy = sy - sy.floorToDouble();
      final p = Offset(
        bounds.left + bounds.width * fx.abs(),
        bounds.top + bounds.height * fy.abs(),
      );
      canvas.drawCircle(
        p,
        .45 + (i % 3) * .25,
        Paint()
          ..color = Color.lerp(base, Colors.black, .48)!
              .withValues(alpha: .10 + (i % 4) * .018),
      );
    }
  }

  void _marbleVeins(Canvas canvas, Rect bounds, Color base) {
    final paint = Paint()
      ..color = Color.lerp(base, const Color(0xFF6F7478), .68)!
          .withValues(alpha: .23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final startY = bounds.top + bounds.height * (i + .6) / 5.6;
      path.moveTo(bounds.left - 8, startY);
      for (var j = 1; j <= 7; j++) {
        final x = bounds.left + bounds.width * j / 7;
        final y = startY + math.sin(i * 2.4 + j * 1.15) * 7;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _terrazzo(Canvas canvas, Rect bounds, Color base) {
    final colors = <Color>[
      Color.lerp(base, Colors.black, .55)!,
      Color.lerp(base, const Color(0xFFB77D69), .45)!,
      Color.lerp(base, const Color(0xFF758794), .50)!,
    ];
    final count = (bounds.width * bounds.height / 550).clamp(16, 110).round();
    for (var i = 0; i < count; i++) {
      final x = bounds.left + bounds.width * ((math.sin(i * 19.4) + 1) / 2);
      final y = bounds.top + bounds.height * ((math.cos(i * 13.7) + 1) / 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 1.2 + (i % 3) * .7,
          height: .9 + ((i + 1) % 3) * .55,
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: .32),
      );
    }
  }

  void _walls(Canvas canvas) {
    for (final wall in floor.walls) {
      final layer = wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
      if (!visibleLayers.contains(layer) || wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pa = _p(a);
      final pb = _p(b);
      final width = math.max(3.8, wall.thicknessMm * mmToPx);
      final selected = wall.id == selectedWallId;
      final color = wall.demolition || wall.projectLayer == ProjectLayer.demolition
          ? ZamerColors.danger
          : selected
              ? ZamerColors.accent
              : wall.projectLayer == ProjectLayer.proposed
                  ? const Color(0xFF5FD189)
                  : const Color(0xFFF0F1ED);

      canvas.drawLine(
        pa + const Offset(1.1, 1.2),
        pb + const Offset(1.1, 1.2),
        Paint()
          ..color = Colors.black.withValues(alpha: .28)
          ..strokeWidth = width + 1.6
          ..strokeCap = StrokeCap.square,
      );
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.square,
      );
      _openings(canvas, wall, pa, pb, width);
    }
  }

  void _openings(
    Canvas canvas,
    PlanWall wall,
    Offset a,
    Offset b,
    double wallWidth,
  ) {
    final length = floor.wallLengthMm(wall);
    if (length <= 0) return;
    final vector = b - a;
    if (vector.distance < 1) return;
    final unit = vector / vector.distance;
    final normal = Offset(-unit.dy, unit.dx);

    for (final opening in wall.openings) {
      final startT = (opening.offsetFromStartMm / length).clamp(0.0, 1.0);
      final endT = ((opening.offsetFromStartMm + opening.widthMm) / length)
          .clamp(0.0, 1.0);
      final p1 = a + vector * startT;
      final p2 = a + vector * endT;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = ZamerColors.background
          ..strokeWidth = wallWidth + 4.2
          ..strokeCap = StrokeCap.square,
      );

      if (opening.type == OpeningType.window) {
        final frame = Paint()
          ..color = const Color(0xFF4CB9F8)
          ..strokeWidth = math.max(1.2, wallWidth * .18)
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(
          p1 + normal * wallWidth * .22,
          p2 + normal * wallWidth * .22,
          frame,
        );
        canvas.drawLine(
          p1 - normal * wallWidth * .22,
          p2 - normal * wallWidth * .22,
          frame,
        );
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xFFB8E4FA).withValues(alpha: .72)
            ..strokeWidth = 1.0,
        );
      } else {
        final hinge = p1;
        final widthPx = (p2 - p1).distance;
        final outside = opening.doorSwing == DoorSwing.leftOut ||
            opening.doorSwing == DoorSwing.rightOut;
        final side = outside ? -1.0 : 1.0;
        final leaf = hinge + normal * widthPx * side;
        final paint = Paint()
          ..color = const Color(0xFFE6E4DE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(hinge, leaf, paint);
        final angle = math.atan2(unit.dy, unit.dx);
        final start = side > 0 ? angle - math.pi / 2 : angle;
        canvas.drawArc(
          Rect.fromCircle(center: hinge, radius: widthPx),
          start,
          math.pi / 2,
          false,
          paint,
        );
      }
    }
  }

  void _objects(Canvas canvas) {
    for (final object in floor.planObjects) {
      if (!visibleLayers.contains(object.layer) || object.elevationMm > 2300) continue;
      TopViewObjectRenderer.draw(
        canvas,
        object,
        center: origin + Offset(object.xMm * mmToPx, object.yMm * mmToPx),
        mmToPx: mmToPx,
      );
    }
  }

  void _roomLabels(Canvas canvas, List<RoomFace> faces) {
    for (final face in faces) {
      final meta = _metaFor(face);
      final center = _q(face.centroid);
      final title = meta?.name.isNotEmpty == true ? meta!.name : 'Помещение';
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$title\n',
              style: const TextStyle(
                color: Color(0xFF1A1D1F),
                fontSize: 9.2,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            TextSpan(
              text: '${face.areaM2.toStringAsFixed(1)} м²',
              style: const TextStyle(
                color: Color(0xFF2D3032),
                fontSize: 7.6,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);

      final box = Rect.fromCenter(
        center: center,
        width: painter.width + 11,
        height: painter.height + 7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFF0ECE4).withValues(alpha: .90),
      );
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
  }

  void _outerDimensions(Canvas canvas) {
    for (final wall in floor.walls) {
      if (wall.type != WallType.exterior || wall.isCurved) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final pa = _p(a);
      final pb = _p(b);
      final vector = pb - pa;
      if (vector.distance < 26) continue;
      final unit = vector / vector.distance;
      final normal = Offset(-unit.dy, unit.dx);
      final offset = 13.0 + wall.thicknessMm * mmToPx / 2;
      final p1 = pa - normal * offset;
      final p2 = pb - normal * offset;
      final paint = Paint()
        ..color = const Color(0xFFE0E2DD).withValues(alpha: .84)
        ..strokeWidth = .72;
      canvas.drawLine(p1, p2, paint);
      canvas.drawLine(p1 - normal * 3.5, p1 + normal * 3.5, paint);
      canvas.drawLine(p2 - normal * 3.5, p2 + normal * 3.5, paint);

      final text = TextPainter(
        text: TextSpan(
          text: '${floor.wallLengthMm(wall).round()}',
          style: const TextStyle(
            color: Color(0xFFF0F1ED),
            fontSize: 7.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final mid = (p1 + p2) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: mid,
            width: text.width + 7,
            height: text.height + 3,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF061217).withValues(alpha: .92),
      );
      text.paint(canvas, Offset(mid.dx - text.width / 2, mid.dy - text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CadPlanPainterV2 oldDelegate) =>
      oldDelegate.floor != floor ||
      oldDelegate.selectedWallId != selectedWallId ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showDimensions != showDimensions ||
      oldDelegate.visibleLayers != visibleLayers;
}
