import '../models/electrical_route_3d.dart';
import '../models/electrical_route_exclusion_zone.dart';
import '../models/models.dart';

/// Hard veto over geometrically known forbidden volumes. No empty-list
/// assertion of installation safety: unknown obstacles remain unknown.
class ElectricalRouteExclusionService {
  const ElectricalRouteExclusionService._();

  static List<ElectricalRouteExclusionZone> saved(FloorPlan floor) =>
      floor.electricalNetwork?.routeExclusionZones ??
      const <ElectricalRouteExclusionZone>[];

  static String? conflictForLeg(
      ElectricalRouteVertex a, ElectricalRouteVertex b,
      Iterable<ElectricalRouteExclusionZone> zones) {
    for (final zone in zones) {
      if (zone.intersects(a, b)) {
        return 'Трасса пересекает запретную зону «${zone.name}».';
      }
    }
    return null;
  }

  static void requireClear(FloorPlan floor, ElectricalRoute3d route) {
    final zones = saved(floor);
    for (var i = 1; i < route.vertices.length; i++) {
      final blocked = conflictForLeg(
          route.vertices[i - 1], route.vertices[i], zones);
      if (blocked != null) {
        throw FormatException('Участок $i: $blocked');
      }
    }
  }

  static void add(FloorPlan floor, ElectricalRouteExclusionZone zone) {
    zone.validate();
    final network = floor.electricalNetwork;
    if (network == null) {
      throw const FormatException('Сначала создайте электрическую сеть.');
    }
    if (network.routeExclusionZones.any((other) => other.id == zone.id)) {
      throw const FormatException('Зона с таким идентификатором уже существует.');
    }
    network.routeExclusionZones.add(zone);
  }

  static void remove(FloorPlan floor, String id) {
    final zones = floor.electricalNetwork?.routeExclusionZones;
    if (zones == null || !zones.any((zone) => zone.id == id)) {
      throw const FormatException('Запретная зона не найдена.');
    }
    zones.removeWhere((zone) => zone.id == id);
  }
}
