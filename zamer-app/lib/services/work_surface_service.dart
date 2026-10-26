import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';
import 'geometry_service.dart';

/// A single room-facing wall surface. The opposite room has its own finish.
class WorkWallSurface {
  const WorkWallSurface({
    required this.wallId, required this.label, required this.widthM,
    required this.heightM, required this.netAreaM2,
    required this.tileAreaM2, required this.paintAreaM2,
    required this.tileHeightMm,
  });
  final String wallId, label;
  final double widthM, heightM, netAreaM2, tileAreaM2, paintAreaM2,
      tileHeightMm;
}

/// Wall-finish takeoff with openings clipped to paint/tile height bands.
class WorkSurfaceService {
  static const finishCodes = <String>{
    'wall_paint', 'wall_wallpaper', 'wall_tile', 'tile_wall_porcelain',
    'tile_mosaic', 'tile_large_format', 'wall_paint_extra_coat',
  };

  static bool hasAssignments(WorkBoard board, FloorPlan floor, RoomMeta room) =>
      board.wallFinishes.any((f) =>
          f.floorId == floor.id && f.roomId == room.id);

  static double tileHeightFor(
    WorkBoard board, FloorPlan floor, RoomFace face, String wallId,
  ) {
    final room = floor.roomMetaByKey(face.key);
    final height = GeometryService.roomHeightMm(floor, face);
    if (room == null) return 0;
    final found = board.wallFinishes.where((f) =>
        f.floorId == floor.id && f.roomId == room.id && f.wallId == wallId);
    if (found.isNotEmpty) {
      return found.last.tileHeightMm.clamp(0.0, height).toDouble();
    }
    if (!hasAssignments(board, floor, room) && room.materials.wallTile) {
      return height;
    }
    return 0;
  }

  static List<WorkWallSurface> walls(
      WorkBoard board, FloorPlan floor, RoomFace face) {
    final result = <WorkWallSurface>[];
    if (face.innerPolygon.length != face.edges.length) return result;
    final height = math.max(0, GeometryService.roomHeightMm(floor, face));
    if (height <= 0) return result;
    for (var i = 0; i < face.edges.length; i++) {
      final wall = floor.wallById(face.edges[i].wallId);
      if (wall == null) continue;
      final a = face.innerPolygon[i];
      final b = face.innerPolygon[(i + 1) % face.innerPolygon.length];
      final dx = b.x - a.x, dy = b.y - a.y;
      final innerLength = math.sqrt(dx * dx + dy * dy);
      final centerLength = floor.wallLengthMm(wall);
      if (innerLength < 1 || centerLength < 1) continue;
      final wallHeight = math.min(
          height, wall.heightOverrideMm ?? height).toDouble();
      final tileHeight = tileHeightFor(board, floor, face, wall.id)
          .clamp(0.0, wallHeight).toDouble();
      var tileArea = innerLength * tileHeight / 1000000;
      var paintArea = innerLength * (wallHeight - tileHeight) / 1000000;
      final projection = innerLength / centerLength;
      for (final opening in wall.openings) {
        final left = opening.offsetFromStartMm.clamp(0, centerLength).toDouble();
        final right = (opening.offsetFromStartMm + opening.widthMm)
            .clamp(0, centerLength).toDouble();
        final width = math.max(0.0, right - left) * projection;
        final bottom = opening.sillHeightMm.clamp(0, wallHeight).toDouble();
        final top = (opening.sillHeightMm + opening.heightMm)
            .clamp(0, wallHeight).toDouble();
        if (top <= bottom) continue;
        final tileCut = math.max(0.0, math.min(top, tileHeight) - bottom);
        final paintCut = math.max(0.0, top - math.max(bottom, tileHeight));
        tileArea -= width * tileCut / 1000000;
        paintArea -= width * paintCut / 1000000;
      }
      tileArea = math.max(0.0, tileArea);
      paintArea = math.max(0.0, paintArea);
      result.add(WorkWallSurface(
        wallId: wall.id, label: 'Стена ' + (i + 1).toString(),
        widthM: innerLength / 1000, heightM: wallHeight / 1000,
        netAreaM2: tileArea + paintArea, tileAreaM2: tileArea,
        paintAreaM2: paintArea, tileHeightMm: tileHeight,
      ));
    }
    return result;
  }

  static bool isTile(String code) =>
      code == 'wall_tile' || code.startsWith('tile_wall_') ||
      code == 'tile_mosaic' || code == 'tile_large_format';

  static double areaForCode(
      WorkBoard board, FloorPlan floor, RoomFace face, String code) =>
      walls(board, floor, face).fold<double>(
        0, (total, wall) => total +
          (isTile(code) ? wall.tileAreaM2 : wall.paintAreaM2));

  static List<String> wallIdsForCode(
      WorkBoard board, FloorPlan floor, RoomFace face, String code) => [
    for (final wall in walls(board, floor, face))
      if ((isTile(code) ? wall.tileAreaM2 : wall.paintAreaM2) > .0001)
        wall.wallId,
  ];

  static void save(
      WorkBoard board, FloorPlan floor, RoomFace face,
      Map<String, double> tileHeights) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) throw StateError('Помещение не найдено.');
    final known = face.edges.map((e) => e.wallId).toSet();
    final maxHeight = GeometryService.roomHeightMm(floor, face);
    final updated = <WorkWallFinish>[];
    for (final entry in tileHeights.entries) {
      if (!known.contains(entry.key) ||
          !entry.value.isFinite || entry.value < 0 ||
          entry.value > maxHeight) {
        throw ArgumentError.value(entry.value, entry.key,
          'Высота облицовки вне допустимого диапазона.');
      }
      updated.add(WorkWallFinish(
        floorId: floor.id, roomId: room.id,
        wallId: entry.key, tileHeightMm: entry.value,
      ));
    }
    board.wallFinishes.removeWhere((f) =>
        f.floorId == floor.id && f.roomId == room.id);
    board.wallFinishes.addAll(updated);
  }

  /// Refresh only untouched auto-generated tasks. Work that already started
  /// is never silently modified. Zero-area tasks need manual cancellation.
  static int refreshUnstartedFinishes(
      WorkBoard board, FloorPlan floor, RoomFace face) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return 0;
    var updated = 0;
    for (final task in board.tasks) {
      if (task.floorId != floor.id || task.roomId != room.id ||
          task.generatedKey == null ||
          task.done > 0 || task.accepted > 0 ||
          task.operationCode == null ||
          !finishCodes.contains(task.operationCode)) continue;
      final area = areaForCode(
          board, floor, face, task.operationCode!);
      if (area <= 0 || task.quantity <= 0) continue;
      final previous = task.quantity;
      task.quantity = double.parse(area.toStringAsFixed(2));
      task.hours *= task.quantity / previous;
      task.surfaceWallIds
        ..clear()
        ..addAll(wallIdsForCode(
          board, floor, face, task.operationCode!));
      updated++;
    }
    return updated;
  }
}
