import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/electrical_design_draft.dart';
import '../models/models.dart';
import '../services/electrical_din_layout_service.dart';
import '../services/electrical_din_layout_proposal_service.dart';

/// User-authored mechanical DIN inventory only, not a wiring diagram.
class ElectricalDinBoardEditor extends StatefulWidget {
  const ElectricalDinBoardEditor({
    super.key,
    required this.floor,
    required this.onSave,
  });

  final FloorPlan floor;
  /// The parent records undo before changing the persisted design draft.
  final Future<void> Function(ElectricalDinBoardDraft draft) onSave;

  @override
  State<ElectricalDinBoardEditor> createState() =>
      _ElectricalDinBoardEditorState();
}

class _ElectricalDinBoardEditorState extends State<ElectricalDinBoardEditor> {
  String _kindLabel(ElectricalDinDeviceKind kind) => switch (kind) {
    ElectricalDinDeviceKind.incoming => 'Вводной аппарат',
    ElectricalDinDeviceKind.breaker => 'Автомат',
    ElectricalDinDeviceKind.rcd => 'УЗО',
    ElectricalDinDeviceKind.rcbo => 'Дифавтомат',
    ElectricalDinDeviceKind.surgeProtector => 'УЗИП',
    ElectricalDinDeviceKind.contactor => 'Контактор',
    ElectricalDinDeviceKind.other => 'Другой аппарат',
  };

  String? _panelId;

  List<ElectricalPoint> get _panels => widget.floor.electricalPoints
      .where((point) => point.type == ElectricalPointType.panel).toList();

  ElectricalDinBoardDraft _current(String panelId) {
    final saved = widget.floor.electricalDesignDraft?.dinBoards[panelId];
    return saved == null
        ? ElectricalDinBoardDraft(panelPointId: panelId)
        : ElectricalDinBoardDraft.fromJson(saved.toJson());
  }

  Future<void> _save(ElectricalDinBoardDraft board) async {
    board.validate();
    await widget.onSave(board);
    if (mounted) setState(() {});
  }

  Future<void> _configure(ElectricalDinBoardDraft current) async {
    var rowsInput = current.rows == 0 ? '' : current.rows.toString();
    var modulesInput = current.modulesPerRow == 0
        ? '' : current.modulesPerRow.toString();
    final requested = await showDialog<(int, int)>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Параметры DIN-корпуса'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            key: const ValueKey('din-rail-rows'),
            initialValue: rowsInput,
            onChanged: (value) => rowsInput = value,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Число DIN-рядов'),
          ),
          TextFormField(
            key: const ValueKey('din-rail-modules'),
            initialValue: modulesInput,
            onChanged: (value) => modulesInput = value,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Модулей на один ряд',
              helperText: 'По паспорту конкретного корпуса',
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена')),
          FilledButton(
            key: const ValueKey('din-save-enclosure'),
            onPressed: () {
              final r = int.tryParse(rowsInput.trim());
              final m = int.tryParse(modulesInput.trim());
              if (r == null || m == null || r <= 0 || m <= 0 ||
                  r > 100 || m > 500) return;
              Navigator.pop(dialog, (r, m));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (requested == null || !mounted) return;
    current.rows = requested.$1;
    current.modulesPerRow = requested.$2;
    await _save(current);
  }

  int? _halfModules(String value, {bool position = false}) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return null;
    final units = (parsed - (position ? 1 : 0)) * 2;
    final rounded = units.round();
    if ((units - rounded).abs() > 0.00001 ||
        rounded < (position ? 0 : 1)) return null;
    return rounded;
  }

  Future<void> _editDevice(ElectricalDinBoardDraft current,
      [ElectricalDinDeviceDraft? original]) async {
    var labelInput = original?.label ?? '';
    var modelInput = original?.model ?? '';
    var widthInput = original?.widthHalfModules == null
        ? '' : (original!.widthHalfModules! / 2).toString();
    var rowInput = original?.row == null
        ? '' : (original!.row! + 1).toString();
    var positionInput = original?.startHalfModule == null
        ? '' : (original!.startHalfModule! / 2 + 1).toString();
    var circuitInput = original?.circuitId ?? '';
    var kind = original?.kind ?? ElectricalDinDeviceKind.other;
    var locked = original?.positionLocked ?? false;
    final requested = await showDialog<ElectricalDinDeviceDraft>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(original == null ? 'Добавить DIN-аппарат' :
              'Параметры DIN-аппарата'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ElectricalDinDeviceKind>(
                  key: const ValueKey('din-device-kind'),
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  items: [
                    for (final value in ElectricalDinDeviceKind.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_kindLabel(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => kind = value);
                  },
                ),
                TextFormField(
                  key: const ValueKey('din-device-label'),
                  initialValue: labelInput,
                  onChanged: (value) => labelInput = value,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                TextFormField(
                  key: const ValueKey('din-device-model'),
                  initialValue: modelInput,
                  onChanged: (value) => modelInput = value,
                  decoration: const InputDecoration(
                    labelText: 'Модель по паспорту',
                  ),
                ),
                TextFormField(
                  key: const ValueKey('din-device-width'),
                  initialValue: widthInput,
                  onChanged: (value) => widthInput = value,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Паспортная ширина, модули',
                    helperText: 'Шаг 0,5; неизвестное оставь пустым',
                  ),
                ),
                TextFormField(
                  key: const ValueKey('din-device-circuit'),
                  initialValue: circuitInput,
                  onChanged: (value) => circuitInput = value,
                  decoration: const InputDecoration(
                    labelText: 'ID физической группы (необязательно)',
                  ),
                ),
                TextFormField(
                  key: const ValueKey('din-device-row'),
                  initialValue: rowInput,
                  onChanged: (value) => rowInput = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ряд, начиная с 1',
                  ),
                ),
                TextFormField(
                  key: const ValueKey('din-device-position'),
                  initialValue: positionInput,
                  onChanged: (value) => positionInput = value,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Позиция, начиная с модуля 1',
                    helperText: '1 / 1,5 / 2 ...',
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('din-device-lock'),
                  value: locked,
                  title: const Text('Закрепить позицию'),
                  subtitle: const Text('Автоперекомпоновка не перемещает'),
                  onChanged: (value) => update(() => locked = value),
                ),
              ],
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
                child: const Text('Отмена')),
            FilledButton(
              key: const ValueKey('din-save-device'),
              onPressed: () {
                final w = widthInput.trim().isEmpty
                    ? null : _halfModules(widthInput);
                final r = rowInput.trim().isEmpty
                    ? null : int.tryParse(rowInput.trim());
                final start = positionInput.trim().isEmpty
                    ? null : _halfModules(positionInput, position: true);
                if ((widthInput.trim().isNotEmpty && w == null) ||
                    (rowInput.trim().isNotEmpty && (r == null || r < 1)) ||
                    (positionInput.trim().isNotEmpty && start == null) ||
                    ((r == null) != (start == null)) ||
                    (locked && r == null)) return;
                var id = original?.id;
                if (id == null) {
                  var counter = 1;
                  while (current.devices.any((d) =>
                      d.id == 'din-$counter')) {
                    counter++;
                  }
                  id = 'din-$counter';
                }
                Navigator.pop(dialog, ElectricalDinDeviceDraft(
                  id: id, kind: kind,
                  label: labelInput.trim(),
                  model: modelInput.trim(),
                  circuitId: circuitInput.trim().isEmpty
                      ? null : circuitInput.trim(),
                  widthHalfModules: w,
                  row: r == null ? null : r - 1,
                  startHalfModule: start,
                  positionLocked: locked,
                ));
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (requested == null || !mounted) return;
    current.devices.removeWhere((d) => d.id == requested.id);
    current.devices.add(requested);
    await _save(current);
  }

  Future<void> _deleteDevice(
      ElectricalDinBoardDraft current, ElectricalDinDeviceDraft device) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить аппарат из черновика?'),
        content: Text('Удалить запись ${device.label.isEmpty ? device.id : device.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Отмена')),
          FilledButton(
            key: const ValueKey('din-delete-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    current.devices.removeWhere((d) => d.id == device.id);
    await _save(current);
  }

  Future<void> _suggestLayout(ElectricalDinBoardDraft current) async {
    final sourceSnapshot = jsonEncode(current.toJson());
    final proposal = ElectricalDinLayoutProposalService.propose(
        widget.floor, current);
    if (proposal.problems.isNotEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Компоновка невозможна'),
          content: Text(proposal.problems.join('\n')),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Закрыть'),
          )],
        ),
      );
      return;
    }
    if (proposal.changes.isEmpty || proposal.preview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Все аппараты уже размещены. Перемещать нечего.'),
        ));
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Предложение DIN-компоновки'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Переместить или установить: '
                    '${proposal.changes.length}. '
                    'Закреплённые позиции не затрагиваются.'),
                const SizedBox(height: 6),
                const Text('Это размещение по габаритам, не схема '
                    'электрических соединений.'),
                for (final change in proposal.changes)
                  ListTile(
                    dense: true,
                    title: Text(change.deviceId),
                    subtitle: Text(
                      'Ряд ${change.nextRow + 1}, '
                      'позиция ${change.nextHalfModule / 2 + 1}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('din-proposal-cancel'),
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('din-proposal-apply'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // A newer manual edit or other floor change invalidates the preview.
    // Never overwrite it with an older proposal from an open dialog.
    final latest = _current(current.panelPointId);
    if (jsonEncode(latest.toJson()) != sourceSnapshot) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Компоновка изменилась. Построй предложение заново.'),
      ));
      return;
    }
    await _save(proposal.preview!);
  }

  @override
  Widget build(BuildContext context) {
    final panels = _panels;
    if (panels.isEmpty) {
      return const Card(child: ListTile(
        title: Text('DIN-компоновка'),
        subtitle: Text('Сначала добавь точку «Щит» на план.'),
      ));
    }
    final panel = panels.where((p) => p.id == _panelId).firstOrNull ??
        panels.first;
    final board = _current(panel.id);
    final audit = ElectricalDinLayoutService.inspect(widget.floor, board);
    return Column(
      key: const ValueKey('din-board-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('DIN-компоновка · ручной черновик',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Паспортная модель, ширина и ряд задаются вручную. '
            'Номиналы и клеммы не подбираются.'),
        if (panels.length > 1) Wrap(
          spacing: 6,
          children: [
            for (final point in panels)
              ChoiceChip(
                label: Text(point.label.isEmpty ? point.id : point.label),
                selected: panel.id == point.id,
                onSelected: (_) => setState(() => _panelId = point.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const ValueKey('din-enclosure-summary'),
          dense: true,
          title: Text('Щит: ${panel.label.isEmpty ? panel.id : panel.label}'),
          subtitle: Text(board.rows == 0 || board.modulesPerRow == 0
              ? 'DIN-корпус не задан'
              : '${board.rows} ряд(а) × ${board.modulesPerRow} модулей; '
                'занято ${audit.occupiedHalfModules / 2}'),
          trailing: IconButton(
            key: const ValueKey('din-configure'),
            tooltip: 'Габариты DIN-корпуса',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _configure(board),
          ),
        ),
        if (board.rows > 0 && board.modulesPerRow > 0 &&
            board.rows <= 8 && board.modulesPerRow <= 36)
          for (var rail = 0; rail < board.rows; rail++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                key: ValueKey('din-rail-preview-$rail'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DIN-ряд ${rail + 1}',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 3),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var half = 0;
                            half < board.modulesPerRow * 2; half++)
                          Builder(builder: (context) {
                            final covering = board.devices.where((d) =>
                                d.row == rail &&
                                d.startHalfModule != null &&
                                d.widthHalfModules != null &&
                                half >= d.startHalfModule! &&
                                half < d.startHalfModule! +
                                    d.widthHalfModules!).toList();
                            final color = covering.length > 1
                                ? Theme.of(context).colorScheme.errorContainer
                                : covering.isNotEmpty
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainer;
                            return Tooltip(
                              message: covering.isEmpty
                                  ? 'Пустое место'
                                  : covering.map((d) =>
                                      d.label.isEmpty ? d.id : d.label).join(', '),
                              child: Container(
                                key: ValueKey('din-cell-$rail-$half'),
                                width: 18,
                                height: 29,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                    width: .5,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: half.isEven ? Text(
                                  '${half ~/ 2 + 1}',
                                  style: const TextStyle(fontSize: 8),
                                ) : null,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        OutlinedButton.icon(
          key: const ValueKey('din-add-device'),
          onPressed: () => _editDevice(board),
          icon: const Icon(Icons.add),
          label: const Text('Добавить аппарат по паспорту'),
        ),
        if (board.devices.isNotEmpty)
          OutlinedButton.icon(
            key: const ValueKey('din-suggest-layout'),
            onPressed: () => _suggestLayout(board),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Предложить свободные места'),
          ),
        if (board.devices.isEmpty)
          const ListTile(dense: true,
            title: Text('Аппараты пока не добавлены'),
          ),
        for (final device in board.devices)
          Card(child: ListTile(
            key: ValueKey('din-device-${device.id}'),
            dense: true,
            title: Text(device.label.isEmpty ? device.id : device.label),
            subtitle: Text(
              '${device.model.isEmpty ? "Модель не указана" : device.model} · '
              '${device.widthHalfModules == null ? "ширина неизвестна" : "${device.widthHalfModules! / 2} модуля"} · '
              '${device.row == null || device.startHalfModule == null ? "место не указано" : "ряд ${device.row! + 1}, позиция ${device.startHalfModule! / 2 + 1}"}'
              '${device.positionLocked ? " · закреплено" : ""}',
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                key: ValueKey('din-edit-${device.id}'),
                tooltip: 'Редактировать аппарат',
                onPressed: () => _editDevice(board, device),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('din-delete-${device.id}'),
                tooltip: 'Удалить аппарат',
                onPressed: () => _deleteDevice(board, device),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
          )),
        if (audit.issues.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('din-issues'),
            title: Text('Замечания к компоновке: ${audit.issues.length}'),
            children: [
              for (final issue in audit.issues)
                ListTile(dense: true, title: Text(issue.message)),
            ],
          ),
        const Text('Этот эскиз не является схемой подключения '
            'или разрешением на монтаж.'),
      ],
    );
  }
}
