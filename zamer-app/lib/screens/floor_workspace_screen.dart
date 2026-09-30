import 'dart:convert';

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/report_service.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
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
    this.initialMode = 0,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  /// Master-mode index: 0 = Measure, 1 = 3D, 2 = Equipment, 3 = Elevations.
  final int initialMode;

  @override
  State<FloorWorkspaceScreen> createState() => _FloorWorkspaceScreenState();
}

class _FloorWorkspaceScreenState extends State<FloorWorkspaceScreen> {
  int _index = 0;

  // Home lives one level above this screen. The remaining four master pages
  // are mapped to the working subpages below.
  final _lastByMode = [0, 8, 5, 2];
  static const _modeTabs = <List<int>>[
    [0, 1], // Замер: план + помещения.
    [8], // 3D: realtime scene / walk / photo studio.
    [4, 5, 6], // Оснащение: электрика + объекты + инженерия.
    [2, 3, 7], // Развёртки: стены + полы + материалы.
  ];

  int get _mode => _modeTabs.indexWhere((group) => group.contains(_index));

  String get _modeLabel => switch (_mode) {
    0 => 'ЗАМЕР 2D',
    1 => '3D',
    2 => 'ОСНАЩЕНИЕ',
    _ => 'РАЗВЁРТКИ',
  };

  final _history = <String>[];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    final mode = widget.initialMode < 0
        ? 0
        : (widget.initialMode > 3 ? 3 : widget.initialMode);
    _index = _lastByMode[mode];
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

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openMeasurementReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementReviewScreen(floor: widget.floor),
      ),
    );
  }

  Future<void> _scanOrImport() async {
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
  }

  Future<void> _showProjectActions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Действия проекта',
        description: '${widget.project.name} • ${widget.floor.name}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.document_scanner_outlined,
              title: 'Скан / импорт плана',
              subtitle: 'Фото, план и калибровка масштаба',
              onTap: () {
                Navigator.pop(sheetContext);
                _scanOrImport();
              },
            ),
            ZActionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF-отчёт',
              subtitle: 'Рабочая документация текущего этажа',
              onTap: () {
                Navigator.pop(sheetContext);
                ReportService.shareFloorPdf(widget.project, widget.floor);
              },
            ),
            ZActionTile(
              icon: Icons.fact_check_outlined,
              title: 'Проверка обмера',
              subtitle: 'Контур, размеры, диагонали и источники',
              onTap: () {
                Navigator.pop(sheetContext);
                _openMeasurementReview();
              },
            ),
          ],
        ),
      ),
    );
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
    final roomCount = GeometryService.roomFaces(widget.floor).length;
    final contextTitle = switch (_mode) {
      0 => 'Обмер и геометрия',
      1 => 'Пространственная модель',
      2 => 'Комплектация объекта',
      _ => 'Рабочая документация',
    };
    final contextSubtitle = switch (_mode) {
      0 => 'Стены, помещения, проёмы и контроль размеров',
      1 => 'Realtime-сцена, прогулка и фоторендер',
      2 => 'Мебель, электрика, сантехника и инженерия',
      _ => 'Развёртки стен, раскладки пола и материалы',
    };
    final contextIcon = switch (_mode) {
      0 => Icons.architecture_outlined,
      1 => Icons.view_in_ar_outlined,
      2 => Icons.chair_alt_outlined,
      _ => Icons.view_carousel_outlined,
    };
    final contextMetrics = <ZWorkspaceMetric>[
      ZWorkspaceMetric(
        icon: tabs[_index].$2,
        value: tabs[_index].$1,
        emphasized: true,
      ),
      if (_mode == 0 || _mode == 1 || _mode == 3)
        ZWorkspaceMetric(
          icon: Icons.square_foot_outlined,
          value: '${widget.floor.walls.length}',
          label: 'стен',
        ),
      if (_mode == 0 || _mode == 3)
        ZWorkspaceMetric(
          icon: Icons.grid_view_outlined,
          value: '$roomCount',
          label: 'пом.',
        ),
      if (_mode == 1 || _mode == 2)
        ZWorkspaceMetric(
          icon: Icons.chair_alt_outlined,
          value: '${widget.floor.planObjects.length}',
          label: 'объектов',
        ),
      if (_mode == 2)
        ZWorkspaceMetric(
          icon: Icons.electrical_services_outlined,
          value: '${widget.floor.electricalPoints.length}',
          label: 'точек',
        ),
    ];

    return Scaffold(
      appBar: ZWorkspaceHeader(
        projectName: widget.project.name,
        floorName: widget.floor.name,
        modeLabel: _modeLabel,
        onCheck: _openMeasurementReview,
        onUndo: _historyIndex > 0 ? () => _travel(-1) : null,
        onRedo: _historyIndex < _history.length - 1 ? () => _travel(1) : null,
        canUndo: _historyIndex > 0,
        canRedo: _historyIndex < _history.length - 1,
        onMore: _showProjectActions,
      ),
      body: Column(
        children: [
          ZWorkspaceContextStrip(
            icon: contextIcon,
            title: contextTitle,
            subtitle: contextSubtitle,
            metrics: contextMetrics,
          ),
          // Layer legend belongs to the measurement workflow only. Keeping it
          // above 3D/equipment/elevations wastes precious mobile workspace.
          if (_mode == 0) const ZWorkspaceLayerLegend(),
          Expanded(child: IndexedStack(index: _index, children: screens)),
          ZWorkspaceSubnav(
            items: subItems,
            selectedIndex: modeTabs.indexOf(_index),
            onSelected: (localIndex) => _selectSubpage(modeTabs, localIndex),
          ),
          ZWorkspacePrimaryNav(
            selectedIndex: _mode,
            onSelected: _selectPrimaryMode,
            onHome: _goHome,
          ),
        ],
      ),
    );
  }
}
