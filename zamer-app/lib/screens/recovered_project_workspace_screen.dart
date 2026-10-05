import 'dart:convert';

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';
import '../services/object_catalog.dart';
import '../services/report_service.dart';
import '../widgets/recovered_workspace_navigation.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
import '../widgets/workspace_navigation.dart';
import 'floor_3d_screen.dart';
import 'layered_elevations_screen.dart';
import 'master_equipment_screen.dart';
import 'master_object_placement_workspace.dart';
import 'master_profile_screen.dart';
import 'measurement_review_screen.dart';
import 'photo_studio_screen.dart';
import 'plan_geometry_tools_screen.dart';
import 'recovered_measure_workspace_screen.dart';
import 'scan_plan_screen.dart';

/// Unified recovery shell after the +108 branch split.
///
/// It deliberately composes the newest functional screens instead of
/// restoring an old FloorWorkspace implementation.
class RecoveredProjectWorkspaceScreen extends StatefulWidget {
  const RecoveredProjectWorkspaceScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    this.initialMode = 0,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  /// 0 = Measure, 1 = 3D, 2 = Equipment, 3 = Elevations.
  final int initialMode;

  @override
  State<RecoveredProjectWorkspaceScreen> createState() =>
      _RecoveredProjectWorkspaceScreenState();
}

class _RecoveredProjectWorkspaceScreenState
    extends State<RecoveredProjectWorkspaceScreen> {
  int _mode = 0;
  int _equipmentPage = 0;
  final _history = <String>[];
  int _historyIndex = 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode.clamp(0, 3).toInt();
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

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(widget.floor);
    _recordHistory();
    await widget.onChanged();
    if (mounted) setState(() {});
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

  void _selectPrimaryMode(int mode) {
    final next = mode.clamp(0, 3).toInt();
    if (next == _mode) return;
    setState(() => _mode = next);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openMeasurementReview() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MeasurementReviewScreen(floor: widget.floor),
      ),
    );
  }

  Future<void> _openGeometryTools({
    PlanGeometryTool initialTool = PlanGeometryTool.radius,
  }) async {
    await Navigator.push<void>(
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

  Future<void> _openPhoto() async {
    await Navigator.push<void>(
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

  Future<void> _scanOrImport() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScanPlanScreen(
          floor: widget.floor,
          onChanged: _changed,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (profileContext) => MasterProfileScreen(
          project: widget.project,
          projectCount: 1,
          onBack: () => Navigator.pop(profileContext),
          onHome: () {
            Navigator.pop(profileContext);
            _goHome();
          },
          onOpenMeasure: () {
            Navigator.pop(profileContext);
            _selectPrimaryMode(0);
          },
          onOpen3D: () {
            Navigator.pop(profileContext);
            _selectPrimaryMode(1);
          },
          onOpenElevations: () {
            Navigator.pop(profileContext);
            _selectPrimaryMode(3);
          },
        ),
      ),
    );
  }

  Future<void> _switchFloor(FloorPlan floor) async {
    if (floor.id == widget.floor.id || !mounted) return;
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecoveredProjectWorkspaceScreen(
          project: widget.project,
          floor: floor,
          onChanged: widget.onChanged,
          initialMode: _mode,
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

  Future<void> _addEquipment(ObjectCatalogItem item) async {
    final object = EquipmentPlacementService.addCatalogItem(
      floor: widget.floor,
      item: item,
    );
    try {
      await _changed();
      if (!mounted) return;
      setState(() => _equipmentPage = 1);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            content: Text('${item.name} добавлен. Размести его на плане.'),
          ),
        );
    } catch (error) {
      EquipmentPlacementService.removeObject(
        floor: widget.floor,
        object: object,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить объект: $error')),
        );
      }
    }
  }

  Future<void> _showProjectActions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      barrierColor: Colors.black.withValues(alpha: .70),
      showDragHandle: true,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Действия проекта',
        description: '${widget.project.name} • ${widget.floor.name}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.layers_outlined,
              title: 'Этажи',
              subtitle: 'Переключить или добавить этаж внутри проекта',
              onTap: () {
                Navigator.pop(sheetContext);
                _showFloorPicker();
              },
            ),
            ZActionTile(
              icon: Icons.category_outlined,
              title: 'Оснащение',
              subtitle: 'Каталог и размещение объектов',
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _mode = 2);
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
            ZActionTile(
              icon: Icons.architecture_outlined,
              title: 'Радиусы и узлы',
              subtitle: 'Точная геометрия стен',
              onTap: () {
                Navigator.pop(sheetContext);
                _openGeometryTools();
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
              subtitle: 'Документация текущего этажа',
              onTap: () {
                Navigator.pop(sheetContext);
                ReportService.shareFloorPdf(widget.project, widget.floor);
              },
            ),
            ZActionTile(
              icon: Icons.person_outline_rounded,
              title: 'Профиль',
              onTap: () {
                Navigator.pop(sheetContext);
                _openProfile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryMode({
    required String label,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final roomCount = GeometryService.roomFaces(widget.floor).length;
    return Scaffold(
      backgroundColor: ZamerColors.background,
      appBar: ZWorkspaceHeader(
        projectName: widget.project.name,
        floorName: widget.floor.name,
        modeLabel: label,
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
            icon: icon,
            title: title,
            subtitle: subtitle,
            metrics: [
              ZWorkspaceMetric(
                icon: Icons.square_foot_outlined,
                value: '${widget.floor.walls.length}',
                label: 'стен',
              ),
              ZWorkspaceMetric(
                icon: Icons.grid_view_outlined,
                value: '$roomCount',
                label: 'пом.',
              ),
              ZWorkspaceMetric(
                icon: Icons.chair_alt_outlined,
                value: '${widget.floor.planObjects.length}',
                label: 'объектов',
              ),
            ],
          ),
          Expanded(child: child),
          ZRecoveredWorkspacePrimaryNav(
            selectedIndex: _mode,
            onSelected: _selectPrimaryMode,
            onHome: _goHome,
            onProfile: _openProfile,
          ),
        ],
      ),
    );
  }

  Widget _equipmentMode() {
    const tabs = <(String, IconData)>[
      ('Каталог', Icons.grid_view_rounded),
      ('Размещение', Icons.open_with_rounded),
    ];
    return _secondaryMode(
      label: 'ОСНАЩЕНИЕ',
      title: _equipmentPage == 0 ? 'Каталог объектов' : 'Размещение объектов',
      subtitle: _equipmentPage == 0
          ? 'Мебель, сантехника, техника, свет, двери и окна'
          : 'Перемещение, вращение, дублирование и удаление на плане',
      icon: Icons.chair_alt_outlined,
      child: Column(
        children: [
          ZWorkspaceSubnav(
            items: tabs,
            selectedIndex: _equipmentPage,
            onSelected: (value) => setState(() => _equipmentPage = value),
          ),
          Expanded(
            child: IndexedStack(
              index: _equipmentPage,
              children: [
                MasterEquipmentScreen(
                  projectTitle: widget.project.name,
                  embedded: true,
                  onAdd: (item) => _addEquipment(item),
                ),
                MasterObjectPlacementWorkspace(
                  floor: widget.floor,
                  onChanged: _changed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == 0) {
      return RecoveredMeasureWorkspaceScreen(
        project: widget.project,
        floor: widget.floor,
        onChanged: _changed,
        onUndo: _historyIndex > 0 ? () => _travel(-1) : null,
        onRedo: _historyIndex < _history.length - 1 ? () => _travel(1) : null,
        canUndo: _historyIndex > 0,
        canRedo: _historyIndex < _history.length - 1,
        onMore: _showProjectActions,
        onOpen3D: () => _selectPrimaryMode(1),
        onOpenPhoto: _openPhoto,
        onOpenReview: _openMeasurementReview,
        onOpenGeometry: _openGeometryTools,
        onOpenFloors: _showFloorPicker,
        onHome: _goHome,
        onProfile: _openProfile,
        onPrimaryMode: _selectPrimaryMode,
      );
    }

    if (_mode == 1) {
      return _secondaryMode(
        label: '3D',
        title: 'Пространственная модель',
        subtitle: 'Realtime-сцена, прогулка и фоторендер',
        icon: Icons.view_in_ar_outlined,
        child: Floor3DScreen(floor: widget.floor),
      );
    }

    if (_mode == 2) return _equipmentMode();

    return _secondaryMode(
      label: 'РАЗВЁРТКИ',
      title: 'Развёртки и рабочая документация',
      subtitle: 'Стены, проёмы, электрика, инженерия, объекты и отделка',
      icon: Icons.view_carousel_outlined,
      child: LayeredElevationsScreen(
        project: widget.project,
        floor: widget.floor,
        onChanged: _changed,
      ),
    );
  }
}
