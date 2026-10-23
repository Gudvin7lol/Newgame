import '../models/models.dart';

/// Early design-stage load inventory. Does not select circuit breakers:
/// protection requires cable ampacity, installation method, prospective
/// fault current, disconnection time, earthing system and local standards.
class ElectricalCircuitEstimate {
  const ElectricalCircuitEstimate({
    required this.name,
    required this.connectedWatts,
    required this.loadCount,
    required this.unratedCount,
    required this.voltageV,
    required this.powerFactor,
  });

  final String name;
  final double connectedWatts;
  final int loadCount;
  final int unratedCount;
  final double voltageV;
  final double powerFactor;

  double get estimatedAmps => connectedWatts / (voltageV * powerFactor);
}

class ElectricalLoadService {
  const ElectricalLoadService._();

  static List<ElectricalCircuitEstimate> summarize(
    FloorPlan floor, {
    double voltageV = 230,
    double powerFactor = 1,
  }) {
    if (!voltageV.isFinite || voltageV <= 0 ||
        !powerFactor.isFinite || powerFactor <= 0 ||
        powerFactor > 1) {
      throw ArgumentError('Voltage and power factor must be positive and finite');
    }
    final groups = <String, List<ElectricalPoint>>{};
    for (final point in floor.electricalPoints) {
      final group = point.circuit.trim().isEmpty
          ? 'Без группы' : point.circuit.trim();
      groups.putIfAbsent(group, () => []).add(point);
    }
    return groups.entries.map((entry) {
      final watts = entry.value.fold<double>(0, (total, point) =>
        point.powerW.isFinite && point.powerW > 0
            ? total + point.powerW : total);
      // Empty power values cannot silently be treated as a verified zero
      // demand for receptacles, fixtures and appliances.
      final missing = entry.value.where((point) =>
        (!point.powerW.isFinite || point.powerW <= 0) &&
        (point.type == ElectricalPointType.socket ||
         point.type == ElectricalPointType.frame ||
         point.type == ElectricalPointType.appliance ||
         point.type == ElectricalPointType.ceilingLight ||
         point.type == ElectricalPointType.wallLight)).length;
      return ElectricalCircuitEstimate(
        name: entry.key,
        connectedWatts: watts,
        loadCount: entry.value.length,
        unratedCount: missing,
        voltageV: voltageV,
        powerFactor: powerFactor,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
