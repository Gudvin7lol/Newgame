import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/report_service.dart';
import 'elevations_screen.dart';
import 'electrical_screen.dart';
import 'layouts_screen.dart';
import 'floor_3d_screen.dart';
import 'materials_screen.dart';
import 'plan_editor_screen.dart';
import 'rooms_screen.dart';
import 'planning_objects_screen.dart';
import 'scan_plan_screen.dart';
import 'engineering_screen.dart';
import 'measurement_review_screen.dart';

class FloorWorkspaceScreen extends StatefulWidget {
  const FloorWorkspaceScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<FloorWorkspaceScreen> createState() => _FloorWorkspaceScreenState();
}

class _FloorWorkspaceScreenState extends State<FloorWorkspaceScreen> {
  int _index = 0;
  final _lastByMode = [0, 3, 4, 8];
  static const _modeTabs = <List<int>>[
    [0, 1, 2],
    [3, 7],
    [4, 5, 6],
    [8],
  ];
  int get _mode => _modeTabs.indexWhere((group) => group.contains(_index));
  final _history = <String>[];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    _history.add(jsonEncode(widget.floor.toJson()));
  }

  void _recordHistory() {
    final snapshot = jsonEncode(widget.floor.toJson());
    if (_history[_historyIndex] == snapshot) return;
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(snapshot);
    if (_history.length > 51) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  Future<void> _travel(int delta) async {
    final next = _historyIndex + delta;
    if (next < 0 || next >= _history.length) return;
    _historyIndex = next;
    widget.floor.restoreFrom(
      FloorPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(_history[next]) as Map),
      ),
    );
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(widget.floor);
    _recordHistory();
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PlanEditorScreen(floor: widget.floor, onChanged: _changed),
      RoomsScreen(floor: widget.floor, onChanged: _changed),
      ElevationsScreen(floor: widget.floor, onChanged: _changed),
      LayoutsScreen(floor: widget.floor, onChanged: _changed),
      ElectricalScreen(floor: widget.floor, onChanged: _changed),
      PlanningObjectsScreen(floor: widget.floor, onChanged: _changed),
      EngineeringScreen(floor: widget.floor, onChanged: _changed),
      MaterialsScreen(
        floor: widget.floor,
        project: widget.project,
        onChanged: _changed,
      ),
      // The GPU viewport is created only when 3D is actually visible.
      // Keeping it alive inside an IndexedStack made Flutter Scene initialise
      // while the tab had an offstage surface on some Android devices.
      // That produced the "3D appears only after app restart" bug.
      _index == 8
          ? Floor3DScreen(
              key: ValueKey(
                '3d-${widget.floor.nodes.length}-${widget.floor.walls.length}-'
                '${widget.floor.planObjects.length}-${widget.floor.electricalPoints.length}',
              ),
              floor: widget.floor,
            )
          : const SizedBox.shrink(),
    ];

    const tabs = <(String, IconData)>[
      ('План', Icons.architecture_outlined),
      ('Комнаты', Icons.grid_view_outlined),
      ('Развёртки', Icons.view_carousel_outlined),
      ('Полы', Icons.grid_4x4_outlined),
      ('Электрика', Icons.electrical_services_outlined),
      ('Объекты', Icons.chair_alt_outlined),
      ('Инженерия', Icons.plumbing_outlined),
      ('Материалы', Icons.inventory_2_outlined),
      ('3D', Icons.view_in_ar_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.floor.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.project.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Проверка обмера',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MeasurementReviewScreen(floor: widget.floor),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: 'Отменить изменение на этаже',
            onPressed: _historyIndex > 0 ? () => _travel(-1) : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Повторить изменение на этаже',
            onPressed: _historyIndex < _history.length - 1
                ? () => _travel(1)
                : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Скан / импорт плана',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScanPlanScreen(floor: widget.floor, onChanged: _changed),
                ),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          IconButton(
            tooltip: 'PDF-отчёт',
            onPressed: () =>
                ReportService.shareFloorPdf(widget.project, widget.floor),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFF121C1F),
            child: const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LayerDot(color: Color(0xFFB9C1C4), text: 'Существующее'),
                  SizedBox(width: 14),
                  _LayerDot(color: Color(0xFFFF6B56), text: 'Демонтаж'),
                  SizedBox(width: 14),
                  _LayerDot(color: Color(0xFF56D6A3), text: 'Новая планировка'),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: screens),
          ),
          if (_modeTabs[_mode].length > 1)
            Container(
              color: const Color(0xFF121C1F),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    for (final i in _modeTabs[_mode])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(tabs[i].$1),
                          avatar: Icon(tabs[i].$2, size: 18),
                          selected: _index == i,
                          onSelected: (_) => setState(() {
                            _index = i;
                            _lastByMode[_mode] = i;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: _mode,
              height: 68,
              onDestinationSelected: (mode) => setState(() {
                _index = _lastByMode[mode];
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.architecture_outlined),
                  label: 'Обмер',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_4x4_outlined),
                  label: 'Отделка',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chair_alt_outlined),
                  label: 'Оснащение',
                ),
                NavigationDestination(
                  icon: Icon(Icons.view_in_ar_outlined),
                  label: '3D',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerDot extends StatelessWidget {
  const _LayerDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ],
  );
}
