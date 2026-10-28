import 'electrical_route_3d.dart';

/// Explicit, provisional electrical topology. Never inferred from positions or
/// the legacy circuit name stored on ElectricalPoint.
///
/// Topology records describe user-entered links, not inspected wiring, safety
/// compliance, protection settings or an approved switchboard.
enum ElectricalCircuitKind { power, lighting, lowVoltage, unknown }

enum ElectricalCorePurpose {
  unspecified,
  phase,
  neutral,
  protectiveEarth,
  switchedPhase,
  signal,
  shield,
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

class ElectricalCircuitRecord {
  ElectricalCircuitRecord({
    required this.id,
    required this.name,
    this.kind = ElectricalCircuitKind.unknown,
    this.sourcePanelPointId,
    this.legacyGroupName,
  });

  final String id;
  String name;
  ElectricalCircuitKind kind;
  String? sourcePanelPointId;
  /// A label copied by a human as a hint; never proof of a connection.
  String? legacyGroupName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'sourcePanelPointId': sourcePanelPointId,
    'legacyGroupName': legacyGroupName,
  };

  factory ElectricalCircuitRecord.fromJson(Map<String, dynamic> json) =>
      ElectricalCircuitRecord(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        kind: _enumValue(ElectricalCircuitKind.values, json['kind'],
            ElectricalCircuitKind.unknown),
        sourcePanelPointId: json['sourcePanelPointId'] as String?,
        legacyGroupName: json['legacyGroupName'] as String?,
      );
}

class ElectricalCableCore {
  ElectricalCableCore({
    required this.id,
    this.purpose = ElectricalCorePurpose.unspecified,
    this.mark = '',
  });

  final String id;
  ElectricalCorePurpose purpose;
  String mark;

  Map<String, dynamic> toJson() => {
    'id': id,
    'purpose': purpose.name,
    'mark': mark,
  };

  factory ElectricalCableCore.fromJson(Map<String, dynamic> json) =>
      ElectricalCableCore(
        id: json['id'] as String,
        purpose: _enumValue(ElectricalCorePurpose.values, json['purpose'],
            ElectricalCorePurpose.unspecified),
        mark: json['mark'] as String? ?? '',
      );
}

class ElectricalCableRecord {
  ElectricalCableRecord({
    required this.id,
    required this.circuitId,
    required this.fromPointId,
    required this.toPointId,
    this.routeRunId,
    this.route3dId,
    this.explicitReserveMm,
    List<ElectricalCableCore>? cores,
    this.description = '',
  }) : cores = cores ?? [];

  final String id;
  String circuitId;
  String fromPointId;
  String toPointId;
  /// Refers to a drawn ElectricalRun only when explicitly linked.
  String? routeRunId;
  /// Independent, explicit world-coordinate path; optional on older projects.
  String? route3dId;
  /// Unknown unless provided by the user; never assume zero reserve.
  double? explicitReserveMm;
  String description;
  final List<ElectricalCableCore> cores;

  Map<String, dynamic> toJson() => {
    'id': id,
    'circuitId': circuitId,
    'fromPointId': fromPointId,
    'toPointId': toPointId,
    'routeRunId': routeRunId,
    'route3dId': route3dId,
    'explicitReserveMm': explicitReserveMm,
    'description': description,
    'cores': cores.map((e) => e.toJson()).toList(),
  };

  factory ElectricalCableRecord.fromJson(Map<String, dynamic> json) =>
      ElectricalCableRecord(
        id: json['id'] as String,
        circuitId: json['circuitId'] as String,
        fromPointId: json['fromPointId'] as String,
        toPointId: json['toPointId'] as String,
        routeRunId: json['routeRunId'] as String?,
        route3dId: json['route3dId'] as String?,
        explicitReserveMm: (json['explicitReserveMm'] as num?)?.toDouble(),
        description: json['description'] as String? ?? '',
        cores: ((json['cores'] as List?) ?? const [])
            .map((e) => ElectricalCableCore.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ElectricalCoreReference {
  const ElectricalCoreReference({
    required this.cableId,
    required this.coreId,
  });

  final String cableId;
  final String coreId;
  String get key => cableId + '/' + coreId;

  Map<String, dynamic> toJson() => {
    'cableId': cableId,
    'coreId': coreId,
  };

  factory ElectricalCoreReference.fromJson(Map<String, dynamic> json) =>
      ElectricalCoreReference(
        cableId: json['cableId'] as String,
        coreId: json['coreId'] as String,
      );
}

/// Each terminal connects precisely the specified cores inside one box.
/// Drawing cables that cross at the box never populates this list.
class ElectricalTerminalRecord {
  ElectricalTerminalRecord({
    required this.id,
    required this.junctionPointId,
    this.mark = '',
    List<ElectricalCoreReference>? members,
  }) : members = members ?? [];

  final String id;
  String junctionPointId;
  String mark;
  final List<ElectricalCoreReference> members;

  Map<String, dynamic> toJson() => {
    'id': id,
    'junctionPointId': junctionPointId,
    'mark': mark,
    'members': members.map((e) => e.toJson()).toList(),
  };

  factory ElectricalTerminalRecord.fromJson(Map<String, dynamic> json) =>
      ElectricalTerminalRecord(
        id: json['id'] as String,
        junctionPointId: json['junctionPointId'] as String,
        mark: json['mark'] as String? ?? '',
        members: ((json['members'] as List?) ?? const [])
            .map((e) => ElectricalCoreReference.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ElectricalNetwork {
  ElectricalNetwork({
    List<ElectricalCircuitRecord>? circuits,
    List<ElectricalCableRecord>? cables,
    List<ElectricalTerminalRecord>? terminals,
    List<ElectricalRoute3d>? routes3d,
  })  : circuits = circuits ?? [],
        cables = cables ?? [],
        terminals = terminals ?? [],
        routes3d = routes3d ?? [];

  static const int schemaVersion = 1;
  final List<ElectricalCircuitRecord> circuits;
  final List<ElectricalCableRecord> cables;
  final List<ElectricalTerminalRecord> terminals;
  /// Physical routes may be reused by several cables.
  final List<ElectricalRoute3d> routes3d;

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'circuits': circuits.map((e) => e.toJson()).toList(),
    'cables': cables.map((e) => e.toJson()).toList(),
    'terminals': terminals.map((e) => e.toJson()).toList(),
    'routes3d': routes3d.map((e) => e.toJson()).toList(),
  };

  factory ElectricalNetwork.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version != schemaVersion) {
      throw FormatException('Неподдерживаемая версия электрической схемы: ' +
          version.toString());
    }
    return ElectricalNetwork(
      circuits: ((json['circuits'] as List?) ?? const [])
          .map((e) => ElectricalCircuitRecord.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      cables: ((json['cables'] as List?) ?? const [])
          .map((e) => ElectricalCableRecord.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      terminals: ((json['terminals'] as List?) ?? const [])
          .map((e) => ElectricalTerminalRecord.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      routes3d: ((json['routes3d'] as List?) ?? const [])
          .map((e) => ElectricalRoute3d.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
