import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_issue_register_service.dart';
import 'electrical_route_exclusion_service.dart';

/// An issue's plan location is a diagnostic hint, not a corrected route.
/// No coordinate is invented for broken or deleted references.
class ElectricalIssueLocation {
  const ElectricalIssueLocation({
    required this.pointId,
    required this.xMm,
    required this.yMm,
    this.diagnosticRouteId,
  });

  final String? pointId;
  final double xMm, yMm;
  /// Only explicit route geometry issues get a warning overlay. Other issue
  /// types must never turn a valid cable into a misleading red route.
  final String? diagnosticRouteId;
}

class ElectricalIssueLocatorService {
  const ElectricalIssueLocatorService._();

  static const _routeIssues = <String>{
    'routeExclusionConflict',
    'invalidRoute3d',
    'staleRoute3d',
    'invalidCableRoute',
    'wrongRoute3d',
  };

  static ElectricalIssueLocation? locate(
      FloorPlan floor, ElectricalIssueEntry issue) {
    final point = floor.electricalPoints
        .where((p) => p.id == issue.focusPointId).firstOrNull;
    final network = floor.electricalNetwork;
    String? routeId;
    if (network != null && _routeIssues.contains(issue.code)) {
      if (issue.object == ElectricalIssueObject.route) {
        routeId = issue.objectId;
      } else if (issue.object == ElectricalIssueObject.cable) {
        final cable = network.cables
            .where((c) => c.id == issue.objectId).firstOrNull;
        routeId = cable?.route3dId;
      }
    }
    final route = network?.routes3d
        .where((r) => r.id == routeId).firstOrNull;
    if (route != null && route.vertices.length >= 2 &&
        route.vertices.every((v) => v.finite &&
            v.xMm.abs() <= 10000000 &&
            v.yMm.abs() <= 10000000 &&
            v.zMm.abs() <= 10000000)) {
      // Prefer the actual forbidden leg, not a potentially remote cable
      // endpoint. A 3D vertical leg has a valid XY station too.
      if (issue.code == 'routeExclusionConflict' ||
          (issue.code == 'invalidCableRoute' &&
              issue.description.contains('запретную зону'))) {
        for (var i = 1; i < route.vertices.length; i++) {
          final a = route.vertices[i - 1];
          final b = route.vertices[i];
          if (ElectricalRouteExclusionService.conflictForLeg(
              a, b, ElectricalRouteExclusionService.saved(floor)) == null) {
            continue;
          }
          return ElectricalIssueLocation(
            pointId: point?.id,
            xMm: (a.xMm + b.xMm) / 2,
            yMm: (a.yMm + b.yMm) / 2,
            diagnosticRouteId: route.id,
          );
        }
      }
      // Missing or moved endpoints are better inspected at their mount
      // location; other geometry issues at the middle of their route.
      final isEndpointProblem = issue.description.contains(
          'Точки или высоты изменились');
      if (isEndpointProblem && point != null &&
          point.xMm.isFinite && point.yMm.isFinite) {
        return ElectricalIssueLocation(
          pointId: point.id,
          xMm: point.xMm, yMm: point.yMm,
          diagnosticRouteId: route.id,
        );
      }
      final middle = route.vertices[route.vertices.length ~/ 2];
      return ElectricalIssueLocation(
        pointId: point?.id,
        xMm: middle.xMm, yMm: middle.yMm,
        diagnosticRouteId: route.id,
      );
    }
    if (point != null && point.xMm.isFinite && point.yMm.isFinite &&
        point.xMm.abs() <= 10000000 &&
        point.yMm.abs() <= 10000000) {
      return ElectricalIssueLocation(
        pointId: point.id, xMm: point.xMm, yMm: point.yMm);
    }
    return null; // Never jump to (0, 0) or a guessed replacement point.
  }
}
