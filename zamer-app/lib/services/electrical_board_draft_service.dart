import 'dart:math' as math;

import '../models/models.dart';
import 'electrical_load_service.dart';

/// A preliminary **layout inventory**, not an electrical installation design.
///
/// Never select a breaker or protective-device rating using only a known
/// wattage, or claim this inventory certifies safety. There is deliberately
/// no ampacity/MCB sizing API in this class.
class ElectricalBoardCircuitDraft {
  const ElectricalBoardCircuitDraft({
    required this.load,
    required this.routedCableMeters,
    required this.cableTypes,
    required this.runCount,
    required this.crossCircuitRuns,
  });

  final ElectricalCircuitEstimate load;
  final double routedCableMeters;
  final List<String> cableTypes;
  final int runCount;
  final int crossCircuitRuns;

  bool get incomplete =>
      load.unratedCount > 0 || runCount == 0 || crossCircuitRuns > 0;
  bool get hasUnassignedCircuit => load.name == 'Без группы';
  String get protectiveDeviceStatus => 'Требует расчёта и проверки';
}

/// Ordered diagram sections represent **logical groups**, not DIN-module
/// widths or any wiring/termination instructions.
class ElectricalBoardSection {
  const ElectricalBoardSection({
    required this.id,
    required this.label,
    required this.role,
  });

  final String id;
  final String label;
  final String role;
}

class ElectricalBoardDraft {
  const ElectricalBoardDraft({
    required this.circuits,
    required this.sections,
    required this.voltageV,
    required this.powerFactor,
    required this.knownConnectedWatts,
    required this.unratedLoads,
    required this.crossCircuitRuns,
    required this.requiredChecks,
  });

  final List<ElectricalBoardCircuitDraft> circuits;
  final List<ElectricalBoardSection> sections;
  final double voltageV;
  final double powerFactor;
  final double knownConnectedWatts;
  final int unratedLoads;
  final int crossCircuitRuns;
  final List<String> requiredChecks;

  /// Arithmetic of the known loads only, not design/demand current.
  double get knownLoadAmps =>
      knownConnectedWatts / (voltageV * powerFactor);
  bool get isComplete => false;
  String get protectionStatus => 'Подбор защитных аппаратов не выполнен';
}

class ElectricalBoardDraftService {
  const ElectricalBoardDraftService._();

  static const List<String> requiredChecks = [
    'Схема питания: число фаз, напряжение и расчётная одновременность',
    'Система заземления, ввод и требования к защитному отключению',
    'Материал и сечение жил, реальный способ прокладки и температура',
    'Допустимые токи линий, падение напряжения и длины трасс',
    'Токи КЗ, петля повреждения и время автоматического отключения',
    'УЗО/дифзащита, селективность, УЗИП и местные требования',
    'Размер корпуса, тепловой режим, DIN-модули и запас места',
    'Проверка проекта квалифицированным электропроектировщиком',
  ];

  static ElectricalBoardDraft create(
    FloorPlan floor, {
    double voltageV = 230,
    double powerFactor = 1,
  }) {
    final groups = ElectricalLoadService.summarize(
      floor, voltageV: voltageV, powerFactor: powerFactor,
    );
    final points = <String, ElectricalPoint>{
      for (final p in floor.electricalPoints) p.id: p,
    };
    String groupName(ElectricalPoint p) =>
        p.circuit.trim().isEmpty ? 'Без группы' : p.circuit.trim();

    final perGroup = <String, List<ElectricalRun>>{};
    var crossCircuitRuns = 0;
    for (final run in floor.electricalRuns) {
      final a = points[run.startPointId];
      final b = points[run.endPointId];
      if (a == null || b == null) continue;
      final first = groupName(a);
      final second = groupName(b);
      if (first != second) {
        crossCircuitRuns++;
        continue; // Never quietly assign a cross-group cable to either line.
      }
      perGroup.putIfAbsent(first, () => []).add(run);
    }

    final circuits = <ElectricalBoardCircuitDraft>[
      for (final group in groups)
        _makeGroup(group, perGroup[group.name] ?? const [], points,
            crossCircuitRuns: floor.electricalRuns.where((run) {
              final a = points[run.startPointId];
              final b = points[run.endPointId];
              if (a == null || b == null) return false;
              return groupName(a) != groupName(b) &&
                  (groupName(a) == group.name ||
                      groupName(b) == group.name);
            }).length),
    ];
    final sections = <ElectricalBoardSection>[
      const ElectricalBoardSection(
        id: 'supply', label: 'Ввод', role: 'Уточнить схему и параметры'),
      const ElectricalBoardSection(
        id: 'protection', label: 'Защита', role: 'Типы и номиналы не выбраны'),
      for (var i = 0; i < circuits.length; i++)
        ElectricalBoardSection(
          id: 'circuit-$i',
          label: circuits[i].load.name,
          role: 'Место группы, без назначения аппарата'),
        const ElectricalBoardSection(
          id: 'reserve', label: 'Резерв',
          role: 'Размер уточнить после расчёта'),
    ];
    return ElectricalBoardDraft(
      circuits: List.unmodifiable(circuits),
      sections: List.unmodifiable(sections),
      voltageV: voltageV,
      powerFactor: powerFactor,
      knownConnectedWatts: groups.fold<double>(
        0, (total, group) => total + group.connectedWatts),
      unratedLoads: groups.fold<int>(
        0, (total, group) => total + group.unratedCount),
      crossCircuitRuns: crossCircuitRuns,
      requiredChecks: requiredChecks,
    );
  }

  static ElectricalBoardCircuitDraft _makeGroup(
    ElectricalCircuitEstimate load,
    List<ElectricalRun> runs,
    Map<String, ElectricalPoint> points, {
    required int crossCircuitRuns,
  }) {
    final cableTypes = <String>{};
    var meters = 0.0;
    for (final run in runs) {
      cableTypes.add(run.cable.trim().isEmpty
          ? 'Кабель не указан' : run.cable.trim());
      final a = points[run.startPointId]!;
      final b = points[run.endPointId]!;
      final dx = (a.xMm - b.xMm).abs();
      final dy = (a.yMm - b.yMm).abs();
      final routeMm = run.routeMode == 'orthogonal'
          ? dx + dy
          : math.sqrt(dx * dx + dy * dy);
      final reserve = run.reservePct.isFinite
          ? run.reservePct.clamp(0.0, 200.0).toDouble()
          : 0.0;
      meters += routeMm / 1000 * (1 + reserve / 100);
    }
    return ElectricalBoardCircuitDraft(
      load: load,
      runCount: runs.length,
      routedCableMeters: meters,
      cableTypes: List.unmodifiable(cableTypes.toList()..sort()),
      crossCircuitRuns: crossCircuitRuns,
    );
  }
}
