import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';

enum ProfessionalMeasureCheckKind {
  unconfirmedWallLength,
  unconfirmedOpeningOffset,
  unconfirmedOpeningWidth,
  unconfirmedOpeningHeight,
  openingOutsideWall,
  missingRoomHeight,
  missingDiagonal,
  calculatedControl,
}

class ProfessionalMeasureCheck {
  const ProfessionalMeasureCheck({
    required this.kind,
    required this.message,
    required this.position,
    this.dimensionKey,
    this.wallId,
    this.openingId,
    this.roomKey,
    this.critical = false,
  });

  final ProfessionalMeasureCheckKind kind;
  final String message;
  final math.Point<double> position;
  final String? dimensionKey;
  final String? wallId;
  final String? openingId;
  final String? roomKey;
  final bool critical;
}

class OpeningDimensionChain {
  const OpeningDimensionChain({
    required this.wallId,
    required this.openingId,
    required this.wallLengthMm,
    required this.fromStartMm,
    required this.widthMm,
    required this.toEndMm,
  });

  final String wallId;
  final String openingId;
  final double wallLengthMm;
  final double fromStartMm;
  final double widthMm;
  final double toEndMm;

  bool get valid =>
      wallLengthMm > 0 &&
      fromStartMm >= 0 &&
      widthMm > 0 &&
      toEndMm >= 0 &&
      (fromStartMm + widthMm + toEndMm - wallLengthMm).abs() < 1;
}

class ProfessionalMeasurementSummary {
  const ProfessionalMeasurementSummary({
    required this.checks,
    required this.expectedDimensions,
    required this.confirmedDimensions,
    required this.calculatedDimensions,
  });

  final List<ProfessionalMeasureCheck> checks;
  final int expectedDimensions;
  final int confirmedDimensions;
  final int calculatedDimensions;

  int get criticalCount => checks.where((check) => check.critical).length;
  int get warningCount => checks.length - criticalCount;
  bool get ready => checks.isEmpty && expectedDimensions > 0;
  double get completion => expectedDimensions <= 0
      ? 0
      : (confirmedDimensions / expectedDimensions).clamp(0.0, 1.0).toDouble();
}

class ProfessionalMeasurementService {
  static bool isConfirmed(DimensionRecord? record) {
    if (record == null) return false;
    return record.source != DimensionSource.calculated &&
        record.author.trim().isNotEmpty;
  }

  static List<OpeningDimensionChain> openingChains(FloorPlan floor) {
    final result = <OpeningDimensionChain>[];
    for (final wall in floor.walls.where((wall) => !wall.demolition)) {
      final length = floor.wallLengthMm(wall);
      for (final opening in wall.openings) {
        result.add(
          OpeningDimensionChain(
            wallId: wall.id,
            openingId: opening.id,
            wallLengthMm: length,
            fromStartMm: opening.offsetFromStartMm,
            widthMm: opening.widthMm,
            toEndMm: length - opening.offsetFromStartMm - opening.widthMm,
          ),
        );
      }
    }
    return result;
  }

  static double? oppositeReferenceLength(FloorPlan floor, PlanWall wall) {
    if (wall.isCurved) return null;
    final start = floor.nodeById(wall.startNodeId);
    final end = floor.nodeById(wall.endNodeId);
    if (start == null || end == null) return null;
    final angle = math.atan2(end.yMm - start.yMm, end.xMm - start.xMm);
    return GeometryService.parallelReferenceLength(floor, start, angle);
  }

  static ProfessionalMeasurementSummary audit(FloorPlan floor) {
    final checks = <ProfessionalMeasureCheck>[];
    final expectedKeys = <String>{};
    var confirmed = 0;
    var calculated = 0;

    void inspectDimension(String key) {
      if (!expectedKeys.add(key)) return;
      final record = floor.dimensionRecords[key];
      if (isConfirmed(record)) {
        confirmed++;
      } else if (record?.source == DimensionSource.calculated) {
        calculated++;
      }
    }

    for (final wall in floor.walls.where((wall) => !wall.demolition)) {
      final a = floor.nodeById(wall.startNodeId);
      final b = floor.nodeById(wall.endNodeId);
      if (a == null || b == null) continue;
      final midpoint = math.Point<double>(
        (a.xMm + b.xMm) / 2,
        (a.yMm + b.yMm) / 2,
      );
      final wallLengthKey = 'wall:${wall.id}:length';
      inspectDimension(wallLengthKey);
      if (!isConfirmed(floor.dimensionRecords[wallLengthKey])) {
        checks.add(
          ProfessionalMeasureCheck(
            kind: ProfessionalMeasureCheckKind.unconfirmedWallLength,
            message: 'Длина стены ${wall.id} не подтверждена замером',
            position: midpoint,
            dimensionKey: wallLengthKey,
            wallId: wall.id,
          ),
        );
      }

      final wallLength = floor.wallLengthMm(wall);
      for (final opening in wall.openings) {
        final centerT = wallLength <= 0
            ? 0.0
            : (opening.offsetFromStartMm + opening.widthMm / 2) / wallLength;
        final position = math.Point<double>(
          a.xMm + (b.xMm - a.xMm) * centerT,
          a.yMm + (b.yMm - a.yMm) * centerT,
        );
        final offsetKey = 'opening:${opening.id}:offset';
        final widthKey = 'opening:${opening.id}:width';
        final heightKey = 'opening:${opening.id}:height';
        inspectDimension(offsetKey);
        inspectDimension(widthKey);
        inspectDimension(heightKey);

        final toEnd = wallLength - opening.offsetFromStartMm - opening.widthMm;
        if (opening.offsetFromStartMm < 0 ||
            opening.widthMm <= 0 ||
            toEnd < 0) {
          checks.add(
            ProfessionalMeasureCheck(
              kind: ProfessionalMeasureCheckKind.openingOutsideWall,
              message:
                  'Проём ${opening.id} выходит за границы стены ${wall.id}: '
                  '${opening.offsetFromStartMm.round()} + ${opening.widthMm.round()} + ${toEnd.round()} мм',
              position: position,
              wallId: wall.id,
              openingId: opening.id,
              critical: true,
            ),
          );
        }
        if (!isConfirmed(floor.dimensionRecords[offsetKey])) {
          checks.add(
            ProfessionalMeasureCheck(
              kind: ProfessionalMeasureCheckKind.unconfirmedOpeningOffset,
              message:
                  'Проём ${opening.id}: расстояние от угла ${opening.offsetFromStartMm.round()} мм не подтверждено',
              position: position,
              dimensionKey: offsetKey,
              wallId: wall.id,
              openingId: opening.id,
            ),
          );
        }
        if (!isConfirmed(floor.dimensionRecords[widthKey])) {
          checks.add(
            ProfessionalMeasureCheck(
              kind: ProfessionalMeasureCheckKind.unconfirmedOpeningWidth,
              message:
                  'Проём ${opening.id}: ширина ${opening.widthMm.round()} мм не подтверждена',
              position: position,
              dimensionKey: widthKey,
              wallId: wall.id,
              openingId: opening.id,
            ),
          );
        }
        if (!isConfirmed(floor.dimensionRecords[heightKey])) {
          checks.add(
            ProfessionalMeasureCheck(
              kind: ProfessionalMeasureCheckKind.unconfirmedOpeningHeight,
              message:
                  'Проём ${opening.id}: высота ${opening.heightMm.round()} мм не подтверждена',
              position: position,
              dimensionKey: heightKey,
              wallId: wall.id,
              openingId: opening.id,
            ),
          );
        }
      }
    }

    final faces = GeometryService.roomFaces(floor);
    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta != null) {
        final heightKey = 'room:${meta.id}:height';
        inspectDimension(heightKey);
        if (!isConfirmed(floor.dimensionRecords[heightKey])) {
          checks.add(
            ProfessionalMeasureCheck(
              kind: ProfessionalMeasureCheckKind.missingRoomHeight,
              message: '${meta.name}: высота помещения не подтверждена',
              position: face.centroid,
              dimensionKey: heightKey,
              roomKey: face.key,
            ),
          );
        }
      }

      final hasDiagonal = floor.measures.any((measure) {
        if (!face.nodeIds.contains(measure.startNodeId) ||
            !face.nodeIds.contains(measure.endNodeId)) {
          return false;
        }
        final a = floor.nodeById(measure.startNodeId);
        final b = floor.nodeById(measure.endNodeId);
        if (a == null || b == null) return false;
        return (a.xMm - b.xMm).abs() > 150 &&
            (a.yMm - b.yMm).abs() > 150;
      });
      if (face.nodeIds.toSet().length >= 4 && !hasDiagonal) {
        checks.add(
          ProfessionalMeasureCheck(
            kind: ProfessionalMeasureCheckKind.missingDiagonal,
            message: '${meta?.name ?? 'Помещение'}: нет контрольной диагонали',
            position: face.centroid,
            roomKey: face.key,
          ),
        );
      }
    }

    for (final measure in floor.measures) {
      final key = 'control:${measure.id}';
      inspectDimension(key);
      final record = floor.dimensionRecords[key];
      if (record == null || record.source == DimensionSource.calculated) {
        final a = floor.nodeById(measure.startNodeId);
        final b = floor.nodeById(measure.endNodeId);
        if (a == null || b == null) continue;
        checks.add(
          ProfessionalMeasureCheck(
            kind: ProfessionalMeasureCheckKind.calculatedControl,
            message:
                'Контроль ${measure.label.isEmpty ? measure.id : measure.label}: '
                'значение ${measure.measuredMm.round()} мм ещё расчётное',
            position: math.Point<double>(
              (a.xMm + b.xMm) / 2,
              (a.yMm + b.yMm) / 2,
            ),
            dimensionKey: key,
          ),
        );
      }
    }

    return ProfessionalMeasurementSummary(
      checks: checks,
      expectedDimensions: expectedKeys.length,
      confirmedDimensions: confirmed,
      calculatedDimensions: calculated,
    );
  }
}
