import 'dart:convert';

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/report_service.dart';
import '../widgets/workspace_navigation.dart';
import 'elevations_screen.dart';
import 'electrical_screen.dart';
import 'engineering_screen.dart';
import 'floor_3d_screen.dart';
import 'layouts_screen.dart';
import 'materials_screen.dart';
import 'measurement_review_screen.dart';
import 'plan_editor_screen.dart';
import 'planning_objects_screen.dart';
import 'rooms_screen.dart';
import 'scan_plan_screen.dart';

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

  // The project workspace follows the four master working pages. Home lives
  // one level above this screen in ProjectsScreen.
  final _lastByMode = [0, 8, 5, 2];
  static const _modeTabs = <List<int>>[
    [0, 1], // Замер: план + помещения.
    [8], // 3D: realtime scene / walk / photo studio.
    [4, 5, 6], // Оснащение: электрика + объекты + инженерия.
    [2, 3, 7], // Развёртки: стены + полы + материалы.
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

  void _selectPrimaryMode(int mode) {
    setState(() => _index = _lastByMode[mode]);
  }

  void _selectSubpage(List<int> modeTabs, int localIndex) {
    final page = modeTabs[localIndex];
    setState(() {
      _index = page;
      _lastByMode[_mode] = page;
    });
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
      // The GPU viewport is created only while 3D is visible. Initialising
      // Flutter Scene inside an offstage IndexedStack surface caused the old
      // "3D appears only after app restart" failure on some Android devices.
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
      ('Стены', Icons.view_carousel_outlined),
      ('Полы', Icons.grid_4x4_outlined),
      ('Электрика', Icons.electrical_services_outlined),
      ('Объекты', Icons.chair_alt_outlined),
      ('Инженерия', Icons.plumbing_outlined),
      ('Материалы', Icons.inventory_2_outlined),
      ('3D', Icons.view_in_ar_outlined),
    ];

    final modeTabs = _modeTabs[_mode];
    final subItems = [for (final i in modeTabs) tabs[i]];

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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ZamerColors.textMuted,
              ),
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
                  builder: (_) => ScanPlanScreen(
                    floor: widget.floor,
                    onChanged: _changed,
                  ),
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
          const SizedBox(width: ZamerSpace.xs),
        ],
      ),
      body: Column(
        children: [
          const ZWorkspaceLayerLegend(),
          Expanded(child: IndexedStack(index: _index, children: screens)),
          ZWorkspaceSubnav(
            items: subItems,
            selectedIndex: modeTabs.indexOf(_index),
            onSelected: (localIndex) => _selectSubpage(modeTabs, localIndex),
          ),
          ZWorkspacePrimaryNav(
            selectedIndex: _mode,
            onSelected: _selectPrimaryMode,
          ),
        ],
      ),
    );
  }
}
