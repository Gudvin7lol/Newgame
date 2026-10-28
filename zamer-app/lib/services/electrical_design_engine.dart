import 'dart:math' as math;

import '../models/models.dart';
import '../models/electrical_design_draft.dart';

/// Every result is a proposal, NEVER a construction approval or wiring map.
class ElectricalDesignIssue {
  const ElectricalDesignIssue(this.code, this.severity, this.message,
      {this.subjectId});
  final String code, message;
  final String? subjectId;
  final ElectricalIssueSeverity severity;
}

class ElectricalLineProposal {
  ElectricalLineProposal({
    required this.id,
    required this.kind,
    required this.pointIds,
    required this.roomId,
    required this.installedWatts,
    required this.demandWatts,
    required this.wet,
    required this.critical,
    required this.threePhase,
    this.phase = ElectricalPhase.unassigned,
  });

  final String id, roomId;
  final ElectricalConsumerKind kind;
  final List<String> pointIds;
  final double? installedWatts, demandWatts;
  final bool wet, critical, threePhase;
  ElectricalPhase phase;
}

class ElectricalDesignResult {
  const ElectricalDesignResult({
    required this.lines,
    required this.issues,
    required this.phaseWatts,
    required this.installedWatts,
    required this.demandWatts,
    required this.imbalancePercent,
  });

  final List<ElectricalLineProposal> lines;
  final List<ElectricalDesignIssue> issues;
  final Map<ElectricalPhase, double> phaseWatts;
  /// Null if any required input is absent; never silently count as zero.
  final double? installedWatts, demandWatts, imbalancePercent;

  /// Intentionally false: cable/protection/earthing/source documentation
  /// is not proven by this load inventory.
  bool get approvedForInstallation => false;
  bool get hasErrors =>
      issues.any((issue) => issue.severity == ElectricalIssueSeverity.error);
}

class ElectricalDesignEngine {
  const ElectricalDesignEngine._();

  static ElectricalConsumerDraft _consumer(
      ElectricalPoint point, ElectricalDesignDraft design) {
    final stored = design.consumers[point.id];
    if (stored != null) return stored;
    // Existing P11 projects have no consumer selection; use ONLY actual
    // recorded wattages, never invent 0.3 kW for each empty socket.
    final kind = switch (point.type) {
      ElectricalPointType.ceilingLight ||
      ElectricalPointType.wallLight => ElectricalConsumerKind.lighting,
      ElectricalPointType.socket ||
      ElectricalPointType.tvSocket ||
      ElectricalPointType.dataSocket ||
      ElectricalPointType.frame => ElectricalConsumerKind.sockets,
      ElectricalPointType.appliance => ElectricalConsumerKind.unknown,
      _ => ElectricalConsumerKind.unknown,
    };
    return ElectricalConsumerDraft(
      pointId: point.id,
      kind: kind,
      installedWatts: point.powerW > 0 && point.powerW.isFinite
          ? point.powerW : null,
    );
  }

  static ElectricalDesignResult calculate(
      FloorPlan floor, ElectricalDesignDraft design) {
    design.validate();
    final settings = design.settings;
    final issues = <ElectricalDesignIssue>[];
    final consumers = <String, ElectricalConsumerDraft>{};
    final pointIds = <String>{};
    for (final point in floor.electricalPoints) {
      if (!pointIds.add(point.id)) {
        issues.add(ElectricalDesignIssue('ERR_DUPLICATE_POINT',
            ElectricalIssueSeverity.error,
            'Идентификатор электроточки повторяется.', subjectId: point.id));
        continue;
      }
      final consumer = _consumer(point, design);
      // Panel, switch, junction and unpowered signal points are not loads.
      if (consumer.kind == ElectricalConsumerKind.unknown) {
        if ({ElectricalPointType.panel, ElectricalPointType.junctionBox,
            ElectricalPointType.switchPoint}.contains(point.type)) continue;
        issues.add(ElectricalDesignIssue('MISSING_CONSUMER_CLASS',
            ElectricalIssueSeverity.missingInformation,
            'Назначь тип потребителя: без него группировка невозможна.',
            subjectId: point.id));
        continue;
      }
      if (consumer.installedWatts == null || consumer.demandFactor == null) {
        issues.add(ElectricalDesignIssue('MISSING_LOAD_ASSUMPTIONS',
            ElectricalIssueSeverity.missingInformation,
            'Укажи установленную мощность и коэффициент спроса.',
            subjectId: point.id));
      }
      if (consumer.roomId == null && !consumer.isDedicated &&
          !consumer.isNonSwitchable) {
        issues.add(ElectricalDesignIssue('MISSING_ROOM_ASSIGNMENT',
            ElectricalIssueSeverity.missingInformation,
            'Не назначено помещение: точка не будет объединяться с другими.',
            subjectId: point.id));
      }
      consumers[point.id] = consumer;
    }
    for (final orphan in design.consumers.keys.where(
        (id) => !pointIds.contains(id))) {
      issues.add(ElectricalDesignIssue('ORPHAN_CONSUMER',
          ElectricalIssueSeverity.warning,
          'Потребитель ссылается на удалённую электроточку.',
          subjectId: orphan));
    }

    final assignments = <String, List<ElectricalConsumerDraft>>{};
    final types = <String, ElectricalConsumerKind>{};
    final roomKeys = <String, String>{};
    final counters = <String, int>{};
    final autoBuckets = <String, List<String>>{};
    final sorted = consumers.values.toList()
      ..sort((a, b) => a.pointId.compareTo(b.pointId));

    void append(String key, ElectricalConsumerDraft c) {
      assignments.putIfAbsent(key, () => []).add(c);
      roomKeys.putIfAbsent(key, () => c.roomId ?? '');
      types.putIfAbsent(key, () => c.kind);
    }

    for (final c in sorted) {
      if (c.lockedLineId != null) {
        append(c.lockedLineId!, c);
        continue;
      }
      final dedicated = c.isDedicated ||
          c.isNonSwitchable ||
          c.kind == ElectricalConsumerKind.dedicated ||
          c.kind == ElectricalConsumerKind.critical ||
          c.threePhase;
      if (dedicated || c.roomId == null) {
        append('point:${c.pointId}', c);
        continue;
      }
      final family = c.catalogId == 'socket_kitchen'
          ? 'kitchenSockets' : c.kind.name;
      final base = '$family:${c.roomId}';
      final previousIds = autoBuckets.putIfAbsent(base, () => []);
      final maxPoints = family == 'kitchenSockets' ? 6
          : c.kind == ElectricalConsumerKind.lighting ? 20 : 10;
      final maxWatts = c.kind == ElectricalConsumerKind.lighting
          ? 1800.0 : 3500.0;
      var index = counters[base] ?? 1;
      var id = 'auto:$base:$index';
      final current = assignments[id] ?? const <ElectricalConsumerDraft>[];
      final known = current.fold<double>(0.0,
          (sum, p) => sum + (p.calculatedWatts ?? 0));
      if (current.length >= maxPoints ||
          (c.calculatedWatts != null &&
              current.isNotEmpty && known + c.calculatedWatts! > maxWatts)) {
        index++;
        counters[base] = index;
        id = 'auto:$base:$index';
      }
      previousIds.add(id);
      append(id, c);
    }

    final lines = <ElectricalLineProposal>[];
    final orderedKeys = assignments.keys.toList()..sort();
    for (final id in orderedKeys) {
      final list = assignments[id]!;
      final kinds = list.map((p) => p.kind).toSet();
      if (kinds.length > 1) {
        issues.add(ElectricalDesignIssue('ERR_MIXED_LINE',
            ElectricalIssueSeverity.error,
            'В одной линии смешаны несовместимые классы потребителей.',
            subjectId: id));
      }
      if (list.length > 1 && list.any((p) =>
          p.isDedicated || p.isNonSwitchable ||
          p.kind == ElectricalConsumerKind.dedicated ||
          p.kind == ElectricalConsumerKind.critical)) {
        issues.add(ElectricalDesignIssue('ERR_DEDICATED_MERGED',
            ElectricalIssueSeverity.error,
            'Выделенный или неотключаемый потребитель не должен '
            'объединяться с другой нагрузкой.',
            subjectId: id));
      }
      if (list.any((p) => p.threePhase) &&
          (list.length != 1 || settings.phasesCount != 3)) {
        issues.add(ElectricalDesignIssue('ERR_THREE_PHASE_LINE',
            ElectricalIssueSeverity.error,
            'Трёхфазная нагрузка требует трёхфазного ввода и отдельной линии.',
            subjectId: id));
      }
      final installed = list.every((p) => p.installedWatts != null)
          ? list.fold<double>(0, (sum, p) => sum + p.installedWatts!)
          : null;
      final demand = list.every((p) => p.calculatedWatts != null)
          ? list.fold<double>(0, (sum, p) => sum + p.calculatedWatts!)
          : null;
      final kind = types[id]!;
      final room = roomKeys[id]!;
      final isWet = list.any((p) => p.isWetZone);
      final isCritical = list.any((p) => p.isNonSwitchable);
      if (demand != null) {
        final cap = kind == ElectricalConsumerKind.lighting
            ? 1800.0 : kind == ElectricalConsumerKind.sockets ? 3500.0 : null;
        if (cap != null && demand > cap) {
          issues.add(ElectricalDesignIssue('ERR_LINE_LOAD_EXCEEDED',
              ElectricalIssueSeverity.error,
              'Расчётная мощность превышает целевой предел линии. '
              'Раздели потребителей; не увеличивай автомат обычных розеток.',
              subjectId: id));
        }
      }
      lines.add(ElectricalLineProposal(
        id: id, kind: kind, pointIds: list.map((e) => e.pointId).toList(),
        roomId: room, installedWatts: installed, demandWatts: demand,
        wet: isWet, critical: isCritical,
        threePhase: list.any((e) => e.threePhase),
      ));
    }

    final existingLines = {for (final line in lines) line.id: line};
    for (final entry in design.lineOverrides.entries) {
      final line = existingLines[entry.key];
      if (line == null) {
        issues.add(ElectricalDesignIssue('ORPHAN_LINE_OVERRIDE',
            ElectricalIssueSeverity.warning,
            'Ручные настройки относятся к отсутствующей линии.',
            subjectId: entry.key));
      } else if (_staleLineOverride(entry.value, line)) {
        issues.add(ElectricalDesignIssue('ERR_STALE_LINE_OVERRIDE',
            ElectricalIssueSeverity.error,
            'Состав линии изменился. Ручные блокировки сохранены, '
            'но не применяются до подтверждения.',
            subjectId: entry.key));
      }
    }

    final phaseWatts = <ElectricalPhase, double>{
      ElectricalPhase.l1: 0, ElectricalPhase.l2: 0, ElectricalPhase.l3: 0,
    };
    // Reserve explicit phase locks before assigning any free line.
    for (final line in lines.where((line) => line.threePhase)) {
      final candidate = design.lineOverrides[line.id];
      final manual = candidate != null &&
          !_staleLineOverride(candidate, line) ? candidate : null;
      if (manual != null && manual.locked('phase') &&
          manual.phase != ElectricalPhase.threePhase) {
        issues.add(ElectricalDesignIssue('ERR_PHASE_LOCK',
            ElectricalIssueSeverity.error,
            'Трёхфазную линию нельзя закрепить за одной фазой.',
            subjectId: line.id));
      }
      line.phase = ElectricalPhase.threePhase;
      if (line.demandWatts != null) {
        for (final phase in phaseWatts.keys) {
          phaseWatts[phase] = phaseWatts[phase]! + line.demandWatts! / 3;
        }
      }
    }
    final onePhase = lines.where((l) => !l.threePhase).toList();
    for (final line in onePhase) {
      final candidate = design.lineOverrides[line.id];
      final manual = candidate != null &&
          !_staleLineOverride(candidate, line) ? candidate : null;
      if (manual != null && manual.locked('phase')) {
        if (manual.phase == ElectricalPhase.unassigned ||
            manual.phase == ElectricalPhase.threePhase ||
            (settings.phasesCount == 1 &&
                manual.phase != ElectricalPhase.l1)) {
          issues.add(ElectricalDesignIssue('ERR_PHASE_LOCK',
              ElectricalIssueSeverity.error,
              'Ручная фаза несовместима с конфигурацией ввода.',
              subjectId: line.id));
        } else {
          line.phase = manual.phase;
          phaseWatts[line.phase] =
              phaseWatts[line.phase]! + (line.demandWatts ?? 0);
        }
      }
    }
    final remaining = onePhase.where(
        (line) => line.phase == ElectricalPhase.unassigned).toList()
      ..sort((a, b) => (b.demandWatts ?? -1).compareTo(a.demandWatts ?? -1));
    final socketRoomPhases = <String, Set<ElectricalPhase>>{};
    for (final line in onePhase.where(
        (l) => l.phase != ElectricalPhase.unassigned &&
            l.kind == ElectricalConsumerKind.sockets)) {
      socketRoomPhases.putIfAbsent(line.roomId, () => {}).add(line.phase);
    }
    final powerFirst = remaining.where(
        (line) => line.kind != ElectricalConsumerKind.lighting).toList();
    final lighting = remaining.where(
        (line) => line.kind == ElectricalConsumerKind.lighting).toList();
    for (final line in [...powerFirst, ...lighting]) {
      final phases = settings.phasesCount == 1
          ? const [ElectricalPhase.l1]
          : [ElectricalPhase.l1, ElectricalPhase.l2, ElectricalPhase.l3];
      final avoid = line.kind == ElectricalConsumerKind.lighting
          ? socketRoomPhases[line.roomId] ?? const <ElectricalPhase>{}
          : const <ElectricalPhase>{};
      final eligible = phases.where((p) => !avoid.contains(p)).toList();
      final candidates = eligible.isNotEmpty ? eligible : phases;
      candidates.sort((a, b) =>
          phaseWatts[a]!.compareTo(phaseWatts[b]!));
      line.phase = candidates.first;
      phaseWatts[line.phase] =
          phaseWatts[line.phase]! + (line.demandWatts ?? 0);
      if (line.kind == ElectricalConsumerKind.sockets) {
        socketRoomPhases.putIfAbsent(line.roomId, () => {}).add(line.phase);
      }
    }

    final hasUnclassified = issues.any((issue) =>
        issue.code == 'MISSING_CONSUMER_CLASS' ||
        issue.code == 'ERR_DUPLICATE_POINT');
    final allKnown = !hasUnclassified &&
        lines.every((l) => l.demandWatts != null);
    final installedKnown = !hasUnclassified &&
        lines.every((l) => l.installedWatts != null);
    final demandTotal = allKnown
        ? lines.fold<double>(0, (sum, line) => sum + line.demandWatts!)
        : null;
    final installedTotal = installedKnown
        ? lines.fold<double>(0, (sum, line) => sum + line.installedWatts!)
        : null;
    double? imbalance;
    if (settings.phasesCount == 3 && allKnown) {
      final values = phaseWatts.values.toList();
      final biggest = values.reduce(math.max);
      final smallest = values.reduce(math.min);
      imbalance = biggest <= 0 ? 0 : (biggest - smallest) / biggest * 100;
      if (imbalance > settings.phaseImbalanceGoalPercent) {
        issues.add(ElectricalDesignIssue('WARN_PHASE_IMBALANCE',
            ElectricalIssueSeverity.warning,
            'Перекос превышает заданную цель ${settings.phaseImbalanceGoalPercent}%.'));
      }
    }

    for (final line in lines) {
      final candidate = design.lineOverrides[line.id];
      final manual = candidate != null &&
          !_staleLineOverride(candidate, line) ? candidate : null;
      final watts = line.demandWatts;
      final amps = watts == null ? null
          : line.threePhase
              ? watts / (math.sqrt(3) * settings.lineVoltageV *
                  settings.powerFactor)
              : watts / (settings.phaseVoltageV * settings.powerFactor);
      if (manual != null) {
        const requiredValues = <String, bool Function(ElectricalLineManualDraft)>{
          'phase': _hasPhase,
          'cable': _hasCable,
          'breaker': _hasBreaker,
          'rcd': _hasRcd,
          'position': _hasPosition,
          'protection': _hasProtection,
        };
        for (final field in manual.lockedFields) {
          if (!requiredValues[field]!(manual)) {
            issues.add(ElectricalDesignIssue('ERR_INVALID_MANUAL_LOCK',
                ElectricalIssueSeverity.error,
                'Ручная блокировка «$field» не содержит значения.',
                subjectId: line.id));
          }
        }
        if (manual.breakerAmps != null &&
            manual.adjustedAmpacityAmps != null &&
            manual.breakerAmps! > manual.adjustedAmpacityAmps!) {
          issues.add(ElectricalDesignIssue('ERR_CABLE_OVERLOAD',
              ElectricalIssueSeverity.error,
              'Номинал аппарата превышает подтверждённую допустимую '
              'нагрузку кабеля с поправками.',
              subjectId: line.id));
        } else if (manual.breakerAmps != null &&
            manual.adjustedAmpacityAmps == null) {
          issues.add(ElectricalDesignIssue('MISSING_CABLE_AMPACITY',
              ElectricalIssueSeverity.missingInformation,
              'Не определён допустимый ток кабеля для способа прокладки.',
              subjectId: line.id));
        }
        if (line.kind == ElectricalConsumerKind.sockets &&
            manual.breakerAmps != null && manual.breakerAmps! > 16) {
          issues.add(ElectricalDesignIssue('ERR_SOCKET_RATING',
              ElectricalIssueSeverity.error,
              'Для бытовых розеток с номиналом 16 А нельзя '
              'автоматически повышать защиту. Проверь аппаратуру.',
              subjectId: line.id));
        }
        if (amps != null && manual.breakerAmps != null &&
            amps > manual.breakerAmps!) {
          issues.add(ElectricalDesignIssue('ERR_LOAD_EXCEEDS_BREAKER',
              ElectricalIssueSeverity.error,
              'Расчётный ток линии превышает введённый номинал аппарата.',
              subjectId: line.id));
        }
      }
      if (line.wet &&
          (manual == null ||
           manual.protection == ElectricalProtection.unknown ||
           manual.rcdLeakageMa == null ||
           manual.rcdLeakageMa! > 30)) {
        issues.add(ElectricalDesignIssue('ERR_WET_NO_RCD',
            ElectricalIssueSeverity.error,
            'Для мокрой зоны не подтверждена соответствующая дифзащита.',
            subjectId: line.id));
      }
      if (manual != null && manual.protection == ElectricalProtection.groupRcd &&
          manual.rcdId == null) {
        issues.add(ElectricalDesignIssue('MISSING_RCD_GROUP',
            ElectricalIssueSeverity.missingInformation,
            'Не назначена группа УЗО и её нулевая шина.',
            subjectId: line.id));
      }
      if (settings.inputBreakerAmps != null && amps != null &&
          settings.phasesCount == 1 && amps > settings.inputBreakerAmps!) {
        issues.add(ElectricalDesignIssue('WARN_INPUT_LIMIT',
            ElectricalIssueSeverity.warning,
            'Расчётный ток одной линии больше введённого тока ввода.',
            subjectId: line.id));
      }
    }
    if (settings.inputBreakerAmps != null && allKnown) {
      for (final phase in settings.phasesCount == 1
          ? const [ElectricalPhase.l1]
          : [ElectricalPhase.l1, ElectricalPhase.l2, ElectricalPhase.l3]) {
        final amps = phaseWatts[phase]! /
            (settings.phaseVoltageV * settings.powerFactor);
        if (amps > settings.inputBreakerAmps!) {
          issues.add(ElectricalDesignIssue('WARN_INPUT_PHASE_OVERLOAD',
              ElectricalIssueSeverity.warning,
              'Расчётный ток ${phase.name.toUpperCase()} превышает '
              'указанный предел ввода.'));
        }
      }
    }
    if (!allKnown) {
      issues.add(const ElectricalDesignIssue('INCOMPLETE_LOADS',
          ElectricalIssueSeverity.missingInformation,
          'Нагрузка и баланс фаз неполные: есть неизвестные значения.'));
    }
    issues.add(const ElectricalDesignIssue('UNVERIFIED_INSTALLATION',
        ElectricalIssueSeverity.missingInformation,
        'Нет проверки способа прокладки, токов КЗ, защитного отключения, '
        'заземления и схем производителя. Монтажный журнал заблокирован.'));
    return ElectricalDesignResult(
      lines: lines,
      issues: issues,
      phaseWatts: phaseWatts,
      installedWatts: installedTotal,
      demandWatts: demandTotal,
      imbalancePercent: imbalance,
    );
  }

  static bool _staleLineOverride(
      ElectricalLineManualDraft manual, ElectricalLineProposal line) {
    final expected = manual.pointIdsSnapshot;
    if (expected == null) return false;
    return expected.toSet().length != line.pointIds.length ||
        !expected.toSet().containsAll(line.pointIds);
  }

  static bool _hasPhase(ElectricalLineManualDraft d) =>
      d.phase != ElectricalPhase.unassigned;
  static bool _hasCable(ElectricalLineManualDraft d) =>
      d.cableSectionMm2 != null;
  static bool _hasBreaker(ElectricalLineManualDraft d) =>
      d.breakerAmps != null;
  static bool _hasRcd(ElectricalLineManualDraft d) =>
      d.rcdId != null;
  static bool _hasPosition(ElectricalLineManualDraft d) =>
      d.moduleRow != null && d.moduleIndex != null;
  static bool _hasProtection(ElectricalLineManualDraft d) =>
      d.protection != ElectricalProtection.unknown;
}
