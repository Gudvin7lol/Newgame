import '../models/electrical_junction_capacity.dart';
import '../models/electrical_network.dart';
import '../models/models.dart';

/// A structural count audit, NOT a legal/thermal/fire/electrical approval.
/// Limits stay unknown unless the user enters reliable device parameters.
class ElectricalJunctionCapacityReport {
  const ElectricalJunctionCapacityReport({
    required this.cableEntries,
    required this.conductorEnds,
    required this.connectorCount,
    required this.occupiedEnds,
    required this.unassignedEnds,
    required this.maxObservedConnectorSize,
    required this.enteredLimits,
    required this.violations,
    required this.missing,
  });
  final int cableEntries, conductorEnds, connectorCount, occupiedEnds;
  final int unassignedEnds, maxObservedConnectorSize;
  final bool enteredLimits;
  final List<String> violations, missing;

  bool get exceeded => violations.isNotEmpty;
  bool get incomplete => missing.isNotEmpty;
  bool get isApproved => false; // Count comparisons are not design approval.
}

class ElectricalJunctionCapacityService {
  const ElectricalJunctionCapacityService._();

  static ElectricalJunctionCapacityReport inspect(
    FloorPlan floor,
    ElectricalNetwork network,
    String junctionId,
  ) {
    if (!floor.electricalPoints.any((p) =>
        p.id == junctionId && p.type == ElectricalPointType.junctionBox)) {
      throw const FormatException('РК отсутствует в модели.');
    }
    final spec = network.junctionCapacities[junctionId];
    spec?.validate();
    if (spec != null && spec.junctionPointId != junctionId) {
      throw const FormatException('Параметры вместимости относятся к другой РК.');
    }
    final cables = network.cables.where((c) =>
        c.fromPointId == junctionId || c.toPointId == junctionId).toList();
    final terminals = network.terminals.where(
        (t) => t.junctionPointId == junctionId).toList();
    final conductorEnds = cables.fold<int>(0,
        (total, c) => total + c.cores.length);
    final mapped = <String>{
      for (final terminal in terminals)
        for (final member in terminal.members) member.key,
    };
    final occupied = cables.fold<int>(0, (total, cable) => total +
        cable.cores.where((core) =>
            mapped.contains('${cable.id}/${core.id}')).length);
    final greatest = terminals.fold<int>(0,
        (max, t) => t.members.length > max ? t.members.length : max);
    final problems = <String>[];
    final missing = <String>[];

    void limit(String name, int actual, int? maximum) {
      if (maximum == null) {
        missing.add('$name: предел не указан');
      } else if (actual > maximum) {
        problems.add('$name: $actual, допустимо по введённым данным '
            'не более $maximum');
      }
    }

    if (spec?.hasEnteredLimits == true && spec!.boxModel.trim().isEmpty) {
      missing.add('Для числовых пределов не указана паспортная модель коробки.');
    }
    limit('Кабельных вводов', cables.length, spec?.maxCableEntries);
    limit('Концов жил', conductorEnds, spec?.maxConductorEnds);
    limit('Соединителей', terminals.length, spec?.maxConnectorCount);
    limit('Концов в одном соединителе',
        greatest, spec?.maxEndsPerConnector);
    if (conductorEnds == 0) {
      missing.add('Нет описания жил. Вводы не равны подтверждённым подключениям.');
    }
    if (conductorEnds > occupied) {
      missing.add('Не назначены соединения для '
          '${conductorEnds - occupied} концов жил.');
    }
    missing.add('Не подтверждены объём/габариты РК, серия соединителей, '
        'сечения жил, теплоотвод, степень защиты и доступность.');
    return ElectricalJunctionCapacityReport(
      cableEntries:cables.length,
      conductorEnds:conductorEnds,
      connectorCount:terminals.length,
      occupiedEnds:occupied,
      unassignedEnds:conductorEnds-occupied,
      maxObservedConnectorSize:greatest,
      enteredLimits:spec?.hasEnteredLimits ?? false,
      violations:List.unmodifiable(problems),
      missing:List.unmodifiable(missing),
    );
  }

  /// Hard block only violations of EXPLICIT user limits. Unknown remains
  /// unverified, never silently assigned a guessed safe capacity.
  static void requireWithinEnteredLimits(
    FloorPlan floor, ElectricalNetwork network, String junctionId,
  ) {
    final report = inspect(floor, network, junctionId);
    if (report.exceeded) {
      throw FormatException('Вместимость РК не подтверждена: '
          '${report.violations.join('; ')}');
    }
  }
}
