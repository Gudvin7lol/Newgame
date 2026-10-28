import 'package:flutter/material.dart';

import '../models/electrical_design_draft.dart';
import '../models/models.dart';

/// These templates are user-editable planning estimates, never measured
/// power or a verified breaker-and-cable schedule.
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

  static ElectricalDevicePreset? find(String? id) {
    for (final item in presets) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class ElectricalConsumerDraftEditor extends StatefulWidget {
  const ElectricalConsumerDraftEditor({
    super.key, required this.point, this.initial,
  });
  final ElectricalPoint point;
  final ElectricalConsumerDraft? initial;

  @override
  State<ElectricalConsumerDraftEditor> createState() =>
      _ElectricalConsumerDraftEditorState();
}

class _ElectricalConsumerDraftEditorState
    extends State<ElectricalConsumerDraftEditor> {
  late final TextEditingController watts, demand, room, line;
  late ElectricalConsumerKind kind;
  String? presetId, error;
  bool dedicated = false, wet = false, critical = false, threePhase = false;

  @override
  void initState() {
    super.initState();
    final saved = widget.initial;
    presetId = ElectricalDeviceCatalog.find(saved?.catalogId)?.id;
    kind = saved?.kind ?? ElectricalConsumerKind.unknown;
    dedicated = saved?.isDedicated ?? false;
    wet = saved?.isWetZone ?? false;
    critical = saved?.isNonSwitchable ?? false;
    threePhase = saved?.threePhase ?? false;
    watts = TextEditingController(
      text: saved?.installedWatts?.toString() ?? '');
    demand = TextEditingController(
      text: saved?.demandFactor?.toString() ?? '');
    room = TextEditingController(text: saved?.roomId ?? '');
    line = TextEditingController(text: saved?.lockedLineId ?? '');
  }

  @override
  void dispose() {
    for (final c in [watts, demand, room, line]) {
      c.dispose();
    }
    super.dispose();
  }

  void choosePreset(String? id) {
    final preset = ElectricalDeviceCatalog.find(id);
    if (preset == null) return;
    setState(() {
      presetId = id;
      kind = preset.kind;
      watts.text = preset.watts.toString();
      demand.text = preset.factor.toString();
      dedicated = preset.dedicated;
      wet = preset.wet;
      critical = preset.critical;
      threePhase = preset.threePhase;
      error = null;
    });
  }

  void save() {
    try {
      final value = ElectricalConsumerDraft(
        pointId: widget.point.id,
        catalogId: presetId,
        kind: kind,
        roomId: room.text.trim().isEmpty ? null : room.text.trim(),
        installedWatts: double.tryParse(watts.text.replaceAll(',', '.')),
        demandFactor: double.tryParse(demand.text.replaceAll(',', '.')),
        isDedicated: dedicated,
        isWetZone: wet,
        isNonSwitchable: critical,
        threePhase: threePhase,
        lockedLineId: line.text.trim().isEmpty ? null : line.text.trim(),
      );
      value.validate();
      if (value.installedWatts == null || value.demandFactor == null ||
          kind == ElectricalConsumerKind.unknown) {
        throw const FormatException('Укажи тип, мощность и коэффициент.');
      }
      Navigator.of(context).pop(value);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .88,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16,
              MediaQuery.viewInsetsOf(context).bottom + 20),
          children: [
            Text('Потребитель и расчётные допущения',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text('Справочник предлагает только оценки. '
                'Перед рабочим проектом сверяй паспорт прибора, '
                'потребление и коэффициент спроса.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('electrical-device-preset'),
              initialValue: presetId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Тип прибора'),
              items: [for (final p in ElectricalDeviceCatalog.presets)
                DropdownMenuItem(value: p.id,
                    child: Text(p.title, overflow: TextOverflow.ellipsis))],
              onChanged: choosePreset,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('electrical-consumer-room'),
              controller: room,
              decoration: const InputDecoration(
                  labelText: 'Помещение (ключ/название)'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('electrical-consumer-watts'),
              controller: watts,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Установленная мощность', suffixText: 'Вт'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('electrical-consumer-demand'),
              controller: demand,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'K спроса', helperText: 'От 0 до 1'),
            ),
            SwitchListTile(
              title: const Text('Отдельная линия'),
              value: dedicated,
              onChanged: (v) => setState(() => dedicated = v)),
            SwitchListTile(
              title: const Text('Мокрая зона'),
              value: wet,
              onChanged: (v) => setState(() => wet = v)),
            SwitchListTile(
              title: const Text('Неотключаемая линия'),
              value: critical,
              onChanged: (v) => setState(() => critical = v)),
            SwitchListTile(
              title: const Text('Трёхфазный потребитель'),
              value: threePhase,
              onChanged: (v) => setState(() => threePhase = v)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('electrical-consumer-line-lock'),
              controller: line,
              decoration: const InputDecoration(
                labelText: 'Ручная линия (не трогать при пересчёте)',
                helperText: 'Оставь пустым для автоматической группировки'),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('electrical-consumer-save'),
              onPressed: save,
              child: const Text('Сохранить допущения')),
          ],
        ),
      ),
    );
  }
}
