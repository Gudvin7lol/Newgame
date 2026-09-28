import 'dart:math' as math;
import '../models/models.dart';
import 'geometry_service.dart';
import 'engineering_service.dart';

class MaterialService {
  static List<MaterialEstimate> roomEstimates(
    FloorPlan floor,
    RoomFace face,
    RoomMeta meta,
  ) {
    final s = meta.materials;
    final result = <MaterialEstimate>[];
    final floorArea = face.areaM2;
    final wallArea = GeometryService.roomNetWallAreaM2(floor, face);
    final skirting = GeometryService.roomSkirtingM(floor, face);

    for (final layer in meta.floorLayers) {
      if (layer.thicknessMm > 0) {
        result.add(
          MaterialEstimate(
            name: 'Пирог пола: ${layer.name}',
            quantity: floorArea,
            unit: 'м²',
            note: 'Слой ${layer.thicknessMm.toStringAsFixed(0)} мм',
          ),
        );
      }
    }
    for (final layer in meta.wallLayers) {
      if (layer.thicknessMm > 0) {
        result.add(
          MaterialEstimate(
            name: 'Пирог стен: ${layer.name}',
            quantity: wallArea,
            unit: 'м²',
            note: 'Слой ${layer.thicknessMm.toStringAsFixed(0)} мм',
          ),
        );
      }
    }

    if (s.floorMode == 'laminate') {
      final need = floorArea * (1 + s.floorWastePct / 100);
      final packs = s.floorPackageM2 > 0
          ? (need / s.floorPackageM2).ceil()
          : null;
      result.add(
        MaterialEstimate(
          name: 'Ламинат / SPC',
          quantity: need,
          unit: 'м²',
          packages: packs,
          packageLabel: 'пач.',
          note: 'Запас ${s.floorWastePct.toStringAsFixed(0)}%',
        ),
      );
      final underlayNeed = floorArea * 1.05;
      result.add(
        MaterialEstimate(
          name: 'Подложка',
          quantity: underlayNeed,
          unit: 'м²',
          packages: s.underlayRollM2 > 0
              ? (underlayNeed / s.underlayRollM2).ceil()
              : null,
          packageLabel: 'рул.',
          note: 'Запас 5%',
        ),
      );
      result.add(
        MaterialEstimate(
          name: 'Плинтус',
          quantity: skirting * 1.05,
          unit: 'м',
          note: 'Запас 5%',
        ),
      );
    }

    if (s.floorTile) {
      final need = floorArea * (1 + s.floorTileWastePct / 100);
      result.add(
        MaterialEstimate(
          name: 'Плитка на пол',
          quantity: need,
          unit: 'м²',
          packages: s.floorTileBoxM2 > 0
              ? (need / s.floorTileBoxM2).ceil()
              : null,
          packageLabel: 'кор.',
          note: 'Запас ${s.floorTileWastePct.toStringAsFixed(0)}%',
        ),
      );
      final glueKg = need * s.tileGlueKgM2;
      result.add(
        MaterialEstimate(
          name: 'Плиточный клей (пол)',
          quantity: glueKg,
          unit: 'кг',
          packages: s.tileGlueBagKg > 0
              ? (glueKg / s.tileGlueBagKg).ceil()
              : null,
          packageLabel: 'меш.',
        ),
      );
    }

    if (s.wallPlaster) {
      final kg = wallArea * s.plasterThicknessMm * s.plasterKgM2Mm;
      result.add(
        MaterialEstimate(
          name: 'Штукатурка',
          quantity: kg,
          unit: 'кг',
          packages: s.plasterBagKg > 0 ? (kg / s.plasterBagKg).ceil() : null,
          packageLabel: 'меш.',
          note: 'Слой ${s.plasterThicknessMm.toStringAsFixed(0)} мм',
        ),
      );
    }

    if (s.wallPutty) {
      final kg = wallArea * s.puttyCoats * s.puttyKgM2Coat;
      result.add(
        MaterialEstimate(
          name: 'Шпаклёвка',
          quantity: kg,
          unit: 'кг',
          packages: s.puttyBagKg > 0 ? (kg / s.puttyBagKg).ceil() : null,
          packageLabel: 'меш.',
          note: '${s.puttyCoats} слоя',
        ),
      );
    }

    if (s.wallPaint) {
      final liters = s.paintCoverageM2L <= 0
          ? 0.0
          : wallArea * s.paintCoats / s.paintCoverageM2L;
      result.add(
        MaterialEstimate(
          name: 'Краска для стен',
          quantity: liters,
          unit: 'л',
          packages: s.paintCanL > 0 ? (liters / s.paintCanL).ceil() : null,
          packageLabel: 'вед.',
          note: '${s.paintCoats} слоя',
        ),
      );
    }

    if (s.wallTile) {
      final need = wallArea * (1 + s.wallTileWastePct / 100);
      result.add(
        MaterialEstimate(
          name: 'Плитка на стены',
          quantity: need,
          unit: 'м²',
          packages: s.wallTileBoxM2 > 0
              ? (need / s.wallTileBoxM2).ceil()
              : null,
          packageLabel: 'кор.',
          note: 'Запас ${s.wallTileWastePct.toStringAsFixed(0)}%',
        ),
      );
      final glueKg = need * s.tileGlueKgM2;
      result.add(
        MaterialEstimate(
          name: 'Плиточный клей (стены)',
          quantity: glueKg,
          unit: 'кг',
          packages: s.tileGlueBagKg > 0
              ? (glueKg / s.tileGlueBagKg).ceil()
              : null,
          packageLabel: 'меш.',
        ),
      );
    }

    final ceiling = meta.ceiling;
    if (ceiling.finish == 'stretch') {
      result.add(
        MaterialEstimate(
          name: 'Натяжной потолок',
          quantity: floorArea * 1.05,
          unit: 'м²',
          note: 'Запас 5%',
        ),
      );
      result.add(
        MaterialEstimate(
          name: 'Багет потолка',
          quantity: face.perimeterM * 1.05,
          unit: 'м',
          note: 'Запас 5%',
        ),
      );
    } else if (ceiling.finish == 'drywall') {
      result.add(
        MaterialEstimate(
          name: 'ГКЛ потолка',
          quantity: floorArea * 1.10,
          unit: 'м²',
          note: 'Запас 10%',
        ),
      );
      result.add(
        MaterialEstimate(
          name: 'Направляющий профиль потолка',
          quantity: face.perimeterM * 1.05,
          unit: 'м',
        ),
      );
    } else if (ceiling.finish == 'paint') {
      result.add(
        MaterialEstimate(
          name: 'Краска потолка',
          quantity: floorArea * 2 / 10,
          unit: 'л',
          note: '2 слоя, 10 м²/л',
        ),
      );
    }
    final zoneArea = ceiling.zones.fold<double>(
      0,
      (sum, zone) => sum + EngineeringService.zoneAreaM2(face, zone),
    );
    if (zoneArea > 0) {
      result.add(
        MaterialEstimate(
          name: 'ГКЛ потолочных зон',
          quantity: zoneArea * 1.10,
          unit: 'м²',
          note: 'Зоны +10%',
        ),
      );
    }

    final heating = EngineeringService.warmFloor(face, meta.heating);
    if (heating.areaM2 > 0) {
      result.add(
        MaterialEstimate(
          name: 'Труба тёплого пола',
          quantity: heating.pipeM,
          unit: 'м',
          note:
              '${heating.circuits} контур(а) • шаг ${heating.spacingMm.round()} мм',
        ),
      );
      result.add(
        MaterialEstimate(
          name: 'Подложка тёплого пола',
          quantity: heating.areaM2 * 1.05,
          unit: 'м²',
        ),
      );
      result.add(
        MaterialEstimate(
          name: 'Контур коллектора',
          quantity: heating.circuits.toDouble(),
          unit: 'шт.',
        ),
      );
    }

    return result;
  }

  static PartitionTakeoff partitionTakeoff(
    FloorPlan floor, {
    double studSpacingMm = 600,
  }) {
    var lengthM = 0.0;
    var oneSideNetM2 = 0.0;
    var studs = 0;

    for (final wall in floor.walls.where((w) => w.type == WallType.partition)) {
      final lenMm = floor.wallLengthMm(wall);
      final hMm = wall.heightOverrideMm ?? floor.defaultHeightMm;
      lengthM += lenMm / 1000.0;
      var openingArea = 0.0;
      for (final o in wall.openings) {
        openingArea += o.widthMm * o.heightMm / 1000000.0;
      }
      oneSideNetM2 += math.max(0.0, lenMm * hMm / 1000000.0 - openingArea);
      studs += math.max(2, (lenMm / studSpacingMm).ceil() + 1);
    }

    final boardArea = oneSideNetM2 * 2 * 1.10;
    return PartitionTakeoff(
      wallLengthM: lengthM,
      netOneSideAreaM2: oneSideNetM2,
      boardAreaM2: boardArea,
      boardSheets: (boardArea / 3.0).ceil(),
      studs: studs,
      trackM: lengthM * 2 * 1.05,
      insulationM2: oneSideNetM2 * 1.05,
    );
  }

  static Map<String, double> wallConstructionVolumes(FloorPlan floor) {
    final result = <String, double>{};
    for (final wall in floor.walls) {
      final lengthMm = floor.wallLengthMm(wall);
      final heightMm = wall.heightOverrideMm ?? floor.defaultHeightMm;
      var volume = lengthMm * heightMm * wall.thicknessMm / 1000000000.0;
      for (final o in wall.openings) {
        volume -= o.widthMm * o.heightMm * wall.thicknessMm / 1000000000.0;
      }
      final key = wall.material.label;
      result[key] = (result[key] ?? 0) + math.max(0.0, volume);
    }
    return result;
  }
}
