import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';

/// A single straight split between tile and laminate, clipped to the room's
/// actual INNER polygon. Source geometry is never mutated.
class WorkFloorSurfaceService {
  static const affectedCodes = <String>{
    'floor_tile', 'floor_laminate', 'floor_underlay',
    'tile_floor_porcelain', 'finish_spc',
  };

  static WorkFloorFinishSplit? selected(
      WorkBoard board, FloorPlan floor, RoomFace face) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return null;
    for (final item in board.floorFinishes.reversed) {
      if (item.floorId == floor.id && item.roomId == room.id) {
        return item;
      }
    }
    return null;
  }

  static ({double min, double max}) bounds(RoomFace face, String axis) {
    if (axis != 'x' && axis != 'y') {
      throw ArgumentError.value(axis, 'axis', 'Допустима ось x или y.');
    }
    if (face.innerPolygon.length < 3) {
      throw StateError('У помещения нет замкнутого контура.');
    }
    final values = [
      for (final p in face.innerPolygon) axis == 'x' ? p.x : p.y,
    ];
    return (
      min: values.reduce(math.min),
      max: values.reduce(math.max),
    );
  }

  static List<math.Point<double>> clip(
      RoomFace face, WorkFloorFinishSplit split, bool tile) {
    final boundsValue = bounds(face, split.axis);
    if (!split.cutMm.isFinite ||
        split.cutMm < boundsValue.min ||
        split.cutMm > boundsValue.max) {
      throw ArgumentError.value(split.cutMm, 'cutMm',
        'Линия разделения вышла за границы помещения.');
    }
    final lower = tile ? split.tileBeforeCut : !split.tileBeforeCut;
    double coord(math.Point<double> p) =>
        split.axis == 'x' ? p.x : p.y;
    bool inside(math.Point<double> p) =>
        lower ? coord(p) <= split.cutMm + 1e-7 :
          coord(p) >= split.cutMm - 1e-7;
    math.Point<double> crossing(
        math.Point<double> a, math.Point<double> b) {
      final delta = coord(b) - coord(a);
      if (delta.abs() < 1e-9) return a;
      final t = ((split.cutMm - coord(a)) / delta)
          .clamp(0.0, 1.0).toDouble();
      return math.Point<double>(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
      );
    }

    final clipped = <math.Point<double>>[];
    final input = face.innerPolygon;
    for (var i = 0; i < input.length; i++) {
      final a = input[i], b = input[(i + 1) % input.length];
      final inA = inside(a), inB = inside(b);
      if (inA && inB) {
        clipped.add(b);
      } else if (inA && !inB) {
        clipped.add(crossing(a, b));
      } else if (!inA && inB) {
        clipped.add(crossing(a, b));
        clipped.add(b);
      }
    }
    return clipped;
  }

  static double polygonArea(List<math.Point<double>> polygon) {
    if (polygon.length < 3) return 0;
    var doubleArea = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      doubleArea += a.x * b.y - b.x * a.y;
    }
    return doubleArea.abs() / 2000000;
  }

  static ({double tileM2, double laminateM2}) areas(
      WorkBoard board, FloorPlan floor, RoomFace face,
      {WorkFloorFinishSplit? preview}) {
    final assigned = preview ?? selected(board, floor, face);
    if (assigned == null) {
      final room = floor.roomMetaByKey(face.key);
      final tile = room?.materials.floorMode == 'tile' ||
          (room?.materials.floorTile ?? false);
      return (
        tileM2: tile ? face.areaM2 : 0,
        laminateM2: tile ? 0 : face.areaM2,
      );
    }
    final tile = polygonArea(clip(face, assigned, true));
    final laminate = polygonArea(clip(face, assigned, false));
    return (tileM2: tile, laminateM2: laminate);
  }

  static double quantityFor(
      WorkBoard board, FloorPlan floor, RoomFace face, String code) {
    final result = areas(board, floor, face);
    return (code == 'floor_tile' || code == 'tile_floor_porcelain')
        ? result.tileM2 : result.laminateM2;
  }

  /// Never allow a split for another room or an empty/infinite zone.
  static void save(
      WorkBoard board, FloorPlan floor, RoomFace face,
      WorkFloorFinishSplit split) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null || split.floorId != floor.id ||
        split.roomId != room.id) {
      throw ArgumentError('Линия разделения не принадлежит помещению.');
    }
    final result = areas(board, floor, face, preview: split);
    if (result.tileM2 < .01 || result.laminateM2 < .01) {
      throw ArgumentError('Для каждой зоны нужна ненулевая площадь.');
    }
    board.floorFinishes.removeWhere((item) =>
      item.floorId == floor.id && item.roomId == room.id);
    board.floorFinishes.add(split);
  }

  /// Generated, untouched work may be corrected. Started or accepted tasks
  /// are immutable. A zero quantity requires explicit human review.
  static int refreshUnstarted(
      WorkBoard board, FloorPlan floor, RoomFace face) {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return 0;
    var count = 0;
    for (final task in board.tasks) {
      if (task.floorId != floor.id || task.roomId != room.id ||
          task.generatedKey == null || task.done > 0 ||
          task.accepted > 0 || task.operationCode == null ||
          !affectedCodes.contains(task.operationCode)) continue;
      final newQty = quantityFor(board, floor, face, task.operationCode!);
      if (newQty <= .0001 || task.quantity <= 0) {
        task.needsQuantityReview = true;
        count++;
        continue;
      }
      final previous = task.quantity;
      task.quantity = double.parse(newQty.toStringAsFixed(2));
      task.hours *= task.quantity / previous;
      task.needsQuantityReview = false;
      count++;
    }
    return count;
  }
}
