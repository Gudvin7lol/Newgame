import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';
import 'object_catalog.dart';

/// Creates and edits real project objects from catalog items.
///
/// The master catalog UI must never be a visual-only picker: every press on
/// `+` goes through this service so the exact catalog id, dimensions and
/// placement survive project serialization and a cold restart.
class EquipmentPlacementService {
  const EquipmentPlacementService._();

  static PlanObject addCatalogItem({
    required FloorPlan floor,
    required ObjectCatalogItem item,
    String? objectId,
  }) {
    final anchor = _defaultAnchor(floor);
    final nearbyCount = floor.planObjects.length;
    final nudge = (nearbyCount % 5) * 80.0;

    final object = PlanObject(
      id: objectId ?? 'obj-${DateTime.now().microsecondsSinceEpoch}',
      type: item.type,
      xMm: anchor.x + nudge,
      yMm: anchor.y + nudge,
      widthMm: item.widthMm,
      depthMm: item.depthMm,
      heightMm: item.heightMm,
      elevationMm: item.elevationMm,
      label: item.name,
      layer: ProjectLayer.proposed,
      catalogId: item.id,
    );

    floor.planObjects.add(object);
    return object;
  }

  static PlanObject duplicateObject({
    required FloorPlan floor,
    required PlanObject source,
    String? objectId,
    double offsetMm = 160,
  }) {
    final duplicate = PlanObject(
      id: objectId ?? 'obj-${DateTime.now().microsecondsSinceEpoch}',
      type: source.type,
      xMm: source.xMm + offsetMm,
      yMm: source.yMm + offsetMm,
      widthMm: source.widthMm,
      depthMm: source.depthMm,
      heightMm: source.heightMm,
      elevationMm: source.elevationMm,
      rotationDeg: source.rotationDeg,
      label: source.label,
      layer: source.layer,
      slopePct: source.slopePct,
      catalogId: source.catalogId,
    );
    floor.planObjects.add(duplicate);
    return duplicate;
  }

  static void rotateBy(PlanObject object, double deltaDeg) {
    final raw = object.rotationDeg + deltaDeg;
    object.rotationDeg = ((raw % 360) + 360) % 360;
  }

  static void moveBy(PlanObject object, {double dxMm = 0, double dyMm = 0}) {
    object.xMm += dxMm;
    object.yMm += dyMm;
  }

  static bool removeObject({
    required FloorPlan floor,
    required PlanObject object,
  }) {
    final before = floor.planObjects.length;
    floor.planObjects.removeWhere((candidate) => candidate.id == object.id);
    floor.electricalPoints.removeWhere(
      (point) => point.id == 'fixture:${object.id}',
    );
    return floor.planObjects.length != before;
  }

  static math.Point<double> _defaultAnchor(FloorPlan floor) {
    final rooms = GeometryService.roomFaces(floor);
    if (rooms.isNotEmpty) return rooms.first.centroid;

    if (floor.nodes.isEmpty) return const math.Point<double>(0, 0);

    var minX = floor.nodes.first.xMm;
    var maxX = minX;
    var minY = floor.nodes.first.yMm;
    var maxY = minY;
    for (final node in floor.nodes.skip(1)) {
      minX = math.min(minX, node.xMm);
      maxX = math.max(maxX, node.xMm);
      minY = math.min(minY, node.yMm);
      maxY = math.max(maxY, node.yMm);
    }
    return math.Point<double>((minX + maxX) / 2, (minY + maxY) / 2);
  }
}
