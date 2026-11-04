import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_cable_journal_service.dart';
import 'electrical_circuit_path_service.dart';

/// Read-only bridge between explicitly recorded physical circuits and the
/// preliminary board UI. Legacy point.circuit labels and design-engine auto
/// line IDs are NOT automatically treated as physical circuit IDs.
class ElectricalBoardNetworkCircuit {
  const ElectricalBoardNetworkCircuit({
    required this.id,
    required this.name,
    required this.kind,
    required this.panelLabel,
    required this.hasValidPanel,
    required this.cableCount,
    required this.routedCount,
    required this.invalidRouteCount,
    required this.missingRouteCount,
    required this.unknownReserveCount,
    required this.knownGeometricMm,
    required this.knownWithReserveMm,
    required this.messages,
    required this.hasAmbiguousId,
  });

  final String id, name, panelLabel;
  final ElectricalCircuitKind kind;
  final bool hasValidPanel, hasAmbiguousId;
  final int cableCount, routedCount, invalidRouteCount, missingRouteCount;
  final int unknownReserveCount;
  /// Only measured physical routes. Never substitute drawn legacy 2D runs.
  final double? knownGeometricMm, knownWithReserveMm;
  final List<String> messages;

  bool get needsReview => messages.isNotEmpty;
  bool get readyForInstallation => false;
}

class ElectricalBoardNetworkReview {
  const ElectricalBoardNetworkReview(this.circuits, this.hasNetwork);
  final List<ElectricalBoardNetworkCircuit> circuits;
  final bool hasNetwork;
  int get requiresReview => circuits.where((c) => c.needsReview).length;
  bool get readyForInstallation => false;
}

class ElectricalBoardNetworkReviewService {
  const ElectricalBoardNetworkReviewService._();

  static ElectricalBoardNetworkReview create(FloorPlan floor) {
    final network = floor.electricalNetwork;
    if (network == null) {
      return const ElectricalBoardNetworkReview([], false);
    }
    final pathIssues = ElectricalCircuitPathService.inspect(floor);
    final counts = <String, int>{};
    for (final circuit in network.circuits) {
      counts.update(circuit.id, (n) => n + 1, ifAbsent: () => 1);
    }
    final panelPoints = {
      for (final point in floor.electricalPoints)
        if (point.type == ElectricalPointType.panel) point.id: point,
    };
    final result = <ElectricalBoardNetworkCircuit>[];
    for (final circuit in network.circuits) {
      final ambiguous = circuit.id.trim().isEmpty || counts[circuit.id] != 1;
      final panel = panelPoints[circuit.sourcePanelPointId];
      final messages = <String>[];
      final panelName = panel == null ? 'Не назначен' :
          (panel.label.trim().isEmpty ? panel.id : panel.label);
      if (ambiguous) {
        messages.add('Повторный или пустой ID электрической группы.');
      }
      if (panel == null) {
        messages.add(circuit.sourcePanelPointId == null
            ? 'Для группы не указан щит-источник.'
            : 'Указанный щит-источник не найден на плане.');
      }
      if (circuit.kind == ElectricalCircuitKind.unknown) {
        messages.add('Назначение группы не классифицировано.');
      }
      final totals = ambiguous ? null :
          ElectricalCableJournalService.create(
              floor, circuitId: circuit.id).totals;
      final count = totals?.cableCount ??
          network.cables.where((c) => c.circuitId == circuit.id).length;
      if (count == 0) {
        messages.add('Не записано ни одного физического кабеля.');
      }
      if (totals != null) {
        if (totals.unknownRouteCount > 0) {
          messages.add('Без 3D-трассы: ${totals.unknownRouteCount}.');
        }
        if (totals.invalidRouteCount > 0) {
          messages.add('Недействительных трасс: ${totals.invalidRouteCount}.');
        }
        if (totals.unknownReserveCount > 0) {
          messages.add('Не указан монтажный запас: ${totals.unknownReserveCount}.');
        }
      }
      for (final issue in pathIssues.where((p) => p.circuitId == circuit.id)) {
        messages.add(issue.message);
      }
      // Full geometry does not establish DIN sizes, protective ratings,
      // RCD selection or electrical installation safety.
      result.add(ElectricalBoardNetworkCircuit(
        id: circuit.id,
        name: circuit.name.trim().isEmpty ? circuit.id : circuit.name,
        kind: circuit.kind,
        panelLabel: panelName,
        hasValidPanel: panel != null,
        hasAmbiguousId: ambiguous,
        cableCount: count,
        routedCount: totals?.routedCount ?? 0,
        missingRouteCount: totals?.unknownRouteCount ?? count,
        invalidRouteCount: totals?.invalidRouteCount ?? 0,
        unknownReserveCount: totals?.unknownReserveCount ?? 0,
        knownGeometricMm: totals?.knownGeometricMm,
        knownWithReserveMm: totals?.complete == true
            ? totals!.knownWithReserveMm : null,
        messages: List.unmodifiable(messages),
      ));
    }
    return ElectricalBoardNetworkReview(List.unmodifiable(result), true);
  }
}
