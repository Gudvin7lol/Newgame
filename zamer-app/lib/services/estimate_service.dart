import '../models/models.dart';
import 'engineering_service.dart';
import 'geometry_service.dart';
import 'material_service.dart';

class EstimateLine {
  const EstimateLine(this.name, this.unit, this.quantity, this.unitPrice);
  final String name, unit;
  final double quantity, unitPrice;
  double get total => quantity * unitPrice;
  String get key => '$name|$unit';
}

class ProjectEstimate {
  const ProjectEstimate(this.lines);
  final List<EstimateLine> lines;
  double get pricedTotal => lines.fold(0, (sum, line) => sum + line.total);
  int get unpricedCount => lines.where((line) => line.unitPrice <= 0).length;
}

class EstimateService {
  static ProjectEstimate buildWork(MeasureProject project) {
    final amounts = <String, double>{};
    void add(String name, String unit, double quantity) {
      if (!quantity.isFinite || quantity <= 0) return;
      final key = '$name|$unit';
      amounts[key] = (amounts[key] ?? 0) + quantity;
    }

    for (final floor in project.floors) {
      GeometryService.syncRoomMetadata(floor);
      for (final face in GeometryService.roomFaces(floor)) {
        final meta = floor.roomMetaByKey(face.key);
        if (meta == null) continue;
        final s = meta.materials;
        final area = face.areaM2;
        final walls = GeometryService.roomNetWallAreaM2(floor, face);
        add(
          s.floorMode == 'tile' || s.floorTile
              ? 'Укладка плитки пола'
              : 'Укладка ламината',
          'м²',
          area,
        );
        add('Укладка подложки', 'м²', area);
        if (s.wallPlaster) add('Штукатурка стен', 'м²', walls);
        if (s.wallPutty) add('Шпаклёвка стен', 'м²', walls);
        if (s.wallPaint) add('Покраска стен', 'м²', walls);
        if (s.wallTile) add('Укладка плитки стен', 'м²', walls);
        add(
          switch (meta.ceiling.finish) {
            'stretch' => 'Монтаж натяжного потолка',
            'drywall' => 'Монтаж потолка ГКЛ',
            _ => 'Покраска потолка',
          },
          'м²',
          area,
        );
        final heating = EngineeringService.warmFloor(face, meta.heating);
        add('Монтаж водяного тёплого пола', 'м²', heating.areaM2);
      }
      final partitions = MaterialService.partitionTakeoff(floor);
      add('Монтаж перегородок', 'м²', partitions.boardAreaM2 / 2);
      for (final wall in floor.walls) {
        if (wall.demolition || wall.projectLayer == ProjectLayer.demolition) {
          add(
            'Демонтаж стен',
            'м²',
            floor.wallLengthMm(wall) /
                1000 *
                (wall.heightOverrideMm ?? floor.defaultHeightMm) /
                1000,
          );
        }
        for (final opening in wall.openings) {
          add(
            opening.type == OpeningType.door
                ? 'Установка двери'
                : 'Установка окна',
            'шт.',
            1,
          );
        }
      }
      add(
        'Монтаж электроточек',
        'шт.',
        floor.electricalPoints.length.toDouble(),
      );
      for (final run in EngineeringService.routeLengths(floor).entries) {
        add('Монтаж трубы: ${run.key.label}', 'м', run.value);
      }
    }
    final lines = amounts.entries.map((entry) {
      final pivot = entry.key.lastIndexOf('|');
      return EstimateLine(
        entry.key.substring(0, pivot),
        entry.key.substring(pivot + 1),
        entry.value,
        project.workRates[entry.key] ?? 0,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return ProjectEstimate(lines);
  }

  static ProjectEstimate build(MeasureProject project) {
    final quantities = <String, double>{};
    void add(String name, String unit, double quantity) {
      if (!quantity.isFinite || quantity <= 0) return;
      final key = '$name|$unit';
      quantities[key] = (quantities[key] ?? 0) + quantity;
    }

    for (final floor in project.floors) {
      GeometryService.syncRoomMetadata(floor);
      for (final face in GeometryService.roomFaces(floor)) {
        final meta = floor.roomMetaByKey(face.key);
        if (meta == null) continue;
        for (final item in MaterialService.roomEstimates(floor, face, meta)) {
          add(item.name, item.unit, item.quantity);
        }
      }
      final partitions = MaterialService.partitionTakeoff(floor);
      add('ГКЛ перегородок', 'м²', partitions.boardAreaM2);
      add('Стоечный профиль перегородок', 'шт.', partitions.studs.toDouble());
      add('Направляющий профиль перегородок', 'м', partitions.trackM);
      for (final entry in EngineeringService.routeLengths(floor).entries) {
        add('Труба: ${entry.key.label}', 'м', entry.value * 1.10);
      }
    }
    final lines = quantities.entries.map((entry) {
      final pivot = entry.key.lastIndexOf('|');
      return EstimateLine(
        entry.key.substring(0, pivot),
        entry.key.substring(pivot + 1),
        entry.value,
        project.unitPrices[entry.key] ?? 0,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return ProjectEstimate(lines);
  }
}
