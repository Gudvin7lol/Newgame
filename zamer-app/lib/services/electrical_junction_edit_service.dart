import '../models/models.dart';
import '../models/electrical_network.dart';
import 'electrical_network_service.dart';

/// Atomic domain mutations for a *detached* network draft. No mutation of the
/// actual FloorPlan happens until the editor returns a validated snapshot.
class ElectricalJunctionEditService {
  const ElectricalJunctionEditService._();

  static ElectricalNetwork copy(ElectricalNetwork? network) => network == null
      ? ElectricalNetwork()
      : ElectricalNetwork.fromJson(network.toJson());

  static ElectricalPoint _box(FloorPlan floor, String junctionId) {
    final matches = floor.electricalPoints.where(
      (point) => point.id == junctionId &&
          point.type == ElectricalPointType.junctionBox,
    );
    if (matches.isEmpty) {
      throw const FormatException('Распредкоробка удалена или изменена.');
    }
    return matches.first;
  }

  static String createCircuit(
    ElectricalNetwork draft, {
    required String id,
    required String name,
    required ElectricalCircuitKind kind,
  }) {
    if (id.trim().isEmpty ||
        draft.circuits.any((element) => element.id == id)) {
      throw const FormatException('Повторный ID электрической цепи.');
    }
    if (name.trim().isEmpty) {
      throw const FormatException('Укажите название цепи.');
    }
    draft.circuits.add(ElectricalCircuitRecord(
      id: id, name: name.trim(), kind: kind,
    ));
    return id;
  }

  static String createCable(
    FloorPlan floor,
    ElectricalNetwork draft, {
    required String id,
    required String junctionId,
    required String otherPointId,
    required String circuitId,
    required bool fromBox,
    required int coreCount,
    String? routeRunId,
    String description = '',
  }) {
    _box(floor, junctionId);
    if (id.trim().isEmpty || draft.cables.any((element) => element.id == id)) {
      throw const FormatException('Повторный ID кабеля.');
    }
    if (junctionId == otherPointId ||
        !floor.electricalPoints.any((p) => p.id == otherPointId)) {
      throw const FormatException('Выберите другую существующую точку.');
    }
    if (!draft.circuits.any((c) => c.id == circuitId)) {
      throw const FormatException('Сначала создайте или выберите цепь.');
    }
    if (coreCount < 1 || coreCount > 12) {
      throw const FormatException('Укажите число жил от 1 до 12.');
    }
    final from = fromBox ? junctionId : otherPointId;
    final to = fromBox ? otherPointId : junctionId;
    if (routeRunId != null) {
      final runs = floor.electricalRuns.where((r) => r.id == routeRunId &&
          ((r.startPointId == from && r.endPointId == to) ||
              (r.startPointId == to && r.endPointId == from)));
      if (runs.isEmpty) {
        throw const FormatException('Линия на плане не совпадает с кабелем.');
      }
    }
    draft.cables.add(ElectricalCableRecord(
      id: id,
      circuitId: circuitId,
      fromPointId: from,
      toPointId: to,
      routeRunId: routeRunId,
      description: description.trim(),
      // Purely physical numbering, no invented L/N/PE designation.
      cores: List.generate(coreCount, (index) =>
          ElectricalCableCore(id: (index + 1).toString())),
    ));
    return id;
  }

  static void setCorePurpose(
    ElectricalNetwork draft, {
    required String cableId,
    required String coreId,
    required ElectricalCorePurpose purpose,
  }) {
    final cable = draft.cables.where((c) => c.id == cableId).firstOrNull;
    final core = cable?.cores.where((c) => c.id == coreId).firstOrNull;
    if (core == null) {
      throw const FormatException('Жила больше не существует.');
    }
    core.purpose = purpose;
  }

  static void removeCable(ElectricalNetwork draft, String id) {
    if (draft.terminals.any((t) => t.members.any((m) => m.cableId == id))) {
      throw const FormatException(
        'Кабель участвует в клеммах. Сначала удалите его соединения.',
      );
    }
    draft.cables.removeWhere((c) => c.id == id);
  }

  static String createTerminal(
    FloorPlan floor,
    ElectricalNetwork draft, {
    required String id,
    required String junctionId,
    required String mark,
    required List<ElectricalCoreReference> members,
  }) {
    _box(floor, junctionId);
    if (id.trim().isEmpty || draft.terminals.any((t) => t.id == id)) {
      throw const FormatException('Повторный ID клеммы.');
    }
    if (members.length < 2) {
      throw const FormatException('Выберите минимум два конца жил.');
    }
    final present = <String>{};
    final circuitIds = <String>{};
    final cableIds = <String>{};
    final purposes = <ElectricalCorePurpose>{};
    for (final ref in members) {
      if (!present.add(ref.key)) {
        throw const FormatException('Одна жила выбрана дважды.');
      }
      if (draft.terminals.any((t) =>
          t.junctionPointId == junctionId &&
          t.members.any((m) => m.key == ref.key))) {
        throw const FormatException('Эта жила уже назначена другой клемме.');
      }
      final cable = draft.cables.where((c) => c.id == ref.cableId).firstOrNull;
      if (cable == null ||
          (cable.fromPointId != junctionId && cable.toPointId != junctionId)) {
        throw const FormatException('Жила не заведена в выбранную коробку.');
      }
      final core = cable.cores.where((c) => c.id == ref.coreId).firstOrNull;
      if (core == null) {
        throw const FormatException('Указанная жила кабеля отсутствует.');
      }
      circuitIds.add(cable.circuitId);
      cableIds.add(cable.id);
      if (core.purpose != ElectricalCorePurpose.unspecified) {
        purposes.add(core.purpose);
      }
    }
    if (cableIds.length < 2) {
      throw const FormatException(
        'Для этой соединительной клеммы нужны жилы минимум двух кабелей.',
      );
    }
    if (circuitIds.length != 1) {
      throw const FormatException('Нельзя смешивать цепи в одной клемме.');
    }
    if (purposes.length > 1) {
      throw const FormatException(
        'У выбранных жил разные назначенные функции. Проверьте маркировку.',
      );
    }
    draft.terminals.add(ElectricalTerminalRecord(
      id: id, junctionPointId: junctionId,
      mark: mark.trim(), members: List.of(members),
    ));
    return id;
  }

  static void removeTerminal(ElectricalNetwork draft, String id) =>
      draft.terminals.removeWhere((t) => t.id == id);

  /// Preflight all references on a cloned floor, keeping the live floor
  /// untouched even when the candidate is corrupt.
  static void validateForSave(
    FloorPlan live,
    String junctionId,
    ElectricalNetwork draft,
  ) {
    _box(live, junctionId);
    final cloned = FloorPlan.fromJson(live.toJson());
    cloned.electricalNetwork = copy(draft);
    final blocking = ElectricalNetworkService.inspect(cloned)
        .where((i) => i.severity == ElectricalNetworkSeverity.error)
        .toList();
    if (blocking.isNotEmpty) {
      throw FormatException(blocking.first.message);
    }
  }

  static bool pointInUse(ElectricalNetwork? network, String pointId) =>
      network != null &&
      (network.cables.any((c) =>
            c.fromPointId == pointId || c.toPointId == pointId) ||
        network.terminals.any((t) => t.junctionPointId == pointId) ||
        network.circuits.any((c) => c.sourcePanelPointId == pointId));
}
