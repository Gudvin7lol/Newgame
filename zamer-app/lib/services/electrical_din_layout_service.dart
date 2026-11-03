import '../models/electrical_design_draft.dart';
import '../models/electrical_network.dart';
import '../models/models.dart';

/// A mechanical footprint check, NOT electrical verification or an automatic
/// protection layout. All rail sizes and device footprints must be entered.
class ElectricalDinLayoutIssue {
  const ElectricalDinLayoutIssue(this.code, this.message, {this.deviceId});
  final String code, message;
  final String? deviceId;
}

class ElectricalDinLayoutReview {
  const ElectricalDinLayoutReview({
    required this.railRows,
    required this.modulesPerRow,
    required this.occupiedHalfModules,
    required this.devices,
    required this.issues,
  });

  final int railRows, modulesPerRow, occupiedHalfModules;
  final List<ElectricalDinDeviceDraft> devices;
  final List<ElectricalDinLayoutIssue> issues;

  int? get totalHalfModules =>
      railRows > 0 && modulesPerRow > 0
          ? railRows * modulesPerRow * 2 : null;
  int? get freeHalfModules => totalHalfModules == null
      ? null : totalHalfModules! - occupiedHalfModules;
  bool get hasProblems => issues.isNotEmpty;
  bool get approvedForInstallation => false;
}

class ElectricalDinLayoutService {
  const ElectricalDinLayoutService._();

  static ElectricalDinLayoutReview inspect(
      FloorPlan floor, ElectricalDinBoardDraft draft) {
    final issues = <ElectricalDinLayoutIssue>[];
    final deviceIds = <String>{};
    final occupied = <(int, int), String>{};
    final panel = floor.electricalPoints.where(
        (p) => p.id == draft.panelPointId &&
            p.type == ElectricalPointType.panel).toList();
    if (panel.length != 1) {
      issues.add(const ElectricalDinLayoutIssue(
          'invalidPanel', 'Щит отсутствует или имеет неоднозначный ID.'));
    }
    if (draft.rows <= 0 || draft.modulesPerRow <= 0) {
      issues.add(const ElectricalDinLayoutIssue(
        'unknownRails',
        'Число DIN-рядов и вместимость корпуса пока не подтверждены.',
      ));
    }
    final circuitCounts = <String, int>{};
    for (final circuit in floor.electricalNetwork?.circuits
        ?? <ElectricalCircuitRecord>[]) {
      circuitCounts.update(
          circuit.id, (count) => count + 1, ifAbsent: () => 1);
    }

    for (final device in draft.devices) {
      if (!deviceIds.add(device.id)) {
        issues.add(ElectricalDinLayoutIssue('duplicateDevice',
            'Повторяется ID аппарата ${device.id}.', deviceId: device.id));
      }
      if (device.model.trim().isEmpty || device.widthHalfModules == null) {
        issues.add(ElectricalDinLayoutIssue('unknownFootprint',
            'Аппарат ${device.id}: модель или паспортная ширина не указана.',
            deviceId: device.id));
      }
      if (device.circuitId != null &&
          circuitCounts[device.circuitId] != 1) {
        issues.add(ElectricalDinLayoutIssue('invalidCircuit',
            'Аппарат ${device.id}: физическая группа удалена или неоднозначна.',
            deviceId: device.id));
      }
      final row = device.row;
      final start = device.startHalfModule;
      final width = device.widthHalfModules;
      if (row == null || start == null) {
        issues.add(ElectricalDinLayoutIssue(
          'unplacedDevice',
          'Аппарат ${device.id}: позиция на DIN-рейке не указана.',
          deviceId: device.id,
        ));
        continue;
      }
      if (draft.rows == 0 || draft.modulesPerRow == 0 ||
          row < 0 || row >= draft.rows ||
          start < 0 || width == null || width <= 0 ||
          start + width > draft.modulesPerRow * 2) {
        issues.add(ElectricalDinLayoutIssue(
          'outOfRail',
          'Аппарат ${device.id}: не помещается в указанном ряду.',
          deviceId: device.id,
        ));
        continue;
      }
      for (var halfModule = start; halfModule < start + width; halfModule++) {
        final cell = (row, halfModule);
        final existing = occupied[cell];
        if (existing != null) {
          issues.add(ElectricalDinLayoutIssue(
            'overlap',
            'Аппараты ${device.id} и $existing занимают одно DIN-место.',
            deviceId: device.id,
          ));
          break;
        }
      }
      // Mark cells even when overlap exists, but do not count the same
      // half-module as additional physically available space.
      for (var halfModule = start; halfModule < start + width; halfModule++) {
        occupied.putIfAbsent((row, halfModule), () => device.id);
      }
    }
    return ElectricalDinLayoutReview(
      railRows: draft.rows,
      modulesPerRow: draft.modulesPerRow,
      occupiedHalfModules: occupied.length,
      devices: List.unmodifiable(draft.devices),
      issues: List.unmodifiable(issues),
    );
  }
}
