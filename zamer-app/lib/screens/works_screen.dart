import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/work_board.dart';
import '../models/work_calendar.dart';
import '../design_system/zamer_tokens.dart';
import '../services/geometry_service.dart';
import '../services/work_schedule_service.dart';
import '../services/workload_service.dart';
import '../services/work_generation_service.dart';
import '../services/work_operation_taxonomy.dart';
import '../services/work_surface_service.dart';
import '../services/work_floor_surface_service.dart';
import '../services/work_floor_polygon_service.dart';
import '../services/work_status_service.dart';
import '../services/work_co_stage_service.dart';
import '../services/work_stage_presentation_service.dart';

const _bg = ZamerColors.background;
const _panel = ZamerColors.surface;
const _edge = Color(0xFF3A3C43);
const _peach = ZamerColors.conceptAccent;
const _blue = ZamerColors.info;
const _green = ZamerColors.success;
const _red = ZamerColors.danger;
const _amber = ZamerColors.warning;
const _muted = Color(0xFF9DA2AD);

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _number(double n) => n.toStringAsFixed(n % 1 == 0 ? 0 : 1);

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key, required this.project,
    required this.onChanged, this.embedded = false, this.floorId});
  final MeasureProject project;
  final Future<void> Function() onChanged;
  final bool embedded;
  final String? floorId;

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  int _tab = 0, _calendar = 0, _control = 0;
  int _compactTab = 0;
  String? _openedGroup;
  String? _expandedTaskId;
  bool _showCrewLoad = false;
  bool _showRoomMap = false;
  final Set<String> _openSubgroups = <String>{};
  DateTime _selected = _day(DateTime.now());
  String? _roomId;
  String? _selectedFloorId;
  WorkBoard get board => widget.project.workBoard;
  @override
  void initState() {
    super.initState();
    _selectedFloorId = widget.floorId;
  }

  @override
  void didUpdateWidget(covariant WorksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorId != widget.floorId && widget.floorId != null) {
      _selectedFloorId = widget.floorId;
      _roomId = null;
    }
  }

  FloorPlan? get _activeFloor {
    final floors = widget.project.floors;
    if (floors.isEmpty) return null;
    return floors.where((floor) => floor.id == _selectedFloorId).firstOrNull ??
        floors.first;
  }

  List<RoomMeta> get rooms => _activeFloor?.roomMetas ?? const <RoomMeta>[];

  Future<void> _save() async {
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Color _statusColor(WorkTask task) => switch (
      WorkStatusService.state(board, task)) {
    WorkState.accepted => _green,
    WorkState.defect || WorkState.overdue => _red,
    WorkState.paused || WorkState.awaitingAcceptance => _amber,
    WorkState.inProgress || WorkState.ready => _blue,
    WorkState.quantityReview => _amber,
    WorkState.blocked || WorkState.planned => _muted,
  };

  String _status(WorkTask task) =>
      WorkStatusService.state(board, task).label;

  Color _roomColor(String roomId) {
    final tasks = board.tasks.where((t) => t.roomId == roomId).toList();
    if (tasks.isEmpty) return const Color(0xFF7B8595);
    if (board.issues.any((e) => e.roomId == roomId && e.open) ||
        tasks.any((t) => t.isDelayed(DateTime.now()))) return _red;
    if (tasks.every((t) => t.fullyAccepted)) return _green;
    if (tasks.any((t) => t.complete)) return _amber;
    if (tasks.any((t) => t.progress > 0)) return _blue;
    return const Color(0xFF7B8595);
  }


  // One ordered library, not dozens of unrelated cards in the work screen.
  static const _workStageOrder = <String>[
    'Подготовка', 'Демонтаж', 'Конструктив', 'Электрика',
    'Инженерия', 'Стены', 'Потолок', 'Пол', 'Двери и окна',
    'Оборудование и финиш', 'Контроль и сдача', 'Другие работы',
  ];

  String _stageFor(WorkTask task) {
    final op = WorkOperationCatalog.byCode[task.operationCode];
    if (op != null) return WorkOperationTaxonomy.groupOf(op);
    return _workStageOrder.contains(task.category)
        ? task.category : 'Другие работы';
  }

  String _subgroupFor(WorkTask task) {
    final op = WorkOperationCatalog.byCode[task.operationCode];
    return op == null ? 'Прочие работы' :
      WorkOperationTaxonomy.subgroupOf(op);
  }

  List<WorkTask> get _visibleWorks {
    final floorId = _activeFloor?.id;
    return board.tasks.where((t) =>
      (floorId == null || t.floorId == null || t.floorId == floorId) &&
      (_roomId == null || t.roomId == _roomId)).toList()
      ..sort((a, b) {
        final date = a.start.compareTo(b.start);
        return date != 0 ? date : a.title.compareTo(b.title);
      });
  }

  Widget _compactTop() {
    final tasks = _visibleWorks;
    final accepted = tasks.where((t) =>
      t.fullyAccepted && !t.needsQuantityReview).length;
    final visibleIds = tasks.map((t) => t.id).toSet();
    final problems = tasks.where((t) {
      final state = WorkStatusService.state(board, t);
      return state == WorkState.defect ||
        state == WorkState.quantityReview ||
        state == WorkState.overdue ||
        state == WorkState.awaitingAcceptance ||
        board.issues.any((issue) => issue.open && issue.taskId == t.id);
    }).length + board.issues.where((issue) =>
      issue.open && !visibleIds.contains(issue.taskId) &&
      (_roomId == null || issue.roomId == _roomId)).length;
    final progress = WorkStagePresentationService.acceptedProgress(tasks);
    final current = WorkStagePresentationService.currentTask(board, tasks);
    final currentState = current == null ? null :
      WorkStatusService.state(board, current);
    final currentLabel = switch (currentState) {
      WorkState.inProgress => 'В работе',
      WorkState.overdue => 'Просрочено',
      WorkState.ready => 'Можно начать',
      WorkState.paused => 'Приостановлено',
      WorkState.planned => 'Далее по плану',
      WorkState.blocked => 'Ожидает',
      _ => 'Следующая работа',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 7),
      decoration: const BoxDecoration(color: _panel,
        border: Border(bottom: BorderSide(color: _edge))),
      child: Column(children: [
        Row(children: [
          Text((progress * 100).round().toString() + '%',
            style: const TextStyle(color: _peach, fontSize: 22,
              fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(accepted.toString() + ' из ' +
                tasks.length.toString() + ' принято',
                style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _meter(progress, height: 5),
            ],
          )),
          if (problems > 0)
            TextButton.icon(
              onPressed: () => setState(() => _compactTab = 2),
              icon: const Icon(Icons.error_outline, size: 16),
              label: Text(problems.toString()),
              style: TextButton.styleFrom(foregroundColor: _amber),
            ),
          PopupMenuButton<String>(
            key: const ValueKey('works-tools'),
            tooltip: 'Инструменты работ',
            icon: const Icon(Icons.more_vert, color: _peach),
            onSelected: (value) {
              if (value == 'generate') _generateTasks();
              if (value == 'wall') _chooseWallFinishes();
              if (value == 'floor') _chooseFloorFinishes(polygons: true);
              if (value == 'split') _chooseFloorFinishes();
              if (value == 'calendar') _calendarSettings();
              if (value == 'workload') {
                setState(() {
                  _compactTab = 2;
                  _showCrewLoad = true;
                });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'generate',
                child: Text('Сформировать работы')),
              PopupMenuItem(value: 'wall',
                child: Text('Отделка стен')),
              PopupMenuItem(value: 'floor',
                child: Text('Зоны пола')),
              PopupMenuItem(value: 'split',
                child: Text('Быстро разделить пол')),
              PopupMenuItem(value: 'calendar',
                child: Text('Рабочий календарь')),
              PopupMenuItem(value: 'workload',
                child: Text('Нагрузка бригад')),
            ],
          ),
        ]),
        if (current != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('works-current-task'),
              onPressed: () => _taskDetail(current),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(currentLabel + ': ' + current.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
              style: TextButton.styleFrom(
                foregroundColor: _peach,
                padding: const EdgeInsets.symmetric(
                  horizontal: 3, vertical: 0),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        if (rooms.length > 1)
          SizedBox(height: 38, child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final room in <(String?, String)>[
                (null, 'Весь этаж'),
                for (final r in rooms) (r.id, r.name),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 5),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(room.$2, maxLines: 1,
                      style: const TextStyle(fontSize: 11)),
                    selected: _roomId == room.$1,
                    onSelected: (_) => setState(() => _roomId = room.$1),
                  ),
                ),
            ],
          )),
      ]),
    );
  }

  String _shortWorkStatus(WorkState state, WorkTask task) =>
      switch (state) {
        WorkState.accepted => 'Принято',
        WorkState.defect => 'Замечание',
        WorkState.quantityReview => 'Проверить',
        WorkState.overdue => 'Просрочено',
        WorkState.awaitingAcceptance => 'Приёмка',
        WorkState.paused => 'Пауза',
        WorkState.blocked => 'Ожидает',
        WorkState.ready => 'К началу',
        WorkState.planned => 'План',
        WorkState.inProgress =>
          (task.progress * 100).round().toString() + '%',
      };

  Widget _compactInlineTaskActions(WorkTask task, WorkState state) {
    final remaining = (task.quantity - task.done).clamp(0.0, task.quantity)
        .toDouble();
    final blocker = WorkStatusService.startBlocker(board, task);
    final primary = task.needsQuantityReview
        ? 'Проверить объём'
        : task.done > task.accepted
            ? 'Принять выполненное'
            : task.paused
                ? 'Возобновить'
                : 'Добавить объём';
    final canPerform = task.needsQuantityReview ||
        task.done > task.accepted ||
        task.paused ||
        (!task.fullyAccepted && blocker == null && remaining > 0);
    Future<void> perform() async {
      if (task.needsQuantityReview) {
        await _confirmQuantity(task);
      } else if (task.done > task.accepted) {
        await _accept(task);
      } else if (task.paused) {
        setState(() => task.paused = false);
        board.log('Возобновлена работа: ' + task.title,
          taskId: task.id);
        await _save();
      } else {
        await _updateDone(task);
      }
    }

    return Container(
      key: ValueKey('work-inline-' + task.id),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 5, 12, 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _edge))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Выполнено ' + _number(task.done) + ' из ' +
          _number(task.quantity) + ' ' + task.unit +
          '  ·  Принято ' + _number(task.accepted) + ' ' + task.unit,
          maxLines: 2,
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 8),
        _meter(task.progress, height: 4),
        if (state == WorkState.blocked && blocker != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(blocker, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _amber, fontSize: 11)),
          ),
        if (task.fullyAccepted && !task.needsQuantityReview)
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text('Работа принята',
              style: TextStyle(color: _green, fontSize: 12,
                fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 7),
        Row(children: [
          if (canPerform) ...[
            Expanded(child: FilledButton(
              key: ValueKey('work-primary-' + task.id),
              onPressed: perform,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: _peach, foregroundColor: _bg),
              child: Text(primary, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 6),
          ] else if (!task.fullyAccepted && blocker != null)
            const Expanded(child: Text('Ожидает предыдущие этапы',
              style: TextStyle(color: _muted, fontSize: 11))),
          TextButton(
            key: ValueKey('work-details-' + task.id),
            onPressed: () => _taskDetail(task),
            child: const Text('Подробнее',
              style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _compactWorkRow(WorkTask task) {
    final state = WorkStatusService.state(board, task);
    final color = _statusColor(task);
    final expanded = widget.embedded && _expandedTaskId == task.id;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        key: ValueKey('work-row-' + task.id),
        onTap: widget.embedded
          ? () => setState(() {
              _expandedTaskId = expanded ? null : task.id;
            })
          : () => _taskDetail(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            Container(width: 4, height: 37,
              decoration: BoxDecoration(color: color,
                borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text((task.roomName.isEmpty ? 'Объект' : task.roomName) +
                    ' · ' + _number(task.quantity) + ' ' +
                    task.unit + ' · ' + _date(task.finish),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10.5)),
              ],
            )),
            const SizedBox(width: 6),
            Tooltip(
              message: state.label,
              child: Text(_shortWorkStatus(state, task),
                style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 10.5, color: color)),
            ),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
              color: _muted, size: 18),
          ]),
        ),
      ),
      if (expanded) _compactInlineTaskActions(task, state),
    ]);
  }

  Widget _compactStages() {
    final tasks = _visibleWorks;
    if (tasks.isEmpty) {
      return _card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Работ пока нет',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Начните с формирования работ по планировке.',
            style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _generateTasks,
            icon: const Icon(Icons.auto_awesome_outlined, size: 17),
            label: const Text('Сформировать работы'),
          ),
        ],
      ));
    }
    final groups = <String, List<WorkTask>>{};
    for (final task in tasks) {
      (groups[_stageFor(task)] ??= []).add(task);
    }
    for (final group in groups.keys.toList()) {
      groups[group] = WorkStagePresentationService.order(groups[group]!);
    }
    return Column(children: [
      for (final group in _workStageOrder)
        if (groups.containsKey(group))
          _card(padding: EdgeInsets.zero,
            child: Column(children: [
              InkWell(
                key: ValueKey('works-group-' + group),
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  _openedGroup = _openedGroup == group ? null : group;
                }),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(children: [
                    Icon(_openedGroup == group
                      ? Icons.keyboard_arrow_down : Icons.chevron_right,
                      size: 19, color: _peach),
                    const SizedBox(width: 7),
                    Expanded(child: Text(group,
                      style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800))),
                    Text(groups[group]!.where((t) => t.fullyAccepted &&
                      !t.needsQuantityReview).length.toString() +
                      '/' + groups[group]!.length.toString(),
                      style: const TextStyle(color: _muted, fontSize: 11)),
                    const SizedBox(width: 8),
                    SizedBox(width: 45, child: _meter(
                      groups[group]!.where((t) => t.fullyAccepted &&
                        !t.needsQuantityReview).length /
                      groups[group]!.length, height: 4)),
                  ]),
                )),
              if (_openedGroup == group) ...[
                const Divider(height: 1, color: _edge),
                Builder(builder: (_) {
                  final subgroups = <String, List<WorkTask>>{};
                  for (final task in groups[group]!) {
                    (subgroups[_subgroupFor(task)] ??= []).add(task);
                  }
                  if (subgroups.length == 1) {
                    return Column(children: [
                      for (final task in groups[group]!)
                        _compactWorkRow(task),
                    ]);
                  }
                  return Column(children: [
                    for (final part in subgroups.entries) ...[
                      InkWell(
                        key: ValueKey('works-subgroup-' + group +
                            '-' + part.key),
                        onTap: () => setState(() {
                          final id = group + '|' + part.key;
                          if (!_openSubgroups.add(id)) {
                            _openSubgroups.remove(id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                          child: Row(children: [
                            Icon(_openSubgroups.contains(
                                group + '|' + part.key)
                              ? Icons.keyboard_arrow_down
                              : Icons.chevron_right,
                              size: 17, color: _muted),
                            const SizedBox(width: 9),
                            Expanded(child: Text(part.key,
                              style: const TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700))),
                            Text(part.value.length.toString(),
                              style: const TextStyle(
                                fontSize: 11, color: _muted)),
                          ]),
                        ),
                      ),
                      if (_openSubgroups.contains(group + '|' + part.key))
                        for (final task in part.value)
                          _compactWorkRow(task),
                    ],
                  ]);
                }),
              ],
            ]),
          ),
    ]);
  }

  List<Widget> _compactTasksForDay() {
    final date = _day(_selected);
    final tasks = _visibleWorks.where((t) =>
      !date.isBefore(_day(t.start)) && !date.isAfter(_day(t.finish))
    ).toList();
    if (tasks.isEmpty) {
      return [_card(child: const Text('В этот день работ нет.',
        style: TextStyle(color: _muted, fontSize: 12)))];
    }
    final arranged = WorkStagePresentationService.order(tasks);
    return [
      _card(padding: EdgeInsets.zero, child: Column(children: [
        for (final task in arranged) _compactWorkRow(task),
      ])),
    ];
  }

  Widget _compactSchedule() => Column(children: [
    Row(children: [
      for (final e in ['Неделя', 'Месяц', 'Гант'].asMap().entries) ...[
        Expanded(child: _segment(e.value, _calendar == e.key,
          () => setState(() => _calendar = e.key))),
        if (e.key < 2) const SizedBox(width: 6),
      ],
    ]),
    const SizedBox(height: 12),
    if (_calendar == 0) _weekSelector(),
    if (_calendar == 1) _monthSelector(),
    if (_calendar == 2) _gantt(),
    if (_calendar != 2) ..._compactTasksForDay(),
  ]);

  Widget _compactControl() {
    final urgent = _visibleWorks.where((t) {
      final state = WorkStatusService.state(board, t);
      return state == WorkState.defect ||
          state == WorkState.quantityReview ||
          state == WorkState.overdue ||
          state == WorkState.awaitingAcceptance;
    }).toList();
    final issues = board.issues.where((issue) => issue.open &&
      (_roomId == null || issue.roomId == _roomId)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (urgent.isEmpty && issues.isEmpty)
        _card(child: const Row(children: [
          Icon(Icons.check_circle_outline, color: _green),
          SizedBox(width: 10),
          Expanded(child: Text('Нет работ, требующих проверки.',
            style: TextStyle(fontSize: 13))),
        ])),
      for (final task in urgent)
        _card(padding: EdgeInsets.zero, child: _compactWorkRow(task)),
      for (final issue in issues)
        _card(child: Row(children: [
          const Icon(Icons.report_problem_outlined, color: _amber, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(issue.title, maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        ])),
      if (_activeFloor != null) ...[
        TextButton.icon(
          key: const ValueKey('works-map-toggle'),
          onPressed: () => setState(() => _showRoomMap = !_showRoomMap),
          icon: Icon(_showRoomMap
            ? Icons.expand_less : Icons.map_outlined, size: 18),
          label: const Text('Контроль помещений'),
          style: TextButton.styleFrom(foregroundColor: _muted),
        ),
        if (_showRoomMap)
          _card(child: _PlanView(
            floor: _activeFloor!,
            selected: _roomId,
            onSelect: (id) => setState(() => _roomId = id),
            colorFor: _roomColor,
          )),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: TextButton.icon(
          key: const ValueKey('works-crew-toggle'),
          onPressed: () => setState(() => _showCrewLoad = !_showCrewLoad),
          icon: Icon(_showCrewLoad
            ? Icons.expand_less : Icons.groups_2_outlined, size: 18),
          label: Text(_showCrewLoad
            ? 'Скрыть загрузку бригад' : 'Показать загрузку бригад'),
          style: TextButton.styleFrom(foregroundColor: _muted),
        ),
      ),
      if (_showCrewLoad) _workloadPanel(),
    ]);
  }

  Widget _embeddedBuild() => Scaffold(
    backgroundColor: _bg,
    body: Column(children: [
      _compactTop(),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [
          for (final entry in ['Этапы', 'График', 'Контроль']
              .asMap().entries) ...[
            Expanded(child: _segment(entry.value,
              _compactTab == entry.key,
              () => setState(() => _compactTab = entry.key))),
            if (entry.key < 2) const SizedBox(width: 7),
          ],
        ]),
      ),
      Expanded(child: ListView(
        key: ValueKey('works-compact-tab-' + _compactTab.toString()),
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 72),
        children: [
          if (_compactTab == 0) _compactStages(),
          if (_compactTab == 1) _compactSchedule(),
          if (_compactTab == 2) _compactControl(),
        ],
      )),
    ]),
    floatingActionButton: FloatingActionButton.small(
      key: const ValueKey('works-add'),
      backgroundColor: _peach,
      foregroundColor: _bg,
      tooltip: _compactTab == 2 ? 'Добавить запись' : 'Добавить работу',
      onPressed: _compactTab == 2 ? _quickActions : _addTask,
      child: const Icon(Icons.add_rounded),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _embeddedBuild();
    final base = Theme.of(context);
    final palette = ColorScheme.fromSeed(
      seedColor: _peach, brightness: Brightness.dark, surface: _bg,
    );
    return Theme(
      data: base.copyWith(
        colorScheme: palette,
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(backgroundColor: _bg, surfaceTintColor: Colors.transparent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFF272A34),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.project.name, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const Text('Работы • календарь и контроль',
              style: TextStyle(color: _muted, fontSize: 11)),
          ]),
          actions: [
            IconButton(
              tooltip: 'Сегодня',
              icon: const Icon(Icons.today_outlined),
              onPressed: () => setState(() => _selected = _day(DateTime.now())),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Expanded(child: _segment('Календарь', _tab == 0,
                () => setState(() => _tab = 0))),
              const SizedBox(width: 8),
              Expanded(child: _segment('Контроль', _tab == 1,
                () => setState(() => _tab = 1))),
            ]),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: _tab == 0 ? _calendarContent() : _controlContent(),
          )),
        ]),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _peach,
          foregroundColor: _bg,
          tooltip: _tab == 0 ? 'Добавить работу' : 'Добавить запись',
          onPressed: _tab == 0 ? _addTask : _quickActions,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _segment(String text, bool active, VoidCallback tap) => InkWell(
    onTap: tap, borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 43, alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: active ? const LinearGradient(
          colors: [Color(0xFFFFE0B8), Color(0xFFF2B18D)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)
          : const LinearGradient(
            colors: [Color(0xFF32363A), Color(0xFF181E23)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: active ? _peach : ZamerColors.outlineLight, width: .8),
        boxShadow: [
          const BoxShadow(color: Color(0x7D000000), blurRadius: 11, offset: Offset(0, 4)),
          if (active) BoxShadow(color: _peach.withValues(alpha: .22),
            blurRadius: 17, spreadRadius: .3),
        ],
      ),
      child: Text(text, style: TextStyle(
        color: active ? _bg : Colors.white70,
        fontSize: 13, fontWeight: FontWeight.w700,
      )),
    ),
  );

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C302F), Color(0xFF202326), Color(0xFF151B1E)],
            stops: [0.0, .42, 1.0],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4A4843), width: .8),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 7)),
            BoxShadow(color: Color(0x19FDD2A3), blurRadius: 14, offset: Offset(-3, -4)),
          ],
        ),
        child: child,
      );

  Widget _delayedNotice() {
    final delayed = board.tasks.where((task) =>
      task.isDelayed(DateTime.now())).toList();
    if (delayed.isEmpty) return const SizedBox.shrink();
    return _card(child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: _red),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Просрочено работ: ${delayed.length}',
            style: const TextStyle(color: _red, fontWeight: FontWeight.w800)),
          Text(delayed.first.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
      TextButton(onPressed: () => setState(() {
        _tab = 0;
        _calendar = 0;
        _selected = _day(delayed.first.finish);
      }), child: const Text('Показать')),
    ]));
  }

  Widget _workloadPanel() {
    if (board.tasks.isEmpty) return const SizedBox.shrink();
    final report = WorkloadService.analyze(board);
    final count = report.overloadedDayCount;
    final crews = WorkloadService.assignedCrews(board);
    return _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.groups_2_outlined, color: count > 0 ? _red : _peach),
          const SizedBox(width: 9),
          const Expanded(child: Text('Загрузка исполнителей',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: _crewLoadDetails,
            child: const Text('Подробнее'),
          ),
        ]),
        const SizedBox(height: 5),
        Text(crews.isEmpty
          ? 'Исполнители ещё не назначены.'
          : count > 0
            ? 'Перегрузка: $count бригадо-дней, '
              '${report.overloadPersonHours.toStringAsFixed(1)} чел·ч сверх нормы.'
            : 'Перегрузок не обнаружено. '
              'Дней с параллельными работами: ${report.overlappingDayCount}.',
          style: TextStyle(fontSize: 12,
            color: count > 0 ? _red : _muted)),
        const SizedBox(height: 6),
        Text('По умолчанию 8 чел·ч/день на назначенного исполнителя. '
          'Норму можно изменить.',
          style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ));
  }

  Future<void> _editCrewCapacity(String crew) async {
    final key = WorkloadService.crewKey(crew);
    final current = WorkloadService.capacityFor(board, crew);
    var entered = current.toStringAsFixed(current % 1 == 0 ? 0 : 1);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(crew),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Сколько человеко-часов эта бригада '
            'может отработать за один рабочий день?',
            style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: entered,
            onChanged: (value) => entered = value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Производительность, чел·ч/день'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена')),
          FilledButton(onPressed: () {
            final amount = double.tryParse(
              entered.trim().replaceAll(',', '.'));
            if (amount == null || !amount.isFinite ||
                amount <= 0 || amount > 1000) {
              ScaffoldMessenger.of(dialog).showSnackBar(
                const SnackBar(content: Text('Введите число от 0 до 1000.')),
              );
              return;
            }
            board.crewDailyHours[key] = amount;
            board.log('Норма для $crew: '
              '${amount.toStringAsFixed(1)} чел·ч/день');
            Navigator.pop(dialog, true);
          }, child: const Text('Сохранить')),
        ],
      ),
    );
    if (saved == true) await _save();
  }

  Future<void> _crewLoadDetails() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, redraw) {
          final crews = WorkloadService.assignedCrews(board);
          final report = WorkloadService.analyze(board);
          final overloaded = report.overloadedDays;
          return SafeArea(top: false, child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .73,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const Text('Загрузка бригад',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Перегружено дней: ${report.overloadedDayCount}. '
                  'Часы распределены равномерно по рабочим дням задачи.',
                  style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 12),
                const Text('Доступная мощность',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                if (crews.isEmpty)
                  const ListTile(title: Text('Назначьте исполнителей работ.'))
                else
                  for (final crew in crews)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined, color: _peach),
                      title: Text(crew),
                      subtitle: Text(
                        '${WorkloadService.capacityFor(board, crew).toStringAsFixed(1)} '
                        'чел·ч/рабочий день'),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () async {
                        await _editCrewCapacity(crew);
                        if (sheet.mounted) redraw(() {});
                      },
                    ),
                const Divider(color: _edge),
                const Text('Дни с перегрузкой',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                if (overloaded.isEmpty)
                  const ListTile(title: Text('Перегрузок нет.'))
                else
                  for (final day in overloaded.take(60))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_rounded,
                        color: _red),
                      title: Text('${day.crew} · ${_date(day.day)}'),
                      subtitle: Text(day.taskTitles.values.join(', '),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        '${day.plannedHours.toStringAsFixed(1)} / '
                        '${day.capacity.toStringAsFixed(1)}',
                        style: const TextStyle(color: _red,
                          fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                if (overloaded.length > 60)
                  Text('Показаны первые 60 из ${overloaded.length}.',
                    style: const TextStyle(color: _muted, fontSize: 12)),
                if (report.skippedInvalidTasks > 0)
                  Text('Работ с некорректными датами: '
                    '${report.skippedInvalidTasks}.',
                    style: const TextStyle(color: _red, fontSize: 12)),
              ],
            ),
          ));
        },
      ),
    );
  }

  Widget _heading(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      if (trailing != null) trailing,
    ]),
  );

  Widget _meter(double value, {Color color = _peach, double height = 7}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(value: value.clamp(0, 1),
          minHeight: height, backgroundColor: const Color(0xFF3A3C46),
          valueColor: AlwaysStoppedAnimation(color)),
      );

  Widget _generatorPanel() => _card(
    child: InkWell(
      onTap: _generateTasks,
      child: Row(children: [
        const Icon(Icons.auto_awesome_outlined, color: _peach, size: 24),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сформировать работы из планировки',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Операции, объёмы, предшественники, сроки и помещения',
            style: TextStyle(color: _muted, fontSize: 11)),
        ])),
        const Icon(Icons.chevron_right, color: _peach),
      ]),
    ),
  );

  Future<void> _generateTasks() async {
    var includeOptional = false;
    var selectedRoom = _roomId;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, redraw) {
          final plan = WorkGenerationService.preview(
            widget.project,
            begin: _selected,
            includeOptional: includeOptional,
            roomIds: selectedRoom == null ? null : {selectedRoom!},
          );
          return SafeArea(top: false, child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .84,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                const Text('Формирование графика',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('В основе реальные площади комнат и отделка '
                  'из модели. Уже созданные работы не перезаписываются.',
                  style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: selectedRoom,
                  decoration: const InputDecoration(labelText: 'Зона генерации'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null, child: Text('Все помещения')),
                    for (final floor in widget.project.floors)
                      for (final room in floor.roomMetas)
                        DropdownMenuItem<String?>(
                          value: room.id,
                          child: Text('${floor.name} · ${room.name}',
                            overflow: TextOverflow.ellipsis),
                        ),
                  ],
                  onChanged: (value) => redraw(() => selectedRoom = value),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Добавить дополнительные операции'),
                  subtitle: const Text('Демонтаж, инженерия, стяжка и другие. '
                    'Их объёмы нужно проверить вручную.',
                    style: TextStyle(color: _muted, fontSize: 11)),
                  value: includeOptional,
                  onChanged: (value) => redraw(() => includeOptional = value),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _stat('Новых', '${plan.tasks.length}'),
                  const SizedBox(width: 7),
                  _stat('Уже есть', '${plan.skippedExisting}'),
                  const SizedBox(width: 7),
                  _stat('Проверить', '${plan.reviewCount}',
                    tint: _amber),
                ]),
                Text('Помещений: ${plan.roomsProcessed}. '
                  'Трудоёмкость: ${plan.totalEstimatedHours.toStringAsFixed(1)} чел·ч. '
                  'Не распознано комнат: ${plan.skippedRooms}.',
                  style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 10),
                const Text('Предварительный список',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                for (final task in plan.tasks.take(45))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(task.title),
                    subtitle: Text('${task.roomName} · '
                      '${_number(task.quantity)} ${task.unit} · '
                      '${_date(task.start)}–${_date(task.finish)}',
                      maxLines: 2),
                    trailing: task.needsQuantityReview ?
                      const Icon(Icons.rule_outlined, color: _amber)
                      : const Icon(Icons.check_circle_outline, color: _green),
                  ),
                if (plan.tasks.length > 45)
                  Text('Показаны первые 45 из ${plan.tasks.length}.',
                    style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: plan.tasks.isEmpty ? null : () {
                    final error = WorkGenerationService.apply(board, plan);
                    if (error != null) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        SnackBar(content: Text(error)));
                      return;
                    }
                    Navigator.pop(sheet, true);
                  },
                  child: const Text('Добавить задачи в график'),
                ),
              ],
            ),
          ));
        },
      ),
    );
    if (result == true) {
      setState(() { _tab = 0; _calendar = 2; });
      await _save();
    }
  }


  Widget _wallFinishEntry() => _card(
    child: InkWell(
      onTap: _chooseWallFinishes,
      child: Row(children: [
        const Icon(Icons.texture_outlined, color: _peach, size: 24),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Отделка по отдельным стенам',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Выделить стены на плане · Плитка / покраска · м²',
              style: TextStyle(color: _muted, fontSize: 11)),
          ],
        )),
        const Icon(Icons.chevron_right, color: _peach),
      ]),
    ),
  );

  Future<void> _chooseWallFinishes() async {
    final choices = <({FloorPlan floor, RoomFace face, RoomMeta room})>[];
    for (final floor in widget.project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        final room = floor.roomMetaByKey(face.key);
        if (room != null && face.innerPolygon.length >= 3) {
          choices.add((floor: floor, face: face, room: room));
        }
      }
    }
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала постройте замкнутые помещения на плане.')));
      return;
    }
    int? selected;
    if (choices.length == 1) {
      selected = 0;
    } else {
      selected = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: _panel,
        showDragHandle: true,
        builder: (sheet) => SafeArea(top: false,
          child: ListView(shrinkWrap: true, children: [
            const Padding(padding: EdgeInsets.all(16),
              child: Text('Выберите помещение',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
            for (var i = 0; i < choices.length; i++)
              ListTile(
                title: Text(choices[i].room.name),
                subtitle: Text(choices[i].floor.name),
                trailing: const Icon(Icons.chevron_right, color: _peach),
                onTap: () => Navigator.pop(sheet, i),
              ),
          ])),
      );
    }
    if (selected == null || !mounted) return;
    final item = choices[selected];
    await _editWallFinishes(item.floor, item.face);
  }

  Future<double?> _askExactTileHeight(
      double current, double maximum) async {
    var typed = current.round().toString();
    return showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Точная высота плитки'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            initialValue: typed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Высота облицовки, мм',
              helperText: '0 мм означает полностью окрашенную стену',
            ),
            onChanged: (value) => typed = value,
          ),
          const SizedBox(height: 8),
          Text('Допустимо: от 0 до ' + maximum.round().toString() + ' мм',
            style: const TextStyle(fontSize: 12, color: _muted)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                  typed.trim().replaceAll(',', '.'));
              if (value == null || !value.isFinite ||
                  value < 0 || value > maximum) {
                ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(
                  content: Text('Высота должна быть в пределах стены.'),
                ));
                return;
              }
              Navigator.pop(dialog, value);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Future<void> _editWallFinishes(FloorPlan floor, RoomFace face) async {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return;
    final initial = WorkSurfaceService.walls(board, floor, face);
    if (initial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Для помещения не найдены стороны стен.')));
      return;
    }
    final heights = <String, double>{
      for (final wall in initial) wall.wallId: wall.tileHeightMm,
    };
    var selectedWall = initial.first.wallId;
    final maxHeight = GeometryService.roomHeightMm(floor, face).toDouble();

    double pointDistance(Offset p, Offset a, Offset b) {
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final lengthSquared = dx * dx + dy * dy;
      if (lengthSquared <= .0001) return (p - a).distance;
      final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) /
          lengthSquared).clamp(0.0, 1.0).toDouble();
      return (p - Offset(a.dx + dx * t, a.dy + dy * t)).distance;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, redraw) {
          final all = WorkSurfaceService.walls(
            board, floor, face, previewHeights: heights);
          final active = all.where((s) => s.wallId == selectedWall).first;
          final totalTile = all.fold<double>(0, (s, w) => s + w.tileAreaM2);
          final totalPaint = all.fold<double>(0, (s, w) => s + w.paintAreaM2);
          final newHeight = heights[selectedWall] ?? 0;

          return SafeArea(top: false, child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .87,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
              children: [
                Text('Поверхности: ' + room.name,
                  style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Нажмите на стену на плане. Плитка считается '
                  'от пола до выбранной высоты; выше остаётся покраска.',
                  style: TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 12),
                AspectRatio(aspectRatio: 1.55,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final mapper = _PlanMapper([face], Size(
                      constraints.maxWidth, constraints.maxHeight));
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        String? closest;
                        var best = 25.0;
                        for (var i = 0; i < face.edges.length; i++) {
                          final a = mapper.toCanvas(face.innerPolygon[i]);
                          final b = mapper.toCanvas(face.innerPolygon[
                            (i + 1) % face.innerPolygon.length]);
                          final d = pointDistance(
                            details.localPosition, a, b);
                          if (d < best) {
                            best = d;
                            closest = face.edges[i].wallId;
                          }
                        }
                        if (closest != null) {
                          redraw(() => selectedWall = closest!);
                        }
                      },
                      child: CustomPaint(
                        painter: _WallFinishPlanPainter(
                          face: face, mapper: mapper,
                          tileHeights: heights, selectedWall: selectedWall),
                        child: const SizedBox.expand(),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.crop_square, color: _peach, size: 17),
                  const SizedBox(width: 7),
                  Expanded(child: Text(active.label +
                    ' · ' + active.widthM.toStringAsFixed(2) + ' м',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(active.netAreaM2.toStringAsFixed(2) + ' м²',
                    style: const TextStyle(color: _muted)),
                ]),
                const SizedBox(height: 10),
                Text('Высота плитки: ' +
                  (newHeight / 1000).toStringAsFixed(2) + ' м',
                  style: const TextStyle(color: _muted, fontSize: 12)),
                Slider(
                  min: 0,
                  max: maxHeight,
                  divisions: math.max(1, (maxHeight / 100).round()),
                  value: newHeight.clamp(0.0, maxHeight).toDouble(),
                  activeColor: _peach,
                  onChanged: (height) =>
                    redraw(() => heights[selectedWall] = height),
                ),
                Wrap(spacing: 6, children: [
                  OutlinedButton(onPressed: () =>
                    redraw(() => heights[selectedWall] = 0),
                    child: const Text('Покраска')),
                  OutlinedButton(onPressed: () =>
                    redraw(() => heights[selectedWall] =
                      math.min(1200.0, maxHeight)),
                    child: const Text('Плитка 1,2 м')),
                  OutlinedButton(onPressed: () =>
                    redraw(() => heights[selectedWall] = maxHeight),
                    child: const Text('Плитка до потолка')),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.straighten, size: 17),
                    label: const Text('Точная высота'),
                    onPressed: () async {
                      final wallId = selectedWall;
                      final height = await _askExactTileHeight(
                        heights[wallId] ?? 0, maxHeight);
                      if (height != null && sheet.mounted) {
                        redraw(() => heights[wallId] = height);
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('Все стены помещения',
                  style: TextStyle(fontWeight: FontWeight.w800)),
                for (final wall in all)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    selected: wall.wallId == selectedWall,
                    selectedColor: _peach,
                    title: Text(wall.label),
                    subtitle: Text('Плитка: ' +
                      wall.tileAreaM2.toStringAsFixed(2) +
                      ' м² · Покраска: ' +
                      wall.paintAreaM2.toStringAsFixed(2) + ' м²',
                      style: const TextStyle(fontSize: 11)),
                    trailing: wall.wallId == selectedWall ?
                      const Icon(Icons.check_circle, color: _peach) :
                      const Icon(Icons.chevron_right),
                    onTap: () => redraw(() => selectedWall = wall.wallId),
                  ),
                const Divider(color: _edge),
                Row(children: [
                  _stat('Под плитку',
                    totalTile.toStringAsFixed(2) + ' м²'),
                  const SizedBox(width: 8),
                  _stat('Под покраску',
                    totalPaint.toStringAsFixed(2) + ' м²'),
                ]),
                const SizedBox(height: 8),
                const Text('Проёмы учитываются по высоте. Ранее начатые '
                  'работы не пересчитываются автоматически.',
                  style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 12),
                FilledButton(onPressed: () {
                  WorkSurfaceService.save(board, floor, face, heights);
                  final changed = WorkSurfaceService.refreshUnstartedFinishes(
                    board, floor, face);
                  board.log('Назначена отделка стен: ' + room.name +
                    ', плитка ' + totalTile.toStringAsFixed(2) +
                    ' м², покраска ' + totalPaint.toStringAsFixed(2) +
                    ' м²; обновлено задач: ' + changed.toString());
                  Navigator.pop(sheet, true);
                }, child: const Text('Сохранить распределение')),
              ],
            ),
          ));
        },
      ),
    );
    if (saved == true) await _save();
  }


  Widget _floorFinishEntry() => _card(
    child: InkWell(
      onTap: _chooseFloorFinishes,
      child: Row(children: [
        const Icon(Icons.grid_on_rounded, color: _peach, size: 24),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Зоны покрытий пола',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Плитка + ламинат · разделить комнату на плане',
              style: TextStyle(fontSize: 11, color: _muted)),
          ],
        )),
        const Icon(Icons.chevron_right, color: _peach),
      ]),
    ),
  );

  Future<void> _chooseFloorFinishes({bool polygons = false}) async {
    final choices = <({FloorPlan floor, RoomFace face, RoomMeta room})>[];
    for (final floor in widget.project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        final room = floor.roomMetaByKey(face.key);
        if (room != null && face.innerPolygon.length >= 3) {
          choices.add((floor: floor, face: face, room: room));
        }
      }
    }
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала создайте замкнутые помещения.')));
      return;
    }
    int? selected;
    if (choices.length == 1) {
      selected = 0;
    } else {
      selected = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: _panel,
        showDragHandle: true,
        builder: (sheet) => SafeArea(top: false, child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(16),
              child: Text('Помещение для разделения пола',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
            for (var i = 0; i < choices.length; i++)
              ListTile(
                title: Text(choices[i].room.name),
                subtitle: Text(choices[i].floor.name),
                trailing: const Icon(Icons.chevron_right, color: _peach),
                onTap: () => Navigator.pop(sheet, i),
              ),
          ],
        )));
    }
    if (selected == null || !mounted) return;
    final choice = choices[selected];
    if (polygons) {
      await _editFloorPolygons(choice.floor, choice.face);
    } else {
      await _editFloorFinishes(choice.floor, choice.face);
    }
  }


  Widget _floorPolygonEntry() => _card(
    child: InkWell(
      onTap: () => _chooseFloorFinishes(polygons: true),
      child: Row(children: [
        const Icon(Icons.polyline_outlined, color: _peach, size: 24),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Нарисовать зоны пола',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Контуры из точек · несколько участков · точные м²',
              style: TextStyle(fontSize: 11, color: _muted)),
          ],
        )),
        const Icon(Icons.chevron_right, color: _peach),
      ]),
    ),
  );


  Future<math.Point<double>?> _askFloorVertexPosition(
      math.Point<double> current) async {
    var x = current.x.round().toString();
    var y = current.y.round().toString();
    return showDialog<math.Point<double>>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Координаты вершины'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            initialValue: x,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
            decoration: const InputDecoration(labelText: 'X, мм'),
            onChanged: (value) => x = value,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: y,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
            decoration: const InputDecoration(labelText: 'Y, мм'),
            onChanged: (value) => y = value,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена')),
          FilledButton(onPressed: () {
            final xMm = double.tryParse(x.trim().replaceAll(',', '.'));
            final yMm = double.tryParse(y.trim().replaceAll(',', '.'));
            if (xMm == null || yMm == null ||
                !xMm.isFinite || !yMm.isFinite) {
              ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(
                content: Text('Введите корректные координаты в мм.')));
              return;
            }
            Navigator.pop(dialog, math.Point<double>(xMm, yMm));
          }, child: const Text('Применить')),
        ],
      ),
    );
  }

  Future<void> _editFloorPolygons(FloorPlan floor, RoomFace face) async {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return;
    final existing = WorkFloorPolygonService.roomZones(board, floor, face);
    final zones = List<WorkFloorFinishZone>.of(existing);
    final drawing = <math.Point<double>>[];
    var material = 'tile';
    var editing = false;
    String? selectedZoneId;
    int? selectedVertex;
    String? editProblem;
    double snapMm = 10;
    var nextId = DateTime.now().microsecondsSinceEpoch;
    final baselineTile = room.materials.floorMode == 'tile' ||
        room.materials.floorTile;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, redraw) {
        ({double tileM2, double laminateM2})? summary;
        String? geometryError;
        try {
          summary = WorkFloorPolygonService.areas(floor, face, zones);
        } on ArgumentError catch (error) {
          // Geometry can change after a previously saved surface allocation.
          // Keep the original zones visible for repair, never discard them.
          geometryError = error.message.toString();
        }
        WorkFloorFinishZone? selectedZone;
        for (final zone in zones) {
          if (zone.id == selectedZoneId) {
            selectedZone = zone;
            break;
          }
        }
        if (selectedZone == null ||
            selectedVertex == null ||
            selectedVertex! < 0 ||
            selectedVertex! >= selectedZone.polygon.length) {
          selectedVertex = null;
        }
        return SafeArea(top: false, child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .9,
          child: Column(children: [
            Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            children: [
              Text('Контуры пола: ' + room.name,
                style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('Основное покрытие: ' +
                (baselineTile ? 'плитка' : 'ламинат') + '. ' +
                (editing
                  ? 'Нажмите на вершину готовой зоны и потяните её. '
                    'Недопустимые пересечения отклоняются.'
                  : 'Касаниями добавляйте точки. После трёх вершин '
                    'можно завершить контур.'),
                style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Нарисовать'),
                  selected: !editing,
                  onSelected: (_) => redraw(() {
                    editing = false;
                    selectedZoneId = null;
                    selectedVertex = null;
                    editProblem = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Править вершины'),
                  selected: editing,
                  onSelected: (_) => redraw(() {
                    editing = true;
                    drawing.clear();
                    editProblem = null;
                  }),
                ),
              ]),
              const SizedBox(height: 12),
              AspectRatio(aspectRatio: 1.4, child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final mapper = _PlanMapper([face], Size(
                    constraints.maxWidth, constraints.maxHeight));
                  math.Point<double> canvasPoint(Offset point) {
                    final x = (point.dx - mapper.offsetX) /
                        mapper.scale + mapper.minX;
                    final y = (point.dy - mapper.offsetY) /
                        mapper.scale + mapper.minY;
                    return math.Point<double>(x, y);
                  }

                  ({String zoneId, int vertex})? nearest(Offset point) {
                    ({String zoneId, int vertex})? found;
                    var smallest = 26.0;
                    for (final zone in zones) {
                      for (var i = 0; i < zone.polygon.length; i++) {
                        final projected = mapper.toCanvas(zone.polygon[i]);
                        final distance = (projected - point).distance;
                        if (distance < smallest) {
                          smallest = distance;
                          found = (zoneId: zone.id, vertex: i);
                        }
                      }
                    }
                    return found;
                  }

                  void selectAt(Offset offset) {
                    final nearby = nearest(offset);
                    redraw(() {
                      selectedZoneId = nearby?.zoneId;
                      selectedVertex = nearby?.vertex;
                      editProblem = null;
                    });
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      if (editing) {
                        selectAt(details.localPosition);
                        return;
                      }
                      final point = canvasPoint(details.localPosition);
                      redraw(() => drawing.add(math.Point<double>(
                        (point.x / snapMm).roundToDouble() * snapMm,
                        (point.y / snapMm).roundToDouble() * snapMm,
                      )));
                    },
                    onPanDown: editing
                      ? (details) => selectAt(details.localPosition)
                      : null,
                    onPanStart: editing
                      ? (details) => selectAt(details.localPosition)
                      : null,
                    onPanUpdate: editing ? (details) {
                      if (selectedZoneId == null ||
                          selectedVertex == null) return;
                      try {
                        final result = WorkFloorPolygonService.movedVertex(
                          face, floor, zones,
                          zoneId: selectedZoneId!,
                          vertexIndex: selectedVertex!,
                          position: canvasPoint(details.localPosition),
                          snapMm: snapMm,
                        );
                        redraw(() {
                          zones..clear()..addAll(result);
                          editProblem = null;
                        });
                      } on RangeError {
                        redraw(() {
                          selectedVertex = null;
                          editProblem = 'Вершина больше не существует.';
                        });
                      } on ArgumentError catch (error) {
                        redraw(() => editProblem =
                          error.message.toString());
                      }
                    } : null,
                    child: CustomPaint(
                      painter: _FloorPolygonPlanPainter(
                        face: face, mapper: mapper,
                        zones: zones, drawing: drawing,
                        draftMaterial: material,
                        baseTile: baselineTile,
                        editing: editing,
                        selectedZoneId: selectedZoneId,
                        selectedVertexIndex: selectedVertex),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              )),
              const SizedBox(height: 12),
              Text(editing ? 'Материал выбранной зоны' : 'Материал новой зоны',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              Wrap(spacing: 8, children: [
                for (final entry in const [
                  ('tile', 'Плитка'),
                  ('laminate', 'Ламинат'),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: editing
                      ? selectedZone?.material == entry.$1
                      : material == entry.$1,
                    onSelected: editing ? (selectedZone == null
                      ? null : (_) {
                        final id = selectedZone!.id;
                        try {
                          final changed =
                            WorkFloorPolygonService.changedMaterial(
                              face, floor, zones,
                              zoneId: id, material: entry.$1);
                          redraw(() {
                            zones..clear()..addAll(changed);
                            editProblem = null;
                          });
                        } on ArgumentError catch (error) {
                          redraw(() =>
                            editProblem = error.message.toString());
                        }
                      }) : (_) => redraw(() => material = entry.$1),
                  ),
              ]),
              if (!editing) ...[
                Text('Точек: ' + drawing.length.toString(),
                  style: const TextStyle(fontSize: 12, color: _muted)),
                Wrap(spacing: 6, runSpacing: 5, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Убрать точку'),
                    onPressed: drawing.isEmpty ? null :
                      () => redraw(() => drawing.removeLast()),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Сбросить контур'),
                    onPressed: drawing.isEmpty ? null :
                      () => redraw(drawing.clear),
                  ),
                ]),
              ] else ...[
                const SizedBox(height: 5),
                Text('Шаг привязки координат',
                  style: const TextStyle(color: _muted, fontSize: 12)),
                Wrap(spacing: 7, children: [
                  for (final step in [10.0, 50.0, 100.0])
                    ChoiceChip(
                      label: Text(step.round().toString() + ' мм'),
                      selected: snapMm == step,
                      onSelected: (_) => redraw(() => snapMm = step),
                    ),
                ]),
                if (selectedZone != null)
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    for (var index = 0;
                        index < selectedZone.polygon.length; index++)
                      ChoiceChip(
                        label: Text('Точка ' + (index + 1).toString(),
                          style: const TextStyle(fontSize: 11)),
                        selected: selectedVertex == index,
                        onSelected: (_) =>
                          redraw(() => selectedVertex = index),
                      ),
                  ]),
                if (selectedZone != null && selectedVertex != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Вершина ' +
                      (selectedVertex! + 1).toString() +
                      ': X ' + selectedZone.polygon[selectedVertex!].x
                        .round().toString() +
                      ' мм, Y ' + selectedZone.polygon[selectedVertex!].y
                        .round().toString() + ' мм'),
                    trailing: TextButton(
                      child: const Text('Ввести X/Y'),
                      onPressed: () async {
                        final id = selectedZone!.id;
                        final vertex = selectedVertex!;
                        final current = selectedZone.polygon[vertex];
                        final position =
                          await _askFloorVertexPosition(current);
                        if (position == null || !sheet.mounted) return;
                        try {
                          final updated =
                            WorkFloorPolygonService.movedVertex(
                              face, floor, zones,
                              zoneId: id, vertexIndex: vertex,
                              position: position,
                              snapMm: 1,
                            );
                          redraw(() {
                            zones..clear()..addAll(updated);
                            editProblem = null;
                          });
                        } on ArgumentError catch (error) {
                          redraw(() =>
                            editProblem = error.message.toString());
                        }
                      },
                    ),
                  )
                else
                  const Text('Нажмите на вершину зоны на плане.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                if (editProblem != null)
                  Text(editProblem!,
                    style: const TextStyle(color: _peach, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Text('Готовые зоны: ' + zones.length.toString(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < zones.length; i++)
                ListTile(
                  dense: true,
                  title: Text('Зона ' + (i + 1).toString() +
                    ' · ' + (zones[i].material == 'tile'
                      ? 'Плитка' : 'Ламинат')),
                  subtitle: Text(
                    WorkFloorPolygonService.area(zones[i].polygon)
                      .toStringAsFixed(2) + ' м²',
                    style: const TextStyle(color: _muted, fontSize: 11)),
                  trailing: IconButton(
                    tooltip: 'Удалить зону',
                    icon: const Icon(Icons.delete_outline, color: _peach),
                    onPressed: () => redraw(() {
                      if (zones[i].id == selectedZoneId) {
                        selectedZoneId = null;
                        selectedVertex = null;
                      }
                      zones.removeAt(i);
                    }),
                  ),
                  onTap: () => redraw(() {
                    editing = true;
                    drawing.clear();
                    selectedZoneId = zones[i].id;
                    selectedVertex = null;
                    editProblem = null;
                  }),
                ),
              const Divider(color: _edge),
              if (geometryError != null)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Проверьте зоны: ' + geometryError,
                    style: const TextStyle(color: _peach, fontSize: 12)))
              else if (summary != null)
                Row(children: [
                  _stat('Плитка',
                    summary.tileM2.toStringAsFixed(2) + ' м²', tint: _blue),
                  const SizedBox(width: 8),
                  _stat('Ламинат',
                    summary.laminateM2.toStringAsFixed(2) + ' м²'),
                ]),
              const SizedBox(height: 8),
              Text('Всего: ' + face.areaM2.toStringAsFixed(2) +
                ' м². Сохранение заменит прежнюю прямую линию '
                'разделения покрытия в этой комнате.',
                style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 12),
            ],
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
            child: Row(children: [
              Expanded(child:
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text('Завершить зону'),
                  onPressed: editing || drawing.length < 3
                    ? null : () {
                    final candidate = WorkFloorFinishZone(
                      id: 'zone_' + (nextId++).toString(),
                      floorId: floor.id, roomId: room.id,
                      material: material, polygon: drawing);
                    try {
                      WorkFloorPolygonService.validate(
                        face, floor, [...zones, candidate]);
                    } on ArgumentError catch (error) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        SnackBar(content: Text(error.message.toString())));
                      return;
                    }
                    redraw(() {
                      zones.add(candidate);
                      drawing.clear();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child:
              FilledButton(
                onPressed: drawing.isNotEmpty || summary == null
                    ? null : () {
                  final takeoff = summary;
                  if (takeoff == null) return;
                  try {
                    WorkFloorPolygonService.save(
                      board, floor, face, zones);
                  } on ArgumentError catch (error) {
                    ScaffoldMessenger.of(sheet).showSnackBar(
                      SnackBar(content: Text(error.message.toString())));
                    return;
                  }
                  final refreshed =
                    WorkFloorSurfaceService.refreshUnstarted(
                      board, floor, face);
                  board.log('Зоны напольных покрытий: ' + room.name +
                    ', участков: ' + zones.length.toString() +
                    ', плитка ' + takeoff.tileM2.toStringAsFixed(2) +
                    ' м², ламинат ' +
                    takeoff.laminateM2.toStringAsFixed(2) +
                    ' м²; проверено задач: ' + refreshed.toString());
                  Navigator.pop(sheet, true);
                },
                child: const Text('Сохранить зоны'),
              ),
              ),
            ]),
          ),
        ]),
        ));
      }),
    );
    if (saved == true) await _save();
  }

  Future<void> _editFloorFinishes(FloorPlan floor, RoomFace face) async {
    final room = floor.roomMetaByKey(face.key);
    if (room == null) return;
    final previous = WorkFloorSurfaceService.selected(board, floor, face);
    var axis = previous?.axis ?? 'x';
    final initialBounds = WorkFloorSurfaceService.bounds(face, axis);
    var cut = previous?.cutMm ??
        (initialBounds.min + initialBounds.max) / 2;
    var tileBefore = previous?.tileBeforeCut ?? true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, redraw) {
        final limits = WorkFloorSurfaceService.bounds(face, axis);
        cut = cut.clamp(limits.min, limits.max).toDouble();
        final allocation = WorkFloorFinishSplit(
          floorId: floor.id, roomId: room.id,
          axis: axis, cutMm: cut,
          tileBeforeCut: tileBefore,
        );
        final areas = WorkFloorSurfaceService.areas(
          board, floor, face, preview: allocation);
        return SafeArea(top: false, child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .86,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            children: [
              Text('Покрытия пола: ' + room.name,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Разделите пол прямой линией. Светлый участок '
                'показывает ламинат, синий участок — плитку. '
                'Объёмы считаются по внутреннему контуру комнаты.',
                style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 13),
              AspectRatio(aspectRatio: 1.45, child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final mapper = _PlanMapper([face], Size(
                    constraints.maxWidth, constraints.maxHeight));
                  return GestureDetector(
                    onTapDown: (details) {
                      final tapped = details.localPosition;
                      final x = (tapped.dx - mapper.offsetX) /
                          mapper.scale + mapper.minX;
                      final y = (tapped.dy - mapper.offsetY) /
                          mapper.scale + mapper.minY;
                      redraw(() {
                        cut = (axis == 'x' ? x : y)
                          .clamp(limits.min, limits.max).toDouble();
                      });
                    },
                    child: CustomPaint(
                      painter: _FloorFinishPlanPainter(
                        face: face, mapper: mapper,
                        split: allocation),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              )),
              const SizedBox(height: 12),
              const Text('Направление разделения',
                style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Слева / справа'),
                  selected: axis == 'x',
                  onSelected: (_) => redraw(() {
                    axis = 'x';
                    final b = WorkFloorSurfaceService.bounds(face, axis);
                    cut = (b.min + b.max) / 2;
                  })),
                ChoiceChip(label: const Text('Сверху / снизу'),
                  selected: axis == 'y',
                  onSelected: (_) => redraw(() {
                    axis = 'y';
                    final b = WorkFloorSurfaceService.bounds(face, axis);
                    cut = (b.min + b.max) / 2;
                  })),
              ]),
              const SizedBox(height: 6),
              Text('Линия: ' + cut.round().toString() + ' мм',
                style: const TextStyle(fontSize: 12, color: _muted)),
              Slider(
                min: limits.min, max: limits.max,
                divisions: math.max(1,
                  ((limits.max - limits.min) / 100).round()),
                value: cut.clamp(limits.min, limits.max).toDouble(),
                activeColor: _peach,
                onChanged: (value) => redraw(() => cut = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Плитка до линии'),
                subtitle: Text(axis == 'x'
                  ? 'Включено: слева · Выключено: справа'
                  : 'Включено: сверху · Выключено: снизу',
                  style: const TextStyle(fontSize: 11, color: _muted)),
                value: tileBefore,
                onChanged: (yes) =>
                  redraw(() => tileBefore = yes),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _stat('Плитка',
                  areas.tileM2.toStringAsFixed(2) + ' м²', tint: _blue),
                const SizedBox(width: 8),
                _stat('Ламинат',
                  areas.laminateM2.toStringAsFixed(2) + ' м²'),
              ]),
              const SizedBox(height: 8),
              Text('Общая площадь: ' + face.areaM2.toStringAsFixed(2) +
                ' м². Переход покрытий рассчитывается по выбранной линии.',
                style: const TextStyle(fontSize: 11, color: _muted)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  try {
                    WorkFloorSurfaceService.save(
                      board, floor, face, allocation);
                  } on ArgumentError catch (error) {
                    ScaffoldMessenger.of(sheet).showSnackBar(
                      SnackBar(content: Text(error.message.toString())));
                    return;
                  }
                  final revised =
                    WorkFloorSurfaceService.refreshUnstarted(
                      board, floor, face);
                  board.log('Распределение покрытий: ' + room.name +
                    ', плитка ' + areas.tileM2.toStringAsFixed(2) +
                    ' м², ламинат ' +
                    areas.laminateM2.toStringAsFixed(2) +
                    ' м²; проверено задач: ' + revised.toString());
                  Navigator.pop(sheet, true);
                },
                child: const Text('Сохранить зоны покрытия'),
              ),
            ],
          ),
        ));
      }),
    );
    if (saved == true) await _save();
  }

  Future<void> _calendarSettings() async {
    var weekdaysOnly = board.calendar.weekdaysOnly;
    final daysOff = {...board.calendar.daysOff};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
        Future<void> addOffDay() async {
          final picked = await showDatePicker(
            context: sheet,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            update(() => daysOff.add(WorkCalendar.key(picked)));
          }
        }
        final sorted = daysOff.toList()..sort();
        return SafeArea(top: false, child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .82),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Рабочий календарь',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Выберите расписание объекта. '
                  'Праздники не назначаются автоматически.',
                  style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Пятидневная неделя (5/2)'),
                  subtitle: Text(weekdaysOnly
                    ? 'Рабочие дни: понедельник–пятница'
                    : 'Рабочие дни: понедельник–воскресенье',
                    style: const TextStyle(fontSize: 11, color: _muted)),
                  value: weekdaysOnly,
                  onChanged: (value) => update(() => weekdaysOnly = value),
                  activeTrackColor: _peach,
                ),
                const Divider(color: _edge),
                Row(children: [
                  const Expanded(child: Text('Дополнительные выходные',
                    style: TextStyle(fontWeight: FontWeight.w700))),
                  TextButton.icon(
                    onPressed: addOffDay,
                    icon: const Icon(Icons.event_busy_outlined, size: 17),
                    label: const Text('Добавить'),
                  ),
                ]),
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Исключений пока нет.',
                      style: TextStyle(color: _muted, fontSize: 12)),
                  )
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final day in sorted)
                      InputChip(
                        label: Text(day, style: const TextStyle(fontSize: 11)),
                        onDeleted: () => update(() => daysOff.remove(day)),
                        deleteIconColor: _peach,
                      ),
                  ]),
                const SizedBox(height: 14),
                const Text('Изменение календаря не переносит существующие '
                  'задачи автоматически. Для пересчёта используйте '
                  '«Сроки и зависимости» в карточке работы.',
                  style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet, true),
                  child: const Text('Сохранить календарь'),
                ),
              ],
            )),
          ),
        ));
      }),
    );
    if (saved != true) return;
    board.calendar.weekdaysOnly = weekdaysOnly;
    board.calendar.daysOff
      ..clear()
      ..addAll(daysOff);
    board.log('Обновлён рабочий календарь объекта');
    await _save();
  }

  List<Widget> _calendarContent() {
    final actual = board.actualProgress;
    final due = board.tasks.isEmpty ? null :
        board.tasks.map((e) => e.finish).reduce((a, b) => a.isAfter(b) ? a : b);
    return [
      _card(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Сдача объекта', style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 7),
          Text(due == null ? 'График не задан' : _date(due),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(due == null ? 'Создайте первую работу' : 'Плановая дата завершения',
            style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        SizedBox(width: 72, height: 72, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(
            value: actual, strokeWidth: 6,
            backgroundColor: _edge, valueColor: const AlwaysStoppedAnimation(_peach))),
          Text('${(actual * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ])),
      ])),
      _delayedNotice(),
      _workloadPanel(),
      _generatorPanel(),
      _wallFinishEntry(),
      _floorFinishEntry(),
      _floorPolygonEntry(),
      _heading('План работ', trailing: TextButton.icon(
        onPressed: _calendarSettings,
        icon: const Icon(Icons.calendar_month_outlined, size: 17),
        label: Text(board.calendar.weekdaysOnly ? '5/2' : '7/7'),
      )),
      Row(children: [
        for (final entry in ['Неделя', 'Месяц', 'Гант'].asMap().entries) ...[
          Expanded(child: _segment(entry.value, _calendar == entry.key,
            () => setState(() => _calendar = entry.key))),
          if (entry.key < 2) const SizedBox(width: 7),
        ],
      ]),
      const SizedBox(height: 14),
      if (_calendar == 0) _weekSelector(),
      if (_calendar == 1) _monthSelector(),
      if (_calendar == 2) _gantt(),
      if (_calendar != 2) ...[
        _heading('Работы на ' + _date(_selected)),
        ..._tasksOnDate(),
      ],
      _card(child: Row(children: [
        const Icon(Icons.link_outlined, color: _peach),
        const SizedBox(width: 10),
        const Expanded(child: Text('Зависимости учитываются при начале работ. '
          'Следующие этапы переносятся по рабочему календарю после подтверждения.',
          style: TextStyle(fontSize: 12, color: _muted))),
        Text('${board.tasks.where((t) => t.predecessorId != null).length}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ])),
    ];
  }

  Widget _weekSelector() {
    final monday = _selected.subtract(Duration(days: _selected.weekday - 1));
    return Column(children: [
      Row(children: [
        IconButton(onPressed: () => setState(() =>
          _selected = _selected.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(_date(monday) + ' — ' +
          _date(monday.add(const Duration(days: 6))), textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(onPressed: () => setState(() =>
          _selected = _selected.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: List.generate(7, (i) {
        final d = monday.add(Duration(days: i));
        final active = _day(d) == _day(_selected);
        final isWorking = board.calendar.isWorkday(d);
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: () => setState(() => _selected = d),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? _peach : _panel,
                border: Border.all(color: active ? _peach : _edge),
                borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(['Пн','Вт','Ср','Чт','Пт','Сб','Вс'][i],
                  style: TextStyle(color: active ? _bg :
                    (isWorking ? _muted : _red.withValues(alpha: .7)), fontSize: 10)),
                const SizedBox(height: 4),
                Text('${d.day}', style: TextStyle(color: active ? _bg : Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                CircleAvatar(radius: 2.5,
                  backgroundColor: (widget.embedded
                  ? _visibleWorks : board.tasks).any((t) =>
                    !d.isBefore(_day(t.start)) && !d.isAfter(_day(t.finish)))
                    ? (active ? _bg : _peach) : Colors.transparent),
              ]),
            ),
          ),
        ));
      })),
    ]);
  }

  Widget _monthSelector() {
    final first = DateTime(_selected.year, _selected.month, 1);
    final lead = first.weekday - 1;
    final days = DateTime(first.year, first.month + 1, 0).day;
    return _card(child: Column(children: [
      Row(children: [
        IconButton(onPressed: () => setState(() =>
          _selected = DateTime(_selected.year, _selected.month - 1, 1)),
          icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text('${_selected.month.toString().padLeft(2,'0')}.${_selected.year}',
          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(onPressed: () => setState(() =>
          _selected = DateTime(_selected.year, _selected.month + 1, 1)),
          icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].map(
        (s) => Expanded(child: Center(child: Text(s,
          style: const TextStyle(color: _muted, fontSize: 11))))).toList()),
      const SizedBox(height: 7),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, childAspectRatio: .82, crossAxisSpacing: 3, mainAxisSpacing: 3),
        itemCount: ((lead + days + 6) ~/ 7) * 7,
        itemBuilder: (context, index) {
          final day = index - lead + 1;
          if (day < 1 || day > days) return const SizedBox.shrink();
          final date = DateTime(first.year, first.month, day);
          final selected = _day(date) == _day(_selected);
          final busy = (widget.embedded
            ? _visibleWorks : board.tasks).any((t) =>
            !date.isBefore(_day(t.start)) && !date.isAfter(_day(t.finish)));
          return InkWell(onTap: () => setState(() => _selected = date),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? _peach : const Color(0xFF252933),
                borderRadius: BorderRadius.circular(9)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$day', style: TextStyle(color: selected ? _bg : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 4),
                CircleAvatar(radius: 2.5,
                  backgroundColor: busy ? (selected ? _bg : _blue) : Colors.transparent),
              ]),
            ),
          );
        },
      ),
    ]));
  }

  Widget _gantt() {
    final tasks = <WorkTask>[...
      (widget.embedded ? _visibleWorks : board.tasks)]
      ..sort((a, b) => a.start.compareTo(b.start));
    if (tasks.isEmpty) return _empty('Нет работ для диаграммы Ганта.');

    int daysBetween(DateTime a, DateTime b) =>
        DateTime.utc(b.year, b.month, b.day)
            .difference(DateTime.utc(a.year, a.month, a.day)).inDays;

    final starts = tasks.expand((task) =>
        [_day(task.start), _day(task.baselineStart)]);
    final finishes = tasks.expand((task) =>
        [_day(task.finish), _day(task.baselineFinish)]);
    final firstDay = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDay = finishes.reduce((a, b) => a.isAfter(b) ? a : b);
    final dayCount = math.max(14, daysBetween(firstDay, lastDay) + 1);
    const dayWidth = 25.0;

    return _card(padding: const EdgeInsets.all(11), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Сравнение графиков',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        const Wrap(spacing: 12, runSpacing: 5, children: [
          _Legend('Текущий', _blue),
          _Legend('Исходный', _muted),
          _Legend('Выполнение', _green),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 104, child: Column(children: [
            const SizedBox(height: 28),
            for (final task in tasks)
              InkWell(
                onTap: () => _taskDetail(task),
                child: SizedBox(height: 56, child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(task.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                )),
              ),
          ])),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: dayCount * dayWidth, child: Column(children: [
              SizedBox(height: 28, child: Row(children: [
                for (var i = 0; i < dayCount; i++)
                  SizedBox(width: dayWidth, child: Center(
                    child: Text(firstDay.add(Duration(days: i)).day.toString(),
                      style: TextStyle(
                        color: firstDay.add(Duration(days: i)).day == 1
                            ? _peach : _muted,
                        fontSize: 10,
                      )),
                  )),
              ])),
              for (final task in tasks)
                SizedBox(height: 56, child: Stack(children: [
                  Positioned(
                    top: 7,
                    left: dayWidth * daysBetween(firstDay, task.baselineStart),
                    width: dayWidth *
                        (daysBetween(task.baselineStart, task.baselineFinish) + 1),
                    height: 15,
                    child: DecoratedBox(decoration: BoxDecoration(
                      color: _muted.withValues(alpha: .09),
                      border: Border.all(color: _muted.withValues(alpha: .85)),
                      borderRadius: BorderRadius.circular(4),
                    )),
                  ),
                  Positioned(
                    top: 26,
                    left: dayWidth * daysBetween(firstDay, task.start),
                    width: dayWidth * (daysBetween(task.start, task.finish) + 1),
                    height: 19,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(children: [
                        SizedBox.expand(child: ColoredBox(
                          color: _statusColor(task).withValues(alpha: .34))),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: task.progress,
                          child: ColoredBox(color: _statusColor(task)),
                        ),
                      ]),
                    ),
                  ),
                ])),
            ])),
          )),
        ]),
      ],
    ));
  }

  List<Widget> _tasksOnDate() {
    final tasks = board.tasks.where((t) =>
      !_selected.isBefore(_day(t.start)) && !_selected.isAfter(_day(t.finish))).toList();
    if (tasks.isEmpty) return [_empty('На выбранный день работ нет.')];
    return tasks.map(_taskCard).toList();
  }

  Widget _empty(String message) => _card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message, textAlign: TextAlign.center,
      style: const TextStyle(color: _muted))));

  Widget _taskCard(WorkTask t) => InkWell(
    onTap: () => _taskDetail(t),
    borderRadius: BorderRadius.circular(17),
    child: _card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 4, height: 84,
        decoration: BoxDecoration(color: _statusColor(t), borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.title, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text((t.roomName.isEmpty ? 'Весь объект' : t.roomName) +
          ' · ' + _date(t.start) + '–' + _date(t.finish),
          style: const TextStyle(fontSize: 11, color: _muted)),
        const SizedBox(height: 11),
        _meter(t.progress, color: _statusColor(t)),
        const SizedBox(height: 5),
        Text(_number(t.done) + ' из ' + _number(t.quantity) + ' ' + t.unit +
          ' · ${(t.progress * 100).round()}%',
          style: const TextStyle(fontSize: 11, color: _muted)),
      ])),
      const SizedBox(width: 7),
      Text(_status(t), style: TextStyle(color: _statusColor(t), fontSize: 10)),
    ])),
  );

  List<Widget> _controlContent() {
    final planned = board.plannedProgress(DateTime.now());
    final actual = board.actualProgress;
    final issues = board.issues.where((e) => e.open).length;
    final accepted = board.tasks.where((t) => t.fullyAccepted).length;
    return [
      _heading('Ход выполнения'),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Общий прогресс',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text('${((actual - planned) * 100).round()} п.п.',
            style: TextStyle(color: actual < planned ? _red : _green,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('По графику', style: TextStyle(color: _muted)),
          Text('${(planned * 100).round()}%'),
        ]),
        const SizedBox(height: 5),
        _meter(planned, color: _blue),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Фактически', style: TextStyle(color: _muted)),
          Text('${(actual * 100).round()}%'),
        ]),
        const SizedBox(height: 5),
        _meter(actual),
      ])),
      Row(children: [
        _stat('Принято', '$accepted'),
        const SizedBox(width: 8),
        _stat('Замечания', '$issues', tint: _red),
        const SizedBox(width: 8),
        _stat('На приёмке', '${board.tasks.where((t)=>t.complete && !t.fullyAccepted).length}',
          tint: _amber),
      ]),
      _delayedNotice(),
      _workloadPanel(),
      _heading('Контроль по помещениям', trailing:
        TextButton.icon(onPressed: _activeFloor == null ? null : _fullPlan,
          icon: const Icon(Icons.open_in_full, size: 16),
          label: const Text('2D-план'))),
      if (widget.project.floors.length > 1)
        _card(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            isExpanded: true,
            value: _activeFloor?.id,
            dropdownColor: _panel,
            icon: const Icon(Icons.keyboard_arrow_down, color: _peach),
            items: [
              for (final floor in widget.project.floors)
                DropdownMenuItem<String>(
                  value: floor.id,
                  child: Row(children: [
                    const Icon(Icons.layers_outlined, color: _peach, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(floor.name, maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
                  ]),
                ),
            ],
            onChanged: (floorId) => setState(() {
              _selectedFloorId = floorId;
              _roomId = null;
            }),
          ))),
      if (_activeFloor == null)
        _empty('Сначала создайте этаж и помещения в «Замере».')
      else
        _card(padding: const EdgeInsets.all(9), child: Column(children: [
          _PlanView(
            floor: _activeFloor!,
            selected: _roomId,
            onSelect: (id) => setState(() => _roomId = id),
            colorFor: _roomColor,
          ),
          const SizedBox(height: 8),
          const Wrap(spacing: 12, runSpacing: 6, children: [
            _Legend('Принято', _green), _Legend('В работе', _blue),
            _Legend('Проблемы', _red), _Legend('Приёмка', _amber),
            _Legend('В плане', _muted),
          ]),
        ])),
      if (_roomId != null)
        _card(child: Row(children: [
          Expanded(child: Text(rooms.where((r) => r.id == _roomId)
            .map((r)=>r.name).firstOrNull ?? 'Помещение',
            style: const TextStyle(fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => setState(() => _roomId = null),
            child: const Text('Все комнаты')),
        ])),
      _heading('Журнал контроля'),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final entry in ['Работы', 'Замечания', 'Приёмка', 'Журнал'].asMap().entries)
          Padding(padding: const EdgeInsets.only(right: 7),
            child: _segment(entry.value, _control == entry.key,
              () => setState(() => _control = entry.key))),
      ])),
      const SizedBox(height: 14),
      ..._controlRows(),
    ];
  }

  Widget _stat(String caption, String value, {Color tint = _peach}) =>
    Expanded(child: _card(child: Column(children: [
      Text(value, style: TextStyle(fontSize: 23, color: tint,
        fontWeight: FontWeight.w800)),
      Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: _muted)),
    ])));

  List<Widget> _controlRows() {
    final tasks = board.tasks.where((t) =>
      (t.floorId == null || t.floorId == _activeFloor?.id) &&
      (_roomId == null || t.roomId == _roomId)).toList();
    if (_control == 0) return tasks.isEmpty ?
      [_empty('Нет работ в выбранной зоне.')] : tasks.map(_taskCard).toList();
    if (_control == 1) {
      final issues = board.issues.where((e) =>
        _roomId == null || e.roomId == _roomId).toList();
      return issues.isEmpty ? [_empty('Замечаний пока нет.')] :
        issues.map((e) => _card(child: ListTile(
          title: Text(e.title),
          subtitle: Text((e.roomName.isEmpty ? 'Объект' : e.roomName) +
            ' · ' + (e.open ? 'Открыто' : 'Закрыто')),
          trailing: e.open ? TextButton(
            onPressed: () async {
              setState(() => e.closedAt = DateTime.now());
              board.log('Замечание устранено: ' + e.title);
              await _save();
            },
            child: const Text('Закрыть'),
          ) : const Icon(Icons.check_circle_outline, color: _green),
        ))).toList();
    }
    if (_control == 2) {
      final pending = tasks.where((t)=>t.complete && !t.fullyAccepted).toList();
      return pending.isEmpty ? [_empty('Нет работ, ожидающих приёмки.')] :
        pending.map((t) => _card(child: Column(children: [
          ListTile(title: Text(t.title), subtitle: Text(
            _number(t.done) + ' ' + t.unit + ' · ' + t.roomName)),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => _accept(t),
            child: const Text('Принять выполненный объём'))),
        ]))).toList();
    }
    final events = board.events.where((e) =>
      _roomId == null || tasks.any((t) => t.id == e.taskId)).toList();
    return events.isEmpty ? [_empty('Журнал пока пуст.')] :
      events.map((e)=>_card(child: ListTile(
        leading: const Icon(Icons.history, color: _peach),
        title: Text(e.text),
        subtitle: Text(e.timestamp.toLocal().toString().substring(0,16)),
      ))).toList();
  }

  void _fullPlan() {
    final floor = _activeFloor;
    if (floor == null) return;
    showDialog<void>(context: context, builder: (_) => Dialog(
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.all(12),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('План объекта',
              style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          ]),
          SizedBox(height: 440,
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.all(24),
              child: _PlanView(
                floor: floor,
                selected: _roomId, onSelect: (id) {
              setState(() => _roomId = id);
              Navigator.pop(context);
            }, colorFor: _roomColor)),
          ),
        ]))));
  }

  void _quickActions() {
    showModalBottomSheet<void>(context: context,
      backgroundColor: _panel, showDragHandle: true,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.add_task, color: _peach),
          title: const Text('Добавить работу'),
          onTap: () { Navigator.pop(context); _addTask(); }),
        ListTile(leading: const Icon(Icons.auto_awesome_outlined, color: _peach),
          title: const Text('Сформировать работы по планировке'),
          onTap: () { Navigator.pop(context); _generateTasks(); }),
        ListTile(leading: const Icon(Icons.note_add_outlined, color: _peach),
          title: const Text('Добавить замечание'),
          onTap: () { Navigator.pop(context); _addIssue(); }),
        ListTile(leading: const Icon(Icons.checklist_outlined, color: _peach),
          title: const Text('Приёмка'),
          onTap: () { Navigator.pop(context); setState(()=>_control=2); }),
      ])));
  }

  Future<String?> _pickWorkOperation() async {
    var query = '';
    String? group;
    String? subgroup;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
        final groups = WorkOperationTaxonomy.groups;
        final showGroupList = group == null && query.trim().isEmpty;
        final matches = WorkOperationTaxonomy.search(
          query, group: group, subgroup: subgroup);
        final subgroups = group == null ? <String>[] :
          WorkOperationTaxonomy.subgroups(group!);

        // Section headings are computed from the filtered results. Operations
        // preserve their stable catalogue identity, without modifying phase.
        final rows = <Object>[];
        String? lastGroup, lastSubgroup;
        for (final major in groups) {
          for (final minor in WorkOperationTaxonomy.subgroups(major)) {
            final local = matches.where((op) =>
                WorkOperationTaxonomy.groupOf(op) == major &&
                WorkOperationTaxonomy.subgroupOf(op) == minor);
            for (final op in local) {
              if (lastGroup != major) {
                rows.add('group:' + major);
                lastGroup = major;
                lastSubgroup = null;
              }
              if (lastSubgroup != minor) {
                rows.add('sub:' + minor);
                lastSubgroup = minor;
              }
              rows.add(op);
            }
          }
        }

        return SafeArea(top: false, child: SizedBox(
          height: (MediaQuery.sizeOf(sheet).height -
              MediaQuery.viewInsetsOf(sheet).bottom) * .85,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                if (group != null)
                  IconButton(
                    tooltip: 'К списку групп',
                    icon: const Icon(Icons.arrow_back_ios_new, size: 19),
                    onPressed: () => update(() {
                      group = null;
                      subgroup = null;
                    }),
                  ),
                const Expanded(child: Text('Библиотека работ',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800))),
                Text('${WorkOperationCatalog.all.length} работ',
                  style: const TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextFormField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Поиск по названию или виду работ'),
                onChanged: (text) => update(() {
                  query = text;
                  // Search all groups when typing a query at the top level.
                }),
              )),
            if (!showGroupList) ...[
              SizedBox(height: 43, child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in ['Все', ...groups])
                    Padding(padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(name,
                          style: const TextStyle(fontSize: 11)),
                        selected: (group ?? 'Все') == name,
                        onSelected: (_) => update(() {
                          group = name == 'Все' ? null : name;
                          subgroup = null;
                        }),
                      )),
                ],
              )),
              if (group != null)
                SizedBox(height: 40, child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final name in ['Все подразделы', ...subgroups])
                      Padding(padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(name,
                            style: const TextStyle(fontSize: 11)),
                          selected: (subgroup ?? 'Все подразделы') == name,
                          onSelected: (_) => update(() =>
                            subgroup = name == 'Все подразделы' ? null : name),
                        )),
                  ],
                )),
            ],
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit_note_outlined, color: _peach),
              title: const Text('Создать произвольную работу'),
              onTap: () => Navigator.pop(sheet, '__manual__'),
            ),
            const Divider(height: 1, color: _edge),
            if (showGroupList)
              Expanded(child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (_, index) {
                  final name = groups[index];
                  final count = WorkOperationTaxonomy.inGroup(name).length;
                  final subs = WorkOperationTaxonomy.subgroups(name);
                  return ListTile(
                    title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subs.join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$count',
                        style: const TextStyle(color: _peach,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_right, color: _peach),
                    ]),
                    onTap: () => update(() { group = name; subgroup = null; }),
                  );
                },
              ))
            else ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('Найдено: ${matches.length}',
                    style: const TextStyle(fontSize: 11, color: _muted)))),
              Expanded(child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, index) {
                  final item = rows[index];
                  if (item is String) {
                    final major = item.startsWith('group:');
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16, major ? 13 : 17, 16, 4),
                      child: Text(item.substring(major ? 6 : 4),
                        style: TextStyle(
                          fontSize: major ? 14 : 12,
                          color: major ? _peach : _muted,
                          fontWeight: FontWeight.w700)),
                    );
                  }
                  final op = item as WorkOperation;
                  final unit = switch (op.basis) {
                    WorkQuantityBasis.package => 'шт/компл.',
                    WorkQuantityBasis.skirting => 'м',
                    _ => 'м²',
                  };
                  return ListTile(
                    title: Text(op.title, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                    subtitle: Text('$unit · '
                      '${op.hoursPerUnit} чел·ч/ед. (ориентир)',
                      style: const TextStyle(fontSize: 11, color: _muted)),
                    trailing: const Icon(Icons.chevron_right, color: _peach),
                    onTap: () => Navigator.pop(sheet, op.code),
                  );
                },
              )),
            ],
          ]),
        ));
      }),
    );
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final amount = TextEditingController(text: '1');
    final hours = TextEditingController(text: '8');
    final assignee = TextEditingController();
    var start = _selected, finish = _selected, unit = 'м²';
    String? roomId = _roomId;
    String? predecessorId;
    String? operationCode;
    final coStageSelection = <String>{};
    var lagDays = 0;
    var showAdvanced = false;
    void refillFromGeometry() {
      final op = WorkOperationCatalog.byCode[operationCode];
      if (op == null) return;
      unit = switch (op.basis) {
        WorkQuantityBasis.skirting => 'м',
        WorkQuantityBasis.package => 'шт',
        _ => 'м²',
      };
      if (op.basis == WorkQuantityBasis.package) {
        amount.text = '1';
        hours.text = op.hoursPerUnit.toStringAsFixed(1);
        return;
      }
      if (roomId == null) return;
      for (final floor in widget.project.floors) {
        for (final face in GeometryService.roomFaces(floor)) {
          if (floor.roomMetaByKey(face.key)?.id != roomId) continue;
          final count = WorkSurfaceService.finishCodes.contains(op.code)
            ? WorkSurfaceService.areaForCode(
                board, floor, face, op.code)
            : WorkFloorSurfaceService.affectedCodes.contains(op.code)
              ? WorkFloorSurfaceService.quantityFor(
                  board, floor, face, op.code)
            : switch (op.basis) {
              WorkQuantityBasis.floorArea || WorkQuantityBasis.ceilingArea =>
                face.areaM2,
              WorkQuantityBasis.wallArea =>
                GeometryService.roomNetWallAreaM2(floor, face),
              WorkQuantityBasis.skirting =>
                GeometryService.roomSkirtingM(floor, face),
              WorkQuantityBasis.package => 1.0,
            };
          if (count.isFinite && count > 0) {
            amount.text = count.toStringAsFixed(2);
            hours.text = (count * op.hoursPerUnit).toStringAsFixed(1);
          }
          return;
        }
      }
    }
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: _panel,
      builder: (context) => StatefulBuilder(builder: (context, state) {
        Future<void> choose(bool beginning) async {
          final chosen = await showDatePicker(context: context,
            firstDate: DateTime(2020), lastDate: DateTime(2100),
            initialDate: board.calendar.nextWorkday(beginning ? start : finish),
            selectableDayPredicate: board.calendar.isWorkday);
          if (chosen != null) state(() {
            if (beginning) { start = chosen; if (finish.isBefore(start)) finish = start; }
            else { finish = chosen; }
          });
        }
        return Padding(padding: EdgeInsets.fromLTRB(
          18, 8, 18, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новая работа', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_outlined, color: _peach),
                label: Text(operationCode == null
                  ? 'Выбрать операцию из библиотеки'
                  : (WorkOperationCatalog.byCode[operationCode]?.title ??
                    'Произвольная работа'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                onPressed: () async {
                  final code = await _pickWorkOperation();
                  if (code == null || !context.mounted) return;
                  state(() {
                    operationCode = code == '__manual__' ? null : code;
                    if (operationCode != null) {
                      title.text = WorkOperationCatalog.byCode[operationCode]!.title;
                      refillFromGeometry();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Название работы')),
              const SizedBox(height: 11),
              DropdownButtonFormField<String?>(
                initialValue: roomId,
                decoration: const InputDecoration(labelText: 'Помещение'),
                items: [
                  const DropdownMenuItem<String?>(value:null, child: Text('Весь объект')),
                  ...rooms.map((r) => DropdownMenuItem<String?>(
                    value: r.id, child: Text(r.name))),
                ],
                onChanged: (v) => state(() {
                  roomId = v;
                  coStageSelection.clear();
                  refillFromGeometry();
                }),
              ),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Объём'))),
                const SizedBox(width: 8),
                SizedBox(width: 94, child: DropdownButtonFormField<String>(
                  key: ValueKey(unit),
                  initialValue: unit,
                  items: ['м²','м','шт','м³'].map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v)=>state(()=>unit=v ?? 'м²'))),
              ]),
              if (roomId != null && operationCode != null)
                TextButton.icon(
                  onPressed: () => state(refillFromGeometry),
                  icon: const Icon(Icons.architecture),
                  label: const Text('Пересчитать объём по геометрии помещения'),
                )
              else if (roomId != null) TextButton.icon(
                onPressed: () {
                  for (final floor in widget.project.floors) {
                    for (final face in GeometryService.roomFaces(floor)) {
                      if (floor.roomMetaByKey(face.key)?.id == roomId) {
                        amount.text = face.areaM2.toStringAsFixed(2);
                        state(() => unit = 'м²');
                        return;
                      }
                    }
                  }
                },
                icon: const Icon(Icons.architecture),
                label: const Text('Подставить площадь пола из модели'),
              ),
              TextButton.icon(
                key: const ValueKey('works-more-details'),
                onPressed: () => state(() => showAdvanced = !showAdvanced),
                icon: Icon(showAdvanced
                    ? Icons.expand_less : Icons.tune_rounded, size: 17),
                label: Text(showAdvanced
                    ? 'Скрыть дополнительные параметры'
                    : 'Дополнительные параметры'),
              ),
              if (showAdvanced) ...[
              TextField(controller: hours,
                keyboardType: const TextInputType.numberWithOptions(decimal:true),
                decoration: const InputDecoration(labelText: 'Трудоёмкость, чел·ч')),
              const SizedBox(height: 11),
              TextField(controller: assignee,
                decoration: const InputDecoration(labelText: 'Исполнитель / бригада')),
              if (board.tasks.isNotEmpty) ...[
                const SizedBox(height: 11),
                DropdownButtonFormField<String?>(
                  initialValue: predecessorId,
                  decoration: const InputDecoration(labelText: 'Предыдущая работа'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null, child: Text('Нет зависимости')),
                    ...board.tasks.map((task) => DropdownMenuItem<String?>(
                      value: task.id,
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (value) => state(() {
                    predecessorId = value;
                    if (value == null) lagDays = 0;
                  }),
                ),
                if (predecessorId != null) ...[
                  const SizedBox(height: 11),
                  DropdownButtonFormField<int>(
                    initialValue: lagDays,
                    decoration: const InputDecoration(
                      labelText: 'Технологическая пауза, календ. дней'),
                    items: [0, 1, 2, 3, 5, 7, 14]
                      .map((d) => DropdownMenuItem(
                        value: d, child: Text('$d дн.'))).toList(),
                    onChanged: (value) => state(() => lagDays = value ?? 0),
                  ),
                ],
              ],
              if (board.tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Созависимые этапы (выполняются параллельно)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const Text('Приёмка всех связанных работ обязательна '
                  'для запуска следующих этапов.',
                  style: TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 3, children: [
                  for (final other in board.tasks.where((item) =>
                      item.roomId == roomId &&
                      (roomId != null || item.floorId == _activeFloor?.id)))
                    FilterChip(
                      label: Text(other.title, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      selected: coStageSelection.contains(other.id),
                      onSelected: (yes) => state(() {
                        if (yes) {
                          coStageSelection.add(other.id);
                        } else {
                          coStageSelection.remove(other.id);
                        }
                      }),
                    ),
                ]),
              ],
              ],
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: ()=>choose(true), child: Text('С ' + _date(start)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: ()=>choose(false), child: Text('По ' + _date(finish)))),
              ]),
              const SizedBox(height: 14),
              FilledButton(onPressed: () {
                final q = double.tryParse(amount.text.replaceAll(',', '.'));
                final h = double.tryParse(hours.text.replaceAll(',', '.'));
                if (title.text.trim().isEmpty || q == null || q <= 0 ||
                    h == null || h <= 0 || finish.isBefore(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Проверьте название, объём, сроки и трудоёмкость')));
                  return;
                }
                final room = rooms.where((r)=>r.id==roomId).firstOrNull;
                String? floorId = _activeFloor?.id;
                if (roomId != null) {
                  for (final f in widget.project.floors) {
                    if (f.roomMetas.any((r)=>r.id==roomId)) floorId=f.id;
                  }
                }
                final taskId = _id();
                final operation = WorkOperationCatalog.byCode[operationCode];
                final requiredTasks = <WorkTask>[];
                if (operation != null) {
                  final missing = <String>[];
                  for (final requiredCode in operation.requiredCodes) {
                    final matches = board.tasks.where((task) =>
                      task.operationCode == requiredCode &&
                      task.roomId == roomId && task.floorId == floorId);
                    if (matches.isEmpty) {
                      final prerequisite = WorkOperationCatalog.byCode[requiredCode];
                      // Specialist steps are truly mandatory inside a selected
                      // detailed workflow. Generic optional stages remain conditional.
                      if (prerequisite == null ||
                          !prerequisite.optional ||
                          prerequisite.catalogOnly) {
                        missing.add(prerequisite?.title ?? requiredCode);
                      }
                    } else {
                      requiredTasks.add(matches.first);
                    }
                  }
                  if (missing.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Сначала создайте этапы: ' +
                        missing.join(', '))));
                    return;
                  }
                }
                if (predecessorId != null) {
                  final selected = board.tasks.where((t) =>
                    t.id == predecessorId).firstOrNull;
                  if (selected != null) requiredTasks.add(selected);
                }
                final required = {for (final t in requiredTasks) t.id}.toList();
                if (requiredTasks.any((t) =>
                    !start.isAfter(t.finish) &&
                    !start.isAtSameMomentAs(
                      board.calendar.firstDayAfter(t.finish, 0)))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(
                      'Начало должно быть после обязательных предшественников.')));
                  return;
                }
                final latest = requiredTasks.isEmpty ? null :
                    requiredTasks.reduce((a, b) =>
                      a.finish.isAfter(b.finish) ? a : b);
                final scheduledPredecessor = predecessorId ?? latest?.id;
                final problem = WorkScheduleService.validate(
                  board: board,
                  taskId: taskId,
                  start: start,
                  finish: finish,
                  predecessorId: scheduledPredecessor,
                  lagDays: lagDays,
                );
                if (problem != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(problem)),
                  );
                  return;
                }
                final created = WorkTask(
                  id: taskId, title:title.text.trim(), start:start, finish:finish,
                  quantity:q, unit:unit, hours:h, floorId:floorId,
                  roomId:roomId, roomName:room?.name ?? '',
                  assignee:assignee.text.trim(),
                  operationCode: operationCode,
                  surfaceWallIds: [
                    if (roomId != null && operationCode != null &&
                        WorkSurfaceService.finishCodes.contains(operationCode))
                      for (final floor in widget.project.floors)
                        for (final face in GeometryService.roomFaces(floor))
                          if (floor.roomMetaByKey(face.key)?.id == roomId)
                            ...WorkSurfaceService.wallIdsForCode(
                              board, floor, face, operationCode!),
                  ],
                  requiredPredecessorIds: required,
                  predecessorId: scheduledPredecessor,
                  lagDays: lagDays);
                board.tasks.add(created);
                final linked = <String>[];
                String? linkingProblem;
                for (final peer in coStageSelection) {
                  linkingProblem = WorkCoStageService.link(board, created.id, peer);
                  if (linkingProblem != null) break;
                  linked.add(peer);
                }
                WorkScheduleProposal? linkedPreview;
                if (linkingProblem == null && linked.isNotEmpty) {
                  linkedPreview = WorkSchedulePlanner.preview(
                    board: board, taskId: created.id,
                    start: created.start, finish: created.finish,
                    predecessorId: created.predecessorId,
                    lagDays: created.lagDays,
                  );
                  linkingProblem = linkedPreview.error;
                }
                if (linkingProblem != null) {
                  for (final id in linked) {
                    WorkCoStageService.unlink(board, created.id, id);
                  }
                  board.tasks.remove(created);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(linkingProblem)));
                  return;
                }
                if (linkedPreview != null) {
                  final applyError = WorkSchedulePlanner.apply(
                      board, linkedPreview);
                  if (applyError != null) {
                    for (final id in linked) {
                      WorkCoStageService.unlink(board, created.id, id);
                    }
                    board.tasks.remove(created);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(applyError)));
                    return;
                  }
                }
                board.log('Создана работа: ' + title.text.trim() +
                    (linked.isEmpty ? '' :
                      '; связанных этапов: ' + linked.length.toString()),
                  taskId: created.id);
                Navigator.pop(context, true);
              }, child: const Text('Добавить в график')),
            ],
          )),
        );
      }),
    );
    title.dispose(); amount.dispose(); hours.dispose(); assignee.dispose();
    if (saved == true) await _save();
  }

  Future<void> _taskDetail(WorkTask t) async {
    await showModalBottomSheet<void>(context: context, backgroundColor: _panel,
      isScrollControlled: true, showDragHandle: true,
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.title, style: const TextStyle(fontSize:19, fontWeight:FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.roomName.isEmpty?'Весь объект':t.roomName,
            style: const TextStyle(color:_muted)),
          const SizedBox(height: 12),
          Text('План: ' + _date(t.start) + ' — ' + _date(t.finish)),
          Text('Исполнитель: ' + (t.assignee.isEmpty?'Не назначен':t.assignee)),
          Text('Выполнено: ' + _number(t.done) + '/' + _number(t.quantity) + ' ' + t.unit),
          Text('Принято: ' + _number(t.accepted) + ' ' + t.unit),
          const SizedBox(height: 8),
          Text('Статус: ${_status(t)}',
            style: TextStyle(color: _statusColor(t), fontSize: 12,
              fontWeight: FontWeight.w700)),
          if (WorkStatusService.prerequisites(t).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('Обязательные предшественники: ' +
                WorkStatusService.prerequisites(t).map((id) =>
                  board.tasks.where((p) => p.id == id).map((p) =>
                    p.title + (p.fullyAccepted ? ' ✓' : ' (не принято)'))
                    .firstOrNull ?? 'Неизвестная работа')
                    .join(', '),
                style: const TextStyle(color: _muted, fontSize: 11))),
          if (WorkCoStageService.memberIds(board, t.id).length > 1)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('Параллельная группа: ' +
                WorkCoStageService.memberIds(board, t.id)
                  .where((id) => id != t.id)
                  .map((id) => board.tasks.where((other) => other.id == id)
                    .map((other) => other.title).firstOrNull ?? id)
                  .join(', '),
                style: const TextStyle(color: _peach, fontSize: 11))),
          if (t.needsQuantityReview)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonal(
                onPressed: () { Navigator.pop(sheet); _confirmQuantity(t); },
                child: const Text('Проверить и подтвердить объём'))),
          const SizedBox(height: 10),
          _meter(t.progress),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {
            Navigator.pop(sheet); _updateDone(t);
          }, child: const Text('Зафиксировать выполнение')),
          OutlinedButton(onPressed: () async {
            Navigator.pop(sheet);
            setState(() => t.paused = !t.paused);
            board.log((t.paused ? 'Приостановлена: ' : 'Возобновлена: ') +
              t.title, taskId: t.id);
            await _save();
          }, child: Text(t.paused ? 'Возобновить работу' : 'Приостановить работу')),
          OutlinedButton(onPressed: () {
            Navigator.pop(sheet); _manageCoStages(t);
          }, child: const Text('Созависимые этапы')),
          OutlinedButton(onPressed: () {
            Navigator.pop(sheet); _editSchedule(t);
          }, child: const Text('Сроки и зависимости')),
          OutlinedButton(onPressed: () {
            Navigator.pop(sheet); _editResources(t);
          }, child: const Text('Исполнитель и трудоёмкость')),
          OutlinedButton(onPressed: () {
            Navigator.pop(sheet); _addIssue(task:t);
          }, child: const Text('Создать замечание')),
          if (t.done > t.accepted)
            TextButton(onPressed: () {
              Navigator.pop(sheet); _accept(t);
            }, child: const Text('Передать / принять выполненный объём')),
        ])),
      )));
  }

  Future<void> _manageCoStages(WorkTask task) async {
    final peers = board.tasks.where((other) =>
      other.id != task.id &&
      other.floorId == task.floorId &&
      other.roomId == task.roomId).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, redraw) {
          final group = WorkCoStageService.memberIds(board, task.id);
          return SafeArea(top: false, child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .7,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Созависимые этапы',
                      style: TextStyle(fontSize: 19,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(task.title,
                      style: const TextStyle(color: _peach)),
                    const SizedBox(height: 8),
                    const Text(
                      'Связанные работы можно выполнять параллельно. '
                      'Следующая работа начнётся только после приёмки '
                      'каждого этапа группы. Сроки пересчитываются при добавлении.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Text('В группе: ${group.length} · Выберите связанные работы',
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  if (peers.isEmpty)
                    const ListTile(title: Text(
                      'Добавьте ещё работы в этом помещении.')),
                  for (final candidate in peers)
                    ListTile(
                      title: Text(candidate.title, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${_date(candidate.start)}–${_date(candidate.finish)} · ' +
                        (group.contains(candidate.id)
                          ? 'Связан с текущим этапом' : 'Отдельный этап'),
                        style: const TextStyle(color: _muted, fontSize: 11)),
                      trailing: Icon(
                        group.contains(candidate.id)
                          ? Icons.link : Icons.add_link,
                        color: group.contains(candidate.id) ? _peach : _muted,
                      ),
                      onTap: () async {
                        final directlyLinked =
                          task.coStageTaskIds.contains(candidate.id);
                        if (directlyLinked) {
                          WorkCoStageService.unlink(
                            board, task.id, candidate.id);
                          board.log('Разъединены созависимые этапы: ' +
                            task.title + ' и ' + candidate.title,
                            taskId: task.id);
                          await _save();
                          if (sheet.mounted) redraw(() {});
                          return;
                        }
                        final problem = WorkCoStageService.link(
                          board, task.id, candidate.id);
                        if (problem != null) {
                          ScaffoldMessenger.of(sheet).showSnackBar(
                            SnackBar(content: Text(problem)));
                          return;
                        }
                        final preview = WorkSchedulePlanner.preview(
                          board: board, taskId: task.id,
                          start: task.start, finish: task.finish,
                          predecessorId: task.predecessorId,
                          lagDays: task.lagDays,
                        );
                        final error = preview.error ??
                          WorkSchedulePlanner.apply(board, preview);
                        if (error != null) {
                          WorkCoStageService.unlink(
                            board, task.id, candidate.id);
                          ScaffoldMessenger.of(sheet).showSnackBar(
                            SnackBar(content: Text(error)));
                          return;
                        }
                        board.log('Связаны параллельные этапы: ' +
                          task.title + ' и ' + candidate.title +
                          '; перенесено задач: ' +
                          preview.shiftedSuccessors.toString(),
                          taskId: task.id);
                        await _save();
                        if (sheet.mounted) redraw(() {});
                      },
                    ),
                ],
              )),
              Padding(padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Готово'),
                )),
            ]),
          ));
        },
      ),
    );
  }

  Future<void> _editResources(WorkTask task) async {
    var assignee = task.assignee;
    var hours = task.hours.toStringAsFixed(task.hours % 1 == 0 ? 0 : 1);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Ресурсы работы'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            initialValue: assignee,
            onChanged: (value) => assignee = value,
            decoration: const InputDecoration(
              labelText: 'Исполнитель или бригада')),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: hours,
            onChanged: (value) => hours = value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Плановая трудоёмкость, чел·ч')),
          const SizedBox(height: 10),
          const Text(
            'Изменение трудоёмкости влияет на прогнозную загрузку '
            'и вес задачи в общем проценте выполнения.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(onPressed: () {
            final value = double.tryParse(
              hours.trim().replaceAll(',', '.'));
            if (value == null || !value.isFinite ||
                value <= 0 || value > 100000) {
              ScaffoldMessenger.of(dialog).showSnackBar(const SnackBar(
                content: Text('Укажите допустимое число человеко-часов.')));
              return;
            }
            task.assignee = assignee.trim();
            task.hours = value;
            board.log('Изменены ресурсы: ' + task.title, taskId: task.id);
            Navigator.pop(dialog, true);
          }, child: const Text('Сохранить')),
        ],
      ),
    );
    if (saved == true) await _save();
  }

  Future<void> _editSchedule(WorkTask task) async {
    var nextStart = task.start;
    var nextFinish = task.finish;
    String? predecessorId = task.predecessorId;
    var lagDays = task.lagDays;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheetState) {
          Future<void> pickDate(bool isStart) async {
            final selected = await showDatePicker(
              context: sheet,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: board.calendar.nextWorkday(isStart ? nextStart :
                (nextFinish.isBefore(nextStart) ? nextStart : nextFinish)),
              selectableDayPredicate: board.calendar.isWorkday,
            );
            if (selected == null || !sheet.mounted) return;
            setSheetState(() {
              if (isStart) {
                nextStart = selected;
                if (nextFinish.isBefore(nextStart)) nextFinish = nextStart;
              } else {
                nextFinish = selected;
              }
            });
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18, 8, 18, MediaQuery.viewInsetsOf(sheet).bottom + 20),
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(task.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Исходный график: ${_date(task.baselineStart)} — ${_date(task.baselineFinish)}',
                    style: const TextStyle(fontSize: 12, color: _muted)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => pickDate(true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('С ${_date(nextStart)}'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => pickDate(false),
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text('По ${_date(nextFinish)}'),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: predecessorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Предыдущая работа'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null, child: Text('Без зависимости')),
                      ...board.tasks
                        .where((candidate) => candidate.id != task.id)
                        .map((candidate) => DropdownMenuItem<String?>(
                          value: candidate.id,
                          child: Text(candidate.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        )),
                    ],
                    onChanged: (value) => setSheetState(() {
                      predecessorId = value;
                      if (value == null) lagDays = 0;
                    }),
                  ),
                  if (predecessorId != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: lagDays,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Технологическая пауза (календарных дней)'),
                      items: [0, 1, 2, 3, 5, 7, 14]
                          .map((d) => DropdownMenuItem(
                            value: d, child: Text('$d дн.')))
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => lagDays = value ?? 0),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Последующие работы сдвигаются только после подтверждения. '
                    'Исходный график сохраняется для сравнения план/факт.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.account_tree_outlined),
                    onPressed: () async {
                      final proposal = WorkSchedulePlanner.preview(
                        board: board,
                        taskId: task.id,
                        start: nextStart,
                        finish: nextFinish,
                        predecessorId: predecessorId,
                        lagDays: lagDays,
                      );
                      if (proposal.error != null) {
                        ScaffoldMessenger.of(sheet).showSnackBar(
                          SnackBar(content: Text(proposal.error!)),
                        );
                        return;
                      }
                      if (proposal.changes.isEmpty) {
                        Navigator.pop(sheet, false);
                        return;
                      }
                      final previousLoad = WorkloadService.analyze(board);
                      final resultingLoad = WorkloadService.analyze(
                        board,
                        proposedChanges: proposal.changes,
                      );
                      final oldFinish = proposal.previousCompletion;
                      final newFinish = proposal.projectedCompletion;
                      final approved = await showDialog<bool>(
                        context: sheet,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Проверка изменений графика'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Затронуто работ: ' +
                                    proposal.changes.length.toString()),
                                Text('Сдвинуты следующие этапы: ' +
                                    proposal.shiftedSuccessors.toString()),
                                const SizedBox(height: 5),
                                Text('Завершение объекта: ' +
                                  (oldFinish == null ? '—' : _date(oldFinish)) +
                                  ' → ' +
                                  (newFinish == null ? '—' : _date(newFinish)),
                                  style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                                const SizedBox(height: 8),
                                Text(
                                  'Перегрузка бригад (дни): ' +
                                  previousLoad.overloadedDayCount.toString() +
                                  ' → ' +
                                  resultingLoad.overloadedDayCount.toString(),
                                  style: TextStyle(fontSize: 12,
                                    color: resultingLoad.overloadedDayCount >
                                      previousLoad.overloadedDayCount
                                      ? _red : _muted),
                                ),
                                if (resultingLoad.overloadedDayCount >
                                      previousLoad.overloadedDayCount)
                                  const Text(
                                    'Внимание: после переноса нагрузка увеличится. '
                                    'Измените даты или мощность бригад.',
                                    style: TextStyle(fontSize: 11, color: _red),
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: math.min(
                                    270.0, proposal.changes.length * 62.0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: proposal.changes.length,
                                    itemBuilder: (context, index) {
                                      final change = proposal.changes[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(change.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                        subtitle: Text(
                                          _date(change.oldStart) + '–' +
                                          _date(change.oldFinish) + ' → ' +
                                          _date(change.start) + '–' +
                                          _date(change.finish)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Применить'),
                            ),
                          ],
                        ),
                      );
                      if (approved != true || !sheet.mounted) return;
                      final failure = WorkSchedulePlanner.apply(board, proposal);
                      if (failure != null) {
                        ScaffoldMessenger.of(sheet).showSnackBar(
                          SnackBar(content: Text(failure)),
                        );
                        return;
                      }
                      for (final change in proposal.changes) {
                        board.log('График: ' + change.title + ' ' +
                          _date(change.oldStart) + '–' + _date(change.oldFinish) +
                          ' → ' + _date(change.start) + '–' +
                          _date(change.finish), taskId: change.taskId);
                      }
                      Navigator.pop(sheet, true);
                    },
                    label: const Text('Проверить перенос сроков'),
                  ),
                ],
              )),
            ),
          );
        },
      ),
    );
    if (updated == true) await _save();
  }

  Future<void> _confirmQuantity(WorkTask task) async {
    var value = task.quantity.toStringAsFixed(
      task.quantity % 1 == 0 ? 0 : 2);
    final saved = await showDialog<double>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Подтверждение объёма'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(task.title + ' · ' + task.roomName),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: value,
            onChanged: (text) => value = text,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Объём (' + task.unit + ')'),
          ),
          const SizedBox(height: 8),
          const Text('Проверьте количество на объекте. '
            'После подтверждения можно учитывать выполненные объёмы.',
            style: TextStyle(color: _muted, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена')),
          FilledButton(onPressed: () {
            final parsed = double.tryParse(value.replaceAll(',', '.'));
            if (parsed == null || !parsed.isFinite || parsed <= 0 ||
                parsed < task.done || parsed < task.accepted) {
              ScaffoldMessenger.of(dialog).showSnackBar(
                const SnackBar(content: Text('Проверьте объём работы.')));
              return;
            }
            Navigator.pop(dialog, parsed);
          }, child: const Text('Подтвердить')),
        ],
      ),
    );
    if (saved == null) return;
    final previous = task.quantity;
    task.quantity = saved;
    if (previous > 0) task.hours = task.hours * saved / previous;
    task.needsQuantityReview = false;
    board.log('Подтверждён объём работы: ' + task.title +
      ', ' + _number(saved) + ' ' + task.unit, taskId: task.id);
    await _save();
  }

  Future<void> _updateDone(WorkTask t) async {
    if (t.paused) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Работа приостановлена.')));
      return;
    }
    final blocker = WorkStatusService.startBlocker(board, t);
    if (blocker != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocker)));
      return;
    }
    final controller = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (dialog) =>
      AlertDialog(title: const Text('Обновить выполнение'), content: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text('Было: ' + _number(t.done) + ' / ' + _number(t.quantity) + ' ' + t.unit),
          const SizedBox(height:12),
          TextField(controller: controller, autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal:true),
            decoration: InputDecoration(labelText:'Добавить объём (' + t.unit + ')')),
        ]), actions: [
          TextButton(onPressed:()=>Navigator.pop(dialog,false), child:const Text('Отмена')),
          FilledButton(onPressed:() {
            final add = double.tryParse(controller.text.replaceAll(',', '.'));
            if (add == null || add <= 0 || t.done + add > t.quantity + .0001) {
              ScaffoldMessenger.of(dialog).showSnackBar(
                const SnackBar(content:Text('Объём должен быть больше 0 и не превышать остаток')));
              return;
            }
            t.done += add;
            board.log('Выполнено +' + _number(add) + ' ' + t.unit + ': ' + t.title,
              taskId:t.id);
            Navigator.pop(dialog,true);
          }, child: const Text('Сохранить')),
        ]));
    controller.dispose();
    if (saved == true) await _save();
  }

  Future<void> _accept(WorkTask t) async {
    if (t.done <= t.accepted) return;
    if (!WorkStatusService.canAccept(board, t)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Устраните замечания и подтвердите объём перед приёмкой.')));
      return;
    }
    final confirmation = await showDialog<bool>(context:context,
      builder:(dialog)=>AlertDialog(title:const Text('Приёмка работы'),
        content:Text('Принять ' + _number(t.done - t.accepted) + ' ' +
          t.unit + ' по работе «' + t.title + '»?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Отмена')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('Принять')),
        ]));
    if (confirmation != true) return;
    setState(()=>t.accepted=t.done);
    board.log('Принято ' + _number(t.accepted) + ' ' + t.unit + ': ' + t.title,
      taskId:t.id);
    await _save();
  }

  Future<void> _addIssue({WorkTask? task}) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(context:context, builder:(dialog)=>
      AlertDialog(title:const Text('Новое замечание'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title, decoration:
            const InputDecoration(labelText:'Название дефекта')),
          const SizedBox(height:12),
          TextField(controller:description, maxLines:3, decoration:
            const InputDecoration(labelText:'Описание и место дефекта')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('Отмена')),
          FilledButton(onPressed:(){
            if(title.text.trim().isEmpty)return;
            final roomId=task?.roomId ?? _roomId;
            board.issues.add(WorkIssue(id:_id(),title:title.text.trim(),
              createdAt:DateTime.now(),taskId:task?.id,
              roomId:roomId, description:description.text.trim(),
              roomName:rooms.where((r)=>r.id==roomId).map((e)=>e.name)
                .firstOrNull ?? ''));
            board.log('Добавлено замечание: ' + title.text.trim(),
              taskId:task?.id);
            Navigator.pop(dialog,true);
          },child:const Text('Создать')),
        ]));
    title.dispose(); description.dispose();
    if(saved==true) { setState(()=>_control=1); await _save(); }
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.tint);
  final String label;
  final Color tint;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize:MainAxisSize.min,children:[
    CircleAvatar(radius:4,backgroundColor:tint),const SizedBox(width:5),
    Text(label,style:const TextStyle(color:_muted,fontSize:10)),
  ]);
}

class _PlanView extends StatelessWidget {
  const _PlanView({
    required this.floor, required this.selected,
    required this.onSelect, required this.colorFor,
  });
  final FloorPlan floor;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Color Function(String) colorFor;

  @override
  Widget build(BuildContext context) {
    final faces = GeometryService.roomFaces(floor);
    if (faces.isEmpty) return const SizedBox(height:180,
      child:Center(child:Text('Закройте контуры помещений на плане',
        style:TextStyle(color:_muted))));
    return SizedBox(height:260, child:LayoutBuilder(builder:(context,box) {
      final mapper = _PlanMapper(faces,Size(box.maxWidth,box.maxHeight));
      return GestureDetector(
        onTapDown:(details){
          for(final face in faces.reversed){
            final meta = floor.roomMetaByKey(face.key);
            if(meta==null)continue;
            final path=Path();
            for(var i=0;i<face.innerPolygon.length;i++){
              final p=mapper.toCanvas(face.innerPolygon[i]);
              if(i==0)path.moveTo(p.dx,p.dy);else path.lineTo(p.dx,p.dy);
            }
            path.close();
            if(path.contains(details.localPosition)){
              onSelect(meta.id);return;
            }
          }
        },
        child:CustomPaint(size:Size.infinite,painter:_PlanPainter(
          floor:floor,faces:faces,mapper:mapper,
          selected:selected,colorFor:colorFor)),
      );
    }));
  }
}

class _PlanMapper {
  _PlanMapper(List<RoomFace> faces, Size size) {
    final pts=faces.expand((f)=>f.innerPolygon).toList();
    minX=pts.map((p)=>p.x).reduce(math.min);
    minY=pts.map((p)=>p.y).reduce(math.min);
    final maxX=pts.map((p)=>p.x).reduce(math.max);
    final maxY=pts.map((p)=>p.y).reduce(math.max);
    scale=math.min((size.width-28)/math.max(1,maxX-minX),
      (size.height-28)/math.max(1,maxY-minY));
    offsetX=(size.width-(maxX-minX)*scale)/2;
    offsetY=(size.height-(maxY-minY)*scale)/2;
  }
  late final double minX,minY,scale,offsetX,offsetY;
  Offset toCanvas(math.Point<double> p)=>
    Offset(offsetX+(p.x-minX)*scale,offsetY+(p.y-minY)*scale);
}

/// Interactive multi-polygon plan: unfinished vertices are not saved until
/// their polygon passes the geometric containment/overlap validator.
class _FloorPolygonPlanPainter extends CustomPainter {
  const _FloorPolygonPlanPainter({
    required this.face, required this.mapper, required this.zones,
    required this.drawing, required this.draftMaterial, required this.baseTile,
    required this.editing, this.selectedZoneId, this.selectedVertexIndex,
  });
  final RoomFace face;
  final _PlanMapper mapper;
  final List<WorkFloorFinishZone> zones;
  final List<math.Point<double>> drawing;
  final String draftMaterial;
  final bool baseTile;
  final bool editing;
  final String? selectedZoneId;
  final int? selectedVertexIndex;

  static const _tile = Color(0xFF517DAE);
  static const _laminate = Color(0xFF969F9B);

  Path _path(List<math.Point<double>> vertices, {bool close = true}) {
    final path = Path();
    for (var i = 0; i < vertices.length; i++) {
      final pos = mapper.toCanvas(vertices[i]);
      if (i == 0) {
        path.moveTo(pos.dx, pos.dy);
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    if (close && vertices.length >= 3) path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
      Paint()..color = const Color(0xFF191E26));
    final roomPath = _path(face.innerPolygon);
    canvas.drawPath(roomPath,
      Paint()..color = baseTile ? _tile : _laminate);
    canvas.save();
    canvas.clipPath(roomPath);
    for (final zone in zones) {
      final color = zone.material == 'tile' ? _tile : _laminate;
      final path = _path(zone.polygon);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFF0CEAE)
        ..strokeWidth = 1.8..style = PaintingStyle.stroke);
    }
    canvas.restore();
    canvas.drawPath(roomPath, Paint()
      ..color = const Color(0xFFF1F3F6)
      ..strokeWidth = 2.5..style = PaintingStyle.stroke);
    if (editing) {
      for (final zone in zones) {
        for (var i = 0; i < zone.polygon.length; i++) {
          final point = mapper.toCanvas(zone.polygon[i]);
          final selected = zone.id == selectedZoneId &&
              i == selectedVertexIndex;
          canvas.drawCircle(point, selected ? 10 : 6.5,
            Paint()..color = const Color(0xFF101419));
          canvas.drawCircle(point, selected ? 7 : 4.4,
            Paint()..color = selected
              ? const Color(0xFFF1AF91)
              : const Color(0xFFE6E9EE));
        }
      }
    }
    if (drawing.isNotEmpty) {
      final draftPath = _path(drawing, close: false);
      canvas.drawPath(draftPath, Paint()
        ..color = const Color(0xFFF1AF91)
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke);
      for (final p in drawing) {
        final canvasPoint = mapper.toCanvas(p);
        canvas.drawCircle(canvasPoint, 4.6,
          Paint()..color = const Color(0xFFF1AF91));
      }
      if (drawing.length >= 3) {
        canvas.drawPath(_path(drawing), Paint()
          ..color = draftMaterial == 'tile'
            ? const Color(0x44517DAE) : const Color(0x44969F9B));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPolygonPlanPainter old) => true;
}

/// 2D preview of one clipped tile/laminate split inside the REAL room polygon.
class _FloorFinishPlanPainter extends CustomPainter {
  const _FloorFinishPlanPainter({
    required this.face, required this.mapper, required this.split,
  });
  final RoomFace face;
  final _PlanMapper mapper;
  final WorkFloorFinishSplit split;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
      Paint()..color = const Color(0xFF191E26));

    void fill(List<math.Point<double>> pts, Color color) {
      if (pts.length < 3) return;
      final polygon = Path();
      for (var i = 0; i < pts.length; i++) {
        final pixel = mapper.toCanvas(pts[i]);
        if (i == 0) {
          polygon.moveTo(pixel.dx, pixel.dy);
        } else {
          polygon.lineTo(pixel.dx, pixel.dy);
        }
      }
      polygon.close();
      canvas.drawPath(polygon, Paint()..color = color);
    }

    fill(WorkFloorSurfaceService.clip(face, split, false),
      const Color(0xFF969F9B));
    fill(WorkFloorSurfaceService.clip(face, split, true),
      const Color(0xFF517DAE));

    final outline = Path();
    for (var i = 0; i < face.innerPolygon.length; i++) {
      final p = mapper.toCanvas(face.innerPolygon[i]);
      if (i == 0) {
        outline.moveTo(p.dx, p.dy);
      } else {
        outline.lineTo(p.dx, p.dy);
      }
    }
    outline.close();
    canvas.drawPath(outline, Paint()
      ..color = const Color(0xFFE2E5E9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke);
    final bounds = WorkFloorSurfaceService.bounds(face, split.axis);
    final start = split.axis == 'x'
      ? math.Point<double>(split.cutMm, bounds.min)
      : math.Point<double>(bounds.min, split.cutMm);
    final end = split.axis == 'x'
      ? math.Point<double>(split.cutMm, bounds.max)
      : math.Point<double>(bounds.max, split.cutMm);
    // The reference line extends across the bounding box; actual zones
    // are clipped to the room interior.
    canvas.drawLine(mapper.toCanvas(start), mapper.toCanvas(end),
      Paint()
        ..color = const Color(0xFFF1AF91)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _FloorFinishPlanPainter old) => true;
}

/// Lightweight 2D editor preview. Every highlighted segment is an actual
/// room-side wall from the geometry engine, not an invented rectangle.
class _WallFinishPlanPainter extends CustomPainter {
  const _WallFinishPlanPainter({
    required this.face,
    required this.mapper,
    required this.tileHeights,
    required this.selectedWall,
  });
  final RoomFace face;
  final _PlanMapper mapper;
  final Map<String, double> tileHeights;
  final String selectedWall;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
      Paint()..color = const Color(0xFF191E26));
    final polygon = Path();
    for (var i = 0; i < face.innerPolygon.length; i++) {
      final p = mapper.toCanvas(face.innerPolygon[i]);
      if (i == 0) {
        polygon.moveTo(p.dx, p.dy);
      } else {
        polygon.lineTo(p.dx, p.dy);
      }
    }
    polygon.close();
    canvas.drawPath(polygon, Paint()
      ..color = const Color(0xFF282E39));
    for (var i = 0; i < face.edges.length; i++) {
      final edge = face.edges[i];
      final a = mapper.toCanvas(face.innerPolygon[i]);
      final b = mapper.toCanvas(
        face.innerPolygon[(i + 1) % face.innerPolygon.length]);
      final active = edge.wallId == selectedWall;
      final tiled = (tileHeights[edge.wallId] ?? 0) > .01;
      final paint = Paint()
        ..color = active ? _peach :
            (tiled ? const Color(0xFF72ACEB) : const Color(0xFF91A39A))
        ..strokeWidth = active ? 9 : 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
      if (active) {
        final center = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        canvas.drawCircle(center, 6,
          Paint()..color = const Color(0xFF111419));
        canvas.drawCircle(center, 3,
          Paint()..color = _peach);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _WallFinishPlanPainter old) => true;
}

class _PlanPainter extends CustomPainter {
  const _PlanPainter({
    required this.floor,required this.faces,required this.mapper,
    required this.selected,required this.colorFor,
  });
  final FloorPlan floor;
  final List<RoomFace> faces;
  final _PlanMapper mapper;
  final String? selected;
  final Color Function(String) colorFor;
  @override
  void paint(Canvas canvas, Size size) {
    // The construction grid stays behind the real room geometry.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF151A1D));
    final gridPaint = Paint()
      ..color = const Color(0xFF323638).withValues(alpha: .45)
      ..strokeWidth = .55;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Room status fills follow the inner polygons, never a guessed rectangle.
    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta == null || face.innerPolygon.length < 3) continue;
      final path = Path();
      for (var i = 0; i < face.innerPolygon.length; i++) {
        final p = mapper.toCanvas(face.innerPolygon[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawShadow(path, Colors.black.withValues(alpha: .75), 6, false);
      canvas.drawPath(path, Paint()
        ..color = colorFor(meta.id).withValues(alpha: .34));
      if (meta.id == selected) {
        canvas.drawPath(path, Paint()
          ..color = _peach
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }

    void wallStroke(Offset a, Offset b, Color color) {
      canvas.drawLine(a, b, Paint()
        ..color = const Color(0xFF07090B)
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 7);
      canvas.drawLine(a, b, Paint()
        ..color = color
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 4);
      canvas.drawLine(a, b, Paint()
        ..color = const Color(0xFFCCC7BD).withValues(alpha: .35)
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 1);
    }

    // Each actual wall is split by its modeled openings. Door gaps and
    // window segments remain visible rather than painting a closed outline.
    for (final wall in floor.walls) {
      final startNode = floor.nodeById(wall.startNodeId);
      final endNode = floor.nodeById(wall.endNodeId);
      if (startNode == null || endNode == null) continue;
      final length = floor.wallLengthMm(wall);
      if (length < 1) continue;
      final start = mapper.toCanvas(math.Point(startNode.xMm, startNode.yMm));
      final end = mapper.toCanvas(math.Point(endNode.xMm, endNode.yMm));
      final direction = (end - start) / length;
      final wallColor = wall.demolition ?
          const Color(0xFFBF7775) : const Color(0xFF97948E);
      var cursor = 0.0;
      final openings = [...wall.openings]
        ..sort((a, b) => a.offsetFromStartMm.compareTo(b.offsetFromStartMm));
      for (final opening in openings) {
        final left = opening.offsetFromStartMm.clamp(0.0, length).toDouble();
        final right = (opening.offsetFromStartMm + opening.widthMm)
            .clamp(0.0, length).toDouble();
        if (right <= left) continue;
        if (left > cursor) {
          wallStroke(start + direction * cursor,
            start + direction * left, wallColor);
        }
        final openingStart = start + direction * left;
        final openingEnd = start + direction * right;
        if (opening.type == OpeningType.window) {
          canvas.drawLine(openingStart, openingEnd, Paint()
            ..color = const Color(0xFF97BFD0)
            ..strokeWidth = 2.5);
          canvas.drawLine(openingStart, openingEnd, Paint()
            ..color = const Color(0xFFD3E1E2).withValues(alpha: .45)
            ..strokeWidth = .75);
        } else {
          final delta = openingEnd - openingStart;
          // Direction only indicates a door leaf in plan view; opening side
          // needs no invented geometry or furniture collision data.
          final leafEnd = openingStart + Offset(-delta.dy, delta.dx);
          canvas.drawLine(openingStart, leafEnd, Paint()
            ..color = const Color(0xFFF1D6B5)
            ..strokeWidth = 1.15);
        }
        cursor = math.max(cursor, right);
      }
      if (cursor < length) {
        wallStroke(start + direction * cursor, end, wallColor);
      }
    }

    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta == null) continue;
      final center = mapper.toCanvas(face.centroid);
      final label = TextPainter(
        text: TextSpan(text: meta.name,
          style: const TextStyle(color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w700, shadows: [
              Shadow(color: Colors.black, blurRadius: 5),
            ])),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: math.max(35, math.min(100, size.width / 3)));
      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }
  }
  @override
  bool shouldRepaint(covariant _PlanPainter old) => true;
}
