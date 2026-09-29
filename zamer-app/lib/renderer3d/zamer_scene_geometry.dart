import 'dart:math' as math;

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/layout_service.dart';

/// Engine-neutral 3D representation of one measured floor.
/// All source dimensions stay in millimetres here. The GPU layer converts once
/// to metres, which keeps measuring math and rendering math from contaminating
/// each other.
class ZamerSceneGeometry {
  ZamerSceneGeometry({
    required this.bounds,
    required this.floors,
    required this.walls,
    required this.objects,
    required this.openings,
    required this.electrical,
  });

  final ZamerSceneBounds bounds;
  final List<ZamerFloorSurface> floors;
  final List<ZamerWallPiece> walls;
  final List<ZamerObjectPlacement> objects;
  final List<ZamerOpeningPlacement> openings;
  final List<ZamerElectricalPlacement> electrical;

  factory ZamerSceneGeometry.fromFloor(FloorPlan floor) {
    GeometryService.syncRoomMetadata(floor);
    final faces = GeometryService.roomFaces(floor);
    final floorSurfaces = <ZamerFloorSurface>[];
    for (final face in faces) {
      // The finish polygon ends at the inner faces of walls. That is correct for
      // take-off drawings, but wrong for the 3D finish layer: when a wall is
      // hidden by cutaway it exposes a black strip where the real floor should
      // continue below the wall. Use the room wall centre-line polygon for the
      // render surface. Adjacent rooms meet below the partition centre line, so
      // the visible floor remains one continuous material instead of separate
      // filler planks around each wall.
      final coveragePolygon = face.nodeIds
          .map((id) => floor.nodeById(id))
          .whereType<PlanNode>()
          .map((n) => math.Point<double>(n.xMm, n.yMm))
          .toList(growable: false);
      final polygon = coveragePolygon.length >= 3
          ? coveragePolygon
          : LayoutService.finishPolygon(face);
      if (polygon.length < 3) continue;
      final meta = floor.roomMetaByKey(face.key);
      final settings = meta?.materials ?? RoomMaterialSettings();
      final sharedFloorAnchor =
          meta != null &&
          floor.carpetRoomIds.length > 1 &&
          floor.carpetRoomIds.contains(meta.id);
      floorSurfaces.add(
        ZamerFloorSurface(
          roomKey: face.key,
          polygonMm: polygon,
          materialMode: settings.floorMode,
          materialId: settings.floorMaterialId,
          directionDeg: settings.floorDirectionDeg,
          tileWidthMm: settings.tileWidthMm,
          tileHeightMm: settings.tileHeightMm,
          plankLengthMm: settings.laminatePlankLengthMm,
          plankWidthMm: settings.laminatePlankWidthMm,
          laminatePattern: settings.laminatePattern,
          laminateOffsetMode: settings.laminateOffsetMode,
          laminateOffsetXMm: settings.laminateOffsetXMm,
          laminateOffsetYMm: settings.laminateOffsetYMm,
          tilePattern: settings.tilePattern,
          tileOffsetXMm: settings.tileOffsetXMm,
          tileOffsetYMm: settings.tileOffsetYMm,
          groutMm: settings.floorTileGroutMm,
          anchorXMm: sharedFloorAnchor ? floor.carpetAnchorX : face.centroid.x,
          anchorYMm: sharedFloorAnchor ? floor.carpetAnchorY : face.centroid.y,
          ceilingHeightMm: meta?.ceilingHeightMm ?? floor.defaultHeightMm,
        ),
      );
    }

    RoomMaterialSettings finishForPoint(double x, double y) {
      RoomFace? best;
      var bestDistance = double.infinity;
      for (final face in faces) {
        final c = face.centroid;
        final dx = c.x - x, dy = c.y - y;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestDistance) {
          bestDistance = d2;
          best = face;
        }
      }
      if (best == null) return RoomMaterialSettings();
      return floor.roomMetaByKey(best.key)?.materials ?? RoomMaterialSettings();
    }

    List<ZamerWallFinishLayer> finishLayersForSegment({
      required Iterable<String> wallIds,
      required double ax,
      required double ay,
      required double bx,
      required double by,
      required String runId,
    }) {
      final ids = wallIds.toSet();
      final midX = (ax + bx) / 2;
      final midY = (ay + by) / 2;
      final dx = bx - ax;
      final dy = by - ay;
      final bySide = <int, ({double distance2, ZamerWallFinishLayer layer})>{};
      for (final face in faces) {
        if (!face.edges.any((edge) => ids.contains(edge.wallId))) continue;
        final c = face.centroid;
        final cross = dx * (c.y - midY) - dy * (c.x - midX);
        if (cross.abs() < 0.001) continue;
        final side = cross > 0 ? 1 : -1;
        final settings =
            floor.roomMetaByKey(face.key)?.materials ?? RoomMaterialSettings();
        final dcx = c.x - midX;
        final dcy = c.y - midY;
        final d2 = dcx * dcx + dcy * dcy;
        final layer = ZamerWallFinishLayer(
          roomKey: face.key,
          sideSign: side,
          materialId: settings.wallMaterialId,
          tileMaterialId: settings.wallTileMaterialId,
          tileEnabled: settings.wallTileEnabledFor(runId),
          tileWidthMm: settings.wallTileWidthMm,
          tileHeightMm: settings.wallTileHeightMm,
          tileOffsetXMm: settings.wallTileXFor(runId),
          tileOffsetYMm: settings.wallTileYFor(runId),
          tileMirrored: settings.wallTileMirroredFor(runId),
          tileRotated: settings.wallTileRotatedFor(runId),
          groutMm: settings.wallTileGroutMm,
          wallColorArgb: settings.wallPaintColorArgb,
          tileTintArgb: settings.wallTileTintArgb,
        );
        final current = bySide[side];
        if (current == null || d2 < current.distance2) {
          bySide[side] = (distance2: d2, layer: layer);
        }
      }
      if (bySide.isEmpty) {
        final settings = finishForPoint(midX, midY);
        return <ZamerWallFinishLayer>[
          ZamerWallFinishLayer(
            roomKey: '',
            sideSign: 1,
            materialId: settings.wallMaterialId,
            tileMaterialId: settings.wallTileMaterialId,
            tileEnabled: settings.wallTileEnabledFor(runId),
            tileWidthMm: settings.wallTileWidthMm,
            tileHeightMm: settings.wallTileHeightMm,
            tileOffsetXMm: settings.wallTileXFor(runId),
            tileOffsetYMm: settings.wallTileYFor(runId),
            tileMirrored: settings.wallTileMirroredFor(runId),
            tileRotated: settings.wallTileRotatedFor(runId),
            groutMm: settings.wallTileGroutMm,
            wallColorArgb: settings.wallPaintColorArgb,
            tileTintArgb: settings.wallTileTintArgb,
          ),
        ];
      }
      return bySide.values.map((entry) => entry.layer).toList(growable: false);
    }

    final wallPieces = <ZamerWallPiece>[];
    final openingPlacements = <ZamerOpeningPlacement>[];
    final handledCurves = <String>{};
    for (final wall in floor.walls) {
      if (wall.projectLayer == ProjectLayer.demolition) continue;
      if (wall.isCurved && wall.curveGroupId != null) {
        final groupId = wall.curveGroupId!;
        if (!handledCurves.add(groupId)) continue;
        final points = GeometryService.smoothCurvePoints(
          floor,
          groupId,
          stepMm: 90,
        );
        if (points.length >= 2) {
          final groupWalls = floor.walls
              .where((w) => w.curveGroupId == groupId)
              .toList();
          final sample = groupWalls.isEmpty ? wall : groupWalls.first;
          final height = sample.heightOverrideMm ?? floor.defaultHeightMm;
          var textureCursorMm = 0.0;
          for (var i = 0; i < points.length - 1; i++) {
            final a = points[i];
            final b = points[i + 1];
            final dx = b.x - a.x;
            final dy = b.y - a.y;
            final len = math.sqrt(dx * dx + dy * dy);
            if (len < 1) continue;
            final finish = finishForPoint((a.x + b.x) / 2, (a.y + b.y) / 2);
            wallPieces.add(
              ZamerWallPiece(
                wallId: sample.id,
                centerXMm: (a.x + b.x) / 2,
                centerYMm: (a.y + b.y) / 2,
                angleRad: math.atan2(dy, dx),
                lengthMm: len + 2,
                thicknessMm: sample.thicknessMm,
                bottomMm: 0,
                heightMm: height,
                textureStartMm: textureCursorMm,
                materialId: finish.wallMaterialId,
                tileMaterialId: finish.wallTileMaterialId,
                tileEnabled: finish.wallTileEnabledFor(groupId),
                tileWidthMm: finish.wallTileWidthMm,
                tileHeightMm: finish.wallTileHeightMm,
                tileOffsetXMm: finish.wallTileXFor(groupId),
                tileOffsetYMm: finish.wallTileYFor(groupId),
                tileMirrored: finish.wallTileMirroredFor(groupId),
                wallColorArgb: finish.wallPaintColorArgb,
                tileTintArgb: finish.wallTileTintArgb,
                finishes: finishLayersForSegment(
                  wallIds: groupWalls.map((w) => w.id),
                  ax: a.x,
                  ay: a.y,
                  bx: b.x,
                  by: b.y,
                  runId: groupId,
                ),
              ),
            );
            textureCursorMm += len;
          }
        }
        continue;
      }

      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      _appendStraightWallPieces(
        floor,
        wall,
        a,
        b,
        wallPieces,
        openingPlacements,
        finishForPoint((a.xMm + b.xMm) / 2, (a.yMm + b.yMm) / 2),
        finishLayersForSegment(
          wallIds: <String>[wall.id],
          ax: a.xMm,
          ay: a.yMm,
          bx: b.xMm,
          by: b.yMm,
          runId: wall.id,
        ),
      );
    }

    final objects = floor.planObjects
        .where((o) => o.layer != ProjectLayer.demolition)
        .map(
          (o) => ZamerObjectPlacement(
            id: o.id,
            catalogId: o.catalogId,
            type: o.type,
            xMm: o.xMm,
            yMm: o.yMm,
            widthMm: o.widthMm,
            depthMm: o.depthMm,
            heightMm: o.heightMm,
            elevationMm: o.elevationMm,
            rotationRad: o.rotationDeg * math.pi / 180,
          ),
        )
        .toList(growable: false);

    bool isRepresentedByLightingObject(ElectricalPoint point) {
      if (point.id.startsWith('fixture:')) return true;
      if (point.type != ElectricalPointType.wallLight &&
          point.type != ElectricalPointType.ceilingLight) {
        return false;
      }
      for (final object in floor.planObjects) {
        if (object.type != PlanObjectType.lighting ||
            object.layer == ProjectLayer.demolition) {
          continue;
        }
        final dx = object.xMm - point.xMm;
        final dy = object.yMm - point.yMm;
        if (dx * dx + dy * dy <= 260 * 260) return true;
      }
      return false;
    }

    final electrical = floor.electricalPoints
        .where((point) => !isRepresentedByLightingObject(point))
        .map((point) {
          var angle = 0.0;
          var wallThickness = 100.0;
          if (point.wallId != null) {
            PlanWall? wall;
            for (final candidate in floor.walls) {
              if (candidate.id == point.wallId) {
                wall = candidate;
                break;
              }
            }
            if (wall != null) {
              wallThickness = wall.thicknessMm;
              final a = floor.nodeById(wall.startNodeId);
              final b = floor.nodeById(wall.endNodeId);
              if (a != null && b != null) {
                angle = math.atan2(b.yMm - a.yMm, b.xMm - a.xMm);
              }
            }
          }
          return ZamerElectricalPlacement(
            id: point.id,
            type: point.type,
            xMm: point.xMm,
            yMm: point.yMm,
            heightMm: point.type == ElectricalPointType.ceilingLight
                ? floor.defaultHeightMm - 35
                : point.heightMm,
            rotationRad: angle,
            wallSide: point.wallSide,
            wallThicknessMm: wallThickness,
            modules: List<ElectricalModuleType>.unmodifiable(point.modules),
            frameVertical: point.frameVertical,
          );
        })
        .toList(growable: false);

    return ZamerSceneGeometry(
      bounds: ZamerSceneBounds.fromFloor(floor),
      floors: floorSurfaces,
      walls: wallPieces,
      objects: objects,
      openings: openingPlacements,
      electrical: electrical,
    );
  }

  static void _appendStraightWallPieces(
    FloorPlan floor,
    PlanWall wall,
    PlanNode a,
    PlanNode b,
    List<ZamerWallPiece> out,
    List<ZamerOpeningPlacement> openingOut,
    RoomMaterialSettings finish,
    List<ZamerWallFinishLayer> finishes,
  ) {
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return;
    final angle = math.atan2(dy, dx);
    final wallHeight = wall.heightOverrideMm ?? floor.defaultHeightMm;
    final openings = wall.openings.toList()
      ..sort((x, y) => x.offsetFromStartMm.compareTo(y.offsetFromStartMm));

    void addPiece(double from, double to, double bottom, double height) {
      final safeFrom = from.clamp(0.0, length).toDouble();
      final safeTo = to.clamp(0.0, length).toDouble();
      final pieceLength = safeTo - safeFrom;
      if (pieceLength < 2 || height < 2) return;
      final mid = (safeFrom + safeTo) / 2;
      final t = mid / length;
      out.add(
        ZamerWallPiece(
          wallId: wall.id,
          centerXMm: a.xMm + dx * t,
          centerYMm: a.yMm + dy * t,
          angleRad: angle,
          lengthMm: pieceLength,
          thicknessMm: wall.thicknessMm,
          bottomMm: bottom,
          heightMm: height,
          textureStartMm: safeFrom,
          materialId: finish.wallMaterialId,
          tileMaterialId: finish.wallTileMaterialId,
          tileEnabled: finish.wallTileEnabledFor(wall.id),
          tileWidthMm: finish.wallTileWidthMm,
          tileHeightMm: finish.wallTileHeightMm,
          tileOffsetXMm: finish.wallTileXFor(wall.id),
          tileOffsetYMm: finish.wallTileYFor(wall.id),
          tileMirrored: finish.wallTileMirroredFor(wall.id),
          wallColorArgb: finish.wallPaintColorArgb,
          tileTintArgb: finish.wallTileTintArgb,
          finishes: finishes,
        ),
      );
    }

    var cursor = 0.0;
    for (final opening in openings) {
      final start = opening.offsetFromStartMm.clamp(0.0, length).toDouble();
      final end = (opening.offsetFromStartMm + opening.widthMm)
          .clamp(0.0, length)
          .toDouble();
      if (end <= start) continue;
      addPiece(cursor, start, 0, wallHeight);

      final mid = (start + end) / 2;
      final t = mid / length;
      openingOut.add(
        ZamerOpeningPlacement(
          id: opening.id,
          wallId: wall.id,
          type: opening.type,
          xMm: a.xMm + dx * t,
          yMm: a.yMm + dy * t,
          widthMm: end - start,
          heightMm: opening.heightMm,
          sillHeightMm: opening.type == OpeningType.window
              ? opening.sillHeightMm
              : 0,
          wallThicknessMm: wall.thicknessMm,
          rotationRad: angle,
          doorSwing: opening.doorSwing,
        ),
      );

      final sill = opening.type == OpeningType.window
          ? opening.sillHeightMm.clamp(0.0, wallHeight).toDouble()
          : 0.0;
      final openingTop = (sill + opening.heightMm)
          .clamp(0.0, wallHeight)
          .toDouble();
      if (sill > 1) addPiece(start, end, 0, sill);
      if (openingTop < wallHeight - 1) {
        addPiece(start, end, openingTop, wallHeight - openingTop);
      }
      cursor = math.max(cursor, end);
    }
    addPiece(cursor, length, 0, wallHeight);
  }
}

class ZamerSceneBounds {
  const ZamerSceneBounds(this.minX, this.minY, this.maxX, this.maxY);
  final double minX, minY, maxX, maxY;

  double get widthMm => math.max(1, maxX - minX);
  double get depthMm => math.max(1, maxY - minY);
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;

  factory ZamerSceneBounds.fromFloor(FloorPlan floor) {
    if (floor.nodes.isEmpty)
      return const ZamerSceneBounds(-1500, -1500, 1500, 1500);
    var minX = floor.nodes.first.xMm;
    var maxX = minX;
    var minY = floor.nodes.first.yMm;
    var maxY = minY;
    for (final n in floor.nodes.skip(1)) {
      minX = math.min(minX, n.xMm);
      maxX = math.max(maxX, n.xMm);
      minY = math.min(minY, n.yMm);
      maxY = math.max(maxY, n.yMm);
    }
    for (final o in floor.planObjects) {
      minX = math.min(minX, o.xMm - o.widthMm / 2);
      maxX = math.max(maxX, o.xMm + o.widthMm / 2);
      minY = math.min(minY, o.yMm - o.depthMm / 2);
      maxY = math.max(maxY, o.yMm + o.depthMm / 2);
    }
    return ZamerSceneBounds(minX, minY, maxX, maxY);
  }
}

class ZamerFloorSurface {
  const ZamerFloorSurface({
    required this.roomKey,
    required this.polygonMm,
    required this.materialMode,
    required this.materialId,
    required this.directionDeg,
    required this.tileWidthMm,
    required this.tileHeightMm,
    required this.plankLengthMm,
    required this.plankWidthMm,
    required this.laminatePattern,
    required this.laminateOffsetMode,
    required this.laminateOffsetXMm,
    required this.laminateOffsetYMm,
    required this.tilePattern,
    required this.tileOffsetXMm,
    required this.tileOffsetYMm,
    required this.groutMm,
    required this.anchorXMm,
    required this.anchorYMm,
    required this.ceilingHeightMm,
  });
  final String roomKey;
  final List<math.Point<double>> polygonMm;
  final String materialMode;
  final String materialId;
  final double directionDeg;
  final double tileWidthMm, tileHeightMm, plankLengthMm, plankWidthMm;
  final String laminatePattern, laminateOffsetMode, tilePattern;
  final double laminateOffsetXMm, laminateOffsetYMm;
  final double tileOffsetXMm, tileOffsetYMm, groutMm;
  final double anchorXMm, anchorYMm;
  final double ceilingHeightMm;
}

class ZamerWallFinishLayer {
  const ZamerWallFinishLayer({
    required this.roomKey,
    required this.sideSign,
    required this.materialId,
    required this.tileMaterialId,
    required this.tileEnabled,
    required this.tileWidthMm,
    required this.tileHeightMm,
    required this.tileOffsetXMm,
    required this.tileOffsetYMm,
    required this.tileMirrored,
    required this.tileRotated,
    required this.groutMm,
    required this.wallColorArgb,
    required this.tileTintArgb,
  });

  final String roomKey;
  final int sideSign;
  final String materialId, tileMaterialId;
  final bool tileEnabled, tileMirrored, tileRotated;
  final double tileWidthMm, tileHeightMm, tileOffsetXMm, tileOffsetYMm, groutMm;
  final int wallColorArgb, tileTintArgb;
}

class ZamerWallPiece {
  const ZamerWallPiece({
    required this.wallId,
    required this.centerXMm,
    required this.centerYMm,
    required this.angleRad,
    required this.lengthMm,
    required this.thicknessMm,
    required this.bottomMm,
    required this.heightMm,
    this.textureStartMm = 0,
    required this.materialId,
    required this.tileMaterialId,
    required this.tileEnabled,
    required this.tileWidthMm,
    required this.tileHeightMm,
    required this.tileOffsetXMm,
    required this.tileOffsetYMm,
    required this.tileMirrored,
    required this.wallColorArgb,
    required this.tileTintArgb,
    required this.finishes,
  });
  final String wallId;
  final double centerXMm, centerYMm, angleRad;
  final double lengthMm, thicknessMm, bottomMm, heightMm;
  final double textureStartMm;
  final String materialId, tileMaterialId;
  final bool tileEnabled;
  final double tileWidthMm, tileHeightMm, tileOffsetXMm, tileOffsetYMm;
  final bool tileMirrored;
  final int wallColorArgb, tileTintArgb;
  final List<ZamerWallFinishLayer> finishes;
}

class ZamerOpeningPlacement {
  const ZamerOpeningPlacement({
    required this.id,
    required this.wallId,
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillHeightMm,
    required this.wallThicknessMm,
    required this.rotationRad,
    required this.doorSwing,
  });

  final String id, wallId;
  final OpeningType type;
  final double xMm, yMm, widthMm, heightMm, sillHeightMm;
  final double wallThicknessMm, rotationRad;
  final DoorSwing doorSwing;
}

class ZamerElectricalPlacement {
  const ZamerElectricalPlacement({
    required this.id,
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.heightMm,
    required this.rotationRad,
    required this.wallSide,
    required this.wallThicknessMm,
    required this.modules,
    required this.frameVertical,
  });

  final String id;
  final ElectricalPointType type;
  final double xMm, yMm, heightMm, rotationRad, wallThicknessMm;
  final int wallSide;
  final List<ElectricalModuleType> modules;
  final bool frameVertical;
}

class ZamerObjectPlacement {
  const ZamerObjectPlacement({
    required this.id,
    required this.catalogId,
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.elevationMm,
    required this.rotationRad,
  });
  final String id, catalogId;
  final PlanObjectType type;
  final double xMm, yMm, widthMm, depthMm, heightMm, elevationMm, rotationRad;
}
