import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/work_board.dart';
import '../design_system/zamer_tokens.dart';
import '../services/geometry_service.dart';

const _bg = ZamerColors.background;
const _panel = ZamerColors.surface;
const _edge = Color(0xFF3A3C43);
const _peach = ZamerColors.conceptAccent;
const _blue = ZamerColors.info;
const _green = ZamerColors.success;
const _red = ZamerColors.danger;
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
  WorkBoard get board => widget.project.workBoard;
  List<RoomMeta> get rooms =>
      widget.project.floors.expand((floor) => floor.roomMetas).toList();

  Future<void> _save() async {
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Color _statusColor(WorkTask task) {
    if (task.fullyAccepted) return _green;
    if (task.isDelayed(DateTime.now())) return _red;
    if (task.paused) return const Color(0xFFECC07C);
    if (task.progress > 0) return _blue;
    return _muted;
  }

  String _status(WorkTask task) {
    if (task.fullyAccepted) return 'Принято';
    if (task.complete) return 'На приёмке';
    if (task.isDelayed(DateTime.now())) return 'Просрочено';
    if (task.paused) return 'Приостановлено';
    if (task.progress > 0) return 'В работе';
    return 'В плане';
  }

  Color _roomColor(String roomId) {
    final tasks = board.tasks.where((t) => t.roomId == roomId).toList();
    if (tasks.isEmpty) return const Color(0xFF7B8595);
    if (board.issues.any((e) => e.roomId == roomId && e.open) ||
        tasks.any((t) => t.isDelayed(DateTime.now()))) return _red;
    if (tasks.every((t) => t.fullyAccepted)) return _green;
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
          colors: [Color(0xFFFBD0AB), _peach]) : null,
        color: active ? null : _panel,
        border: Border.all(color: active ? _peach : _edge),
        boxShadow: active ? [BoxShadow(color: _peach.withValues(alpha: .18), blurRadius: 12)] : null,
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
            colors: [Color(0xFF282B35), _panel],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _edge),
        ),
        child: child,
      );

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
      _heading('План работ'),
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
          'Перенос сроков пока выполняется вручную.',
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
                  style: TextStyle(color: active ? _bg : _muted, fontSize: 10)),
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
        )));
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
    final sorted = [...board.tasks]..sort((a, b) => a.start.compareTo(b.start));
    if (sorted.isEmpty) return _empty('Нет работ для диаграммы Ганта.');
    final minDate = sorted.first.start;
    final start = _day(minDate);
    final maxDate = sorted.map((t) => t.finish).reduce((a,b) => a.isAfter(b)?a:b);
    final span = math.max(14, _day(maxDate).difference(start).inDays + 1);
    final width = span * 22.0;
    return _card(padding: const EdgeInsets.all(10), child: Column(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('График по дням',
        style: TextStyle(color: _muted, fontSize: 12))),
      const SizedBox(height: 10),
      Row(children: [
        SizedBox(width: 105, child: Column(children: [
          const SizedBox(height: 25),
          for (final t in sorted) SizedBox(height: 49,
            child: Align(alignment: Alignment.centerLeft, child: Text(t.title,
              overflow: TextOverflow.ellipsis, maxLines: 2,
              style: const TextStyle(fontSize: 11)))),
        ])),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, child: Column(children: [
            SizedBox(height: 25, child: Row(children: List.generate(span, (i) =>
              SizedBox(width: 22, child: Center(child: Text(
                '${start.add(Duration(days:i)).day}',
                style: const TextStyle(fontSize: 10, color: _muted)))))),
            for (final t in sorted)
              SizedBox(height: 49, child: Stack(children: [
                Positioned(left: 22.0 * _day(t.start).difference(start).inDays,
                  top: 12, width: 22.0 *
                    (_day(t.finish).difference(_day(t.start)).inDays + 1),
                  height: 24,
                  child: ClipRRect(borderRadius: BorderRadius.circular(5),
                    child: Stack(children: [
                      Container(color: _statusColor(t).withValues(alpha: .35)),
                      FractionallySizedBox(widthFactor: t.progress,
                        child: Container(color: _statusColor(t))),
                    ]))),
              ])),
          ])))),
      ]),
    ]));
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
        _stat('На приёмке', '${board.tasks.where((t)=>t.complete && !t.fullyAccepted).length}'),
      ]),
      _heading('Контроль по помещениям', trailing:
        TextButton.icon(onPressed: _fullPlan,
          icon: const Icon(Icons.open_in_full, size: 16),
          label: const Text('2D-план'))),
      if (widget.project.floors.isEmpty)
        _empty('Сначала создайте этаж и помещения в «Замере».')
      else
        _card(padding: const EdgeInsets.all(9), child: Column(children: [
          _PlanView(
            floor: widget.project.floors.first,
            selected: _roomId,
            onSelect: (id) => setState(() => _roomId = id),
            colorFor: _roomColor,
          ),
          const SizedBox(height: 8),
          const Wrap(spacing: 12, runSpacing: 6, children: [
            _Legend('Принято', _green), _Legend('В работе', _blue),
            _Legend('Проблемы', _red), _Legend('В плане', _muted),
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
      _roomId == null || t.roomId == _roomId).toList();
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
          SizedBox(height: 440, child: _PlanView(
            floor: widget.project.floors.first,
            selected: _roomId, onSelect: (id) {
              setState(() => _roomId = id);
              Navigator.pop(context);
            }, colorFor: _roomColor)),
        ]))));
  }

  void _quickActions() {
    showModalBottomSheet<void>(context: context,
      backgroundColor: _panel, showDragHandle: true,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.add_task, color: _peach),
          title: const Text('Добавить работу'),
          onTap: () { Navigator.pop(context); _addTask(); }),
        ListTile(leading: const Icon(Icons.note_add_outlined, color: _peach),
          title: const Text('Добавить замечание'),
          onTap: () { Navigator.pop(context); _addIssue(); }),
        ListTile(leading: const Icon(Icons.checklist_outlined, color: _peach),
          title: const Text('Приёмка'),
          onTap: () { Navigator.pop(context); setState(()=>_control=2); }),
      ])));
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final amount = TextEditingController(text: '1');
    final hours = TextEditingController(text: '8');
    final assignee = TextEditingController();
    var start = _selected, finish = _selected, unit = 'м²';
    String? roomId = _roomId;
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: _panel,
      builder: (context) => StatefulBuilder(builder: (context, state) {
        Future<void> choose(bool beginning) async {
          final chosen = await showDatePicker(context: context,
            firstDate: DateTime(2020), lastDate: DateTime(2100),
            initialDate: beginning ? start : finish);
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
                onChanged: (v) => state(() => roomId = v),
              ),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Объём'))),
                const SizedBox(width: 8),
                SizedBox(width: 94, child: DropdownButtonFormField<String>(
                  initialValue: unit,
                  items: ['м²','м','шт','м³'].map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v)=>state(()=>unit=v ?? 'м²'))),
              ]),
              if (roomId != null) TextButton.icon(
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
                String? floorId;
                for (final f in widget.project.floors) {
                  if (f.roomMetas.any((r)=>r.id==roomId)) floorId=f.id;
                }
                board.tasks.add(WorkTask(
                  id: _id(), title:title.text.trim(), start:start, finish:finish,
                  quantity:q, unit:unit, hours:h, floorId:floorId,
                  roomId:roomId, roomName:room?.name ?? '',
                  assignee:assignee.text.trim()));
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
          const SizedBox(height: 10),
          _meter(t.progress),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {
            Navigator.pop(sheet); _updateDone(t);
          }, child: const Text('Зафиксировать выполнение')),
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

  Future<void> _updateDone(WorkTask t) async {
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
  void paint(Canvas canvas,Size size){
    canvas.drawRect(Offset.zero & size,Paint()..color=const Color(0xFF171A21));
    for(final f in faces){
      final meta=floor.roomMetaByKey(f.key);
      if(meta==null)continue;
      final path=Path();
      for(var i=0;i<f.innerPolygon.length;i++){
        final p=mapper.toCanvas(f.innerPolygon[i]);
        if(i==0)path.moveTo(p.dx,p.dy);else path.lineTo(p.dx,p.dy);
      }
      path.close();
      canvas.drawPath(path,Paint()..color=colorFor(meta.id).withValues(alpha:.38));
      canvas.drawPath(path,Paint()
        ..color=meta.id==selected?_peach:const Color(0xFFB7B4AA)
        ..style=PaintingStyle.stroke
        ..strokeWidth=meta.id==selected?3:2);
      final center=mapper.toCanvas(f.centroid);
      final name=TextPainter(
        text:TextSpan(text:meta.name,style:const TextStyle(
          color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)),
        textAlign:TextAlign.center,textDirection:TextDirection.ltr,
        maxLines:2,ellipsis:'…')..layout(maxWidth:math.max(35,math.min(100,size.width/3)));
      name.paint(canvas,center-Offset(name.width/2,name.height/2));
    }
  }
  @override
  bool shouldRepaint(covariant _PlanPainter old) => true;
}
