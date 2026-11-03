/// Explicit, provisional electrical engineering assumptions.
/// These are NOT approved wiring directions, breaker recommendations,
/// statutory cable ratings or evidence of verified installation conditions.
enum ElectricalConsumerKind { dedicated, sockets, lighting, critical, unknown }
enum ElectricalPhase { l1, l2, l3, threePhase, unassigned }
enum ElectricalProtection { unknown, groupRcd, rcbo }
enum ElectricalIssueSeverity { error, warning, missingInformation }

T enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

class ElectricalSupplyDraft {
  const ElectricalSupplyDraft({
    this.phasesCount = 1,
    this.phaseVoltageV = 230,
    this.lineVoltageV = 400,
    this.powerFactor = 0.98,
    this.inputBreakerAmps,
    this.approvedInputPowerKw,
    this.phaseImbalanceGoalPercent = 15,
  });

  final int phasesCount;
  final double phaseVoltageV, lineVoltageV, powerFactor;
  final double? inputBreakerAmps, approvedInputPowerKw;
  /// User-set optimisation target, NOT a universal regulatory limit.
  final double phaseImbalanceGoalPercent;

  void validate() {
    if (phasesCount != 1 && phasesCount != 3) {
      throw const FormatException('Введите 1 или 3 фазы.');
    }
    if (!phaseVoltageV.isFinite || phaseVoltageV <= 0 ||
        !lineVoltageV.isFinite || lineVoltageV <= 0 ||
        !powerFactor.isFinite || powerFactor <= 0 || powerFactor > 1 ||
        !phaseImbalanceGoalPercent.isFinite ||
        phaseImbalanceGoalPercent < 0 || phaseImbalanceGoalPercent > 100 ||
        (inputBreakerAmps != null &&
            (!inputBreakerAmps!.isFinite || inputBreakerAmps! <= 0)) ||
        (approvedInputPowerKw != null &&
            (!approvedInputPowerKw!.isFinite || approvedInputPowerKw! <= 0))) {
      throw const FormatException('Некорректные исходные параметры электросети.');
    }
  }

  Map<String, dynamic> toJson() => {
    'phasesCount': phasesCount, 'phaseVoltageV': phaseVoltageV,
    'lineVoltageV': lineVoltageV, 'powerFactor': powerFactor,
    'inputBreakerAmps': inputBreakerAmps,
    'approvedInputPowerKw': approvedInputPowerKw,
    'phaseImbalanceGoalPercent': phaseImbalanceGoalPercent,
  };

  factory ElectricalSupplyDraft.fromJson(Map<String, dynamic> j) =>
      ElectricalSupplyDraft(
        phasesCount: (j['phasesCount'] as num?)?.toInt() ?? 1,
        phaseVoltageV: (j['phaseVoltageV'] as num?)?.toDouble() ?? 230,
        lineVoltageV: (j['lineVoltageV'] as num?)?.toDouble() ?? 400,
        powerFactor: (j['powerFactor'] as num?)?.toDouble() ?? 0.98,
        inputBreakerAmps: (j['inputBreakerAmps'] as num?)?.toDouble(),
        approvedInputPowerKw: (j['approvedInputPowerKw'] as num?)?.toDouble(),
        phaseImbalanceGoalPercent:
            (j['phaseImbalanceGoalPercent'] as num?)?.toDouble() ?? 15,
      );
}

class ElectricalConsumerDraft {
  const ElectricalConsumerDraft({
    required this.pointId,
    this.catalogId,
    this.roomId,
    this.kind = ElectricalConsumerKind.unknown,
    this.installedWatts,
    this.demandFactor,
    this.isDedicated = false,
    this.isWetZone = false,
    this.isNonSwitchable = false,
    this.threePhase = false,
    this.lockedLineId,
  });
  final String pointId;
  final String? catalogId, roomId, lockedLineId;
  final ElectricalConsumerKind kind;
  final double? installedWatts, demandFactor;
  final bool isDedicated, isWetZone, isNonSwitchable, threePhase;

  void validate() {
    if (pointId.isEmpty ||
        (installedWatts != null &&
            (!installedWatts!.isFinite || installedWatts! < 0)) ||
        (demandFactor != null &&
            (!demandFactor!.isFinite || demandFactor! < 0 ||
                demandFactor! > 1)) ||
        (lockedLineId != null && lockedLineId!.trim().isEmpty)) {
      throw const FormatException('Некорректные данные потребителя.');
    }
  }

  double? get calculatedWatts =>
      installedWatts == null || demandFactor == null
          ? null : installedWatts! * demandFactor!;

  Map<String, dynamic> toJson() => {
    'pointId': pointId, 'catalogId': catalogId, 'roomId': roomId,
    'kind': kind.name, 'installedWatts': installedWatts,
    'demandFactor': demandFactor, 'isDedicated': isDedicated,
    'isWetZone': isWetZone, 'isNonSwitchable': isNonSwitchable,
    'threePhase': threePhase, 'lockedLineId': lockedLineId,
  };

  factory ElectricalConsumerDraft.fromJson(Map<String, dynamic> j) =>
      ElectricalConsumerDraft(
        pointId: j['pointId'] as String,
        catalogId: j['catalogId'] as String?,
        roomId: j['roomId'] as String?,
        kind: enumOr(ElectricalConsumerKind.values, j['kind'],
            ElectricalConsumerKind.unknown),
        installedWatts: (j['installedWatts'] as num?)?.toDouble(),
        demandFactor: (j['demandFactor'] as num?)?.toDouble(),
        isDedicated: j['isDedicated'] == true,
        isWetZone: j['isWetZone'] == true,
        isNonSwitchable: j['isNonSwitchable'] == true,
        threePhase: j['threePhase'] == true,
        lockedLineId: j['lockedLineId'] as String?,
      );
}

/// Manual parameters survive an auto-recalculation. A locked field can be
/// INVALID; the engine never silently replaces it with a 'safe' value.
class ElectricalLineManualDraft {
  const ElectricalLineManualDraft({
    required this.lineId,
    this.phase = ElectricalPhase.unassigned,
    this.protection = ElectricalProtection.unknown,
    this.rcdId,
    this.breakerAmps,
    this.cableSectionMm2,
    this.adjustedAmpacityAmps,
    this.rcdLeakageMa,
    this.moduleRow,
    this.moduleIndex,
    this.rcdRatedAmps,
    this.pointIdsSnapshot,
    this.lockedFields = const {},
  });

  final String lineId;
  final ElectricalPhase phase;
  final ElectricalProtection protection;
  final String? rcdId;
  final double? breakerAmps, cableSectionMm2, adjustedAmpacityAmps;
  final double? rcdLeakageMa, rcdRatedAmps;
  final int? moduleRow, moduleIndex;
  /// Optional snapshot prevents a lock applying to changed automatic groups.
  final List<String>? pointIdsSnapshot;
  final Set<String> lockedFields;

  bool locked(String field) => lockedFields.contains(field);

  void validate() {
    const allowed = {
      'phase', 'protection', 'rcd', 'breaker', 'cable', 'position',
    };
    if (lineId.isEmpty || !allowed.containsAll(lockedFields) ||
        [breakerAmps, cableSectionMm2, adjustedAmpacityAmps,
         rcdLeakageMa, rcdRatedAmps].whereType<double>().any(
          (v) => !v.isFinite || v <= 0) ||
        (moduleRow != null && moduleRow! < 0) ||
        (moduleIndex != null && moduleIndex! < 0) ||
        (pointIdsSnapshot != null && (pointIdsSnapshot!.isEmpty ||
            pointIdsSnapshot!.any((id) => id.isEmpty) ||
            pointIdsSnapshot!.toSet().length != pointIdsSnapshot!.length))) {
      throw const FormatException('Некорректные ручные параметры линии.');
    }
  }

  Map<String, dynamic> toJson() => {
    'lineId': lineId, 'phase': phase.name,
    'protection': protection.name, 'rcdId': rcdId,
    'breakerAmps': breakerAmps, 'cableSectionMm2': cableSectionMm2,
    'adjustedAmpacityAmps': adjustedAmpacityAmps,
    'rcdLeakageMa': rcdLeakageMa, 'rcdRatedAmps': rcdRatedAmps,
    'moduleRow': moduleRow, 'moduleIndex': moduleIndex,
    'lockedFields': lockedFields.toList()..sort(),
    'pointIdsSnapshot': pointIdsSnapshot,
  };

  factory ElectricalLineManualDraft.fromJson(Map<String, dynamic> j) =>
      ElectricalLineManualDraft(
        lineId: j['lineId'] as String,
        phase: enumOr(ElectricalPhase.values, j['phase'],
            ElectricalPhase.unassigned),
        protection: enumOr(ElectricalProtection.values, j['protection'],
            ElectricalProtection.unknown),
        rcdId: j['rcdId'] as String?,
        breakerAmps: (j['breakerAmps'] as num?)?.toDouble(),
        cableSectionMm2: (j['cableSectionMm2'] as num?)?.toDouble(),
        adjustedAmpacityAmps:
            (j['adjustedAmpacityAmps'] as num?)?.toDouble(),
        rcdLeakageMa: (j['rcdLeakageMa'] as num?)?.toDouble(),
        rcdRatedAmps: (j['rcdRatedAmps'] as num?)?.toDouble(),
        moduleRow: (j['moduleRow'] as num?)?.toInt(),
        moduleIndex: (j['moduleIndex'] as num?)?.toInt(),
        pointIdsSnapshot: (j['pointIdsSnapshot'] as List?)
            ?.map((e) => e.toString()).toList(),
        lockedFields: Set<String>.from(
            (j['lockedFields'] as List?)?.map((e) => e.toString()) ??
                const <String>[]),
      );
}

/// User-entered device identity and passport footprint only. No protection
/// device type, rating or wiring is selected from load arithmetic.
enum ElectricalDinDeviceKind {
  incoming, breaker, rcd, rcbo, surgeProtector, contactor, other,
}

class ElectricalDinDeviceDraft {
  const ElectricalDinDeviceDraft({
    required this.id,
    this.kind = ElectricalDinDeviceKind.other,
    this.label = '',
    this.model = '',
    this.circuitId,
    this.widthHalfModules,
    this.row,
    this.startHalfModule,
    this.positionLocked = false,
  });

  final String id, label, model;
  final String? circuitId;
  final ElectricalDinDeviceKind kind;
  /// Explicit manufacturer footprint in half-module steps. Null is unknown.
  final int? widthHalfModules;
  /// Zero-based rail number and half-module index, never inferred.
  final int? row, startHalfModule;
  final bool positionLocked;

  void validate() {
    if (id.trim().isEmpty ||
        (widthHalfModules != null && widthHalfModules! <= 0) ||
        (row != null && row! < 0) ||
        (startHalfModule != null && startHalfModule! < 0) ||
        (circuitId != null && circuitId!.trim().isEmpty)) {
      throw const FormatException('Некорректные размеры или ID аппарата щита.');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'model': model,
    'circuitId': circuitId,
    'widthHalfModules': widthHalfModules,
    'row': row,
    'startHalfModule': startHalfModule,
    'positionLocked': positionLocked,
  };

  factory ElectricalDinDeviceDraft.fromJson(Map<String, dynamic> j) =>
      ElectricalDinDeviceDraft(
        id: j['id'] as String,
        kind: enumOr(ElectricalDinDeviceKind.values, j['kind'],
            ElectricalDinDeviceKind.other),
        label: j['label'] as String? ?? '',
        model: j['model'] as String? ?? '',
        circuitId: j['circuitId'] as String?,
        widthHalfModules: (j['widthHalfModules'] as num?)?.toInt(),
        row: (j['row'] as num?)?.toInt(),
        startHalfModule: (j['startHalfModule'] as num?)?.toInt(),
        positionLocked: j['positionLocked'] == true,
      );
}

/// Physical rail inventory is a *user-authored* draft separate from load
/// proposals. Never silently repack locked hardware or invent its width.
class ElectricalDinBoardDraft {
  ElectricalDinBoardDraft({
    required this.panelPointId,
    this.rows = 0,
    this.modulesPerRow = 0,
    List<ElectricalDinDeviceDraft>? devices,
  }) : devices = devices ?? [];

  final String panelPointId;
  int rows, modulesPerRow;
  final List<ElectricalDinDeviceDraft> devices;

  void validate() {
    if (panelPointId.trim().isEmpty ||
        rows < 0 || modulesPerRow < 0 ||
        rows > 100 || modulesPerRow > 500) {
      throw const FormatException('Некорректные параметры DIN-щита.');
    }
    for (final device in devices) {
      device.validate();
    }
  }

  Map<String, dynamic> toJson() => {
    'panelPointId': panelPointId,
    'rows': rows,
    'modulesPerRow': modulesPerRow,
    'devices': devices.map((d) => d.toJson()).toList(),
  };

  factory ElectricalDinBoardDraft.fromJson(Map<String, dynamic> j) {
    final draft = ElectricalDinBoardDraft(
      panelPointId: j['panelPointId'] as String,
      rows: (j['rows'] as num?)?.toInt() ?? 0,
      modulesPerRow: (j['modulesPerRow'] as num?)?.toInt() ?? 0,
      devices: ((j['devices'] as List?) ?? const [])
          .map((d) => ElectricalDinDeviceDraft.fromJson(
              Map<String, dynamic>.from(d as Map)))
          .toList(),
    );
    draft.validate();
    return draft;
  }
}

/// Persisted on FloorPlan: imported P11 projects stay compatible.
class ElectricalDesignDraft {
  ElectricalDesignDraft({
    this.settings = const ElectricalSupplyDraft(),
    Map<String, ElectricalConsumerDraft>? consumers,
    Map<String, ElectricalLineManualDraft>? lineOverrides,
    Map<String, ElectricalDinBoardDraft>? dinBoards,
  }) : consumers = consumers ?? {},
       lineOverrides = lineOverrides ?? {},
       dinBoards = dinBoards ?? {};

  ElectricalSupplyDraft settings;
  final Map<String, ElectricalConsumerDraft> consumers;
  final Map<String, ElectricalLineManualDraft> lineOverrides;
  final Map<String, ElectricalDinBoardDraft> dinBoards;

  void validate() {
    settings.validate();
    for (final entry in consumers.entries) {
      entry.value.validate();
      if (entry.key != entry.value.pointId) {
        throw const FormatException('Не совпадает идентификатор потребителя.');
      }
    }
    for (final entry in lineOverrides.entries) {
      entry.value.validate();
      if (entry.key != entry.value.lineId) {
        throw const FormatException('Не совпадает идентификатор линии.');
      }
    }
    for (final entry in dinBoards.entries) {
      entry.value.validate();
      if (entry.key != entry.value.panelPointId) {
        throw const FormatException('Не совпадает идентификатор щита.');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'settings': settings.toJson(),
    'consumers': consumers.map((k, v) => MapEntry(k, v.toJson())),
    'lineOverrides': lineOverrides.map((k, v) => MapEntry(k, v.toJson())),
    if (dinBoards.isNotEmpty)
      'dinBoards': dinBoards.map((k, v) => MapEntry(k, v.toJson())), 
  };

  factory ElectricalDesignDraft.fromJson(Map<String, dynamic> j) {
    final state = ElectricalDesignDraft(
      settings: ElectricalSupplyDraft.fromJson(
        Map<String, dynamic>.from((j['settings'] as Map?) ?? const {})),
      consumers: ((j['consumers'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), ElectricalConsumerDraft.fromJson(
          Map<String, dynamic>.from(v as Map)))),
      lineOverrides: ((j['lineOverrides'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), ElectricalLineManualDraft.fromJson(
          Map<String, dynamic>.from(v as Map)))),
      dinBoards: ((j['dinBoards'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), ElectricalDinBoardDraft.fromJson(
          Map<String, dynamic>.from(v as Map)))), 
    );
    state.validate();
    return state;
  }
}
