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
    this.lockedFields = const {},
  });

  final String lineId;
  final ElectricalPhase phase;
  final ElectricalProtection protection;
  final String? rcdId;
  final double? breakerAmps, cableSectionMm2, adjustedAmpacityAmps;
  final double? rcdLeakageMa, rcdRatedAmps;
  final int? moduleRow, moduleIndex;
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
        (moduleIndex != null && moduleIndex! < 0)) {
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
        lockedFields: Set<String>.from(
            (j['lockedFields'] as List?)?.map((e) => e.toString()) ??
                const <String>[]),
      );
}

/// Persisted on FloorPlan: imported P11 projects stay compatible.
class ElectricalDesignDraft {
  ElectricalDesignDraft({
    this.settings = const ElectricalSupplyDraft(),
    Map<String, ElectricalConsumerDraft>? consumers,
    Map<String, ElectricalLineManualDraft>? lineOverrides,
  }) : consumers = consumers ?? {},
       lineOverrides = lineOverrides ?? {};

  ElectricalSupplyDraft settings;
  final Map<String, ElectricalConsumerDraft> consumers;
  final Map<String, ElectricalLineManualDraft> lineOverrides;

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
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'settings': settings.toJson(),
    'consumers': consumers.map((k, v) => MapEntry(k, v.toJson())),
    'lineOverrides': lineOverrides.map((k, v) => MapEntry(k, v.toJson())),
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
    );
    state.validate();
    return state;
  }
}
