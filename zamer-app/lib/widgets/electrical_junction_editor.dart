import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_network.dart';
import '../services/electrical_network_service.dart';
import '../services/electrical_junction_edit_service.dart';
import '../services/electrical_route_service.dart';
import 'electrical_route_editor.dart';

/// A detached, explicit editor. No writes to FloorPlan before "Save".
class ElectricalJunctionEditor extends StatefulWidget {
  const ElectricalJunctionEditor({
    super.key,
    required this.floor,
    required this.junctionPointId,
  });

  final FloorPlan floor;
  final String junctionPointId;

  @override
  State<ElectricalJunctionEditor> createState() => _ElectricalJunctionEditorState();
}

class _ElectricalJunctionEditorState extends State<ElectricalJunctionEditor> {
  late ElectricalNetwork draft;
  String? error;
  int nextId = 0;
  String id(String prefix) =>
      prefix + '-' + DateTime.now().microsecondsSinceEpoch.toString() +
      '-' + (nextId++).toString();

  @override
  void initState() {
    super.initState();
    draft = ElectricalJunctionEditService.copy(widget.floor.electricalNetwork);
  }

  String pointLabel(String id) {
    final point = widget.floor.electricalPoints.where((p) => p.id == id).firstOrNull;
    if (point == null) return 'Точка удалена';
    return point.label.trim().isEmpty ? point.type.label : point.label;
  }

  String circuitLabel(String id) =>
      draft.circuits.where((c) => c.id == id).firstOrNull?.name ??
      'Цепь не найдена';

  void change(void Function() operation) {
    try {
      operation();
      setState(() => error = null);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> createCircuit() async {
    var name = '';
    var kind = ElectricalCircuitKind.unknown;
    final result = await showDialog<(String, ElectricalCircuitKind)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Новая цепь'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('junction-circuit-name'),
                onChanged: (value) => name = value,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название группы'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ElectricalCircuitKind>(
                key: const ValueKey('junction-circuit-kind'),
                isExpanded: true,
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Назначение'),
                items: const [
                  DropdownMenuItem(
                    value: ElectricalCircuitKind.unknown,
                    child: Text('Не указано'),
                  ),
                  DropdownMenuItem(
                    value: ElectricalCircuitKind.power,
                    child: Text('Силовая'),
                  ),
                  DropdownMenuItem(
                    value: ElectricalCircuitKind.lighting,
                    child: Text('Освещение'),
                  ),
                  DropdownMenuItem(
                    value: ElectricalCircuitKind.lowVoltage,
                    child: Text('Слаботочная'),
                  ),
                ],
                onChanged: (value) => refresh(() =>
                    kind = value ?? ElectricalCircuitKind.unknown),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('junction-circuit-create'),
              onPressed: () => Navigator.pop(dialog, (name, kind)),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    change(() {
      ElectricalJunctionEditService.createCircuit(
        draft, id: id('ec'), name: result.$1, kind: result.$2,
      );
    });
  }

  Future<void> createCable() async {
    if (draft.circuits.isEmpty) {
      setState(() => error = 'Сначала создайте электрическую цепь.');
      return;
    }
    final candidates = widget.floor.electricalPoints
        .where((p) => p.id != widget.junctionPointId).toList();
    if (candidates.isEmpty) {
      setState(() => error = 'На плане нет второй точки для кабеля.');
      return;
    }
    var otherId = candidates.first.id;
    var circuitId = draft.circuits.first.id;
    var fromBox = false;
    var coreCount = 3;
    String? runId;
    var description = '';
    final result = await showDialog<_CableInput>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) {
          final matchedRuns = widget.floor.electricalRuns.where((r) =>
              (r.startPointId == otherId && r.endPointId == widget.junctionPointId) ||
              (r.endPointId == otherId && r.startPointId == widget.junctionPointId))
              .toList();
          if (runId != null && !matchedRuns.any((r) => r.id == runId)) runId = null;
          return AlertDialog(
            title: const Text('Добавить кабель'),
            scrollable: true,
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Кабель создаётся только после выбора точек, цепи '
                      'и количества жил. Соединения клемм не назначаются автоматически.'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('junction-cable-other'),
                    isExpanded: true,
                    initialValue: otherId,
                    decoration: const InputDecoration(labelText: 'Другая точка'),
                    items: [
                      for (final p in candidates)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(pointLabel(p.id),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      refresh(() { otherId = value; runId = null; });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('junction-cable-circuit'),
                    isExpanded: true,
                    initialValue: circuitId,
                    decoration: const InputDecoration(labelText: 'Цепь'),
                    items: [
                      for (final c in draft.circuits)
                        DropdownMenuItem(
                          value: c.id, child: Text(c.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) refresh(() => circuitId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const ValueKey('junction-cable-direction'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Из коробки'),
                    subtitle: Text(fromBox ? 'РК → точка' : 'Точка → РК'),
                    value: fromBox,
                    onChanged: (value) => refresh(() => fromBox = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('junction-cable-cores'),
                    isExpanded: true,
                    initialValue: coreCount,
                    decoration: const InputDecoration(labelText: 'Число жил'),
                    items: [
                      for (final count in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12])
                        DropdownMenuItem(value: count,
                            child: Text(count.toString() + ' жил')),
                    ],
                    onChanged: (value) {
                      if (value != null) refresh(() => coreCount = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('junction-cable-route-' + otherId),
                    isExpanded: true,
                    initialValue: runId,
                    decoration: const InputDecoration(labelText: 'Линия на плане'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null, child: Text('Не назначена'),
                      ),
                      for (final r in matchedRuns)
                        DropdownMenuItem<String?>(
                          value: r.id, child: Text(r.id,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => refresh(() => runId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('junction-cable-mark'),
                    onChanged: (value) => description = value,
                    decoration: const InputDecoration(
                      labelText: 'Маркировка кабеля',
                      hintText: 'Необязательно',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Отмена'),
              ),
              FilledButton(
                key: const ValueKey('junction-cable-create'),
                onPressed: () => Navigator.pop(dialog, _CableInput(
                  otherId, circuitId, fromBox, coreCount, runId,
                  description,
                )),
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null) return;
    change(() => ElectricalJunctionEditService.createCable(
      widget.floor, draft,
      id: id('cable'),
      junctionId: widget.junctionPointId,
      otherPointId: result.otherId,
      circuitId: result.circuitId,
      fromBox: result.fromBox,
      coreCount: result.coreCount,
      routeRunId: result.runId,
      description: result.description,
    ));
  }

  Future<void> createTerminal() async {
    final connected = draft.cables.where((c) =>
        c.fromPointId == widget.junctionPointId ||
        c.toPointId == widget.junctionPointId).toList();
    final used = {
      for (final t in draft.terminals.where(
          (t) => t.junctionPointId == widget.junctionPointId))
        for (final ref in t.members) ref.key,
    };
    final available = <ElectricalCoreReference>[
      for (final c in connected)
        for (final core in c.cores)
          if (!used.contains(c.id + '/' + core.id))
            ElectricalCoreReference(cableId: c.id, coreId: core.id),
    ];
    if (available.length < 2) {
      setState(() => error = 'Нужно минимум два свободных конца жил.');
      return;
    }
    final selected = <String>{};
    var mark = '';
    final result = await showDialog<List<ElectricalCoreReference>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Новая клемма'),
          scrollable: true,
          content: SizedBox(
            width: 370,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Явно выберите концы жил, которые подключаются '
                    'к одной клемме. Одинаковый цвет не означает соединение.'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('junction-terminal-mark'),
                  onChanged: (value) => mark = value,
                  decoration: const InputDecoration(
                    labelText: 'Маркировка клеммы', hintText: 'Например X1',
                  ),
                ),
                for (final ref in available)
                  CheckboxListTile(
                    key: ValueKey('junction-core-' + ref.key),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text((draft.cables
                            .where((c) => c.id == ref.cableId)
                            .first.description.isEmpty
                                ? ref.cableId
                                : draft.cables
                                    .where((c) => c.id == ref.cableId)
                                    .first.description) +
                        ' · жила ' + ref.coreId),
                    subtitle: Text(circuitLabel(draft.cables
                        .where((c) => c.id == ref.cableId).first.circuitId)),
                    value: selected.contains(ref.key),
                    onChanged: (value) => refresh(() {
                      if (value == true) {
                        selected.add(ref.key);
                      } else {
                        selected.remove(ref.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('junction-terminal-create'),
              onPressed: selected.length < 2 ? null : () {
                Navigator.pop(dialog, [
                  for (final ref in available)
                    if (selected.contains(ref.key)) ref,
                ]);
              },
              child: const Text('Соединить'),
            ),
          ],
        ),
      ),
    );
    final label = mark;
    if (!mounted || result == null) return;
    change(() => ElectricalJunctionEditService.createTerminal(
      widget.floor, draft, id: id('terminal'),
      junctionId: widget.junctionPointId,
      mark: label,
      members: result,
    ));
  }

  void save() {
    try {
      ElectricalJunctionEditService.validateForSave(
        widget.floor, widget.junctionPointId, draft,
      );
      Navigator.pop(context, ElectricalJunctionEditService.copy(draft));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> editCable(ElectricalCableRecord cable) async {
    var description = cable.description;
    var circuitId = cable.circuitId;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Свойства кабеля'),
          scrollable: true,
          content: SizedBox(
            width: 330,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                key: ValueKey('junction-edit-cable-name'),
                initialValue: description,
                onChanged: (v) => description = v,
                decoration: const InputDecoration(
                    labelText: 'Маркировка кабеля'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('junction-edit-cable-circuit'),
                initialValue: circuitId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Цепь'),
                items: [
                  for (final c in draft.circuits)
                    DropdownMenuItem(value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => refresh(() => circuitId = v ?? circuitId),
              ),
              const SizedBox(height: 12),
              const Text('Концы, жилы и клеммы останутся прежними. '
                  'Смена группы подключённого кабеля блокируется.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Отмена')),
            FilledButton(
              key: const ValueKey('junction-edit-cable-save'),
              onPressed: () => Navigator.pop(dialog,
                  (description, circuitId)),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    change(() => ElectricalJunctionEditService.editCableDetails(
      draft, cableId: cable.id, description: result.$1,
      circuitId: result.$2,
    ));
  }

  Future<void> editRoute(ElectricalCableRecord cable) async {
    final initial = draft.routes3d
        .where((r) => r.id == cable.route3dId).firstOrNull;
    final result = await Navigator.of(context).push<ElectricalRouteEditResult>(
      MaterialPageRoute(
        builder: (_) => ElectricalRouteEditor(
          floor: widget.floor, cable: cable, initial: initial,
        ),
      ),
    );
    if (!mounted || result == null) return;
    change(() => ElectricalRouteService.upsertForCable(
      widget.floor, draft, cable.id, result.path,
      reserveMm: result.reserveMm,
    ));
  }

  String routeSummary(ElectricalCableRecord cable) {
    final route = draft.routes3d
        .where((r) => r.id == cable.route3dId).firstOrNull;
    if (route == null) return '3D-трасса не задана';
    try {
      final m = ElectricalRouteService.measure(widget.floor, route,
          reserveMm: cable.explicitReserveMm);
      final len = (m.geometricMm / 1000).toStringAsFixed(2);
      return 'Трасса ' + len + ' м · ' +
          (m.procurementLengthMm == null ? 'запас неизвестен'
              : 'с запасом ' +
                (m.procurementLengthMm! / 1000).toStringAsFixed(2) + ' м');
    } on FormatException {
      return 'Трасса требует перепроверки';
    }
  }

  Widget cableTile(ElectricalCableRecord cable) {
    final other = cable.fromPointId == widget.junctionPointId
        ? cable.toPointId : cable.fromPointId;
    final fromBox = cable.fromPointId == widget.junctionPointId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: ValueKey('junction-cable-' + cable.id),
        leading: Icon(fromBox ? Icons.call_made : Icons.call_received),
        title: Text(cable.description.isEmpty ? pointLabel(other)
            : cable.description),
        subtitle: Text((fromBox ? 'Выход' : 'Вход') +
            ' · ' + circuitLabel(cable.circuitId) +
            ' · ' + cable.cores.length.toString() + ' жил'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(routeSummary(cable),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton.icon(
                key: ValueKey('junction-edit-cable-' + cable.id),
                onPressed: () => editCable(cable),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Свойства'),
              ),
              TextButton.icon(
                key: ValueKey('junction-edit-route-' + cable.id),
                onPressed: () => editRoute(cable),
                icon: const Icon(Icons.route),
                label: const Text('Трасса'),
              ),
              if (cable.route3dId != null)
                TextButton(
                  key: ValueKey('junction-clear-route-' + cable.id),
                  onPressed: () => change(() =>
                      ElectricalRouteService.clearCableRoute(draft, cable.id)),
                  child: const Text('Убрать трассу'),
                ),
            ],
          ),
          for (final core in cable.cores)
            ListTile(
              dense: true,
              title: Text('Жила ' + core.id),
              trailing: SizedBox(
                width: 160,
                child: DropdownButton<ElectricalCorePurpose>(
                  key: ValueKey('junction-purpose-' + cable.id + '-' + core.id),
                  isExpanded: true,
                  value: core.purpose,
                  items: const [
                    DropdownMenuItem(value: ElectricalCorePurpose.unspecified,
                        child: Text('Не задано')),
                    DropdownMenuItem(value: ElectricalCorePurpose.phase,
                        child: Text('L')),
                    DropdownMenuItem(value: ElectricalCorePurpose.neutral,
                        child: Text('N')),
                    DropdownMenuItem(value: ElectricalCorePurpose.protectiveEarth,
                        child: Text('PE')),
                    DropdownMenuItem(value: ElectricalCorePurpose.switchedPhase,
                        child: Text('L после выкл.')),
                    DropdownMenuItem(value: ElectricalCorePurpose.signal,
                        child: Text('Сигнал')),
                    DropdownMenuItem(value: ElectricalCorePurpose.shield,
                        child: Text('Экран')),
                  ],
                  onChanged: (purpose) {
                    if (purpose == null) return;
                    change(() => ElectricalJunctionEditService.setCorePurpose(
                      draft, cableId: cable.id, coreId: core.id,
                      purpose: purpose,
                    ));
                  },
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('junction-delete-cable-' + cable.id),
              onPressed: () => change(() =>
                  ElectricalJunctionEditService.removeCable(draft, cable.id)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить кабель'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incoming = draft.cables.where(
        (c) => c.toPointId == widget.junctionPointId).toList();
    final outgoing = draft.cables.where(
        (c) => c.fromPointId == widget.junctionPointId).toList();
    final terminals = draft.terminals.where(
        (t) => t.junctionPointId == widget.junctionPointId).toList();
    final occupied = {
      for (final terminal in terminals)
        for (final member in terminal.members) member.key,
    };
    final unassigned = [...incoming, ...outgoing].fold<int>(
      0, (sum, cable) => sum + cable.cores.where(
          (c) => !occupied.contains(cable.id + '/' + c.id)).length,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Соединения коробки'),
        actions: [
          IconButton(
            tooltip: 'Закрыть без сохранения',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Черновая электрическая схема. Подключения создаются '
                'только вручную, а не по пересечению линий.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Count(label: 'Вход', count: incoming.length)),
                const SizedBox(width: 8),
                Expanded(child: _Count(label: 'Выход', count: outgoing.length)),
                const SizedBox(width: 8),
                Expanded(child: _Count(label: 'Свободных жил', count: unassigned)),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, key: const ValueKey('junction-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text('Цепи',
                  style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                key: const ValueKey('junction-add-circuit'),
                onPressed: createCircuit,
                icon: const Icon(Icons.add),
                label: const Text('Цепь'),
              ),
            ]),
            if (draft.circuits.isEmpty)
              const Text('Нет цепей. Создайте цепь, прежде чем добавлять кабель.'),
            for (final c in draft.circuits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(c.name),
                subtitle: Text(c.kind.name),
              ),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text('Кабели',
                  style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                key: const ValueKey('junction-add-cable'),
                onPressed: createCable,
                icon: const Icon(Icons.add),
                label: const Text('Кабель'),
              ),
            ]),
            if (incoming.isEmpty && outgoing.isEmpty)
              const Text('Кабели пока не назначены. Линии на плане '
                  'не создают электрическое соединение.'),
            if (incoming.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Входящие'),
              for (final c in incoming) cableTile(c),
            ],
            if (outgoing.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Исходящие'),
              for (final c in outgoing) cableTile(c),
            ],
            const Divider(height: 26),
            Row(children: [
              Expanded(child: Text('Клеммы',
                  style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                key: const ValueKey('junction-add-terminal'),
                onPressed: createTerminal,
                icon: const Icon(Icons.add),
                label: const Text('Соединить'),
              ),
            ]),
            if (terminals.isEmpty)
              const Text('Нет подтверждённых соединений жил.'),
            for (final t in terminals)
              ListTile(
                key: ValueKey('junction-terminal-' + t.id),
                contentPadding: EdgeInsets.zero,
                title: Text(t.mark.isEmpty ? 'Клемма ' + t.id : t.mark),
                subtitle: Text(t.members
                    .map((ref) => ref.cableId + ':' + ref.coreId).join(' · ')),
                trailing: IconButton(
                  key: ValueKey('junction-delete-terminal-' + t.id),
                  tooltip: 'Удалить соединение',
                  icon: const Icon(Icons.close),
                  onPressed: () => change(() =>
                      ElectricalJunctionEditService.removeTerminal(draft, t.id)),
                ),
              ),
            const SizedBox(height: 12),
            Text('Не заменяет проверку монтажной схемы, допустимости '
                'клемм и электробезопасности.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16,
              12 + MediaQuery.viewInsetsOf(context).bottom),
          child: FilledButton(
            key: const ValueKey('junction-save'),
            onPressed: save,
            child: const Text('Сохранить связи'),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainer,
    ),
    child: Column(children: [
      Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
      Text(label, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall),
    ]),
  );
}

class _CableInput {
  const _CableInput(this.otherId, this.circuitId, this.fromBox,
      this.coreCount, this.runId, this.description);
  final String otherId;
  final String circuitId;
  final bool fromBox;
  final int coreCount;
  final String? runId;
  final String description;
}
