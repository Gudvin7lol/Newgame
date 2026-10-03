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

    final mount = _applyCatalogMount(floor, object, item);
    floor.planObjects.add(object);
    _syncFixedLighting(floor, object, item, mount);
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

    ObjectCatalogItem? item;
    if (source.catalogId.isNotEmpty) {
      item = ObjectCatalog.byId(source.catalogId);
      final mount = _applyCatalogMount(floor, duplicate, item);
      floor.planObjects.add(duplicate);
      _syncFixedLighting(floor, duplicate, item, mount);
    } else {
      floor.planObjects.add(duplicate);
    }
    return duplicate;
  }

  static void rotateBy(PlanObject object, double deltaDeg) {
    if (object.catalogId.isNotEmpty &&
        ObjectCatalog.byId(object.catalogId).mount == CatalogMount.wall) {
      return;
    }
    final raw = object.rotationDeg + deltaDeg;
    object.rotationDeg = ((raw % 360) + 360) % 360;
  }

  static void moveBy(
    PlanObject object, {
    double dxMm = 0,
    double dyMm = 0,
    FloorPlan? floor,
  }) {
    object.xMm += dxMm;
    object.yMm += dyMm;
    if (floor == null || object.catalogId.isEmpty) return;
    final item = ObjectCatalog.byId(object.catalogId);
    final mount = _applyCatalogMount(floor, object, item);
    _syncFixedLighting(floor, object, item, mount);
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

  static ({String? wallId, double? wallOffsetMm, int wallSide})
      _applyCatalogMount(
    FloorPlan floor,
    PlanObject object,
    ObjectCatalogItem item,
  ) {
    if (item.mount == CatalogMount.ceiling) {
      object.elevationMm = math.max(0.0, floor.defaultHeightMm - object.heightMm);
      return (wallId: null, wallOffsetMm: null, wallSide: 1);
    }
    if (item.mount != CatalogMount.wall || floor.walls.isEmpty) {
      return (wallId: null, wallOffsetMm: null, wallSide: 1);
    }

    final hit = GeometryService.nearestWallProjection(
      floor,
      math.Point<double>(object.xMm, object.yMm),
      thresholdMm: 100000,
    );
    if (hit == null) {
      return (wallId: null, wallOffsetMm: null, wallSide: 1);
    }
    final a = floor.nodeById(hit.wall.startNodeId);
    final b = floor.nodeById(hit.wall.endNodeId);
    if (a == null || b == null) {
      return (wallId: null, wallOffsetMm: null, wallSide: 1);
    }

    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) {
      return (wallId: null, wallOffsetMm: null, wallSide: 1);
    }
    final nx = -dy / length;
    final ny = dx / length;
    final sideValue =
        (object.xMm - hit.point.x) * nx + (object.yMm - hit.point.y) * ny;
    final wallSide = sideValue >= 0 ? 1 : -1;
    final clearance = hit.wall.thicknessMm / 2 + object.depthMm / 2 + 6;
    object.xMm = hit.point.x + nx * wallSide * clearance;
    object.yMm = hit.point.y + ny * wallSide * clearance;
    object.rotationDeg = math.atan2(dy, dx) * 180 / math.pi;

    return (
      wallId: hit.wall.id,
      wallOffsetMm: length * hit.t,
      wallSide: wallSide,
    );
  }

  static void _syncFixedLighting(
    FloorPlan floor,
    PlanObject object,
    ObjectCatalogItem item,
    ({String? wallId, double? wallOffsetMm, int wallSide}) mount,
  ) {
    final fixtureId = 'fixture:${object.id}';
    if (item.type != PlanObjectType.lighting || item.mount == CatalogMount.floor) {
      floor.electricalPoints.removeWhere((point) => point.id == fixtureId);
      return;
    }

    final isWall = item.mount == CatalogMount.wall;
    var pointX = object.xMm;
    var pointY = object.yMm;
    if (isWall && mount.wallId != null) {
      final wall = floor.wallById(mount.wallId!);
      final a = wall == null ? null : floor.nodeById(wall.startNodeId);
      final b = wall == null ? null : floor.nodeById(wall.endNodeId);
      if (wall != null && a != null && b != null) {
        final length = floor.wallLengthMm(wall);
        if (length > 1) {
          final t = ((mount.wallOffsetMm ?? 0) / length).clamp(0.0, 1.0);
          pointX = a.xMm + (b.xMm - a.xMm) * t;
          pointY = a.yMm + (b.yMm - a.yMm) * t;
        }
      }
    }

    floor.electricalPoints.removeWhere((point) => point.id == fixtureId);
    floor.electricalPoints.add(
      ElectricalPoint(
        id: fixtureId,
        type: isWall
            ? ElectricalPointType.wallLight
            : ElectricalPointType.ceilingLight,
        xMm: pointX,
        yMm: pointY,
        label: item.name,
        heightMm: isWall
            ? object.elevationMm + object.heightMm / 2
            : floor.defaultHeightMm,
        circuit: 'Освещение',
        powerW: isWall ? 12 : 24,
        wallId: mount.wallId,
        wallOffsetMm: mount.wallOffsetMm,
        wallSide: mount.wallSide,
      ),
    );
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
