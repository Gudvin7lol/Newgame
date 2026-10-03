import 'dart:math' as math;

import '../models/models.dart';
import 'geometry_service.dart';
import 'object_catalog.dart';

/// Creates real project objects from catalog items.
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
