import '../models/electrical_design_draft.dart';
import '../models/electrical_network.dart';
import '../models/models.dart';

/// Geometry-only suggestion, never a protective device recommendation.
/// All widths, rail capacities and device identities come from the user.
class ElectricalDinPositionChange {
  const ElectricalDinPositionChange({
    required this.deviceId,
    required this.previousRow,
    required this.previousHalfModule,
    required this.nextRow,
    required this.nextHalfModule,
  });

  final String deviceId;
  final int? previousRow, previousHalfModule;
  final int nextRow, nextHalfModule;
}

class ElectricalDinLayoutProposal {
  const ElectricalDinLayoutProposal({
    required this.preview,
    required this.changes,
    required this.problems,
  });

  /// Detached snapshot; NULL if an atomic complete placement is impossible.
  /// Calling propose() never changes the live floor or input board.
  final ElectricalDinBoardDraft? preview;
  final List<ElectricalDinPositionChange> changes;
  final List<String> problems;

  bool get canApply => preview != null && problems.isEmpty &&
      changes.isNotEmpty;
  bool get approvedForInstallation => false;
}

class ElectricalDinLayoutProposalService {
  const ElectricalDinLayoutProposalService._();

  static ElectricalDinLayoutProposal propose(
      FloorPlan floor, ElectricalDinBoardDraft board) {
    ElectricalDinLayoutProposal reject(String reason) =>
        ElectricalDinLayoutProposal(
          preview: null, changes: const [], problems: [reason]);

    try {
      board.validate();
    } on FormatException catch (error) {
      return reject(error.message);
    }
    final panels = floor.electricalPoints.where((p) =>
        p.id == board.panelPointId &&
        p.type == ElectricalPointType.panel);
    if (panels.length != 1) {
      return reject('Щит удалён или его ID неоднозначен.');
    }
    if (board.rows <= 0 || board.modulesPerRow <= 0) {
      return reject('Укажи паспортную вместимость DIN-корпуса.');
    }
    final ids = <String>{};
    final circuits = <String, int>{};
    for (final c in floor.electricalNetwork?.circuits ??
        <ElectricalCircuitRecord>[]) {
      circuits.update(c.id, (n) => n + 1, ifAbsent: () => 1);
    }
    final perRow = board.modulesPerRow * 2;
    // Preserve every locked position byte-for-byte. Invalid locks block the
    // proposal instead of being shifted or silently ignored.
    final occupied = List.generate(
        board.rows, (_) => List<String?>.filled(perRow, null));
    for (final d in board.devices) {
      if (!ids.add(d.id)) {
        return reject('Повторный ID аппарата: ${d.id}.');
      }
      if (d.widthHalfModules == null || d.model.trim().isEmpty) {
        return reject('У аппарата ${d.id} нет модели или паспортной ширины.');
      }
      if (d.widthHalfModules! > perRow) {
        return reject('Аппарат ${d.id} шире одного DIN-ряда.');
      }
      if (d.circuitId != null && circuits[d.circuitId] != 1) {
        return reject('Аппарат ${d.id} ссылается на удалённую '
            'или неоднозначную физическую группу.');
      }
      if (!d.positionLocked) continue;
      final row = d.row;
      final start = d.startHalfModule;
      final width = d.widthHalfModules!;
      if (row == null || start == null ||
          row < 0 || row >= board.rows ||
          start < 0 || start + width > perRow) {
        return reject('Закреплённая позиция аппарата ${d.id} '
            'выходит за DIN-ряд или не задана.');
      }
      for (var x = start; x < start + width; x++) {
        if (occupied[row][x] != null) {
          return reject('Закреплённые аппараты ${occupied[row][x]} '
              'и ${d.id} пересекаются.');
        }
        occupied[row][x] = d.id;
      }
    }

    // Place wider units first to reduce fragmentation. Stable ID tie-break
    // makes the same input yield exactly the same suggestion.
    final movable = board.devices.where((d) => !d.positionLocked).toList()
      ..sort((a, b) {
        final size = b.widthHalfModules!.compareTo(a.widthHalfModules!);
        return size == 0 ? a.id.compareTo(b.id) : size;
      });
    final placements = <String, (int, int)>{};
    for (final d in movable) {
      final width = d.widthHalfModules!;
      (int, int)? place;
      for (var row = 0; row < board.rows && place == null; row++) {
        for (var x = 0; x <= perRow - width; x++) {
          var clear = true;
          for (var step = 0; step < width; step++) {
            if (occupied[row][x + step] != null) {
              clear = false;
              break;
            }
          }
          if (clear) {
            place = (row, x);
            break;
          }
        }
      }
      if (place == null) {
        return reject('Недостаточно непрерывных DIN-мест для '
            'аппарата ${d.id}. Ничего не перемещено.');
      }
      placements[d.id] = place;
      for (var step = 0; step < width; step++) {
        occupied[place.$1][place.$2 + step] = d.id;
      }
    }

    final changes = <ElectricalDinPositionChange>[];
    final updated = <ElectricalDinDeviceDraft>[];
    for (final d in board.devices) {
      final target = placements[d.id];
      if (target == null) {
        // Exact locked-device object; no reordering or position mutation.
        updated.add(ElectricalDinDeviceDraft.fromJson(d.toJson()));
        continue;
      }
      if (d.row != target.$1 || d.startHalfModule != target.$2) {
        changes.add(ElectricalDinPositionChange(
          deviceId: d.id,
          previousRow: d.row,
          previousHalfModule: d.startHalfModule,
          nextRow: target.$1,
          nextHalfModule: target.$2,
        ));
      }
      updated.add(ElectricalDinDeviceDraft(
        id: d.id,
        kind: d.kind,
        label: d.label,
        model: d.model,
        circuitId: d.circuitId,
        widthHalfModules: d.widthHalfModules,
        row: target.$1,
        startHalfModule: target.$2,
        positionLocked: false,
      ));
    }
    final preview = ElectricalDinBoardDraft(
      panelPointId: board.panelPointId,
      rows: board.rows,
      modulesPerRow: board.modulesPerRow,
      devices: updated,
    );
    return ElectricalDinLayoutProposal(
      preview: preview,
      changes: List.unmodifiable(changes),
      problems: const [],
    );
  }
}
