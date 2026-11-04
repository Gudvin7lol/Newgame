import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_junction_capacity_service.dart';

/// A review-only set of unassigned, explicitly marked conductor ends.
/// Same circuit and purpose do not prove that the ends SHOULD connect.
class ElectricalJunctionConnectionProposal {
  const ElectricalJunctionConnectionProposal({
    required this.circuitId,
    required this.purpose,
    required this.members,
    required this.warnings,
  });
  final String circuitId;
  final ElectricalCorePurpose purpose;
  final List<ElectricalCoreReference> members;
  final List<String> warnings;
}

class ElectricalJunctionConnectionProposalService {
  const ElectricalJunctionConnectionProposalService._();

  static List<ElectricalJunctionConnectionProposal> propose(
      FloorPlan floor, ElectricalNetwork draft, String junctionId) {
    final report = ElectricalJunctionCapacityService.inspect(
        floor,draft,junctionId);
    if (report.exceeded) return const [];
    final occupied = <String>{
      for (final t in draft.terminals.where(
          (t) => t.junctionPointId == junctionId))
        for (final m in t.members) m.key,
    };
    final groups = <String,List<ElectricalCoreReference>>{};
    final roles = <String,ElectricalCorePurpose>{};
    final circuits = <String,String>{};

    for (final cable in draft.cables) {
      if (cable.fromPointId != junctionId &&
          cable.toPointId != junctionId) continue;
      if (!draft.circuits.any((c) => c.id == cable.circuitId)) continue;
      for (final core in cable.cores) {
        if (core.purpose == ElectricalCorePurpose.unspecified) continue;
        final reference = ElectricalCoreReference(
            cableId:cable.id,coreId:core.id);
        if (occupied.contains(reference.key)) continue;
        final key = '${cable.circuitId}:${core.purpose.name}';
        groups.putIfAbsent(key,()=>[]).add(reference);
        roles[key] = core.purpose;
        circuits[key] = cable.circuitId;
      }
    }

    final result = <ElectricalJunctionConnectionProposal>[];
    for (final entry in groups.entries) {
      if (entry.value.length < 2 ||
          entry.value.map((m)=>m.cableId).toSet().length < 2) continue;
      final cap = draft.junctionCapacities[junctionId];
      if (cap?.maxEndsPerConnector != null &&
          entry.value.length > cap!.maxEndsPerConnector!) continue;
      if (cap?.maxConnectorCount != null &&
          report.connectorCount >= cap!.maxConnectorCount!) continue;
      result.add(ElectricalJunctionConnectionProposal(
        circuitId:circuits[entry.key]!,
        purpose:roles[entry.key]!,
        members:List.unmodifiable(entry.value),
        warnings:const [
          'Равные обозначения жил не доказывают электрическую связь.',
          'Убедитесь в принципиальной схеме, назначении цепей и '
              'доступности выбранных концов кабелей.',
          'Подтвердите подходящую модель соединителя, число и '
              'сечение проводников до создания клеммной записи.',
        ],
      ));
    }
    result.sort((a,b)=>a.circuitId.compareTo(b.circuitId));
    return result;
  }

  /// The candidate may have become stale after editing cables or terminals.
  /// Recheck its exact members in the CURRENT draft before applying.
  static void requireCurrent(
      FloorPlan floor, ElectricalNetwork draft, String junctionId,
      ElectricalJunctionConnectionProposal original) {
    final proposals = propose(floor,draft,junctionId);
    final current = proposals.any((p) =>
        p.circuitId == original.circuitId &&
        p.purpose == original.purpose &&
        p.members.map((m)=>m.key).toSet().containsAll(
          original.members.map((m)=>m.key)) &&
        original.members.map((m)=>m.key).toSet().containsAll(
          p.members.map((m)=>m.key)));
    if (!current) {
      throw const FormatException(
          'Предложение соединения устарело, проверьте связи заново.');
    }
  }
}
