import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_junction_capacity_service.dart';
import 'electrical_route_exclusion_service.dart';

/// A read-only structural audit, NOT electrical verification or approval.
/// It keeps fatal inconsistencies distinct from unknown physical constraints.
class ElectricalJunctionAuditEntry {
  const ElectricalJunctionAuditEntry({
    required this.junctionId,
    required this.label,
    required this.capacity,
    required this.errors,
    required this.unknown,
  });

  final String junctionId, label;
  final ElectricalJunctionCapacityReport? capacity;
  final List<String> errors, unknown;
  bool get blocked => errors.isNotEmpty;
  bool get needsReview => unknown.isNotEmpty;
}

class ElectricalJunctionAuditReport {
  const ElectricalJunctionAuditReport({
    required this.entries,
    required this.globalErrors,
  });
  final List<ElectricalJunctionAuditEntry> entries;
  final List<String> globalErrors;

  int get boxes => entries.length;
  int get blocked => entries.where((e) => e.blocked).length;
  int get toReview => entries.where((e) => e.needsReview).length;
  bool get hasBlockingIssues =>
      globalErrors.isNotEmpty || blocked > 0;
  bool get approved => false; // Counts do not certify installation.
}

class ElectricalJunctionAuditService {
  const ElectricalJunctionAuditService._();

  static ElectricalJunctionAuditReport inspect(FloorPlan floor) {
    final network = floor.electricalNetwork ?? ElectricalNetwork();
    final boxes = floor.electricalPoints.where(
        (p) => p.type == ElectricalPointType.junctionBox).toList();
    final boxIds = boxes.map((b) => b.id).toSet();
    final globalErrors = <String>[];
    for (final entry in network.junctionCapacities.entries) {
      if (!boxIds.contains(entry.key)) {
        globalErrors.add('Параметры РК ${entry.key} относятся к '
            'несуществующей распределительной коробке.');
      } else if (entry.value.junctionPointId != entry.key) {
        globalErrors.add('Параметры РК ${entry.key} имеют '
            'несовпадающий идентификатор.');
      }
    }
    for (final terminal in network.terminals) {
      if (!boxIds.contains(terminal.junctionPointId)) {
        globalErrors.add('Соединение ${terminal.id} указывает '
            'на отсутствующую РК ${terminal.junctionPointId}.');
      }
    }

    final entries = <ElectricalJunctionAuditEntry>[];
    for (final box in boxes) {
      final errors = <String>[];
      final unknown = <String>[];
      ElectricalJunctionCapacityReport? capacity;
      try {
        capacity = ElectricalJunctionCapacityService.inspect(
            floor, network, box.id);
        errors.addAll(capacity.violations);
        unknown.addAll(capacity.missing);
      } on FormatException catch (e) {
        errors.add(e.message);
      }

      final terminals = network.terminals.where(
          (t) => t.junctionPointId == box.id).toList();
      final used = <String>{};
      for (final terminal in terminals) {
        if (terminal.members.length < 2) {
          errors.add('Соединение ${terminal.id}: менее двух концов жил.');
        }
        final circuits = <String>{};
        final roles = <ElectricalCorePurpose>{};
        var unknownPurpose = false;
        final cableIds = <String>{};
        for (final ref in terminal.members) {
          if (!used.add(ref.key)) {
            errors.add('Конец ${ref.key} подключён больше одного раза.');
          }
          final cable = network.cables.where(
              (c) => c.id == ref.cableId).firstOrNull;
          if (cable == null ||
              (cable.fromPointId != box.id &&
               cable.toPointId != box.id)) {
            errors.add('Соединение ${terminal.id}: конец ${ref.key} '
                'не относится к кабелю выбранной РК.');
            continue;
          }
          cableIds.add(cable.id);
          circuits.add(cable.circuitId);
          final core = cable.cores.where(
              (c) => c.id == ref.coreId).firstOrNull;
          if (core == null) {
            errors.add('Соединение ${terminal.id}: жила ${ref.key} '
                'не найдена.');
          } else if (core.purpose == ElectricalCorePurpose.unspecified) {
            unknownPurpose = true;
          } else {
            roles.add(core.purpose);
          }
        }
        if (circuits.length > 1) {
          errors.add('Соединение ${terminal.id} объединяет разные цепи.');
        }
        if (roles.length > 1) {
          errors.add('Соединение ${terminal.id}: функции жил различаются.');
        }
        if (cableIds.length < 2) {
          errors.add('Соединение ${terminal.id} не объединяет '
              'два отдельных кабеля.');
        }
        if (unknownPurpose) {
          unknown.add('У соединения ${terminal.id} есть жилы '
              'без подтверждённого назначения.');
        }
      }
      for (final cable in network.cables.where(
          (c) => c.fromPointId == box.id || c.toPointId == box.id)) {
        if (cable.route3dId == null) {
          unknown.add('Кабель ${cable.id}: трёхмерная трасса не задана.');
          continue;
        }
        final route = network.routes3d.where(
            (r) => r.id == cable.route3dId).firstOrNull;
        if (route == null) {
          errors.add('Кабель ${cable.id} ссылается '
              'на отсутствующую 3D-трассу.');
        } else {
          try {
            ElectricalRouteExclusionService.requireClear(floor, route);
          } on FormatException catch (e) {
            errors.add('Кабель ${cable.id}: ${e.message}');
          }
        }
      }
      unknown.add('Не подтверждены условия доступа после отделки, '
          'реальные размеры, соединители и условия эксплуатации.');
      entries.add(ElectricalJunctionAuditEntry(
        junctionId:box.id,
        label:box.label.isEmpty ? 'РК ${box.id}' : box.label,
        capacity:capacity,
        errors:List.unmodifiable(errors),
        unknown:List.unmodifiable(unknown),
      ));
    }
    return ElectricalJunctionAuditReport(
      entries:List.unmodifiable(entries),
      globalErrors:List.unmodifiable(globalErrors),
    );
  }
}
