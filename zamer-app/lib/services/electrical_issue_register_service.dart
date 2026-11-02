import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import 'electrical_cable_journal_service.dart';
import 'electrical_junction_audit_service.dart';
import 'electrical_network_service.dart';

/// One read-only collection of model integrity problems. This is not an
/// electrical safety certificate and never mutates the live FloorPlan.
enum ElectricalIssueSeverity { error, review }
enum ElectricalIssueObject { point, junction, cable, route, circuit, unlocated }

class ElectricalIssueEntry {
  const ElectricalIssueEntry({
    required this.code,
    required this.description,
    required this.severity,
    required this.object,
    required this.objectId,
    required this.focusPointId,
    required this.source,
  });

  final String code, description, source;
  final ElectricalIssueSeverity severity;
  final ElectricalIssueObject object;
  final String? objectId, focusPointId;
  bool get canLocate => focusPointId != null;
}

class ElectricalIssueRegister {
  const ElectricalIssueRegister(this.entries);
  final List<ElectricalIssueEntry> entries;
  int get errors => entries.where(
      (issue) => issue.severity == ElectricalIssueSeverity.error).length;
  int get toReview => entries.length - errors;
  bool get hasBlockingIssues => errors > 0;
  bool get approved => false;
}

class ElectricalIssueRegisterService {
  const ElectricalIssueRegisterService._();

  static ElectricalIssueRegister inspect(FloorPlan floor) {
    final result = <ElectricalIssueEntry>[];
    final network = floor.electricalNetwork;
    final cableById = <String, ElectricalCableRecord>{
      for (final cable in network?.cables ?? <ElectricalCableRecord>[])
        cable.id: cable,
    };
    final points = <String, ElectricalPoint>{
      for (final point in floor.electricalPoints) point.id: point,
    };
    final circuits = <String, ElectricalCircuitRecord>{
      for (final group in network?.circuits ?? <ElectricalCircuitRecord>[])
        group.id: group,
    };
    final routeToCable = <String, ElectricalCableRecord>{
      for (final cable in network?.cables ?? <ElectricalCableRecord>[])
        if (cable.route3dId != null) cable.route3dId!: cable,
    };
    final routeIds = <String>{
      for (final route in network?.routes3d ?? <ElectricalRoute3d>[])
        route.id,
    };
    final terminals = <String, ElectricalTerminalRecord>{
      for (final terminal in network?.terminals ?? <ElectricalTerminalRecord>[])
        terminal.id: terminal,
    };

    String? anchorForCable(ElectricalCableRecord? cable) {
      if (cable == null) return null;
      if (points.containsKey(cable.fromPointId)) return cable.fromPointId;
      if (points.containsKey(cable.toPointId)) return cable.toPointId;
      return null;
    }

    void add(String code, String message, ElectricalIssueSeverity severity,
        ElectricalIssueObject object, String? id, String? focus, String source) {
      result.add(ElectricalIssueEntry(
        code: code, description: message,
        severity: severity, object: object, objectId: id,
        focusPointId: focus != null && points.containsKey(focus) ? focus : null,
        source: source,
      ));
    }

    for (final issue in ElectricalNetworkService.inspect(floor)) {
      final id = issue.referenceId;
      ElectricalIssueObject object = ElectricalIssueObject.unlocated;
      String? focus;
      // IDs live in different namespaces. A cable and a 3D route can
      // legitimately share a string ID; distinguish by the issue code
      // rather than accidentally navigating to the wrong cable.
      const routeCodes = <String>{
        'duplicateRoute3d', 'invalidRoute3d',
        'routeExclusionConflict', 'orphanRoute3d',
      };
      const terminalCodes = <String>{
        'duplicateTerminal', 'invalidJunction', 'incompleteTerminal',
        'unknownCore', 'foreignCore', 'doubleTermination',
        'mixedCircuits', 'mixedCoreRoles', 'unknownCoreRoles',
      };
      const circuitCodes = <String>{
        'duplicateCircuit', 'circuitName', 'badPanel',
      };
      // ID namespaces are deliberately independent. A terminal and a cable
      // can have identical text IDs, so each issue code must resolve against
      // its owning collection, never against an arbitrary earlier match.
      if (id != null && routeCodes.contains(issue.code)) {
        if (routeIds.contains(id)) {
          object = ElectricalIssueObject.route;
          focus = anchorForCable(routeToCable[id]);
        }
      } else if (id != null && terminalCodes.contains(issue.code)) {
        if (terminals.containsKey(id)) {
          object = ElectricalIssueObject.junction;
          focus = terminals[id]!.junctionPointId;
        }
      } else if (id != null && circuitCodes.contains(issue.code)) {
        if (circuits.containsKey(id)) {
          object = ElectricalIssueObject.circuit;
          final cable = network?.cables.where(
              (c) => c.circuitId == id).firstOrNull;
          focus = anchorForCable(cable);
        }
      } else if (id != null && cableById.containsKey(id)) {
        object = ElectricalIssueObject.cable;
        focus = anchorForCable(cableById[id]);
      } else if (id != null && points.containsKey(id)) {
        object = ElectricalIssueObject.point;
        focus = id;
      }
      add(issue.code, issue.message,
          issue.severity == ElectricalNetworkSeverity.error
              ? ElectricalIssueSeverity.error
              : ElectricalIssueSeverity.review,
          object, id, focus, 'Схема');
    }

    final audit = ElectricalJunctionAuditService.inspect(floor);
    for (final message in audit.globalErrors) {
      add('junctionGlobal', message, ElectricalIssueSeverity.error,
          ElectricalIssueObject.unlocated, null, null, 'РК');
    }
    for (final box in audit.entries) {
      for (final message in box.errors) {
        // Wall binding discrepancies are also collected for *every* point
        // below. Report them there with a direct point target, not twice.
        if (message.contains('привязкой к стене') ||
            message.contains('Привязанная стена удалена') ||
            message.contains('Неполная или некорректная привязка')) {
          continue;
        }
        // A physical path conflict is already identified by its route id
        // in the network audit. Do not repeat it for every connected box.
        if (message.startsWith('Кабель ') &&
            (message.contains('запретную зону') ||
             message.contains('Точки или высоты изменились') ||
             message.contains('3D-трасса'))) {
          continue;
        }
        add('junctionDetail', message, ElectricalIssueSeverity.error,
            ElectricalIssueObject.junction, box.junctionId,
            box.junctionId, 'РК');
      }
      if (box.unknown.isNotEmpty) {
        add('junctionUnverified',
            'РК ${box.label}: не проверены условия монтажа '
            'и/или паспортные параметры (${box.unknown.length} замечаний).',
            ElectricalIssueSeverity.review, ElectricalIssueObject.junction,
            box.junctionId, box.junctionId, 'РК');
      }
    }

    // An electrical point can be stale even before any cable is drawn.
    // Make every locked-wall discrepancy directly navigable.
    for (final point in floor.electricalPoints) {
      final problem = ElectricalJunctionAuditService.wallAnchorProblem(
        floor, point,
      );
      if (problem == null) continue;
      add('wallAnchor', 'Точка ${point.id}: $problem',
          ElectricalIssueSeverity.error, ElectricalIssueObject.point,
          point.id, point.id, 'Привязка');
    }

    final journal = ElectricalCableJournalService.create(floor);
    for (final row in journal.rows) {
      if (row.status == CableJournalStatus.noRoute) {
        add('missingPhysicalRoute',
            'Кабель ${row.cable.id}: физическая трасса пока не задана.',
            ElectricalIssueSeverity.review, ElectricalIssueObject.cable,
            row.cable.id, anchorForCable(row.cable), 'Кабели');
      } else if (row.status == CableJournalStatus.invalidRoute) {
        // Do not repeat a route problem already reported by the network
        // audit. The cable journal still independently marks it invalid.
        // Other cable faults (e.g. an unknown circuit, invalid cores)
        // must not hide a separate broken physical route. Deduplicate only
        // when a matching network-level route error has already been raised.
        const routeFaults = <String>{
          'missingRoute3d', 'wrongRoute3d', 'staleRoute3d',
          'invalidRoute3d', 'routeExclusionConflict',
        };
        // Route and cable IDs are separate namespaces. An unrelated route
        // with the same text ID must not suppress this cable's own fault.
        final alreadyReported = result.any((issue) =>
            routeFaults.contains(issue.code) &&
            ((issue.object == ElectricalIssueObject.cable &&
              issue.objectId == row.cable.id) ||
             (issue.object == ElectricalIssueObject.route &&
              row.cable.route3dId != null &&
              issue.objectId == row.cable.route3dId)));
        if (!alreadyReported) {
          add('invalidCableRoute',
              'Кабель ${row.cable.id}: ${row.problem ?? 'трасса недействительна'}.',
              ElectricalIssueSeverity.error, ElectricalIssueObject.cable,
              row.cable.id, anchorForCable(row.cable), 'Кабели');
        }
      }
    }

    // Stable order for the same project, errors before unverified items.
    result.sort((a,b) {
      final severity = a.severity.index.compareTo(b.severity.index);
      if (severity != 0) return severity;
      final src = a.source.compareTo(b.source);
      if (src != 0) return src;
      final id = (a.objectId ?? '').compareTo(b.objectId ?? '');
      if (id != 0) return id;
      return a.description.compareTo(b.description);
    });
    return ElectricalIssueRegister(List.unmodifiable(result));
  }
}
