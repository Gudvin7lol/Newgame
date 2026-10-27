import '../models/models.dart';
import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import 'electrical_route_service.dart';

enum ElectricalNetworkSeverity { warning, error }

class ElectricalNetworkIssue {
  const ElectricalNetworkIssue(this.code, this.message,
      {this.referenceId, this.severity = ElectricalNetworkSeverity.error});

  final String code;
  final String message;
  final String? referenceId;
  final ElectricalNetworkSeverity severity;
}

class JunctionCableSummary {
  const JunctionCableSummary({
    required this.incoming,
    required this.outgoing,
    required this.terminals,
    required this.unterminatedCoreEnds,
    required this.isMapped,
  });

  final List<ElectricalCableRecord> incoming;
  final List<ElectricalCableRecord> outgoing;
  final List<ElectricalTerminalRecord> terminals;
  final int unterminatedCoreEnds;
  final bool isMapped;
}

/// Checks model integrity, not electrical safety or normative compliance.
/// Connections only exist when a human explicitly creates a terminal record.
class ElectricalNetworkService {
  const ElectricalNetworkService._();

  static List<ElectricalNetworkIssue> inspect(FloorPlan floor) {
    final result = <ElectricalNetworkIssue>[];
    void issue(String code, String message, String? id,
        [ElectricalNetworkSeverity severity = ElectricalNetworkSeverity.error]) {
      result.add(ElectricalNetworkIssue(
        code, message, referenceId: id, severity: severity));
    }

    final network = floor.electricalNetwork;
    if (network == null) {
      issue('noNetwork', 'Схема связей ещё не создана.', null,
          ElectricalNetworkSeverity.warning);
      return result;
    }

    final points = {for (final p in floor.electricalPoints) p.id: p};
    final runs = {for (final r in floor.electricalRuns) r.id: r};
    final circuits = <String, ElectricalCircuitRecord>{};
    final cables = <String, ElectricalCableRecord>{};
    final terminalIds = <String>{};

    for (final c in network.circuits) {
      if (c.id.trim().isEmpty || circuits.containsKey(c.id)) {
        issue('duplicateCircuit', 'Пустой или повторяющийся ID цепи.', c.id);
      }
      circuits[c.id] = c;
      if (c.name.trim().isEmpty) {
        issue('circuitName', 'У цепи не задано название.', c.id,
            ElectricalNetworkSeverity.warning);
      }
      if (c.sourcePanelPointId != null) {
        final source = points[c.sourcePanelPointId];
        if (source == null || source.type != ElectricalPointType.panel) {
          issue('badPanel', 'Источник цепи должен быть существующим щитом.',
              c.id);
        }
      }
    }

    for (final c in network.cables) {
      if (c.id.trim().isEmpty || cables.containsKey(c.id)) {
        issue('duplicateCable', 'Пустой или повторяющийся ID кабеля.', c.id);
      }
      cables[c.id] = c;
      if (!circuits.containsKey(c.circuitId)) {
        issue('unknownCircuit', 'Кабель ссылается на удалённую цепь.', c.id);
      }
      if (c.fromPointId == c.toPointId ||
          !points.containsKey(c.fromPointId) ||
          !points.containsKey(c.toPointId)) {
        issue('invalidCableEnds', 'Неверные начало или конец кабеля.', c.id);
      }
      if (c.routeRunId != null) {
        final run = runs[c.routeRunId];
        if (run == null ||
            !((run.startPointId == c.fromPointId &&
                    run.endPointId == c.toPointId) ||
                (run.startPointId == c.toPointId &&
                    run.endPointId == c.fromPointId))) {
          issue('staleRoute', 'Привязанная линия не совпадает с концами кабеля.',
              c.id);
        }
      }
      if (c.cores.isEmpty) {
        issue('missingCores', 'Жилы кабеля ещё не описаны.', c.id,
            ElectricalNetworkSeverity.warning);
      }
      final coreIds = <String>{};
      for (final core in c.cores) {
        if (core.id.trim().isEmpty || !coreIds.add(core.id)) {
          issue('duplicateCore', 'Пустой или повторяющийся ID жилы.', c.id);
        }
      }
    }

    // A core end belongs to at most one terminal in any one physical box.
    // A cable's two ends are independent and may terminate in two boxes.
    final occupiedEnds = <String>{};
    for (final t in network.terminals) {
      if (t.id.trim().isEmpty || !terminalIds.add(t.id)) {
        issue('duplicateTerminal', 'Пустой или повторяющийся ID клеммы.', t.id);
      }
      if (points[t.junctionPointId]?.type !=
          ElectricalPointType.junctionBox) {
        issue('invalidJunction', 'Клемма должна находиться в существующей РК.',
            t.id);
      }
      if (t.members.length < 2) {
        issue('incompleteTerminal', 'Клемма содержит менее двух жил.', t.id,
            ElectricalNetworkSeverity.warning);
      }
      final circuitsInTerminal = <String>{};
      final roles = <ElectricalCorePurpose>{};
      for (final ref in t.members) {
        final cable = cables[ref.cableId];
        final core = cable == null
            ? null
            : <ElectricalCableCore>[
                for (final x in cable.cores)
                  if (x.id == ref.coreId) x,
              ].firstOrNull;
        if (cable == null || core == null) {
          issue('unknownCore', 'Клемма ссылается на неизвестную жилу.', t.id);
          continue;
        }
        circuitsInTerminal.add(cable.circuitId);
        roles.add(core.purpose);
        if (cable.fromPointId != t.junctionPointId &&
            cable.toPointId != t.junctionPointId) {
          issue('foreignCore', 'Жила этого кабеля не входит в данную коробку.',
              t.id);
          continue;
        }
        final endKey = t.junctionPointId + '/' + ref.key;
        if (!occupiedEnds.add(endKey)) {
          issue('doubleTermination', 'Одна жила заведена в несколько клемм.',
              t.id);
        }
      }
      if (circuitsInTerminal.length > 1) {
        issue('mixedCircuits',
            'В клемме смешаны разные цепи. Проверьте назначение.', t.id);
      }
      final knownRoles = roles
          .where((role) => role != ElectricalCorePurpose.unspecified)
          .toSet();
      if (knownRoles.length > 1) {
        issue('mixedCoreRoles',
            'В одной клемме указаны разные назначенные функции жил.', t.id);
      }
      if (roles.contains(ElectricalCorePurpose.unspecified)) {
        issue('unknownCoreRoles',
            'Не у всех жил клеммы указано назначение.', t.id,
            ElectricalNetworkSeverity.warning);
      }
    }

    final routeIds = <String>{};
    final routes = <String, ElectricalRoute3d>{};
    for (final route in network.routes3d) {
      if (route.id.trim().isEmpty || !routeIds.add(route.id)) {
        issue('duplicateRoute3d', 'Пустой или повторный ID трассы.', route.id);
      }
      routes[route.id] = route;
      try {
        ElectricalRouteService.measure(floor, route);
      } on FormatException catch (e) {
        issue('invalidRoute3d', e.message, route.id);
      }
    }
    for (final cable in network.cables) {
      if (cable.explicitReserveMm != null &&
          (!cable.explicitReserveMm!.isFinite ||
           cable.explicitReserveMm! < 0)) {
        issue('invalidReserve', 'Отрицательный или неверный запас.', cable.id);
      }
      if (cable.route3dId != null) {
        try {
          final assigned = routes[cable.route3dId];
          if (assigned == null) {
            issue('missingRoute3d', 'Не найдена 3D-трасса кабеля.', cable.id);
          } else {
            final path = assigned;
            if (!((path.fromPointId == cable.fromPointId &&
                   path.toPointId == cable.toPointId) ||
                  (path.fromPointId == cable.toPointId &&
                   path.toPointId == cable.fromPointId))) {
              issue('wrongRoute3d', '3D-трасса ведёт к другим точкам.', cable.id);
            } else {
              ElectricalRouteService.measure(
                floor, path, reserveMm: cable.explicitReserveMm);
            }
          }
        } on FormatException catch (e) {
          issue('staleRoute3d', e.message, cable.id);
        }
      } else if (cable.explicitReserveMm != null) {
        issue('reserveWithoutRoute', 'Запас задан без маршрута.', cable.id,
            ElectricalNetworkSeverity.warning);
      }
    }
    final used3d = network.cables.map((c) => c.route3dId)
        .whereType<String>().toSet();
    for (final path in network.routes3d) {
      if (!used3d.contains(path.id)) {
        issue('orphanRoute3d', 'Трасса не закреплена за кабелем.', path.id,
            ElectricalNetworkSeverity.warning);
      }
    }

    final linkedRuns = network.cables
        .map((c) => c.routeRunId)
        .whereType<String>()
        .toSet();
    final orphanRuns = floor.electricalRuns
        .where((r) => !linkedRuns.contains(r.id))
        .length;
    if (orphanRuns > 0) {
      issue('unmappedRuns',
          'Линий чертежа без подтверждённой связи с кабелем: ' +
              orphanRuns.toString() + '.', null,
          ElectricalNetworkSeverity.warning);
    }
    return result;
  }

  static JunctionCableSummary junction(FloorPlan floor, String junctionId) {
    final network = floor.electricalNetwork;
    final incoming = <ElectricalCableRecord>[];
    final outgoing = <ElectricalCableRecord>[];
    final terminals = <ElectricalTerminalRecord>[];
    if (network == null) {
      return JunctionCableSummary(
        incoming: incoming, outgoing: outgoing, terminals: terminals,
        unterminatedCoreEnds: 0, isMapped: false);
    }
    incoming.addAll(network.cables.where((c) => c.toPointId == junctionId));
    outgoing.addAll(network.cables.where((c) => c.fromPointId == junctionId));
    terminals.addAll(network.terminals
        .where((t) => t.junctionPointId == junctionId));
    final assigned = {
      for (final terminal in terminals)
        for (final ref in terminal.members) ref.key,
    };
    var pendingEnds = 0;
    for (final cable in [...incoming, ...outgoing]) {
      for (final core in cable.cores) {
        if (!assigned.contains(cable.id + '/' + core.id)) pendingEnds++;
      }
    }
    return JunctionCableSummary(
      incoming: incoming, outgoing: outgoing, terminals: terminals,
      unterminatedCoreEnds: pendingEnds,
      isMapped: incoming.isNotEmpty ||
          outgoing.isNotEmpty || terminals.isNotEmpty,
    );
  }
}
