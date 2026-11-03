import '../models/electrical_network.dart';
import '../models/models.dart';

/// Diagnostic of *documented* conductor paths from the named distribution
/// board. Geometric reachability is NOT electrical continuity, and never
/// confirms a safe or energized circuit.
class ElectricalCircuitPathIssue {
  const ElectricalCircuitPathIssue({
    required this.code,
    required this.circuitId,
    required this.message,
    this.cableId,
  });

  final String code;
  final String circuitId;
  final String message;
  final String? cableId;
}

class ElectricalCircuitPathService {
  const ElectricalCircuitPathService._();

  static const _tracked = <ElectricalCorePurpose>{
    ElectricalCorePurpose.phase,
    ElectricalCorePurpose.neutral,
    ElectricalCorePurpose.protectiveEarth,
  };

  static String _coreKey(String cable, String core) =>
      cable + '\u0000' + core;

  static String _roleName(ElectricalCorePurpose role) => switch (role) {
    ElectricalCorePurpose.phase => 'L',
    ElectricalCorePurpose.neutral => 'N',
    ElectricalCorePurpose.protectiveEarth => 'PE',
    _ => role.name,
  };

  /// Uses explicit terminals only. Neither line crossings nor a shared box
  /// nor an identical conductor mark creates electrical connectivity.
  static List<ElectricalCircuitPathIssue> inspect(FloorPlan floor) {
    final network = floor.electricalNetwork;
    if (network == null) return const [];
    final result = <ElectricalCircuitPathIssue>[];
    final points = {for (final p in floor.electricalPoints) p.id: p};
    final circuitIds = <String>{};
    for (final circuit in network.circuits) {
      // Invalid panels are diagnosed separately by ElectricalNetworkService.
      final panelId = circuit.sourcePanelPointId;
      if (!circuitIds.add(circuit.id) || panelId == null ||
          points[panelId]?.type != ElectricalPointType.panel) {
        continue;
      }
      final cables = network.cables
          .where((c) => c.circuitId == circuit.id).toList();
      if (cables.isEmpty) continue;
      final cableIds = <String>{};
      if (cables.any((c) => c.id.trim().isEmpty ||
          !cableIds.add(c.id))) {
        // Ambiguous IDs are already blocking network errors; do not invent
        // topology through an arbitrary same-ID cable.
        continue;
      }

      final cableById = {for (final c in cables) c.id: c};
      final parent = <String, String>{};
      final roles = <String, ElectricalCorePurpose>{};
      for (final cable in cables) {
        final coreIds = <String>{};
        for (final core in cable.cores) {
          if (!coreIds.add(core.id) || !_tracked.contains(core.purpose)) {
            continue;
          }
          final key = _coreKey(cable.id, core.id);
          parent[key] = key;
          roles[key] = core.purpose;
        }
      }

      String root(String id) {
        final previous = parent[id];
        if (previous == null || previous == id) return id;
        final resolved = root(previous);
        parent[id] = resolved;
        return resolved;
      }

      void link(String a, String b) {
        final first = root(a);
        final second = root(b);
        if (first != second) parent[second] = first;
      }

      for (final terminal in network.terminals) {
        if (points[terminal.junctionPointId]?.type !=
            ElectricalPointType.junctionBox ||
            terminal.members.length < 2) {
          continue;
        }
        final members = <String>[];
        for (final ref in terminal.members) {
          final cable = cableById[ref.cableId];
          final key = _coreKey(ref.cableId, ref.coreId);
          if (cable == null || !roles.containsKey(key) ||
              (cable.fromPointId != terminal.junctionPointId &&
               cable.toPointId != terminal.junctionPointId)) {
            members.clear();
            break;
          }
          members.add(key);
        }
        // Bad or cross-circuit terminals are never trusted as connections.
        if (members.length != terminal.members.length ||
            members.toSet().length != members.length ||
            members.map((k) => roles[k]).toSet().length != 1) {
          continue;
        }
        for (var i = 1; i < members.length; i++) {
          link(members.first, members[i]);
        }
      }

      final feeds = <ElectricalCorePurpose, Set<String>>{};
      for (final cable in cables.where((c) =>
          c.fromPointId == panelId || c.toPointId == panelId)) {
        for (final core in cable.cores) {
          final key = _coreKey(cable.id, core.id);
          final role = roles[key];
          if (role == null) continue;
          feeds.putIfAbsent(role, () => <String>{}).add(root(key));
        }
      }
      if (feeds.isEmpty) {
        result.add(ElectricalCircuitPathIssue(
          code: 'unverifiedPanelFeed',
          circuitId: circuit.id,
          message: 'Для группы ' + circuit.name +
              ' не описан кабель с назначенными L/N/PE жилами от щита.',
        ));
        continue;
      }

      for (final cable in cables) {
        final missing = <ElectricalCorePurpose>{};
        for (final core in cable.cores) {
          final key = _coreKey(cable.id, core.id);
          final role = roles[key];
          if (role == null) continue;
          if (!(feeds[role]?.contains(root(key)) ?? false)) {
            missing.add(role);
          }
        }
        if (missing.isEmpty) continue;
        final roleLabels = missing.map(_roleName).toList()..sort();
        result.add(ElectricalCircuitPathIssue(
          code: 'unverifiedPanelPath',
          circuitId: circuit.id,
          cableId: cable.id,
          message: 'Кабель ' + cable.id + ': по записанным клеммам ' +
              'не прослеживается путь к щиту для ' +
              roleLabels.join(', ') + '. Проверьте подключения.',
        ));
      }
    }
    return List.unmodifiable(result);
  }
}
