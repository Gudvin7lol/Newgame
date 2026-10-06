import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../services/layout_service.dart';
import '../services/floor_continuity_service.dart';

typedef _TileGrid = ({double w, double h, double x, double y});

class Floor3DPainter extends CustomPainter {
  Floor3DPainter({
    required this.floor,
    required this.rotation,
    required this.tilt,
    required this.zoom,
    this.cutaway = true,
    this.pan = Offset.zero,
    this.walkMode = false,
    this.walkX = 0,
    this.walkY = 0,
  });

  final FloorPlan floor;
  final double rotation;
  final double tilt;
  final double zoom;
  final bool cutaway;
  final Offset pan;
  final bool walkMode;
  final double walkX, walkY;
  double _walkFocal = 400;
  List<RoomFace> _carpetRooms = const [];
  List<RoomFace> _rooms = const [];

  double _forward(_P3 p) =>
      (p.x - walkX) * math.sin(rotation) + (p.y - walkY) * math.cos(rotation);

  List<_P3> _visiblePolygon(List<_P3> polygon) {
    if (!walkMode || polygon.isEmpty) return polygon;
    const near = 100.0;
    final result = <_P3>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final da = _forward(a), db = _forward(b);
      if (da >= near) result.add(a);
      if ((da < near) != (db < near)) {
        final t = (near - da) / (db - da);
        result.add(
          _P3(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t,
          ),
        );
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // A first-person view uses a wider field of view than the overview.
    // Clip the scene so near-plane walls cannot cover the app chrome.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _walkFocal = size.shortestSide * 0.62;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2F4F7),
    );
    if (floor.walls.isEmpty) {
      canvas.restore();
      return;
    }

    GeometryService.inferLegacyArcGroups(floor);
    GeometryService.syncRoomMetadata(floor);
    final roomFaces = GeometryService.roomFaces(floor);
    _rooms = roomFaces;
    final tiledWallIds = <String>{};
    final wallMaterialById = <String, String>{};
    final wallBaseMaterialById = <String, String>{};
    final wallSurfaces =
        <
          String,
          ({
            String materialId,
            String baseId,
            bool tiled,
            _TileGrid? grid,
            double from,
            double to,
          })
        >{};
    final faces = <_Face>[];
    for (final room in roomFaces) {
      if (room.innerPolygon.length < 3) continue;
      final meta = floor.roomMetaByKey(room.key);
      final settings = meta?.materials;
      final isTileFloor =
          settings?.floorTile == true || settings?.floorMode == 'tile';
      faces.add(
        _Face(
          LayoutService.finishPolygon(
            room,
          ).map((p) => _P3(p.x, p.y, 0)).toList(),
          isTileFloor ? 6 : 5,
          materialId: settings?.floorMaterialId,
          tileGrid: isTileFloor && settings != null
              ? (
                  w: settings.tileWidthMm,
                  h: settings.tileHeightMm,
                  x: settings.tileOffsetXMm,
                  y: settings.tileOffsetYMm,
                )
              : null,
          floorRoom: room,
          floorSettings: settings,
        ),
      );
      if (settings != null) {
        final runs = GeometryService.elevationRuns(floor, room);
        for (final run in runs) {
          final tiled = settings.wallTileEnabledFor(run.id);
          for (final edge in run.edges) {
            final wall = floor.wallById(edge.wallId);
            if (wall != null) {
              wallBaseMaterialById.putIfAbsent(
                wall.id,
                () => settings.wallMaterialId,
              );
              final sameDirection = edge.fromNodeId == wall.startNodeId;
              // The first long face of _wallPiecePoints is on the + normal
              // (left in model coordinates). Positive screen-area rooms lie
              // there when this edge follows the stored wall direction.
              final insidePlus = (room.signedAreaMm2 > 0) == sameDirection;
              wallSurfaces['${wall.id}:${insidePlus ? 0 : 2}'] = (
                materialId: tiled
                    ? settings.wallTileMaterialId
                    : settings.wallMaterialId,
                tiled: tiled,
                baseId: settings.wallMaterialId,
                from: settings.wallTileFromMm,
                to: settings.wallTileToMm,
                grid: tiled
                    ? (
                        w: settings.wallTileWidthMm,
                        h: settings.wallTileHeightMm,
                        x: settings.wallTileXFor(run.id),
                        y: settings.wallTileYFor(run.id),
                      )
                    : null,
              );
            }
            wallMaterialById.putIfAbsent(
              edge.wallId,
              () =>
                  tiled ? settings.wallTileMaterialId : settings.wallMaterialId,
            );
            if (tiled) tiledWallIds.add(edge.wallId);
          }
        }
      }
    }

    final carpetRooms = roomFaces
        .where(
          (room) =>
              floor.carpetRoomIds.contains(floor.roomMetaByKey(room.key)?.id),
        )
        .toList();
    _carpetRooms = carpetRooms;
    if (carpetRooms.length > 1) {
      final settings = floor.roomMetaByKey(carpetRooms.first.key)?.materials;
      if (settings != null) {
        final tiled = settings.floorTile || settings.floorMode == 'tile';
        for (final polygon in FloorContinuityService.doorThresholds(
          floor,
          carpetRooms,
        )) {
          faces.add(
            _Face(
              polygon.map((p) => _P3(p.x, p.y, 0)).toList(),
              tiled ? 6 : 5,
              materialId: settings.floorMaterialId,
              tileGrid: tiled
                  ? (
                      w: settings.tileWidthMm,
                      h: settings.tileHeightMm,
                      x: settings.tileOffsetXMm,
                      y: settings.tileOffsetYMm,
                    )
                  : null,
              floorRoom: carpetRooms.first,
              floorSettings: settings,
            ),
          );
        }
      }
    }

    final hiddenWallIds = cutaway ? _cutawayWallIds() : <String>{};
    final pieces = <_Piece>[];
    final doneCurves = <String>{};

    for (final wall in floor.walls) {
      if (hiddenWallIds.contains(wall.id)) continue;
      final kind =
          (wall.demolition || wall.projectLayer == ProjectLayer.demolition)
          ? 2
          : (tiledWallIds.contains(wall.id) ? 1 : 0);
      if (wall.isCurved) {
        final groupId = wall.curveGroupId!;
        if (doneCurves.contains(groupId)) continue;
        doneCurves.add(groupId);
        final grouped = floor.walls
            .where(
              (w) => w.curveGroupId == groupId && !hiddenWallIds.contains(w.id),
            )
            .toList();
        if (grouped.isEmpty) continue;
        final hasOpenings = grouped.any((w) => w.openings.isNotEmpty);
        if (!hasOpenings) {
          final pts = GeometryService.smoothCurvePoints(
            floor,
            groupId,
            stepMm: 28,
          );
          if (pts.length >= 2) {
            final thickness = grouped.first.thicknessMm;
            final height = grouped
                .map((w) => w.heightOverrideMm ?? floor.defaultHeightMm)
                .fold<double>(0, (a, b) => math.max(a, b).toDouble());
            final groupKind =
                grouped.any(
                  (w) =>
                      w.demolition || w.projectLayer == ProjectLayer.demolition,
                )
                ? 2
                : (grouped.any((w) => tiledWallIds.contains(w.id)) ? 1 : 0);
            for (var i = 0; i < pts.length - 1; i++) {
              pieces.add(
                _wallPiecePoints(
                  pts[i],
                  pts[i + 1],
                  thickness,
                  0,
                  height,
                  kind: groupKind,
                  materialId: wallMaterialById[grouped.first.id],
                  wallId: grouped.first.id,
                  outline: false,
                ),
              );
            }
            continue;
          }
        }
        for (final w in grouped) {
          final k = (w.demolition || w.projectLayer == ProjectLayer.demolition)
              ? 2
              : (tiledWallIds.contains(w.id) ? 1 : 0);
          _appendWallPieces(
            pieces,
            w,
            kind: k,
            materialId: wallMaterialById[w.id],
          );
        }
        continue;
      }
      _appendWallPieces(
        pieces,
        wall,
        kind: kind,
        materialId: wallMaterialById[wall.id],
      );
    }

    _appendOpeningModels(pieces, hiddenWallIds);

    for (final node in floor.nodes) {
      final connected = floor.walls
          .where(
            (w) =>
                !hiddenWallIds.contains(w.id) &&
                (w.startNodeId == node.id || w.endNodeId == node.id),
          )
          .toList();
      if (connected.length < 2) continue;
      if (connected.length == 2 &&
          connected[0].curveGroupId != null &&
          connected[0].curveGroupId == connected[1].curveGroupId)
        continue;
      var width = 0.0;
      var height = floor.defaultHeightMm;
      for (final w in connected) {
        width = math.max(width, w.thicknessMm);
        height = math.max(height, w.heightOverrideMm ?? floor.defaultHeightMm);
      }
      final kind =
          connected.any(
            (w) => w.demolition || w.projectLayer == ProjectLayer.demolition,
          )
          ? 2
          : (connected.any((w) => tiledWallIds.contains(w.id)) ? 1 : 0);
      pieces.add(
        _junctionPiece(
          node,
          width,
          height,
          kind: kind,
          materialId: connected.isEmpty
              ? null
              : wallMaterialById[connected.first.id],
        ),
      );
    }

    _appendPlanObjects(pieces);
    for (final piece in pieces)
      faces.addAll(_faces(piece, wallSurfaces, wallBaseMaterialById));

    final projected = <_ProjectedFace>[];
    for (final face in faces) {
      final visible = _visiblePolygon(face.points);
      if (visible.length < 3) continue;
      final pts = visible.map(_project3).toList();
      final depth =
          visible.fold<double>(0, (s, p) => s + _depth(p)) / visible.length;
      projected.add(
        _ProjectedFace(
          points: pts,
          depth: depth,
          lighting: _lighting(face.points),
          shade: face.shade,
          materialId: face.materialId,
          color: face.color,
          outline: face.outline,
          tileGrid: face.tileGrid,
          tileFromMm: face.tileFromMm,
          tileToMm: face.tileToMm,
          baseMaterialId: face.baseMaterialId,
          worldZ0Mm: face.points.map((p) => p.z).reduce(math.min),
          worldZ1Mm: face.points.map((p) => p.z).reduce(math.max),
          worldWidthMm: _length3(face.points[0], face.points[1]),
          worldHeightMm: face.points.length == 4
              ? _length3(face.points[0], face.points[3])
              : 0,
          floorRoom: face.floorRoom,
          floorSettings: face.floorSettings,
          vertexDepths: visible.map(_depth).toList(),
        ),
      );
    }
    projected.sort((a, b) => a.depth.compareTo(b.depth));

    // A wall disappearing in cutaway mode must not change the camera scale or
    // center. Build the viewport from the complete, persistent model extent.
    final cameraPoints = <Offset>[];
    final maxHeight = math.max(
      floor.defaultHeightMm,
      floor.walls.fold<double>(
        0,
        (h, w) => math.max(h, w.heightOverrideMm ?? 0),
      ),
    );
    for (final node in floor.nodes) {
      cameraPoints.add(_project3(_P3(node.xMm, node.yMm, 0)));
      cameraPoints.add(_project3(_P3(node.xMm, node.yMm, maxHeight)));
    }
    for (final object in floor.planObjects) {
      final radius =
          math.sqrt(
            object.widthMm * object.widthMm + object.depthMm * object.depthMm,
          ) /
          2;
      for (final x in [object.xMm - radius, object.xMm + radius]) {
        for (final y in [object.yMm - radius, object.yMm + radius]) {
          cameraPoints.add(_project3(_P3(x, y, object.elevationMm)));
          cameraPoints.add(
            _project3(_P3(x, y, object.elevationMm + object.heightMm)),
          );
        }
      }
    }
    for (final ep in floor.electricalPoints) {
      cameraPoints.add(_project3(_P3(ep.xMm, ep.yMm, ep.heightMm)));
    }
    final bounds = _bounds(
      cameraPoints.isEmpty
          ? projected.expand((e) => e.points).toList()
          : cameraPoints,
    );
    final scale = walkMode
        ? zoom
        : bounds.width <= 0 || bounds.height <= 0
        ? 1.0
        : math.min(
                (size.width - 40) / bounds.width,
                (size.height - 40) / bounds.height,
              ) *
              zoom;
    final center = Offset(size.width / 2, size.height / 2) + pan;
    final modelCenter = walkMode ? Offset.zero : bounds.center;
    final screenFaces = projected
        .map(
          (face) => face.points
              .map((p) => center + (p - modelCenter) * scale)
              .toList(),
        )
        .toList();
    final visibility = _DepthVisibility(
      screenFaces,
      projected.map((face) => face.vertexDepths).toList(),
      size,
      perspective: walkMode,
    );

    final markers =
        floor.electricalPoints
            .where((ep) => _electricalVisible(ep, hiddenWallIds))
            .map((ep) => (point: ep, depth: _depth(_electricalPosition(ep))))
            .toList()
          ..sort((a, b) => a.depth.compareTo(b.depth));
    var markerIndex = 0;
    void drawMarker(ElectricalPoint ep) {
      final q0 = _project3(_electricalPosition(ep));
      _electricalMarker(canvas, center + (q0 - modelCenter) * scale, ep, scale);
    }

    for (var faceIndex = 0; faceIndex < projected.length; faceIndex++) {
      final face = projected[faceIndex];
      while (markerIndex < markers.length &&
          markers[markerIndex].depth < face.depth) {
        drawMarker(markers[markerIndex++].point);
      }
      if (face.points.length < 3) continue;
      final pts = screenFaces[faceIndex];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.save();
      canvas.clipPath(visibility.masks[faceIndex]);
      final fallback = switch (face.shade) {
        0 => const Color(0xFFD9DEE5),
        1 => const Color(0xFFC7CDD6),
        2 => const Color(0xFFE8EBEF),
        4 => const Color(0xFFDDE8EA),
        5 => const Color(0xFFE5DDD1),
        6 => const Color(0xFFE8EAED),
        7 => const Color(0xFFE8B0B6),
        _ => const Color(0xFFF4F0E8),
      };
      final base =
          face.color ??
          (face.shade == 7 || face.materialId == null
              ? fallback
              : MaterialCatalog.byId(
                  face.baseMaterialId ?? face.materialId!,
                ).color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(const Color(0xFF202830), base, face.lighting)!,
      );
      if (face.floorRoom != null &&
          face.floorSettings?.floorMode == 'laminate') {
        if (face.floorSettings?.laminatePattern == 'herringbone') {
          _drawHerringboneFloor(
            canvas,
            path,
            face.floorRoom!,
            face.floorSettings!,
            center,
            modelCenter,
            scale,
          );
        } else {
          _drawStraightFloor(
            canvas,
            path,
            face.floorRoom!,
            face.floorSettings!,
            center,
            modelCenter,
            scale,
          );
        }
      }
      if (face.tileGrid != null &&
          face.tileFromMm != null &&
          face.worldZ1Mm > face.worldZ0Mm &&
          pts.length == 4) {
        final h = face.worldZ1Mm - face.worldZ0Mm;
        final t0 = ((face.tileFromMm! - face.worldZ0Mm) / h).clamp(0.0, 1.0);
        final t1 = ((face.tileToMm! - face.worldZ0Mm) / h).clamp(0.0, 1.0);
        if (t1 > t0) {
          final a = Offset.lerp(pts[0], pts[3], t0)!;
          final b = Offset.lerp(pts[1], pts[2], t0)!;
          final c = Offset.lerp(pts[1], pts[2], t1)!;
          final d = Offset.lerp(pts[0], pts[3], t1)!;
          final tilePath = Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(c.dx, c.dy)
            ..lineTo(d.dx, d.dy)
            ..close();
          canvas.drawPath(
            tilePath,
            Paint()..color = MaterialCatalog.byId(face.materialId!).color,
          );
          _drawMaterialTexture(
            canvas,
            tilePath,
            [a, b, c, d],
            face.materialId!,
            face.tileGrid,
            face.worldWidthMm,
            h * (t1 - t0),
          );
        }
      } else if (face.materialId != null &&
          !(face.floorRoom != null &&
              face.floorSettings?.floorMode == 'laminate')) {
        _drawMaterialTexture(
          canvas,
          path,
          pts,
          face.materialId!,
          face.tileGrid,
          face.worldWidthMm,
          face.worldHeightMm,
        );
      }
      if (face.outline) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF7B838D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
      if (face.shade == 7) _demoHatch(canvas, path, pts);
      canvas.restore();
    }

    while (markerIndex < markers.length)
      drawMarker(markers[markerIndex++].point);
    canvas.restore();
  }

  void _drawHerringboneFloor(
    Canvas canvas,
    Path roomPath,
    RoomFace room,
    RoomMaterialSettings settings,
    Offset center,
    Offset modelCenter,
    double scale,
  ) {
    final l = settings.laminatePlankLengthMm;
    final w = settings.laminatePlankWidthMm;
    if (l < 100 || w < 40) return;
    final grouped = floor.carpetRoomIds.contains(
      floor.roomMetaByKey(room.key)?.id,
    );
    final anchor = grouped
        ? math.Point<double>(floor.carpetAnchorX, floor.carpetAnchorY)
        : room.centroid;
    final b = grouped
        ? LayoutService.groupBounds(
            _carpetRooms,
            settings.floorDirectionDeg,
            anchor,
          )
        : LayoutService.localBounds(room, settings.floorDirectionDeg);
    final run = l / math.sqrt2, pitch = w * math.sqrt2;
    final ox = settings.laminateOffsetXMm % run;
    final oy = settings.laminateOffsetYMm % pitch;
    final angle = settings.floorDirectionDeg * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    final c = anchor;
    Offset project(double x, double y) {
      // Both localBounds and groupBounds are relative to their anchor.
      final world = _P3(c.x + x * ca - y * sa, c.y + x * sa + y * ca, 3);
      return center + (_project3(world) - modelCenter) * scale;
    }

    final outline = Paint()
      ..color = const Color(0xFF8E806F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final fillA = Paint()..color = const Color(0xFFE3D7C5);
    final fillB = Paint()..color = const Color(0xFFD4C6B3);
    canvas.save();
    canvas.clipPath(roomPath);
    var count = 0;
    final firstRow = ((b.minY - run - oy) / pitch).floor();
    final lastRow = ((b.maxY + run - oy) / pitch).ceil();
    final firstCol = ((b.minX - run - ox) / run).floor();
    final lastCol = ((b.maxX + run - ox) / run).ceil();
    for (var row = firstRow; row <= lastRow && count < 30000; row++) {
      final y = row * pitch + oy;
      for (var col = firstCol; col <= lastCol && count < 30000; col++) {
        final x = col * run + ox;
        final y0 = y + (col.isOdd ? run : 0);
        final y1 = y + (col.isOdd ? 0 : run);
        final p0 = project(x, y0), p1 = project(x + run, y1);
        final p2 = project(x + run, y1 + pitch), p3 = project(x, y0 + pitch);
        final board = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();
        canvas.drawPath(board, col.isOdd ? fillA : fillB);
        canvas.drawPath(board, outline);
        count++;
      }
    }
    canvas.restore();
  }

  void _drawStraightFloor(
    Canvas canvas,
    Path roomPath,
    RoomFace room,
    RoomMaterialSettings settings,
    Offset center,
    Offset modelCenter,
    double scale,
  ) {
    final l = settings.laminatePlankLengthMm;
    final w = settings.laminatePlankWidthMm;
    if (l < 100 || w < 40) return;
    final grouped = floor.carpetRoomIds.contains(
      floor.roomMetaByKey(room.key)?.id,
    );
    final anchor = grouped
        ? math.Point<double>(floor.carpetAnchorX, floor.carpetAnchorY)
        : room.centroid;
    final b = grouped
        ? LayoutService.groupBounds(
            _carpetRooms,
            settings.floorDirectionDeg,
            anchor,
          )
        : LayoutService.localBounds(room, settings.floorDirectionDeg);
    final a = settings.floorDirectionDeg * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    Offset project(double x, double y) {
      final world = _P3(
        anchor.x + x * ca - y * sa,
        anchor.y + x * sa + y * ca,
        3,
      );
      return center + (_project3(world) - modelCenter) * scale;
    }

    final ox = settings.laminateOffsetXMm % l;
    final oy = settings.laminateOffsetYMm % w;
    final outline = Paint()
      ..color = const Color(0xFF918575)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    final shades = [
      Paint()..color = const Color(0xFFE2D3BE),
      Paint()..color = const Color(0xFFD9C8B0),
      Paint()..color = const Color(0xFFE8DAC8),
    ];
    canvas.save();
    canvas.clipPath(roomPath);
    var count = 0;
    for (
      var row = ((b.minY - w - oy) / w).floor();
      row <= ((b.maxY + w - oy) / w).ceil() && count < 30000;
      row++
    ) {
      final y = row * w + oy;
      final shift = settings.laminateOffsetMode == 'half'
          ? (row.isOdd ? l / 2 : 0.0)
          : settings.laminateOffsetMode == 'third'
          ? ((row % 3 + 3) % 3) * l / 3
          : 0.0;
      for (
        var col = ((b.minX - l - ox - shift) / l).floor();
        col <= ((b.maxX + l - ox - shift) / l).ceil() && count < 30000;
        col++
      ) {
        final x = col * l + ox + shift;
        final pts = [
          project(x, y),
          project(x + l, y),
          project(x + l, y + w),
          project(x, y + w),
        ];
        final board = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (final point in pts.skip(1)) board.lineTo(point.dx, point.dy);
        board.close();
        canvas.drawPath(board, shades[(row + col).abs() % shades.length]);
        canvas.drawPath(board, outline);
        count++;
      }
    }
    canvas.restore();
  }

  double _length3(_P3 a, _P3 b) => math.sqrt(
    math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2),
  );

  double _lighting(List<_P3> vertices) {
    if (vertices.length < 3) return 1;
    final a = vertices[0], b = vertices[1], c = vertices[2];
    final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
    final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
    final nx = uy * vz - uz * vy;
    final ny = uz * vx - ux * vz;
    final nz = ux * vy - uy * vx;
    final length = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (length < .0001) return .85;
    final diffuse = (nx * -.42 + ny * -.38 + nz * .82) / length;
    return (.78 + .21 * diffuse.clamp(0.0, 1.0)).clamp(.78, .99).toDouble();
  }

  void _drawMaterialTexture(
    Canvas canvas,
    Path path,
    List<Offset> pts,
    String materialId,
    _TileGrid? grid,
    double widthMm,
    double heightMm,
  ) {
    if (pts.length != 4) return;
    final preset = MaterialCatalog.byId(materialId);
    final line = Paint()
      ..color = const Color(0xFF5F6670).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55;
    Offset lerp(Offset a, Offset b, double t) => a + (b - a) * t;
    canvas.save();
    canvas.clipPath(path);
    if (preset.pattern == 'wood') {
      for (var i = 1; i < 9; i++) {
        final t = i / 9;
        canvas.drawLine(lerp(pts[0], pts[3], t), lerp(pts[1], pts[2], t), line);
      }
      for (var i = 1; i < 4; i++) {
        final t = i / 4;
        final a = lerp(pts[0], pts[1], t);
        final b = lerp(pts[3], pts[2], t);
        canvas.drawLine(a, b, line..strokeWidth = 0.35);
      }
    } else if (preset.pattern == 'tile') {
      final w = math.max(1.0, grid?.w ?? 600);
      final h = math.max(1.0, grid?.h ?? 300);
      final x = (grid?.x ?? 0) % w;
      final y = (grid?.y ?? 0) % h;
      for (var k = 0; k < 160; k++) {
        final at = x + k * w;
        if (at >= widthMm) break;
        if (at <= 1 || widthMm <= 0) continue;
        final t = at / widthMm;
        canvas.drawLine(lerp(pts[0], pts[1], t), lerp(pts[3], pts[2], t), line);
      }
      for (var k = 0; k < 160; k++) {
        final at = y + k * h;
        if (at >= heightMm) break;
        if (at <= 1 || heightMm <= 0) continue;
        final t = at / heightMm;
        canvas.drawLine(lerp(pts[0], pts[3], t), lerp(pts[1], pts[2], t), line);
      }
    } else if (preset.pattern == 'brick') {
      for (var row = 1; row < 6; row++) {
        final t = row / 6;
        final a = lerp(pts[0], pts[3], t);
        final b = lerp(pts[1], pts[2], t);
        canvas.drawLine(a, b, line);
      }
      for (var col = 1; col < 5; col++) {
        final t = col / 5;
        canvas.drawLine(
          lerp(pts[0], pts[1], t),
          lerp(pts[3], pts[2], t),
          line..strokeWidth = 0.4,
        );
      }
    } else if (preset.pattern == 'concrete') {
      final b = path.getBounds();
      for (var i = 0; i < 24; i++) {
        final x = b.left + ((i * 37) % 97) / 97 * b.width;
        final y = b.top + ((i * 53) % 89) / 89 * b.height;
        canvas.drawCircle(
          Offset(x, y),
          0.7,
          Paint()..color = const Color(0xFF555B63).withValues(alpha: 0.14),
        );
      }
    }
    canvas.restore();
  }

  void _gridOnFace(Canvas canvas, Path path, List<Offset> pts) {
    final b = path.getBounds();
    canvas.save();
    canvas.clipPath(path);
    final line = Paint()
      ..color = const Color(0xFFADB5BD)
      ..strokeWidth = 0.55;
    const step = 18.0;
    for (double x = b.left; x < b.right; x += step)
      canvas.drawLine(Offset(x, b.top), Offset(x, b.bottom), line);
    for (double y = b.top; y < b.bottom; y += step)
      canvas.drawLine(Offset(b.left, y), Offset(b.right, y), line);
    canvas.restore();
  }

  void _boardsOnFace(Canvas canvas, Path path, List<Offset> pts) {
    final b = path.getBounds();
    canvas.save();
    canvas.clipPath(path);
    final line = Paint()
      ..color = const Color(0xFFC1B6A7)
      ..strokeWidth = 0.55;
    const step = 14.0;
    for (double y = b.top; y < b.bottom; y += step) {
      canvas.drawLine(Offset(b.left, y), Offset(b.right, y), line);
    }
    canvas.restore();
  }

  void _demoHatch(Canvas canvas, Path path, List<Offset> pts) {
    final b = path.getBounds();
    canvas.save();
    canvas.clipPath(path);
    final line = Paint()
      ..color = const Color(0xFFB74754)
      ..strokeWidth = 0.8;
    for (double x = b.left - b.height; x < b.right; x += 14) {
      canvas.drawLine(Offset(x, b.bottom), Offset(x + b.height, b.top), line);
    }
    canvas.restore();
  }

  Offset _electricalAxis(ElectricalPoint p) {
    if (p.frameVertical) {
      var axis =
          _project3(const _P3(0, 0, 120)) - _project3(const _P3(0, 0, 0));
      if (axis.distance < .1) axis = const Offset(0, 1);
      return axis / axis.distance;
    }
    final wall = p.wallId == null ? null : floor.wallById(p.wallId!);
    if (wall != null) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a != null && b != null) {
        var axis =
            _project3(_P3(b.xMm, b.yMm, p.heightMm)) -
            _project3(_P3(a.xMm, a.yMm, p.heightMm));
        if (axis.distance >= .1) return axis / axis.distance;
      }
    }
    return const Offset(1, 0);
  }

  _P3 _electricalPosition(ElectricalPoint p) {
    final wall = p.wallId == null ? null : floor.wallById(p.wallId!);
    final a = wall == null ? null : floor.nodeById(wall.startNodeId);
    final b = wall == null ? null : floor.nodeById(wall.endNodeId);
    if (wall == null || a == null || b == null) {
      return _P3(p.xMm, p.yMm, p.heightMm);
    }
    final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return _P3(p.xMm, p.yMm, p.heightMm);
    final distance = p.wallSide * (wall.thicknessMm / 2 + 5);
    return _P3(
      p.xMm - dy / length * distance,
      p.yMm + dx / length * distance,
      p.heightMm,
    );
  }

  bool _electricalVisible(ElectricalPoint point, Set<String> hiddenWalls) {
    final position = _electricalPosition(point);
    if (walkMode && _forward(position) < 100) return false;
    final wall = point.wallId == null ? null : floor.wallById(point.wallId!);
    if (wall == null || hiddenWalls.contains(wall.id)) return true;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return true;
    final nx = -(b.yMm - a.yMm) * point.wallSide;
    final ny = (b.xMm - a.xMm) * point.wallSide;
    final vx = walkMode ? walkX - point.xMm : math.sin(rotation);
    final vy = walkMode ? walkY - point.yMm : math.cos(rotation);
    return nx * vx + ny * vy > 0;
  }

  void _electricalMarker(
    Canvas canvas,
    Offset q,
    ElectricalPoint p,
    double scale,
  ) {
    final border = Paint()
      ..color = const Color(0xFF9E5B47).withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final fill = Paint()
      ..color = const Color(0xFFF8F5F2).withValues(alpha: 0.88);
    final axis = _electricalAxis(p);
    // The second axis is the projected wall height. A screen-space
    // perpendicular makes sockets turn like billboards as the camera moves.
    var vertical =
        _project3(const _P3(0, 0, 120)) - _project3(const _P3(0, 0, 0));
    if (vertical.distance < .1) vertical = const Offset(0, -1);
    vertical /= vertical.distance;
    final normal = p.frameVertical
        ? (p.wallId == null ? const Offset(1, 0) : _wallHorizontalAxis(p))
        : vertical;
    final modules = p.modules.isEmpty
        ? const <ElectricalModuleType>[ElectricalModuleType.socket220]
        : p.modules;

    if (p.type == ElectricalPointType.frame || modules.length > 1) {
      const module = 6.0;
      const gap = 1.0;
      final total = modules.length * module + (modules.length - 1) * gap + 3;
      final halfH = module / 2 + 1.8;
      final a = q - axis * (total / 2) - normal * halfH;
      final b = q + axis * (total / 2) - normal * halfH;
      final c = q + axis * (total / 2) + normal * halfH;
      final d = q - axis * (total / 2) + normal * halfH;
      final frame = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      canvas.drawPath(frame, fill);
      canvas.drawPath(frame, border);
      final first = q - axis * ((modules.length - 1) * (module + gap) / 2);
      for (var i = 0; i < modules.length; i++) {
        final center = first + axis * (i * (module + gap));
        canvas.drawCircle(center, 1.8, border);
      }
      return;
    }

    if (p.isWallDevice) {
      final halfW = p.type == ElectricalPointType.wallLight ? 4.0 : 3.2;
      final halfH = p.type == ElectricalPointType.wallLight ? 2.8 : 2.2;
      final a = q - axis * halfW - normal * halfH;
      final b = q + axis * halfW - normal * halfH;
      final c = q + axis * halfW + normal * halfH;
      final d = q - axis * halfW + normal * halfH;
      final plate = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      canvas.drawPath(plate, fill);
      canvas.drawPath(plate, border);
      return;
    }

    if (p.type == ElectricalPointType.ceilingLight) {
      canvas.drawCircle(q, 3.2, fill);
      canvas.drawCircle(q, 3.2, border);
      canvas.drawLine(
        q + const Offset(-2.2, 0),
        q + const Offset(2.2, 0),
        border,
      );
      canvas.drawLine(
        q + const Offset(0, -2.2),
        q + const Offset(0, 2.2),
        border,
      );
      return;
    }

    canvas.drawCircle(q, 2.8, fill);
    canvas.drawCircle(q, 2.8, border);
  }

  Offset _wallHorizontalAxis(ElectricalPoint p) {
    final wall = p.wallId == null ? null : floor.wallById(p.wallId!);
    if (wall == null) return const Offset(1, 0);
    final a = floor.nodeById(wall.startNodeId),
        b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return const Offset(1, 0);
    final axis =
        _project3(_P3(b.xMm, b.yMm, p.heightMm)) -
        _project3(_P3(a.xMm, a.yMm, p.heightMm));
    return axis.distance < .1 ? const Offset(1, 0) : axis / axis.distance;
  }

  String _moduleShort(ElectricalModuleType type) => switch (type) {
    ElectricalModuleType.socket220 => '○',
    ElectricalModuleType.switch1 => 'S',
    ElectricalModuleType.switch2 => 'S2',
    ElectricalModuleType.tv => 'TV',
    ElectricalModuleType.data => 'RJ',
    ElectricalModuleType.blank => '·',
  };

  void _appendPlanObjects(List<_Piece> pieces) {
    for (final o in floor.planObjects) {
      final color = _objectColor(o);
      final z0 = math.max(0.0, o.elevationMm).toDouble();
      final z1 = z0 + math.max(20.0, o.heightMm).toDouble();
      final oa = o.rotationDeg * math.pi / 180;
      final oca = math.cos(oa), osa = math.sin(oa);
      void box(
        double dx,
        double dy,
        double w,
        double d,
        double a,
        double b, {
        Color? c,
      }) {
        final rx = dx * oca - dy * osa;
        final ry = dx * osa + dy * oca;
        pieces.add(
          _boxPieceCenter(
            o.xMm + rx,
            o.yMm + ry,
            w,
            d,
            a,
            b,
            o.rotationDeg,
            color: c ?? color,
          ),
        );
      }

      final id = o.catalogId;
      if (id.startsWith('sofa-')) {
        box(
          0,
          60,
          o.widthMm * .82,
          o.depthMm * .62,
          z0 + 120,
          z0 + 300,
          c: const Color(0xFFB7B0A8),
        );
        final seats = id == 'sofa-2' ? 2 : 3;
        for (var i = 0; i < seats; i++) {
          final x = (i + .5) * o.widthMm * .82 / seats - o.widthMm * .41;
          box(
            x,
            70,
            o.widthMm * .82 / seats - 18,
            o.depthMm * .56,
            z0 + 300,
            z0 + o.heightMm * .53,
            c: i.isEven ? const Color(0xFFC6BFB6) : const Color(0xFFBEB7AE),
          );
        }
        box(
          0,
          -o.depthMm * .36,
          o.widthMm * .92,
          o.depthMm * .16,
          z0 + 160,
          z1,
          c: const Color(0xFF9E9891),
        );
        box(
          -o.widthMm * .45,
          0,
          o.widthMm * .10,
          o.depthMm * .76,
          z0 + 100,
          z0 + o.heightMm * .64,
          c: const Color(0xFF9E9891),
        );
        box(
          o.widthMm * .45,
          0,
          o.widthMm * .10,
          o.depthMm * .76,
          z0 + 100,
          z0 + o.heightMm * .64,
          c: const Color(0xFF9E9891),
        );
        for (final x in [-o.widthMm * .39, o.widthMm * .39]) {
          box(
            x,
            o.depthMm * .30,
            70,
            70,
            z0,
            z0 + 120,
            c: const Color(0xFF6D6460),
          );
          box(
            x,
            -o.depthMm * .30,
            70,
            70,
            z0,
            z0 + 120,
            c: const Color(0xFF6D6460),
          );
        }
      } else if (id == 'armchair') {
        box(
          0,
          50,
          o.widthMm * .62,
          o.depthMm * .58,
          z0 + 140,
          z0 + 470,
          c: const Color(0xFFB1ABA4),
        );
        box(
          0,
          -o.depthMm * .34,
          o.widthMm * .78,
          o.depthMm * .16,
          z0 + 200,
          z1,
          c: const Color(0xFF96908A),
        );
        box(
          -o.widthMm * .39,
          0,
          o.widthMm * .14,
          o.depthMm * .72,
          z0 + 150,
          z0 + 610,
          c: const Color(0xFF96908A),
        );
        box(
          o.widthMm * .39,
          0,
          o.widthMm * .14,
          o.depthMm * .72,
          z0 + 150,
          z0 + 610,
          c: const Color(0xFF96908A),
        );
      } else if (id.startsWith('bed-')) {
        box(
          0,
          80,
          o.widthMm,
          o.depthMm * .88,
          z0 + 100,
          z0 + 430,
          c: const Color(0xFFE2DDD5),
        );
        box(
          0,
          -o.depthMm * .47,
          o.widthMm,
          o.depthMm * .06,
          z0,
          z1,
          c: const Color(0xFFB6A48E),
        );
        box(
          -o.widthMm * .22,
          -o.depthMm * .29,
          o.widthMm * .36,
          o.depthMm * .18,
          z0 + 430,
          z0 + 560,
          c: const Color(0xFFF2EEE8),
        );
        box(
          o.widthMm * .22,
          -o.depthMm * .29,
          o.widthMm * .36,
          o.depthMm * .18,
          z0 + 430,
          z0 + 560,
          c: const Color(0xFFF2EEE8),
        );
      } else if (id == 'table-rect') {
        box(
          0,
          0,
          o.widthMm,
          o.depthMm,
          z0 + o.heightMm - 70,
          z1,
          c: const Color(0xFFB58F68),
        );
        for (final sx in [-1.0, 1.0])
          for (final sy in [-1.0, 1.0])
            box(
              sx * o.widthMm * .40,
              sy * o.depthMm * .36,
              55,
              55,
              z0,
              z0 + o.heightMm - 60,
              c: const Color(0xFF765B45),
            );
      } else if (id == 'table-round') {
        // A many-sided top reads as a round table while staying cheap to render.
        for (var i = 0; i < 12; i++) {
          final a0 = 2 * math.pi * i / 12;
          box(
            math.cos(a0) * o.widthMm * .22,
            math.sin(a0) * o.depthMm * .22,
            o.widthMm * .28,
            o.depthMm * .28,
            z0 + o.heightMm - 65,
            z1,
            c: const Color(0xFFB58F68),
          );
        }
        box(
          0,
          0,
          100,
          100,
          z0,
          z0 + o.heightMm - 50,
          c: const Color(0xFF765B45),
        );
      } else if (id == 'chair') {
        box(
          0,
          30,
          o.widthMm * .80,
          o.depthMm * .70,
          z0 + 430,
          z0 + 500,
          c: const Color(0xFFB58F68),
        );
        box(
          0,
          -o.depthMm * .40,
          o.widthMm * .82,
          60,
          z0 + 450,
          z1,
          c: const Color(0xFF9A795B),
        );
        for (final sx in [-1.0, 1.0])
          for (final sy in [-1.0, 1.0])
            box(
              sx * o.widthMm * .32,
              sy * o.depthMm * .28,
              38,
              38,
              z0,
              z0 + 440,
              c: const Color(0xFF765B45),
            );
      } else if (id.startsWith('kitchen-')) {
        box(
          0,
          0,
          o.widthMm,
          o.depthMm,
          z0 + 80,
          z1 - 35,
          c: const Color(0xFFD5C5B2),
        );
        if (id != 'kitchen-upper' && id != 'kitchen-tall') {
          box(
            0,
            0,
            o.widthMm + 20,
            o.depthMm + 35,
            z1 - 35,
            z1,
            c: const Color(0xFF98958E),
          );
          box(
            0,
            o.depthMm * .40,
            o.widthMm * .88,
            40,
            z0,
            z0 + 80,
            c: const Color(0xFF857F76),
          );
        }
        final doorCount = o.widthMm >= 750 ? 2 : 1;
        for (var i = 0; i < doorCount; i++) {
          final x = (i + .5) * o.widthMm / doorCount - o.widthMm / 2;
          box(
            x,
            o.depthMm * .51,
            o.widthMm / doorCount - 18,
            18,
            z0 + 115,
            z1 - 65,
            c: const Color(0xFFE4D8C7),
          );
          box(
            x + o.widthMm / doorCount * .3,
            o.depthMm * .54,
            12,
            24,
            z1 - 180,
            z1 - 130,
            c: const Color(0xFF8E9295),
          );
        }
        if (id == 'kitchen-sink') {
          box(
            0,
            0,
            o.widthMm * .55,
            o.depthMm * .48,
            z1 - 28,
            z1 - 20,
            c: const Color(0xFF7F969E),
          );
          for (final x in [-o.widthMm * .285, o.widthMm * .285]) {
            box(
              x,
              0,
              12,
              o.depthMm * .52,
              z1 - 18,
              z1 + 9,
              c: const Color(0xFFC5CCCE),
            );
          }
          for (final y in [-o.depthMm * .25, o.depthMm * .25]) {
            box(
              0,
              y,
              o.widthMm * .57,
              12,
              z1 - 18,
              z1 + 9,
              c: const Color(0xFFC5CCCE),
            );
          }
          box(
            0,
            -o.depthMm * .14,
            30,
            30,
            z1,
            z1 + 180,
            c: const Color(0xFF8B9296),
          );
          box(
            0,
            -o.depthMm * .06,
            25,
            160,
            z1 + 155,
            z1 + 180,
            c: const Color(0xFF8B9296),
          );
        } else if (id == 'kitchen-oven') {
          box(
            0,
            o.depthMm * .53,
            o.widthMm * .85,
            24,
            z0 + 180,
            z0 + 700,
            c: const Color(0xFF44494B),
          );
          box(
            0,
            o.depthMm * .54,
            o.widthMm * .68,
            26,
            z0 + 240,
            z0 + 590,
            c: const Color(0xFF737E84),
          );
        }
      } else if (id.startsWith('wardrobe-') ||
          id == 'fridge' ||
          id == 'washer' ||
          id == 'dishwasher' ||
          id == 'dryer' ||
          id == 'shelf' ||
          id == 'mirror' ||
          id == 'boiler' ||
          id == 'tv') {
        box(
          0,
          0,
          o.widthMm,
          o.depthMm,
          z0,
          z1,
          c: id.startsWith('wardrobe') || id == 'kitchen-base'
              ? const Color(0xFFC6B39E)
              : const Color(0xFFD5D9DC),
        );
        if (id == 'fridge') {
          final front = o.depthMm * .51;
          box(
            0,
            front,
            o.widthMm * .94,
            18,
            z0 + 70,
            z1 - 50,
            c: const Color(0xFFE7ECEE),
          );
          box(
            0,
            front + 12,
            o.widthMm * .94,
            8,
            z0 + o.heightMm * .34,
            z0 + o.heightMm * .35,
            c: const Color(0xFF8A9499),
          );
          box(
            o.widthMm * .37,
            front + 16,
            18,
            24,
            z0 + o.heightMm * .44,
            z0 + o.heightMm * .70,
            c: const Color(0xFF969FA3),
          );
        } else if (id == 'washer' || id == 'dryer') {
          final front = o.depthMm * .51;
          box(
            0,
            front,
            o.widthMm * .9,
            18,
            z0 + 45,
            z1 - 25,
            c: const Color(0xFFF0F2F3),
          );
          final radius = math.min(o.widthMm * .28, o.heightMm * .27);
          final cz = z0 + o.heightMm * .46;
          box(
            0,
            front + 15,
            radius * 1.28,
            8,
            cz - radius * .60,
            cz + radius * .60,
            c: const Color(0xFF65757B),
          );
          for (var i = 0; i < 16; i++) {
            final theta = 2 * math.pi * i / 16;
            final x = math.cos(theta) * radius;
            final z = cz + math.sin(theta) * radius;
            box(
              x,
              front + 20,
              28,
              12,
              z - 16,
              z + 16,
              c: const Color(0xFFBEC7CB),
            );
          }
          box(
            -o.widthMm * .28,
            front + 20,
            48,
            15,
            z1 - 110,
            z1 - 75,
            c: const Color(0xFF59666D),
          );
        } else if (id.startsWith('wardrobe-')) {
          final front = o.depthMm * .51;
          for (final x in [-o.widthMm * .24, o.widthMm * .24]) {
            box(
              x,
              front,
              o.widthMm * .46,
              18,
              z0 + 55,
              z1 - 35,
              c: const Color(0xFFD2BDA5),
            );
            box(
              x + (x < 0 ? 1.0 : -1.0) * o.widthMm * .16,
              front + 15,
              16,
              20,
              z0 + o.heightMm * .43,
              z0 + o.heightMm * .62,
              c: const Color(0xFF9B8D7D),
            );
          }
        } else if (id == 'tv') {
          box(
            0,
            o.depthMm * .55,
            o.widthMm * .94,
            18,
            z0 + 30,
            z1 - 30,
            c: const Color(0xFF1F2B35),
          );
          box(
            0,
            o.depthMm * .57,
            o.widthMm * .83,
            8,
            z0 + 72,
            z1 - 70,
            c: const Color(0xFF506876),
          );
        }
      } else if (id == 'toilet') {
        box(
          0,
          -o.depthMm * .31,
          o.widthMm * .82,
          o.depthMm * .24,
          z0,
          z0 + 720,
          c: const Color(0xFFF6F7F7),
        );
        box(
          0,
          o.depthMm * .12,
          o.widthMm * .68,
          o.depthMm * .54,
          z0 + 200,
          z0 + 470,
          c: const Color(0xFFF8F9F9),
        );
      } else if (id == 'sink') {
        box(
          0,
          0,
          o.widthMm * .90,
          o.depthMm * .80,
          z0 + 720,
          z1,
          c: const Color(0xFFF7F8F8),
        );
        box(
          0,
          0,
          o.widthMm * .20,
          o.depthMm * .20,
          z0,
          z0 + 720,
          c: const Color(0xFFE4E6E7),
        );
      } else if (id == 'bath') {
        final rim = 70.0;
        box(
          0,
          -o.depthMm / 2 + rim / 2,
          o.widthMm,
          rim,
          z0,
          z1,
          c: const Color(0xFFF5F6F6),
        );
        box(
          0,
          o.depthMm / 2 - rim / 2,
          o.widthMm,
          rim,
          z0,
          z1,
          c: const Color(0xFFF5F6F6),
        );
        box(
          -o.widthMm / 2 + rim / 2,
          0,
          rim,
          o.depthMm - rim * 2,
          z0,
          z1,
          c: const Color(0xFFF5F6F6),
        );
        box(
          o.widthMm / 2 - rim / 2,
          0,
          rim,
          o.depthMm - rim * 2,
          z0,
          z1,
          c: const Color(0xFFF5F6F6),
        );
        box(
          0,
          0,
          o.widthMm - rim * 2,
          o.depthMm - rim * 2,
          z0,
          z0 + 120,
          c: const Color(0xFFDCE9EC),
        );
      } else if (id == 'shower') {
        box(
          0,
          0,
          o.widthMm,
          o.depthMm,
          z0,
          z0 + 80,
          c: const Color(0xFFE2E6E8),
        );
        box(
          -o.widthMm / 2 + 20,
          0,
          40,
          o.depthMm,
          z0 + 80,
          z1,
          c: const Color(0xFFBFD8DF),
        );
        box(
          0,
          -o.depthMm / 2 + 20,
          o.widthMm,
          40,
          z0 + 80,
          z1,
          c: const Color(0xFFBFD8DF),
        );
      } else if (id == 'radiator' || o.type == PlanObjectType.radiator) {
        for (var i = 0; i < 8; i++) {
          final x = -o.widthMm * .44 + o.widthMm * .88 * i / 7;
          box(
            x,
            0,
            o.widthMm * .07,
            o.depthMm,
            z0,
            z1,
            c: const Color(0xFFE8E8E4),
          );
        }
      } else {
        box(0, 0, o.widthMm, o.depthMm, z0, z1);
      }
    }
  }

  Color _objectColor(PlanObject o) {
    if (o.layer == ProjectLayer.demolition) return const Color(0xFFE2A0A8);
    if (o.type == PlanObjectType.sanitary) return const Color(0xFFF0F3F4);
    if (o.type == PlanObjectType.radiator) return const Color(0xFFE5E4DF);
    if (o.type == PlanObjectType.lighting) return const Color(0xFFFFD978);
    if (o.type == PlanObjectType.furniture) return const Color(0xFFC7B49C);
    return o.layer == ProjectLayer.proposed
        ? const Color(0xFFB9C7E8)
        : const Color(0xFFB7BDC3);
  }

  _Piece _boxPieceCenter(
    double cx,
    double cy,
    double width,
    double depth,
    double z0,
    double z1,
    double rotationDeg, {
    Color? color,
  }) {
    final a = rotationDeg * math.pi / 180;
    final ca = math.cos(a), sa = math.sin(a);
    math.Point<double> xy(double x, double y) =>
        math.Point(cx + x * ca - y * sa, cy + x * sa + y * ca);
    final p0 = xy(-width / 2, -depth / 2),
        p1 = xy(width / 2, -depth / 2),
        p2 = xy(width / 2, depth / 2),
        p3 = xy(-width / 2, depth / 2);
    return _Piece(
      [
        _P3(p0.x, p0.y, z0),
        _P3(p1.x, p1.y, z0),
        _P3(p2.x, p2.y, z0),
        _P3(p3.x, p3.y, z0),
        _P3(p0.x, p0.y, z1),
        _P3(p1.x, p1.y, z1),
        _P3(p2.x, p2.y, z1),
        _P3(p3.x, p3.y, z1),
      ],
      8,
      null,
      color,
    );
  }

  void _appendOpeningModels(List<_Piece> pieces, Set<String> hiddenWallIds) {
    for (final wall in floor.walls) {
      if (hiddenWallIds.contains(wall.id) || wall.openings.isEmpty) continue;
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;
      final ux = dx / length, uy = dy / length;
      final angle = math.atan2(dy, dx) * 180 / math.pi;
      for (final o in wall.openings) {
        final width = math.min(o.widthMm, length - o.offsetFromStartMm);
        if (width <= 80) continue;
        final mid = o.offsetFromStartMm + width / 2;
        final x = a.xMm + ux * mid, y = a.yMm + uy * mid;
        final bottom = o.sillHeightMm, top = bottom + o.heightMm;
        final frame = const Color(0xFF9A8070);
        void bar(double along, double z0, double z1, double barWidth) {
          pieces.add(
            _boxPieceCenter(
              x + ux * along,
              y + uy * along,
              barWidth,
              wall.thicknessMm + 16,
              z0,
              z1,
              angle,
              color: frame,
            ),
          );
        }

        bar(-width / 2 + 22, bottom, top, 44);
        bar(width / 2 - 22, bottom, top, 44);
        bar(0, top - 22, top + 22, width);
        if (o.type == OpeningType.window) {
          bar(0, bottom - 18, bottom + 18, width);
          pieces.add(
            _boxPieceCenter(
              x,
              y,
              width - 88,
              12,
              bottom + 20,
              top - 24,
              angle,
              color: const Color(0xFFB9D8E1),
            ),
          );
          bar(0, bottom + 22, top - 22, 36);
        } else {
          final leftHinge =
              o.doorSwing == DoorSwing.leftIn ||
              o.doorSwing == DoorSwing.leftOut;
          final side = leftHinge ? -1.0 : 1.0;
          final opensIn =
              o.doorSwing == DoorSwing.leftIn ||
              o.doorSwing == DoorSwing.rightIn;
          final swung = angle + (opensIn ? 28 : -28) * side;
          final radians = swung * math.pi / 180;
          final hingeX = x + ux * side * (width / 2 - 30);
          final hingeY = y + uy * side * (width / 2 - 30);
          final leafWidth = width - 70;
          pieces.add(
            _boxPieceCenter(
              hingeX - side * math.cos(radians) * leafWidth / 2,
              hingeY - side * math.sin(radians) * leafWidth / 2,
              leafWidth,
              38,
              12,
              math.min(top - 20, o.heightMm),
              swung,
              color: const Color(0xFFC9AD8C),
            ),
          );
        }
      }
    }
  }

  void _appendWallPieces(
    List<_Piece> pieces,
    PlanWall wall, {
    required int kind,
    String? materialId,
  }) {
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return;
    final height = wall.heightOverrideMm ?? floor.defaultHeightMm;
    final len = floor.wallLengthMm(wall);
    if (len <= 0) return;
    final trimStart = floor.nodeDegree(wall.startNodeId) > 1
        ? wall.thicknessMm / 2
        : 0.0;
    final trimEnd = floor.nodeDegree(wall.endNodeId) > 1
        ? wall.thicknessMm / 2
        : 0.0;
    final openings = List<WallOpening>.from(wall.openings)
      ..sort((x, y) => x.offsetFromStartMm.compareTo(y.offsetFromStartMm));
    var cursor = 0.0;
    for (final o in openings) {
      final start = o.offsetFromStartMm.clamp(0, len).toDouble();
      final end = (o.offsetFromStartMm + o.widthMm).clamp(0, len).toDouble();
      if (start > cursor + 1)
        pieces.add(
          _wallPiece(
            a,
            b,
            wall.thicknessMm,
            len,
            cursor,
            start,
            0,
            height,
            trimStart,
            trimEnd,
            kind: kind,
            materialId: materialId,
            wallId: wall.id,
          ),
        );
      if (o.sillHeightMm > 1)
        pieces.add(
          _wallPiece(
            a,
            b,
            wall.thicknessMm,
            len,
            start,
            end,
            0,
            o.sillHeightMm,
            trimStart,
            trimEnd,
            kind: kind,
            materialId: materialId,
            wallId: wall.id,
          ),
        );
      final topStart = (o.sillHeightMm + o.heightMm)
          .clamp(0, height)
          .toDouble();
      if (topStart < height - 1)
        pieces.add(
          _wallPiece(
            a,
            b,
            wall.thicknessMm,
            len,
            start,
            end,
            topStart,
            height,
            trimStart,
            trimEnd,
            kind: kind,
            materialId: materialId,
            wallId: wall.id,
          ),
        );
      cursor = math.max(cursor, end);
    }
    if (cursor < len - 1)
      pieces.add(
        _wallPiece(
          a,
          b,
          wall.thicknessMm,
          len,
          cursor,
          len,
          0,
          height,
          trimStart,
          trimEnd,
          kind: kind,
          materialId: materialId,
          wallId: wall.id,
        ),
      );
  }

  _Piece _wallPiece(
    PlanNode a,
    PlanNode b,
    double thickness,
    double fullLen,
    double d0,
    double d1,
    double z0,
    double z1,
    double trimStart,
    double trimEnd, {
    required int kind,
    String? materialId,
    String? wallId,
  }) {
    if (d0 <= 0.5) d0 += trimStart;
    if (d1 >= fullLen - 0.5) d1 -= trimEnd;
    if (d1 < d0 + 1) d1 = d0 + 1;
    final ux = (b.xMm - a.xMm) / fullLen;
    final uy = (b.yMm - a.yMm) / fullLen;
    final p0 = math.Point<double>(a.xMm + ux * d0, a.yMm + uy * d0);
    final p1 = math.Point<double>(a.xMm + ux * d1, a.yMm + uy * d1);
    return _wallPiecePoints(
      p0,
      p1,
      thickness,
      z0,
      z1,
      kind: kind,
      materialId: materialId,
      wallId: wallId,
      outline: false,
    );
  }

  _Piece _wallPiecePoints(
    math.Point<double> a,
    math.Point<double> b,
    double thickness,
    double z0,
    double z1, {
    required int kind,
    String? materialId,
    String? wallId,
    bool outline = true,
  }) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.01)
      return _Piece(
        List.generate(8, (_) => _P3(a.x, a.y, z0)),
        kind,
        materialId,
      );
    final nx = -dy / len * thickness / 2;
    final ny = dx / len * thickness / 2;
    return _Piece(
      [
        _P3(a.x + nx, a.y + ny, z0),
        _P3(b.x + nx, b.y + ny, z0),
        _P3(b.x - nx, b.y - ny, z0),
        _P3(a.x - nx, a.y - ny, z0),
        _P3(a.x + nx, a.y + ny, z1),
        _P3(b.x + nx, b.y + ny, z1),
        _P3(b.x - nx, b.y - ny, z1),
        _P3(a.x - nx, a.y - ny, z1),
      ],
      kind,
      materialId,
      null,
      outline,
      wallId,
    );
  }

  _Piece _junctionPiece(
    PlanNode node,
    double width,
    double height, {
    required int kind,
    String? materialId,
  }) {
    final h = width / 2;
    return _Piece(
      [
        _P3(node.xMm - h, node.yMm - h, 0),
        _P3(node.xMm + h, node.yMm - h, 0),
        _P3(node.xMm + h, node.yMm + h, 0),
        _P3(node.xMm - h, node.yMm + h, 0),
        _P3(node.xMm - h, node.yMm - h, height),
        _P3(node.xMm + h, node.yMm - h, height),
        _P3(node.xMm + h, node.yMm + h, height),
        _P3(node.xMm - h, node.yMm + h, height),
      ],
      kind,
      materialId,
      null,
      false,
    );
  }

  List<_Face> _faces(
    _Piece p,
    Map<
      String,
      ({
        String materialId,
        String baseId,
        bool tiled,
        _TileGrid? grid,
        double from,
        double to,
      })
    >
    wallSurfaces,
    Map<String, String> wallBaseMaterialById,
  ) {
    final sideA = p.kind == 1 ? 4 : (p.kind == 2 ? 7 : 0);
    final sideB = p.kind == 1 ? 4 : (p.kind == 2 ? 7 : 1);
    final insideA = p.wallId == null ? null : wallSurfaces['${p.wallId}:0'];
    final insideB = p.wallId == null ? null : wallSurfaces['${p.wallId}:2'];
    final backPaint = p.kind == 2 || p.wallId == null
        ? null
        : wallBaseMaterialById[p.wallId];
    return [
      _Face(
        [p.v[0], p.v[1], p.v[5], p.v[4]],
        insideA == null && p.wallId != null && p.kind != 2
            ? 0
            : insideA?.tiled == true
            ? 4
            : sideA,
        materialId: insideA?.materialId ?? backPaint,
        tileGrid: insideA?.grid,
        tileFromMm: insideA?.tiled == true ? insideA?.from : null,
        tileToMm: insideA?.tiled == true ? insideA?.to : null,
        baseMaterialId: insideA?.tiled == true ? insideA?.baseId : null,
        color: p.color,
        outline: p.outline,
      ),
      _Face(
        [p.v[1], p.v[2], p.v[6], p.v[5]],
        sideB,
        color: p.color,
        outline: p.outline,
      ),
      _Face(
        [p.v[2], p.v[3], p.v[7], p.v[6]],
        insideB == null && p.wallId != null && p.kind != 2
            ? 0
            : insideB?.tiled == true
            ? 4
            : sideA,
        materialId: insideB?.materialId ?? backPaint,
        tileGrid: insideB?.grid,
        tileFromMm: insideB?.tiled == true ? insideB?.from : null,
        tileToMm: insideB?.tiled == true ? insideB?.to : null,
        baseMaterialId: insideB?.tiled == true ? insideB?.baseId : null,
        color: p.color,
        outline: p.outline,
      ),
      _Face(
        [p.v[3], p.v[0], p.v[4], p.v[7]],
        sideB,
        color: p.color,
        outline: p.outline,
      ),
      _Face(
        [p.v[4], p.v[5], p.v[6], p.v[7]],
        2,
        color: p.color,
        outline: p.outline,
      ),
    ];
  }

  Set<String> _cutawayWallIds() {
    final boundary = <String, List<FaceEdge>>{};
    for (final room in _rooms) {
      for (final edge in room.edges) {
        boundary.putIfAbsent(edge.wallId, () => []).add(edge);
      }
    }
    final cameraX = math.sin(rotation), cameraY = math.cos(rotation);
    final hidden = <String>{};
    for (final entry in boundary.entries) {
      if (entry.value.length != 1) continue; // shared room divider
      final wall = floor.wallById(entry.key);
      if (wall == null ||
          wall.demolition ||
          wall.projectLayer == ProjectLayer.demolition)
        continue;
      final edge = entry.value.single;
      final a = floor.nodeById(edge.fromNodeId);
      final b = floor.nodeById(edge.toNodeId);
      if (a == null || b == null) continue;
      final dx = b.xMm - a.xMm, dy = b.yMm - a.yMm;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) continue;
      // Bounded faces follow the clockwise screen contour. The right normal
      // points into the room; hide a boundary only when its outward normal
      // faces the viewer. Interior partitions and objects stay in the scene.
      final towardCamera = (dy * cameraX - dx * cameraY) / length;
      if (towardCamera > 0.16) hidden.add(wall.id);
    }
    return hidden;
  }

  Offset _project3(_P3 p) {
    if (walkMode) {
      final dx = p.x - walkX, dy = p.y - walkY;
      final forward = math.max(100.0, _forward(p));
      final across = dx * math.cos(rotation) - dy * math.sin(rotation);
      return Offset(
        _walkFocal * across / forward,
        _walkFocal * (1650 - p.z) / forward + tilt * _walkFocal,
      );
    }
    final ca = math.cos(rotation);
    final sa = math.sin(rotation);
    final xr = p.x * ca - p.y * sa;
    final yr = p.x * sa + p.y * ca;
    final ce = math.cos(tilt);
    final se = math.sin(tilt);
    return Offset(xr, yr * ce - p.z * se);
  }

  double _depth(_P3 p) {
    if (walkMode) return -_forward(p);
    final sa = math.sin(rotation);
    final ca = math.cos(rotation);
    final yr = p.x * sa + p.y * ca;
    return yr * math.sin(tilt) + p.z * math.cos(tilt);
  }

  Rect _bounds(List<Offset> pts) {
    if (pts.isEmpty) return Rect.zero;
    var minX = pts.first.dx;
    var maxX = pts.first.dx;
    var minY = pts.first.dy;
    var maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  bool shouldRepaint(covariant Floor3DPainter oldDelegate) => true;
}

class _P3 {
  const _P3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _Piece {
  const _Piece(
    this.v,
    this.kind, [
    this.materialId,
    this.color,
    this.outline = true,
    this.wallId,
  ]);
  final List<_P3> v;
  final int kind; // 0 wall, 1 tile, 2 demolition, 8+ object library
  final String? materialId;
  final Color? color;
  final bool outline;
  final String? wallId;
}

class _Face {
  const _Face(
    this.points,
    this.shade, {
    this.materialId,
    this.color,
    this.outline = true,
    this.tileGrid,
    this.tileFromMm,
    this.tileToMm,
    this.baseMaterialId,
    this.floorRoom,
    this.floorSettings,
  });
  final List<_P3> points;
  final int shade;
  final String? materialId;
  final Color? color;
  final bool outline;
  final _TileGrid? tileGrid;
  final double? tileFromMm;
  final double? tileToMm;
  final String? baseMaterialId;
  final RoomFace? floorRoom;
  final RoomMaterialSettings? floorSettings;
}

class _ProjectedFace {
  const _ProjectedFace({
    required this.points,
    required this.depth,
    required this.vertexDepths,
    required this.lighting,
    required this.shade,
    this.materialId,
    this.color,
    this.outline = true,
    this.tileGrid,
    this.tileFromMm,
    this.tileToMm,
    this.baseMaterialId,
    this.floorRoom,
    this.floorSettings,
    required this.worldWidthMm,
    required this.worldHeightMm,
    required this.worldZ0Mm,
    required this.worldZ1Mm,
  });
  final List<Offset> points;
  final double depth;
  final List<double> vertexDepths;
  final double lighting;
  final int shade;
  final String? materialId;
  final Color? color;
  final bool outline;
  final _TileGrid? tileGrid;
  final double? tileFromMm;
  final double? tileToMm;
  final String? baseMaterialId;
  final RoomFace? floorRoom;
  final RoomMaterialSettings? floorSettings;
  final double worldWidthMm;
  final double worldHeightMm;
  final double worldZ0Mm;
  final double worldZ1Mm;
}

// A small depth buffer for the existing Canvas renderer. The drawing remains
// vector based; the buffer only decides which surface owns each screen cell.
// This prevents a wall or an oversized piece of furniture from erasing a
// closer floor/seat as the camera rotates. Resolution is capped for 4K export.
class _DepthVisibility {
  _DepthVisibility(
    List<List<Offset>> polygons,
    List<List<double>> depths,
    Size size, {
    required bool perspective,
  }) : masks = List.generate(polygons.length, (_) => Path()) {
    final cell = math.max(1.0, math.max(size.width, size.height) / 900);
    final width = (size.width / cell).ceil();
    final height = (size.height / cell).ceil();
    final nearest = List<double>.filled(
      width * height,
      double.negativeInfinity,
    );
    final owner = List<int>.filled(width * height, -1);
    for (var index = 0; index < polygons.length; index++) {
      final points = polygons[index];
      final values = depths[index];
      if (points.length < 3 || points.length != values.length) continue;
      final polygon = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        polygon.lineTo(point.dx, point.dy);
      }
      polygon.close();
      final rect = polygon.getBounds();
      final minX = math.max(0, (rect.left / cell).floor());
      final maxX = math.min(width - 1, (rect.right / cell).ceil());
      final minY = math.max(0, (rect.top / cell).floor());
      final maxY = math.min(height - 1, (rect.bottom / cell).ceil());
      if (minX > maxX || minY > maxY) continue;
      final depthValues = [
        for (final d in values) perspective ? (d < -0.01 ? -1 / d : 0.0) : d,
      ];
      double? gx, gy, base;
      for (var i = 1; i < points.length - 1; i++) {
        final a = points[0], b = points[i], c = points[i + 1];
        final ux = b.dx - a.dx, uy = b.dy - a.dy;
        final vx = c.dx - a.dx, vy = c.dy - a.dy;
        final determinant = ux * vy - uy * vx;
        if (determinant.abs() < 0.001) continue;
        final du = depthValues[i] - depthValues[0];
        final dv = depthValues[i + 1] - depthValues[0];
        gx = (du * vy - dv * uy) / determinant;
        gy = (dv * ux - du * vx) / determinant;
        base = depthValues[0] - gx * a.dx - gy * a.dy;
        break;
      }
      if (gx == null || gy == null || base == null) continue;
      for (var y = minY; y <= maxY; y++) {
        final py = (y + .5) * cell;
        for (var x = minX; x <= maxX; x++) {
          final px = (x + .5) * cell;
          if (!polygon.contains(Offset(px, py))) continue;
          final offset = y * width + x;
          final z = base + gx * px + gy * py;
          if (z > nearest[offset] + 0.000001 ||
              ((z - nearest[offset]).abs() <= 0.000001 &&
                  index > owner[offset])) {
            nearest[offset] = z;
            owner[offset] = index;
          }
        }
      }
    }
    for (var y = 0; y < height; y++) {
      var start = 0;
      var current = owner[y * width];
      for (var x = 1; x <= width; x++) {
        final next = x < width ? owner[y * width + x] : -1;
        if (next == current) continue;
        if (current >= 0) {
          masks[current].addRect(
            Rect.fromLTRB(
              start * cell,
              y * cell,
              math.min(size.width, x * cell),
              math.min(size.height, (y + 1) * cell),
            ),
          );
        }
        start = x;
        current = next;
      }
    }
  }

  final List<Path> masks;
}
