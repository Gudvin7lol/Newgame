import '../models/models.dart';
import '../models/electrical_design_draft.dart';

class ElectricalDevicePreset {
  const ElectricalDevicePreset(this.id, this.title, this.kind,
      this.watts, this.factor, {
    this.dedicated = false,
    this.wet = false,
    this.critical = false,
    this.threePhase = false,
  });
  final String id, title;
  final ElectricalConsumerKind kind;
  final double watts, factor;
  final bool dedicated, wet, critical, threePhase;
}

abstract final class ElectricalDeviceCatalog {
  static const presets = <ElectricalDevicePreset>[
    ElectricalDevicePreset('socket_std', 'Розетка бытовая (оценка)',
        ElectricalConsumerKind.sockets, 300, 1),
    ElectricalDevicePreset('socket_kitchen', 'Розетка фартука (оценка)',
        ElectricalConsumerKind.sockets, 1500, .6, wet: true),
    ElectricalDevicePreset('socket_wet', 'Розетка санузла (оценка)',
        ElectricalConsumerKind.sockets, 1500, .5, wet: true),
    ElectricalDevicePreset('light_point', 'Светильник (оценка)',
        ElectricalConsumerKind.lighting, 50, 1),
    ElectricalDevicePreset('hob_1p', 'Варочная панель 1Ф (оценка)',
        ElectricalConsumerKind.dedicated, 7000, .8, dedicated: true),
    ElectricalDevicePreset('hob_3p', 'Варочная панель 3Ф (оценка)',
        ElectricalConsumerKind.dedicated, 7000, .8,
        dedicated: true, threePhase: true),
    ElectricalDevicePreset('oven', 'Духовой шкаф (оценка)',
        ElectricalConsumerKind.dedicated, 3500, .8, dedicated: true),
    ElectricalDevicePreset('dishwasher', 'Посудомойка (оценка)',
        ElectricalConsumerKind.dedicated, 2000, .8,
        dedicated: true, wet: true),
    ElectricalDevicePreset('washer', 'Стиральная машина (оценка)',
        ElectricalConsumerKind.dedicated, 2200, .8,
        dedicated: true, wet: true),
    ElectricalDevicePreset('boiler', 'Бойлер (оценка)',
        ElectricalConsumerKind.dedicated, 2500, .9,
        dedicated: true, wet: true),
    ElectricalDevicePreset('ac_unit', 'Кондиционер (оценка)',
        ElectricalConsumerKind.dedicated, 1500, .8, dedicated: true),
    ElectricalDevicePreset('floor_heat', 'Тёплый пол (оценка)',
        ElectricalConsumerKind.dedicated, 800, .9,
        dedicated: true, wet: true),
    ElectricalDevicePreset('fridge', 'Холодильник (оценка)',
        ElectricalConsumerKind.critical, 300, 1,
        dedicated: true, critical: true),
    ElectricalDevicePreset('router_hub', 'Роутер (оценка)',
        ElectricalConsumerKind.critical, 100, 1,
        dedicated: true, critical: true),
  ];

  /// Defaults for *new* electric points only. Estimates are not passport
  /// ratings or a verified design. Legacy imports are never backfilled.
  /// TV/data terminals, switches, boards and junctions consume no 230 V power.
  static ElectricalConsumerDraft? defaultForPoint(ElectricalPoint point) {
    ElectricalDevicePreset? preset;
    var count = 1;
    switch (point.type) {
      case ElectricalPointType.socket:
        preset = find('socket_std');
        break;
      case ElectricalPointType.frame:
        count = point.modules.where(
          (module) => module == ElectricalModuleType.socket220,
        ).length;
        if (count == 0) return null;
        preset = find('socket_std');
        break;
      case ElectricalPointType.ceilingLight:
      case ElectricalPointType.wallLight:
        preset = find('light_point');
        break;
      default:
        return null;
    }
    if (preset == null) return null;
    return ElectricalConsumerDraft(
      pointId: point.id,
      catalogId: preset.id,
      kind: preset.kind,
      installedWatts: preset.watts * count,
      demandFactor: preset.factor,
      isDedicated: preset.dedicated,
      isWetZone: preset.wet,
      isNonSwitchable: preset.critical,
      threePhase: preset.threePhase,
    );
  }

  static ElectricalDevicePreset? find(String? id) {
    for (final item in presets) {
      if (item.id == id) return item;
    }
    return null;
  }
}

