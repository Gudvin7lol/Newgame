import '../models/electrical_design_draft.dart';
import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_din_layout_service.dart';

/// A single-device mechanical move proposal. It does not mutate the input,
/// silently shift other devices or assert that electrical wiring is safe.
class ElectricalDinMoveProposal {
  const ElectricalDinMoveProposal({this.preview, this.problem});
  final ElectricalDinBoardDraft? preview;
  final String? problem;
  bool get canApply => preview != null && problem == null;
  bool get approvedForInstallation => false;
}

class ElectricalDinMoveService {
  const ElectricalDinMoveService._();

  static ElectricalDinMoveProposal prepare(
    FloorPlan floor,
    ElectricalDinBoardDraft board, {
    required String deviceId,
    required int targetRow,
    required int targetHalfModule,
  }) {
    ElectricalDinMoveProposal reject(String message) =>
        ElectricalDinMoveProposal(problem: message);

    try {
      board.validate();
    } on FormatException catch (error) {
      return reject(error.message);
    }
    if (floor.electricalPoints.where((p) =>
        p.id == board.panelPointId &&
        p.type == ElectricalPointType.panel).length != 1) {
      return reject('Щит удалён или его ID неоднозначен.');
    }
    if (board.rows <= 0 || board.modulesPerRow <= 0) {
      return reject('Не указана вместимость DIN-рейки.');
    }
    final ids = <String>{};
    for (final d in board.devices) {
      if (!ids.add(d.id)) {
        return reject('Повторяется ID аппарата ${d.id}.');
      }
    }
    final matched = board.devices.where((d) => d.id == deviceId).toList();
    if (matched.length != 1) {
      return reject('Аппарат не найден или имеет неоднозначный ID.');
    }
    final source = matched.single;
    if (source.positionLocked) {
      return reject('Позиция аппарата закреплена. Сначала сними блокировку.');
    }
    if (source.model.trim().isEmpty || source.widthHalfModules == null) {
      return reject('Для перемещения нужна модель и паспортная ширина.');
    }
    final width = source.widthHalfModules!;
    if (targetRow < 0 || targetRow >= board.rows ||
        targetHalfModule < 0 ||
        targetHalfModule + width > board.modulesPerRow * 2) {
      return reject('Аппарат не помещается на выбранном DIN-месте.');
    }
    if (source.row == targetRow &&
        source.startHalfModule == targetHalfModule) {
      return reject('Аппарат уже находится на этом месте.');
    }
    for (final other in board.devices) {
      if (other.id == deviceId ||
          other.row == null || other.startHalfModule == null) continue;
      if (other.widthHalfModules == null ||
          other.model.trim().isEmpty) {
        return reject('У аппарата ${other.id} неизвестная паспортная ширина.');
      }
      if (other.row == targetRow &&
          targetHalfModule < other.startHalfModule! +
              other.widthHalfModules! &&
          other.startHalfModule! < targetHalfModule + width) {
        return reject('Место занято аппаратом ${other.id}.');
      }
    }

    final updated = board.devices.map((d) {
      if (d.id != deviceId) {
        return ElectricalDinDeviceDraft.fromJson(d.toJson());
      }
      return ElectricalDinDeviceDraft(
        id: d.id,
        kind: d.kind,
        label: d.label,
        model: d.model,
        circuitId: d.circuitId,
        widthHalfModules: d.widthHalfModules,
        row: targetRow,
        startHalfModule: targetHalfModule,
        positionLocked: false,
      );
    }).toList();
    final next = ElectricalDinBoardDraft(
      panelPointId: board.panelPointId,
      rows: board.rows,
      modulesPerRow: board.modulesPerRow,
      devices: updated,
    );
    const blocking = <String>{
      'invalidPanel', 'duplicateDevice', 'invalidCircuit',
      'outOfRail', 'overlap',
    };
    final faults = ElectricalDinLayoutService.inspect(floor, next).issues
        .where((issue) => blocking.contains(issue.code)).toList();
    if (faults.isNotEmpty) {
      return reject(faults.first.message);
    }
    return ElectricalDinMoveProposal(preview: next);
  }
}
