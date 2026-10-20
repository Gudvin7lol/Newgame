import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/doorway_floor_service.dart';
import '../services/geometry_service.dart';
import '../services/herringbone_layout.dart';
import '../services/material_catalog.dart';
import '../services/plan_visibility_service.dart';
import '../services/room_interior_dimensions_service.dart';
import '../services/space_check_service.dart';
import 'cad_wall_join_geometry.dart';
import 'top_view_object_renderer.dart';

/// UI KIT 02 CAD renderer for +78.
///
/// Floor finishes use the same room material parameters that feed 3D: plank
/// sizes, tile sizes, offsets, direction and layout mode. Furniture is rendered
/// by [TopViewObjectRenderer] with detailed top-view symbols instead of generic
/// rectangles.
/// A renderer can use imported top-view artwork and return true when painted.
/// A false result falls back to the shared vector symbol.
typedef ObjectTopViewPainter = bool Function(
  Canvas canvas,
  PlanObject object,
  Offset center,
  double mmToPx,
);

class CadPlanPainterV2 extends CustomPainter {
  CadPlanPainterV2({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedWallId,
    this.showGrid = true,
    this.showDimensions = true,
    this.drawTopView,
    Set<ProjectLayer>? visibleLayers,
    Set<PlanDisplayLayer>? visibleCategories,
    Set<PlanCollisionKind>? collisionKinds,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet(),
       visibleCategories = visibleCategories ?? (PlanDisplayLayer.values.toSet()
         ..remove(PlanDisplayLayer.axisDimensions)),
       collisionKinds = collisionKinds ?? <PlanCollisionKind>{};

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final bool showGrid;
  final bool showDimensions;
  final ObjectTopViewPainter? drawTopView;
  final Set<ProjectLayer> visibleLayers;
  final Set<PlanDisplayLayer> visibleCategories;
  final Set<PlanCollisionKind> collisionKinds;

  Offset _p(PlanNode n) => origin + Offset(n.xMm * mmToPx, n.yMm * mmToPx);
  Offset _q(math.Point<double> p) => origin + Offset(p.x * mmToPx, p.y * mmToPx);

  @override
  void paint(Canvas canvas, Size size) {
    _background(canvas, size);
    final faces = GeometryService.roomFaces(floor);
    if (visibleCategories.contains(PlanDisplayLayer.floorFinishes)) {
      _rooms(canvas, faces);
    }
    if (visibleCategories.contains(PlanDisplayLayer.walls)) _walls(canvas, faces);
    _objects(canvas);
    if (visibleCategories.contains(PlanDisplayLayer.engineering)) {
      _services(canvas);
    }
    if (visibleCategories.contains(PlanDisplayLayer.electrical)) {
      _electrical(canvas);
    }
    if (visibleCategories.contains(PlanDisplayLayer.roomLabels)) {
      _roomLabels(canvas, faces);
    }
    if (showDimensions) {
      if (visibleCategories.contains(PlanDisplayLayer.dimensions)) {
        _innerDimensions(canvas, faces);
      }
      // Axial labels are engineering reference data. They are opt-in:
      // room measurements always refer to inside corners, not these axes.
      if (visibleCategories.contains(PlanDisplayLayer.axisDimensions)) {
        _outerDimensions(canvas);
      }
      _controlDimensions(canvas);
    }
    if (collisionKinds.isNotEmpty) _collisionOverlay(canvas);
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

  /// Render room finishes beyond the inner wall face so the same board/tile
  /// grid can be replayed inside the wall-thickness doorway patch.
  /// Padding in whole repeat units retains plank/tile phase; even wood rows
  /// preserve the half-board staggering when used.
  Rect _finishRenderBounds(RoomFace face, RoomMaterialSettings settings) {
    final rect = _roomPath(face).getBounds();
    final preset = MaterialCatalog.byId(settings.floorMaterialId);
    final pattern = settings.floorMode == 'tile' ? 'tile' : preset.pattern;
    double repeatPad(double minimum, double repeat) {
      return math.max(2, (minimum / repeat).ceil() + 1) * repeat;
    }
    var padX = 140.0, padY = 140.0;
    if (pattern == 'tile') {
      padX = repeatPad(140, math.max(16, settings.tileWidthMm * mmToPx));
      padY = repeatPad(140, math.max(16, settings.tileHeightMm * mmToPx));
    } else if (pattern == 'wood' &&
        settings.laminatePattern != 'herringbone') {
      final length = math.max(28, settings.laminatePlankLengthMm * mmToPx);
      final width = math.max(8, settings.laminatePlankWidthMm * mmToPx);
      padX = repeatPad(140, length);
      // Keep an even number of board rows to preserve staggered joints.
      padY = (math.max(2, (140 / width).ceil() + 1) / 2).ceil() * 2 * width;
    }
    return Rect.fromLTRB(
      rect.left - padX, rect.top - padY,
      rect.right + padX, rect.bottom + padY,
    );
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
      _drawFinish(canvas, _finishRenderBounds(face, settings), settings, preset);
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

  void _walls(Canvas canvas, List<RoomFace> faces) {
    final bodies = CadWallJoinGeometry.bodies(
      floor: floor,
      mmToPx: mmToPx,
      origin: origin,
      visibleLayers: visibleLayers,
    );
    final all = Path();
    for (final layer in ProjectLayer.values) {
      all.addPath(bodies[layer]!, Offset.zero);
    }
    // One shadow for the union of the bodies. Independent square-ended
    // strokes used to produce black strips and bright bulges at T joints.
    canvas.save();
    canvas.translate(1.1, 1.2);
    canvas.drawPath(
      all,
      Paint()..color = Colors.black.withValues(alpha: .26),
    );
    canvas.restore();

    const colors = <ProjectLayer, Color>{
      ProjectLayer.existing: Color(0xFFF0F1ED),
      ProjectLayer.demolition: ZamerColors.danger,
      ProjectLayer.proposed: Color(0xFF5FD189),
    };
    for (final layer in ProjectLayer.values) {
      if (!visibleLayers.contains(layer)) continue;
      canvas.drawPath(
        bodies[layer]!,
        Paint()..color = colors[layer]!,
      );
    }

    // Selection is a thin centreline highlight, not a full-width orange
    // stroke. A selected 100-mm partition should never conceal its
    // 300-mm host wall or look like an extra thick orange slab.
    if (selectedWallId != null) {
      final wall = floor.wallById(selectedWallId!);
      if (wall != null && !wall.isCurved) {
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a != null && b != null) {
          canvas.drawLine(
            _p(a), _p(b),
            Paint()
              ..color = ZamerColors.accent
              ..strokeWidth = math.max(1.6, wall.thicknessMm * mmToPx * .11)
              ..strokeCap = StrokeCap.butt,
          );
        }
      }
    }

    // Openings are subtracted after the entire wall union has been filled.
    // Drawing them per wall would allow a later adjacent wall to cover an
    // earlier door or window at a junction.
    if (visibleCategories.contains(PlanDisplayLayer.openings)) {
      for (final wall in floor.walls) {
        final layer =
            wall.demolition ? ProjectLayer.demolition : wall.projectLayer;
        if (!visibleLayers.contains(layer) || wall.isCurved) continue;
        final a = floor.nodeById(wall.startNodeId);
        final b = floor.nodeById(wall.endNodeId);
        if (a == null || b == null) continue;
        _openings(
          canvas, wall, _p(a), _p(b),
          math.max(3.8, wall.thicknessMm * mmToPx), faces,
        );
      }
    }
  }

  Color _doorFinishColor(RoomFace? face, Color fallback) {
    if (face == null) return fallback;
    final meta = _metaFor(face);
    final material = MaterialCatalog.byId(
      (meta?.materials ?? RoomMaterialSettings()).floorMaterialId,
    );
    return Color.lerp(material.color, const Color(0xFF11181B), .16)!;
  }

  void _doorwayQuad(
    Canvas canvas,
    Offset a,
    Offset b,
    Offset normal,
    double from,
    double to,
    Color color, {
    RoomFace? face,
  }) {
    final path = Path()
      ..moveTo((a + normal * from).dx, (a + normal * from).dy)
      ..lineTo((b + normal * from).dx, (b + normal * from).dy)
      ..lineTo((b + normal * to).dx, (b + normal * to).dy)
      ..lineTo((a + normal * to).dx, (a + normal * to).dy)
      ..close();
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path, Paint()..color = color);
    if (face != null) {
      // Repaint the *same procedural flooring* (planks, tiles, grout) through
      // the door, using the neighboring room's existing pattern anchor.
      // A flat rectangle here looked like a broken board at every opening.
      final settings = _metaFor(face)?.materials ?? RoomMaterialSettings();
      final preset = MaterialCatalog.byId(settings.floorMaterialId);
      _drawFinish(canvas, _finishRenderBounds(face, settings), settings, preset);
    }
    canvas.restore();
  }

  void _openings(
    Canvas canvas,
    PlanWall wall,
    Offset a,
    Offset b,
    double wallWidth,
    List<RoomFace> faces,
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
      // The old code erased the wall using the dark canvas background,
      // leaving a black bar through every doorway. A cut must instead be
      // painted with the neighboring room's finish.
      final left = p1 - unit * 1.4;
      final right = p2 + unit * 1.4;
      final half = wallWidth / 2 + 2.4;
      if (opening.type == OpeningType.window) {
        _doorwayQuad(
          canvas, left, right, normal, -half, half,
          const Color(0xFFDDE7E9),
        );
        final frame = Paint()
          ..color = const Color(0xFF4CB9F8)
          ..strokeWidth = math.max(1.2, wallWidth * .18)
          ..strokeCap = StrokeCap.butt;
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
          p1, p2,
          Paint()
            ..color = const Color(0xFFB8E4FA).withValues(alpha: .72)
            ..strokeWidth = 1.0,
        );
        continue;
      }

      final adjacent = DoorwayFloorService.roomsByDoor(
        floor, wall, opening, faces,
      );
      final positive = _doorFinishColor(
        adjacent.positive, const Color(0xFFB9B8AE),
      );
      final negative = _doorFinishColor(adjacent.negative, positive);
      final joined = DoorwayFloorService.continuous(
        floor, adjacent.positive, adjacent.negative,
      );
      final split = DoorwayFloorService.jointFromWallAxisMm(
        wall, opening,
      ) * mmToPx;
      // The joint lies 20 mm *inside the doorway* measured from the
      // swing-side wall face, never outside the opening in the room.
      final low = math.min(-half, split - 1);
      final high = math.max(half, split + 1);
      if (joined) {
        final intoPositive = DoorwayFloorService.opensToPositiveSide(
          opening.doorSwing,
        );
        _doorwayQuad(
          canvas, left, right, normal, low, high,
          intoPositive ? negative : positive,
          face: intoPositive ? adjacent.negative : adjacent.positive,
        );
      } else {
        final cut = split.clamp(low, high).toDouble();
        _doorwayQuad(canvas, left, right, normal, low, cut, negative,
            face: adjacent.negative);
        _doorwayQuad(canvas, left, right, normal, cut, high, positive,
            face: adjacent.positive);
        canvas.drawLine(
          left + normal * cut,
          right + normal * cut,
          Paint()
            ..color = const Color(0xFFD3CBC0)
            ..strokeWidth = 1.0,
        );
      }

      final isRight = opening.doorSwing == DoorSwing.rightIn ||
          opening.doorSwing == DoorSwing.rightOut;
      final hinge = isRight ? p2 : p1;
      final closed = isRight ? -unit : unit;
      final side = DoorwayFloorService.opensToPositiveSide(
        opening.doorSwing,
      ) ? 1.0 : -1.0;
      final widthPx = (p2 - p1).distance;
      final leaf = hinge + normal * widthPx * side;
      final paint = Paint()
        ..color = const Color(0xFFE6E4DE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(hinge, leaf, paint);
      final closedAngle = math.atan2(closed.dy, closed.dx);
      final openAngle = math.atan2(normal.dy * side, normal.dx * side);
      var sweep = openAngle - closedAngle;
      while (sweep > math.pi) { sweep -= 2 * math.pi; }
      while (sweep < -math.pi) { sweep += 2 * math.pi; }
      canvas.drawArc(
        Rect.fromCircle(center: hinge, radius: widthPx),
        closedAngle, sweep, false, paint,
      );
    }
  }

  void _objects(Canvas canvas) {
    for (final object in floor.planObjects) {
      final category = switch (object.type) {
        PlanObjectType.furniture => PlanDisplayLayer.furniture,
        PlanObjectType.sanitary ||
        PlanObjectType.waterPoint ||
        PlanObjectType.drainPoint => PlanDisplayLayer.sanitary,
        PlanObjectType.radiator => PlanDisplayLayer.engineering,
        PlanObjectType.lighting => PlanDisplayLayer.electrical,
        _ => PlanDisplayLayer.structures,
      };
      if (!visibleCategories.contains(category) ||
          !visibleLayers.contains(object.layer) || object.elevationMm > 2300) {
        continue;
      }
      final center = origin + Offset(object.xMm * mmToPx, object.yMm * mmToPx);
      // Paint only one representation per object, in the same draw pass.
      // Room names and dimension chains must remain above furniture artwork.
      if (drawTopView?.call(canvas, object, center, mmToPx) == true) {
        continue;
      }
      TopViewObjectRenderer.draw(
        canvas,
        object,
        center: center,
        mmToPx: mmToPx,
      );
    }
  }

  // Draw simple, coordinate-accurate 2D schematic overlays for engineering.
  // They use the same floor coordinates as the production plan and do not
  // change or persist anything in the project.
  void _electrical(Canvas canvas) {
    final pointById = <String, ElectricalPoint>{
      for (final point in floor.electricalPoints) point.id: point,
    };
    final line = Paint()
      ..color = const Color(0xFFEDBD70).withValues(alpha: .8)
      ..strokeWidth = 1.5;
    for (final run in floor.electricalRuns) {
      final a = pointById[run.startPointId];
      final b = pointById[run.endPointId];
      if (a == null || b == null) continue;
      canvas.drawLine(
        _q(math.Point<double>(a.xMm, a.yMm)),
        _q(math.Point<double>(b.xMm, b.yMm)),
        line,
      );
    }
    for (final point in floor.electricalPoints) {
      final center = _q(math.Point<double>(point.xMm, point.yMm));
      canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF0B2227));
      canvas.drawCircle(center, 4, Paint()
        ..color = const Color(0xFFEDBD70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8);
    }
  }

  void _services(Canvas canvas) {
    final colors = <ServiceRunType, Color>{
      ServiceRunType.coldWater: const Color(0xFF39A7F7),
      ServiceRunType.hotWater: const Color(0xFFF56860),
      ServiceRunType.drain: const Color(0xFFB9BCC3),
      ServiceRunType.heating: const Color(0xFFF8AB59),
    };
    for (final run in floor.serviceRuns) {
      if (run.points.length < 2) continue;
      final path = Path();
      final first = run.points.first;
      final start = _q(math.Point<double>(first.xMm, first.yMm));
      path.moveTo(start.dx, start.dy);
      for (final vertex in run.points.skip(1)) {
        final p = _q(math.Point<double>(vertex.xMm, vertex.yMm));
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = colors[run.type] ?? const Color(0xFFB9BCC3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round);
    }
  }

  void _collisionOverlay(Canvas canvas) {
    if (collisionKinds.contains(PlanCollisionKind.doorClearance)) {
      // Quietly show where each leaf sweeps. Actual obstructions get a strong
      // orange warning marker below. This makes the collision zone tangible.
      final tint = const Color(0xFFF6B35B);
      for (final wall in floor.walls) {
        for (final opening in wall.openings) {
          if (opening.type != OpeningType.door) continue;
          final region = SpaceCheckService.doorSwingZone(floor, wall, opening);
          if (region.length < 3) continue;
          final start = _q(region.first);
          final path = Path()..moveTo(start.dx, start.dy);
          for (final p in region.skip(1)) {
            final point = _q(p);
            path.lineTo(point.dx, point.dy);
          }
          path.close();
          canvas.drawPath(path, Paint()
            ..color = tint.withValues(alpha: .055));
          canvas.drawPath(path, Paint()
            ..color = tint.withValues(alpha: .20)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .65);
        }
      }
    }
    for (final issue in PlanCollisionService.inspect(floor)) {
      if (!collisionKinds.contains(issue.kind)) continue;
      final center = _q(issue.position);
      final paint = Paint()
        ..color = issue.kind == PlanCollisionKind.doorClearance
            ? const Color(0xFFF6B35B)
            : const Color(0xFFEF5350);
      canvas.drawCircle(center, 9, Paint()
        ..color = const Color(0xFF0C1B20).withValues(alpha: .95));
      canvas.drawCircle(center, 7.5, paint);
      final text = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
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

  /// Native room size chain. Each line starts and ends at intersections of
  /// real room-side wall faces, including unequal-thickness inner corners.
  /// A split host wall forms one uninterrupted dimension if its inner face
  /// remains collinear across the T-junction.
  void _innerDimensions(Canvas canvas, List<RoomFace> faces) {
    final linePaint = Paint()
      ..color = const Color(0xFF52757A).withValues(alpha: .46)
      ..strokeWidth = .50;
    final capPaint = Paint()
      ..color = const Color(0xFF52757A).withValues(alpha: .56)
      ..strokeWidth = .55;
    for (final dimension in RoomInteriorDimensionsService.forFloor(
      floor, faces: faces,
    )) {
      final a = _q(dimension.start);
      final b = _q(dimension.end);
      final vector = b - a;
      if (vector.distance < 24) continue;

      final tangent = vector / vector.distance;
      // The half-edge traversal keeps the room on its right in screen
      // coordinates; therefore this offset remains on the room side.
      final roomNormal = Offset(-tangent.dy, tangent.dx);
      const marginPx = 10.0;
      final inset = roomNormal * marginPx;
      final p1 = a + inset;
      final p2 = b + inset;

      // Witnesses originate at actual inside corners. The short offset line
      // is only a label/readability aid; its ends are not axis points.
      canvas.drawLine(a + roomNormal * 2.5, p1 + roomNormal * 2.0, linePaint);
      canvas.drawLine(b + roomNormal * 2.5, p2 + roomNormal * 2.0, linePaint);
      canvas.drawLine(p1, p2, linePaint);
      canvas.drawLine(
        p1 - roomNormal * 3,
        p1 + roomNormal * 3,
        capPaint,
      );
      canvas.drawLine(
        p2 - roomNormal * 3,
        p2 + roomNormal * 3,
        capPaint,
      );

      // Distance is calculated in millimetres from the offset polygon and
      // rounded only for display. Saved CAD geometry retains full precision.
      if (vector.distance < 46) continue;
      final text = TextPainter(
        text: TextSpan(
          text: '${dimension.lengthMm.round()}',
          style: const TextStyle(
            color: Color(0xFF456167),
            fontSize: 7.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final center = (p1 + p2) / 2;
      final bg = Rect.fromCenter(
        center: center,
        width: text.width + 9,
        height: text.height + 3.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(2)),
        Paint()..color = const Color(0xFFF3F0E8).withValues(alpha: .82),
      );
      text.paint(
        canvas,
        center - Offset(text.width / 2, text.height / 2),
      );
    }
  }

  void _controlDimensions(Canvas canvas) {
    for (final measure in floor.measures) {
      // A recorded inner-face size and a structural axis size are different
      // types of measurements. Do not show one under the other's filter.
      if (measure.isInterior &&
          !visibleCategories.contains(PlanDisplayLayer.dimensions)) continue;
      if (!measure.isInterior &&
          !visibleCategories.contains(PlanDisplayLayer.axisDimensions)) continue;
      final startNode = floor.nodeById(measure.startNodeId);
      final endNode = floor.nodeById(measure.endNodeId);
      if (startNode == null || endNode == null) continue;
      final p1 = measure.interiorStart ??
          math.Point<double>(startNode.xMm, startNode.yMm);
      final p2 = measure.interiorEnd ??
          math.Point<double>(endNode.xMm, endNode.yMm);
      final a = _q(p1), b = _q(p2);
      if ((b - a).distance < 1) continue;
      final colour = measure.isInterior
          ? const Color(0xFF247EA0)
          : const Color(0xFFDAAC4B);
      final paint = Paint()
        ..color = colour
        ..strokeWidth = .8;
      canvas.drawLine(a, b, paint);
      canvas.drawCircle(a, 2.3, Paint()..color = colour);
      canvas.drawCircle(b, 2.3, Paint()..color = colour);
      final text = TextPainter(
        text: TextSpan(
          text: 'контр. ${measure.measuredMm.round()}',
          style: const TextStyle(
            color: Color(0xFF14252D),
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final mid = (a + b) / 2;
      final panel = Rect.fromCenter(
        center: mid, width: text.width + 8, height: text.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(panel, const Radius.circular(2)),
        Paint()..color = const Color(0xFFEEF4F5),
      );
      text.paint(
        canvas,
        mid - Offset(text.width / 2, text.height / 2),
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
        ..color = const Color(0xFF96AAA9).withValues(alpha: .48)
        ..strokeWidth = .52;
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
        Paint()..color = const Color(0xFF344F56).withValues(alpha: .60),
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
      oldDelegate.visibleLayers != visibleLayers ||
      oldDelegate.visibleCategories != visibleCategories ||
      oldDelegate.collisionKinds != collisionKinds;
}
