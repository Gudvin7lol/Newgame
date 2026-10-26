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
import '../services/work_status_service.dart';

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
  const WorksScreen({super.key, required this.project, required this.onChanged});
  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  int _tab = 0, _calendar = 0, _control = 0;
  DateTime _selected = _day(DateTime.now());
  String? _roomId;
  String? _selectedFloorId;
  WorkBoard get board => widget.project.workBoard;
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

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: _stat('Новых', '${plan.tasks.length}')),
                  const SizedBox(width: 7),
                  Expanded(child: _stat('Уже есть', '${plan.skippedExisting}')),
                  const SizedBox(width: 7),
                  Expanded(child: _stat('Проверить', '${plan.reviewCount}',
                    tint: _amber)),
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
                  backgroundColor: board.tasks.any((t) =>
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
          final busy = board.tasks.any((t) =>
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
    final tasks = [...board.tasks]
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
    var category = 'Все';
    final categories = WorkOperationCatalog.all.map((op) => op.phase)
        .toSet().toList()..sort();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
        final search = query.trim().toLowerCase();
        final matches = WorkOperationCatalog.all.where((op) =>
            (category == 'Все' || op.phase == category) &&
            (search.isEmpty || op.title.toLowerCase().contains(search) ||
              op.code.toLowerCase().contains(search))).toList();
        return SafeArea(top: false, child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .78,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('Библиотека работ',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)))),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextFormField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Найти операцию, материал или этап'),
                onChanged: (text) => update(() => query = text),
              )),
            SizedBox(height: 43, child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              children: [
                for (final name in ['Все', ...categories])
                  Padding(padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(name, style: const TextStyle(fontSize: 11)),
                      selected: category == name,
                      onSelected: (_) => update(() => category = name),
                    )),
              ])),
            ListTile(
              dense: true,
              leading: const Icon(Icons.edit_note_outlined, color: _peach),
              title: const Text('Создать произвольную работу'),
              onTap: () => Navigator.pop(sheet, '__manual__'),
            ),
            const Divider(height: 1, color: _edge),
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('Найдено: ${matches.length}',
                  style: const TextStyle(fontSize: 11, color: _muted)))),
            Expanded(child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (_, index) {
                final op = matches[index];
                final unit = switch (op.basis) {
                  WorkQuantityBasis.package => 'шт/компл.',
                  WorkQuantityBasis.skirting => 'м',
                  _ => 'м²',
                };
                return ListTile(
                  title: Text(op.title, maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  subtitle: Text('${op.phase} · $unit · '
                    '${op.hoursPerUnit} чел·ч/ед. (ориентир)',
                    style: const TextStyle(fontSize: 11, color: _muted)),
                  trailing: const Icon(Icons.chevron_right, color: _peach),
                  onTap: () => Navigator.pop(sheet, op.code),
                );
              },
            )),
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
    var lagDays = 0;
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
          final count = switch (op.basis) {
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
                      if (!(WorkOperationCatalog.byCode[requiredCode]?.optional ?? false)) {
                        missing.add(WorkOperationCatalog.byCode[requiredCode]?.title ??
                          requiredCode);
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
                board.tasks.add(WorkTask(
                  id: taskId, title:title.text.trim(), start:start, finish:finish,
                  quantity:q, unit:unit, hours:h, floorId:floorId,
                  roomId:roomId, roomName:room?.name ?? '',
                  assignee:assignee.text.trim(),
                  operationCode: operationCode,
                  requiredPredecessorIds: required,
                  predecessorId: scheduledPredecessor,
                  lagDays: lagDays));
                board.log('Создана работа: ' + title.text.trim(),
                  taskId: board.tasks.last.id);
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
        child: Column(mainAxisSize: MainAxisSize.min,
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
        ]),
      )));
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
