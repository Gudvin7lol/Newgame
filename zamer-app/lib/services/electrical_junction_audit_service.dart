import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_junction_capacity_service.dart';
import 'electrical_route_service.dart';

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

  /// Check explicit wall-coordinate bindings against the latest measured
  /// wall nodes. Legacy freely placed points have no wall binding to check.
  /// Curved geometry is intentionally not reprojected onto a straight chord.
  static String? _wallAnchorProblem(FloorPlan floor, ElectricalPoint point) {
    if (point.wallId == null && point.wallOffsetMm == null) return null;
    if (point.wallId == null || point.wallOffsetMm == null ||
        !point.wallOffsetMm!.isFinite ||
        point.wallSide != 1 && point.wallSide != -1) {
      return 'Неполная или некорректная привязка к стене.';
    }
    final wall = floor.wallById(point.wallId!);
    if (wall == null) return 'Привязанная стена удалена.';
    if (wall.demolition) return 'Точка привязана к демонтируемой стене.';
    if (wall.isCurved) {
      return 'Положение на криволинейной стене требует ручной проверки.';
    }
    final start = floor.nodeById(wall.startNodeId);
    final finish = floor.nodeById(wall.endNodeId);
    final length = floor.wallLengthMm(wall);
    if (start == null || finish == null ||
        !length.isFinite || length <= .001 ||
        point.wallOffsetMm! < 0 || point.wallOffsetMm! > length) {
      return 'Стена или размер вдоль неё некорректны.';
    }
    final station = point.wallOffsetMm! / length;
    final expectedX = start.xMm + (finish.xMm - start.xMm) * station;
    final expectedY = start.yMm + (finish.yMm - start.yMm) * station;
    if (!point.xMm.isFinite || !point.yMm.isFinite ||
        (point.xMm - expectedX).abs() > 1 ||
        (point.yMm - expectedY).abs() > 1) {
      return 'Координаты точки не совпадают с привязкой к стене '
          'после изменения плана.';
    }
    return null;
  }

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
      final boxAnchor = _wallAnchorProblem(floor, box);
      if (boxAnchor != null) {
        errors.add('РК ${box.id}: $boxAnchor');
      }
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
        // On a changed floor, connected cable references can go stale even
        // when the topology record and its 3D path still exist.
        final startPoint = floor.electricalPoints
            .where((p) => p.id == cable.fromPointId).firstOrNull;
        final endPoint = floor.electricalPoints
            .where((p) => p.id == cable.toPointId).firstOrNull;
        if (startPoint == null || endPoint == null) {
          errors.add('Кабель ${cable.id}: отсутствует концевая '
              'точка после изменения плана.');
        }
        for (final terminalPoint in [startPoint, endPoint]) {
          if (terminalPoint == null) continue;
          final problem = _wallAnchorProblem(floor, terminalPoint);
          if (problem == null) continue;
          final message = 'Точка ${terminalPoint.id}: $problem';
          if (!errors.contains(message)) errors.add(message);
        }
        if (!network.circuits.any((c) => c.id == cable.circuitId)) {
          errors.add('Кабель ${cable.id}: группа удалена '
              'или больше не существует.');
        }
        if (cable.routeRunId != null) {
          final linked = floor.electricalRuns.where((run) =>
              run.id == cable.routeRunId &&
              ((run.startPointId == cable.fromPointId &&
                run.endPointId == cable.toPointId) ||
               (run.startPointId == cable.toPointId &&
                run.endPointId == cable.fromPointId)));
          if (linked.isEmpty) {
            errors.add('Кабель ${cable.id}: линия на плане '
                'не совпадает с фактическими концами.');
          }
        }
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
            // Includes missing/relocated endpoints, old heights, path
            // ownership and any newly introduced exclusion zones.
            ElectricalRouteService.measureCable(floor, cable);
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
