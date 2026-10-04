import '../models/models.dart';

/// Stable hash of the floor state that actually affects the GPU scene.
///
/// UI-only fields such as labels, notes, circuits and prices are deliberately
/// excluded so editing metadata does not rebuild every GLB in the room.
class ZamerSceneFingerprint {
  const ZamerSceneFingerprint._();

  static int of(FloorPlan floor) {
    final values = <Object?>[
      floor.defaultHeightMm,
      floor.carpetAnchorX,
      floor.carpetAnchorY,
      floor.carpetRoomIds.length,
      floor.walls.length,
      floor.planObjects.length,
      floor.electricalPoints.length,
    ];

    final carpetRooms = floor.carpetRoomIds.toList()..sort();
    values.addAll(carpetRooms);

    for (final node in floor.nodes) {
      values.addAll(<Object?>[node.id, node.xMm, node.yMm]);
    }

    for (final wall in floor.walls) {
      values.addAll(<Object?>[
        wall.id,
        wall.startNodeId,
        wall.endNodeId,
        wall.thicknessMm,
        wall.heightOverrideMm,
        wall.projectLayer,
        wall.demolition,
        wall.curveGroupId,
        wall.curveRadiusMm,
        wall.curveSagittaMm,
        wall.curveArcLengthMm,
        wall.openings.length,
      ]);
      for (final opening in wall.openings) {
        values.addAll(<Object?>[
          opening.id,
          opening.type,
          opening.widthMm,
          opening.heightMm,
          opening.offsetFromStartMm,
          opening.sillHeightMm,
          opening.doorSwing,
        ]);
      }
    }

    for (final meta in floor.roomMetas) {
      final m = meta.materials;
      values.addAll(<Object?>[
        meta.id,
        meta.faceKey,
        meta.ceilingHeightMm,
        m.floorMode,
        m.floorTile,
        m.floorMaterialId,
        m.floorDirectionDeg,
        m.tileWidthMm,
        m.tileHeightMm,
        m.tilePattern,
        m.tileOffsetXMm,
        m.tileOffsetYMm,
        m.floorTileGroutMm,
        m.laminatePlankLengthMm,
        m.laminatePlankWidthMm,
        m.laminatePattern,
        m.laminateOffsetMode,
        m.laminateOffsetXMm,
        m.laminateOffsetYMm,
        m.wallMaterialId,
        m.wallPaintColorArgb,
        m.wallTile,
        m.wallTileMaterialId,
        m.wallTileTintArgb,
        m.wallTileWidthMm,
        m.wallTileHeightMm,
        m.wallTilePattern,
        m.wallTileOffsetXMm,
        m.wallTileOffsetYMm,
        m.wallTileFromMm,
        m.wallTileToMm,
        m.wallTileGroutMm,
      ]);
      final runIds = <String>{
        ...m.wallTileRunOffsetX.keys,
        ...m.wallTileRunOffsetY.keys,
        ...m.wallTileRunEnabled.keys,
        ...m.wallTileRunMirrored.keys,
        ...m.wallTileRunRotated.keys,
      }.toList()..sort();
      for (final runId in runIds) {
        values.addAll(<Object?>[
          runId,
          m.wallTileRunOffsetX[runId],
          m.wallTileRunOffsetY[runId],
          m.wallTileRunEnabled[runId],
          m.wallTileRunMirrored[runId],
          m.wallTileRunRotated[runId],
        ]);
      }
    }

    for (final object in floor.planObjects) {
      values.addAll(<Object?>[
        object.id,
        object.catalogId,
        object.type,
        object.layer,
        object.xMm,
        object.yMm,
        object.widthMm,
        object.depthMm,
        object.heightMm,
        object.elevationMm,
        object.rotationDeg,
      ]);
    }

    for (final point in floor.electricalPoints) {
      values.addAll(<Object?>[
        point.id,
        point.type,
        point.xMm,
        point.yMm,
        point.heightMm,
        point.wallId,
        point.wallOffsetMm,
        point.wallSide,
        point.frameVertical,
        point.modules.length,
      ]);
      values.addAll(point.modules);
    }

    return Object.hashAll(values);
  }
}
