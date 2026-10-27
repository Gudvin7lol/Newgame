import '../models/models.dart';
import 'engineering_service.dart';
import 'geometry_service.dart';
import 'material_service.dart';
import 'work_floor_surface_service.dart';
import 'work_surface_service.dart';

class EstimateLine {
  const EstimateLine(this.name, this.unit, this.quantity, this.unitPrice, {
    this.priceKey,
    this.detail = '',
    this.derivedPrice = false,
  });
  final String name, unit;
  final double quantity, unitPrice;
  /// Purchase price keys are unique to the physical package specification.
  final String? priceKey;
  final String detail;
  /// True if a pack price was estimated from an existing source-unit price.
  final bool derivedPrice;
  double get total => quantity * unitPrice;
  String get key => priceKey ?? '$name|$unit';
}

class ProjectEstimate {
  const ProjectEstimate(this.lines);
  final List<EstimateLine> lines;
  double get pricedTotal => lines.fold(0, (sum, line) => sum + line.total);
  int get unpricedCount => lines.where((line) => line.unitPrice <= 0).length;
  int get derivedPriceCount =>
      lines.where((line) => line.derivedPrice).length;
}

/// Aggregated by exact material and physical packaging capacity.
class _PurchaseGroup {
  _PurchaseGroup(this.name, this.sourceUnit, this.packageUnit, this.packageSize);
  final String name, sourceUnit;
  final String? packageUnit;
  final double? packageSize;
  double required = 0;
  void add(double value) => required += value;
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
        final floorParts = WorkFloorSurfaceService.areas(
          project.workBoard, floor, face);
        final paintWalls = WorkSurfaceService.areaForCode(
          project.workBoard, floor, face, 'wall_paint');
        final tileWalls = WorkSurfaceService.areaForCode(
          project.workBoard, floor, face, 'wall_tile');
        final assigned = WorkSurfaceService.hasAssignments(
          project.workBoard, floor, meta);
        add('Укладка плитки пола', 'м²', floorParts.tileM2);
        add('Укладка ламината', 'м²', floorParts.laminateM2);
        // Underlay is not laid beneath a standard bonded-tile finish.
        add('Укладка подложки', 'м²', floorParts.laminateM2);
        if (s.wallPlaster) add('Штукатурка стен', 'м²', walls);
        if (s.wallPutty) add('Шпаклёвка стен', 'м²', paintWalls);
        if (s.wallPaint || assigned) {
          add('Покраска стен', 'м²', paintWalls);
        }
        if (s.wallTile || assigned) {
          add('Укладка плитки стен', 'м²', tileWalls);
        }
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

/// The only material takeoff source for both consumption and purchasing.
  /// Package rounding is deliberately performed AFTER aggregating demands.
  static List<MaterialEstimate> _materialTakeoff(MeasureProject project) {
    final lines = <MaterialEstimate>[];
    for (final floor in project.floors) {
      GeometryService.syncRoomMetadata(floor);
      for (final face in GeometryService.roomFaces(floor)) {
        final meta = floor.roomMetaByKey(face.key);
        if (meta == null) continue;
        final floorParts = WorkFloorSurfaceService.areas(
            project.workBoard, floor, face);
        final paintWalls = WorkSurfaceService.areaForCode(
            project.workBoard, floor, face, 'wall_paint');
        final tileWalls = WorkSurfaceService.areaForCode(
            project.workBoard, floor, face, 'wall_tile');
        final assigned = WorkSurfaceService.hasAssignments(
            project.workBoard, floor, meta);
        lines.addAll(MaterialService.roomEstimates(
          floor, face, meta,
          laminateAreaM2: floorParts.laminateM2,
          tileFloorAreaM2: floorParts.tileM2,
          paintWallAreaM2: (meta.materials.wallPaint || assigned)
              ? paintWalls : 0,
          tileWallAreaM2: (meta.materials.wallTile || assigned)
              ? tileWalls : 0,
        ));
      }
      final partitions = MaterialService.partitionTakeoff(floor);
      lines.add(MaterialEstimate(
          name: 'ГКЛ перегородок', unit: 'м²',
          quantity: partitions.boardAreaM2));
      lines.add(MaterialEstimate(
          name: 'Стоечный профиль перегородок', unit: 'шт.',
          quantity: partitions.studs.toDouble()));
      lines.add(MaterialEstimate(
          name: 'Направляющий профиль перегородок', unit: 'м',
          quantity: partitions.trackM));
      for (final entry in EngineeringService.routeLengths(floor).entries) {
        lines.add(MaterialEstimate(
            name: 'Труба: ${entry.key.label}', unit: 'м',
            quantity: entry.value * 1.10));
      }
    }
    return lines.where((item) =>
        item.quantity.isFinite && item.quantity > 0).toList();
  }

  /// Existing measured-consumption estimate, intentionally unchanged.
  static ProjectEstimate build(MeasureProject project) {
    final quantities = <String, double>{};
    for (final item in _materialTakeoff(project)) {
      final key = '${item.name}|${item.unit}';
      quantities[key] = (quantities[key] ?? 0) + item.quantity;
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

  /// Purchase-ready material requirements. Non-packaged items remain in
  /// measured units. Packaged items are grouped by compatible package size,
  /// summed across rooms, then rounded to whole purchasable packages.
  ///
  /// Package prices are stored under name|pack-unit|size+source-unit.
  /// Source-unit prices are used as explicitly labelled estimates only.
  static ProjectEstimate buildPurchases(MeasureProject project) {
    final groups = <String, _PurchaseGroup>{};
    for (final item in _materialTakeoff(project)) {
      final size = item.packageSize;
      final packUnit = item.packageLabel;
      final packaged = size != null && size.isFinite && size > 0 &&
          packUnit != null && packUnit.isNotEmpty;
      final groupKey = packaged
          ? '${item.name}|${item.unit}|$packUnit|${size.toStringAsFixed(6)}'
          : '${item.name}|${item.unit}|unpackaged';
      final group = groups.putIfAbsent(groupKey, () => _PurchaseGroup(
        item.name, item.unit,
        packaged ? packUnit : null,
        packaged ? size : null,
      ));
      group.add(item.quantity);
    }
    final result = <EstimateLine>[];
    for (final group in groups.values) {
      final size = group.packageSize;
      if (size == null) {
        final key = '${group.name}|${group.sourceUnit}';
        result.add(EstimateLine(group.name, group.sourceUnit,
            group.required, project.unitPrices[key] ?? 0,
            detail: 'Расход без округления (упаковка не задана)'));
        continue;
      }
      final count = (group.required / size - 1e-9).ceil();
      if (count <= 0) continue;
      final packUnit = group.packageUnit!;
      // Six fractional digits avoid collapsing valid different package sizes.
      final packKey = '${group.name}|$packUnit|'
          '${size.toStringAsFixed(6)} ${group.sourceUnit}';
      final configuredPrice = project.unitPrices[packKey];
      final sourceUnitPrice = project.unitPrices[
          '${group.name}|${group.sourceUnit}'] ?? 0;
      final derived = configuredPrice == null && sourceUnitPrice > 0;
      final price = configuredPrice ?? sourceUnitPrice * size;
      result.add(EstimateLine(
        group.name, packUnit, count.toDouble(), price,
        priceKey: packKey,
        detail: 'Нужно ${group.required.toStringAsFixed(2)} '
            '${group.sourceUnit}; упаковка ${size.toStringAsFixed(2)} '
            '${group.sourceUnit} / $packUnit',
        derivedPrice: derived,
      ));
    }
    result.sort((a, b) {
      final name = a.name.compareTo(b.name);
      return name != 0 ? name : a.key.compareTo(b.key);
    });
    return ProjectEstimate(result);
  }
}
