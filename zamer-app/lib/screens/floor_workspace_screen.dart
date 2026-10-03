import 'dart:convert';

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';
import '../services/object_catalog.dart';
import '../services/report_service.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
import '../widgets/workspace_navigation.dart';
import 'elevations_screen.dart';
import 'electrical_screen.dart';
import 'engineering_screen.dart';
import 'floor_3d_screen.dart';
import 'layouts_screen.dart';
import 'master_equipment_screen.dart';
import 'materials_screen.dart';
import 'measure_concept_workspace_screen.dart';
import 'measurement_review_screen.dart';
import 'photo_studio_screen.dart';
import 'plan_editor_production_screen.dart';
import 'plan_editor_screen.dart';
import 'plan_geometry_tools_screen.dart';
import 'planning_objects_screen.dart';
import 'projects_screen.dart';
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

  final _lastByMode = [0, 8, 9, 2];
  static const _modeTabs = <List<int>>[
    [0, 1],
    [8],
    [9, 5, 4, 6],
    [2, 3, 7],
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

  Future<void> _addEquipment(ObjectCatalogItem item) async {
    final object = EquipmentPlacementService.addCatalogItem(
      floor: widget.floor,
      item: item,
    );
    try {
      GeometryService.syncRoomMetadata(widget.floor);
      await widget.onChanged();
      _recordHistory();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} добавлен и сохранён'),
          action: SnackBarAction(
            label: 'РАЗМЕСТИТЬ',
            onPressed: () => setState(() {
              _index = 5;
              _lastByMode[2] = 5;
            }),
          ),
        ),
      );
    } catch (error) {
      EquipmentPlacementService.removeObject(
        floor: widget.floor,
        object: object,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить объект: $error')),
      );
    }
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

  void _openObjectsFromMeasure() {
    setState(() {
      _index = 5;
      _lastByMode[2] = 5;
    });
  }

  void _openCatalogFromMeasure() {
    setState(() {
      _index = 9;
      _lastByMode[2] = 9;
    });
  }

  Future<void> _openGeometryTools({
    PlanGeometryTool initialTool = PlanGeometryTool.radius,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlanGeometryToolsScreen(
          floor: widget.floor,
          onChanged: _changed,
          initialTool: initialTool,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAdvancedEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Расширенный редактор')),
          body: PlanEditorScreen(floor: widget.floor, onChanged: _changed),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _selectMeasureView(ZMeasureViewMode view) async {
    switch (view) {
      case ZMeasureViewMode.twoD:
        if (!_modeTabs[0].contains(_index)) {
          setState(() => _index = _lastByMode[0]);
        }
      case ZMeasureViewMode.threeD:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text('${widget.project.name} • ${widget.floor.name}'),
              ),
              body: Floor3DScreen(floor: widget.floor),
            ),
          ),
        );
      case ZMeasureViewMode.photo:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PhotoStudioScreen(
              floor: widget.floor,
              rotation: -.65,
              tilt: .82,
              zoom: .92,
              pan: Offset.zero,
            ),
          ),
        );
    }
  }

  Future<void> _switchFloor(FloorPlan floor) async {
    if (floor.id == widget.floor.id || !mounted) return;
    final mode = _mode < 0 ? 0 : _mode;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorWorkspaceScreen(
          project: widget.project,
          floor: floor,
          onChanged: widget.onChanged,
          initialMode: mode,
        ),
      ),
    );
  }

  Future<void> _addFloor() async {
    final nextNumber = widget.project.floors.length + 1;
    final floor = FloorPlan(
      id: 'f-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Этаж $nextNumber',
    );
    widget.project.floors.add(floor);
    await widget.onChanged();
    if (mounted) await _switchFloor(floor);
  }

  Future<void> _showFloorPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      barrierColor: Colors.black.withValues(alpha: .70),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Этажи', style: ZamerTypography.h3),
              const SizedBox(height: 8),
              for (final floor in widget.project.floors)
                ZActionTile(
                  icon: floor.id == widget.floor.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  title: floor.name,
                  subtitle: floor.id == widget.floor.id
                      ? 'Текущий этаж'
                      : '${floor.walls.length} стен',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _switchFloor(floor);
                  },
                ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _addFloor();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить этаж'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openProjects() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
    );
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

  Widget _roomRequiredState(String title) {
    return ZEmptyState(
      icon: Icons.grid_off_outlined,
      title: '$title пока недоступны',
      subtitle:
          'Сначала замкни контур помещения в «Замере». После этого рабочая область сформируется автоматически.',
      actionLabel: 'Перейти в Замер',
      onAction: () => setState(() {
        _index = 0;
        _lastByMode[0] = 0;
      }),
    );
  }

  Future<void> _showProjectActions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      barrierColor: Colors.black.withValues(alpha: .70),
      showDragHandle: true,
      builder: (sheetContext) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: ZamerColors.white,
                displayColor: ZamerColors.white,
              ),
          iconTheme: const IconThemeData(color: ZamerColors.gray300),
        ),
        child: ZSheetFrame(
          title: 'Действия проекта',
          description: '${widget.project.name} • ${widget.floor.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZActionTile(
                icon: Icons.layers_outlined,
                title: 'Этажи',
                subtitle: 'Переключить или добавить этаж',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showFloorPicker();
                },
              ),
              ZActionTile(
                icon: Icons.architecture_outlined,
                title: 'Радиусы и узлы',
                subtitle: 'Production-инструменты точной геометрии',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openGeometryTools();
                },
              ),
              ZActionTile(
                icon: Icons.tune_rounded,
                title: 'Расширенный редактор',
                subtitle: 'Старые дополнительные режимы до полного переноса',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAdvancedEditor();
                },
              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomCount = GeometryService.roomFaces(widget.floor).length;
    final hasRooms = roomCount > 0;

    if (_mode == 0) {
      return MeasureConceptWorkspaceScreen(
        project: widget.project,
        floor: widget.floor,
        onChanged: _changed,
        onUndo: _historyIndex > 0 ? () => _travel(-1) : null,
        onRedo: _historyIndex < _history.length - 1 ? () => _travel(1) : null,
        canUndo: _historyIndex > 0,
        canRedo: _historyIndex < _history.length - 1,
        onMore: _showProjectActions,
        onOpen3D: () => _selectMeasureView(ZMeasureViewMode.threeD),
        onOpenPhoto: () => _selectMeasureView(ZMeasureViewMode.photo),
        onOpenObjects: _openObjectsFromMeasure,
        onOpenReview: _openMeasurementReview,
        onOpenGeometry: _openGeometryTools,
        onOpenFloors: _showFloorPicker,
        onOpenSettings: _showProjectActions,
        onHome: _goHome,
        onProjects: _openProjects,
        onCatalog: _openCatalogFromMeasure,
      );
    }

    final screens = [
      PlanEditorProductionScreen(
        floor: widget.floor,
        onChanged: _changed,
        onOpenObjects: _openObjectsFromMeasure,
        onOpenReview: _openMeasurementReview,
        onOpenAdvanced: _openGeometryTools,
      ),
      RoomsScreen(floor: widget.floor, onChanged: _changed),
      hasRooms
          ? ElevationsScreen(floor: widget.floor, onChanged: _changed)
          : _roomRequiredState('Развёртки стен'),
      hasRooms
          ? LayoutsScreen(floor: widget.floor, onChanged: _changed)
          : _roomRequiredState('Раскладки пола'),
      ElectricalScreen(floor: widget.floor, onChanged: _changed),
      PlanningObjectsScreen(floor: widget.floor, onChanged: _changed),
      EngineeringScreen(floor: widget.floor, onChanged: _changed),
      hasRooms
          ? MaterialsScreen(
              floor: widget.floor,
              project: widget.project,
              onChanged: _changed,
            )
          : _roomRequiredState('Материалы и отделка'),
      _index == 8
          ? Floor3DScreen(
              key: ValueKey(
                '3d-${widget.floor.nodes.length}-${widget.floor.walls.length}-'
                '${widget.floor.planObjects.length}-${widget.floor.electricalPoints.length}',
              ),
              floor: widget.floor,
            )
          : const SizedBox.shrink(),
      MasterEquipmentScreen(
        projectTitle: widget.project.name,
        embedded: true,
        onAdd: _addEquipment,
      ),
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
      ('Каталог', Icons.category_outlined),
    ];

    final modeTabs = _modeTabs[_mode];
    final subItems = [for (final i in modeTabs) tabs[i]];
    final contextTitle = switch (_mode) {
      1 => 'Пространственная модель',
      2 => 'Комплектация объекта',
      _ => 'Рабочая документация',
    };
    final contextSubtitle = switch (_mode) {
      1 => 'Realtime-сцена, прогулка и фоторендер',
      2 => 'Каталог, размещение, электрика и инженерия',
      _ => 'Развёртки стен, раскладки пола и материалы',
    };
    final contextIcon = switch (_mode) {
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
      if (_mode == 1 || _mode == 3)
        ZWorkspaceMetric(
          icon: Icons.square_foot_outlined,
          value: '${widget.floor.walls.length}',
          label: 'стен',
        ),
      if (_mode == 3)
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
