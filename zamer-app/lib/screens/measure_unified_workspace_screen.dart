import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
import '../widgets/workspace_navigation.dart';
import 'electrical_screen.dart';
import 'engineering_screen.dart';
import 'master_equipment_screen.dart';
import 'materials_master_screen.dart';
import 'measure_floor_plan_layer_screen.dart';
import 'plan_editor_production_screen.dart';
import 'measure_plan_tool.dart';
export 'measure_plan_tool.dart' show MeasurePlanTool;
import 'planning_objects_screen.dart';

/// Every plan operation is available in the same Measure workspace.
/// No basic/advanced editor navigation or duplicate app-level section.
/// The field-first Measure workspace.
///
/// Geometry, flooring, furniture, electrical, engineering and materials are
/// layers of one measured plan instead of separate top-level app sections.
class MeasureUnifiedWorkspaceScreen extends StatefulWidget {
  const MeasureUnifiedWorkspaceScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onMore,
    required this.onOpen3D,
    required this.onOpenPhoto,
    required this.onOpenReview,
    required this.planToolRequest,
    required this.onOpenFloors,
    required this.onOpenRooms,
    required this.onScanPlan,
    required this.onExportPdf,
    required this.onHome,
    required this.onCatalog,
    required this.onProfile,
    required this.onPrimaryMode,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onMore;
  final VoidCallback onOpen3D;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenReview;
  final ValueListenable<MeasurePlanTool> planToolRequest;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenRooms;
  final VoidCallback onScanPlan;
  final VoidCallback onExportPdf;
  final VoidCallback onHome;
  final VoidCallback onCatalog;
  final VoidCallback onProfile;
  final ValueChanged<int> onPrimaryMode;

  @override
  State<MeasureUnifiedWorkspaceScreen> createState() =>
      _MeasureUnifiedWorkspaceScreenState();
}

class _MeasureUnifiedWorkspaceScreenState
    extends State<MeasureUnifiedWorkspaceScreen> {
  int _layer = 0;
  ZMeasureViewMode _view = ZMeasureViewMode.twoD;
  MeasurePlanTool _planTool = MeasurePlanTool.overview;

  static const _planTools = <(MeasurePlanTool, String, IconData)>[
    (MeasurePlanTool.overview, 'Обзор', Icons.dashboard_customize_outlined),
    (MeasurePlanTool.select, 'Выбрать', Icons.ads_click_outlined),
    (MeasurePlanTool.nodes, 'Узлы', Icons.adjust_rounded),
    (MeasurePlanTool.exterior, 'Стены', Icons.home_work_outlined),
    (MeasurePlanTool.partition, 'Перегородки', Icons.view_week_outlined),
    (MeasurePlanTool.arc, 'Дуги', Icons.architecture_outlined),
    (MeasurePlanTool.precision, 'Радиусы', Icons.radio_button_unchecked_outlined),
    (MeasurePlanTool.openings, 'Проёмы', Icons.door_front_door_outlined),
    (MeasurePlanTool.demolition, 'Демонтаж', Icons.auto_delete_outlined),
    (MeasurePlanTool.dimensions, 'Размеры', Icons.square_foot_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _planTool = widget.planToolRequest.value;
    widget.planToolRequest.addListener(_handlePlanToolRequest);
  }

  @override
  void didUpdateWidget(covariant MeasureUnifiedWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planToolRequest != widget.planToolRequest) {
      oldWidget.planToolRequest.removeListener(_handlePlanToolRequest);
      widget.planToolRequest.addListener(_handlePlanToolRequest);
      _handlePlanToolRequest();
    }
  }

  @override
  void dispose() {
    widget.planToolRequest.removeListener(_handlePlanToolRequest);
    super.dispose();
  }

  void _handlePlanToolRequest() {
    _selectPlanTool(widget.planToolRequest.value);
  }

  void _selectPlanTool(MeasurePlanTool tool) {
    if (!mounted) return;
    setState(() {
      _planTool = tool;
      _view = ZMeasureViewMode.twoD;
      _layer = 0;
    });
  }

  // One compact row of tools and a project-action overflow.
  Widget _planToolbar() => Container(
    height: 46,
    padding: const EdgeInsets.fromLTRB(7, 3, 2, 3),
    decoration: const BoxDecoration(
      color: ZamerColors.surfaceLow,
      border: Border(bottom: BorderSide(color: ZamerColors.outlineSoft)),
    ),
    child: Row(
      children: [
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _planTools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (_, index) {
              final (tool, label, icon) = _planTools[index];
              final selected = _planTool == tool;
              return Tooltip(
                message: label,
                child: Material(
                  color: selected ? ZamerColors.accent : ZamerColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    key: ValueKey('measure-tool-${tool.name}'),
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => _selectPlanTool(tool),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 17,
                            color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(label, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: selected ? ZamerColors.accentInk : ZamerColors.textPrimary,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('measure-plan-more'),
          tooltip: 'Операции проекта',
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onSelected: (action) => switch (action) {
            'import' => widget.onScanPlan(),
            'rooms' => widget.onOpenRooms(),
            'floors' => widget.onOpenFloors(),
            'catalog' => _openCatalogSheet(),
            'review' => widget.onOpenReview(),
            'pdf' => widget.onExportPdf(),
            'photo' => widget.onOpenPhoto(),
            'help' => _showQuickGuide(),
            _ => widget.onMore(),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'import', child: Text('Импорт плана')),
            PopupMenuItem(value: 'rooms', child: Text('Помещения')),
            PopupMenuItem(value: 'floors', child: Text('Этажи')),
            PopupMenuItem(value: 'catalog', child: Text('Каталог')),
            PopupMenuItem(value: 'review', child: Text('Проверка обмера')),
            PopupMenuItem(value: 'pdf', child: Text('PDF')),
            PopupMenuItem(value: 'photo', child: Text('Фото')),
            PopupMenuItem(
              value: 'help',
              child: Text('Как пользоваться'),
            ),
          ],
        ),
      ],
    ),
  );

  void _showQuickGuide() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.help_outline_rounded),
                title: Text('Быстрый старт'),
                subtitle: Text('Все операции выполняются на одном плане'),
              ),
              const ListTile(
                leading: CircleAvatar(radius: 16, child: Text('1')),
                title: Text('Стены'),
                subtitle: Text('Выберите «Стены» и укажите начало и конец. '
                    'Нажмите «Стоп» для завершения цепочки.'),
              ),
              const ListTile(
                leading: CircleAvatar(radius: 16, child: Text('2')),
                title: Text('Выбор и размеры'),
                subtitle: Text('В «Выбрать» нажмите стену для её свойств. '
                    '«Узлы» позволяют двигать точки с привязками.'),
              ),
              const ListTile(
                leading: CircleAvatar(radius: 16, child: Text('3')),
                title: Text('Привязки и слои'),
                subtitle: Text('Сетка, привязки и «Слои» находятся прямо '
                    'над холстом. В «Слои» можно скрывать категории, '
                    'включать красные маркеры проверенных коллизий.'),
              ),
              const ListTile(
                leading: CircleAvatar(radius: 16, child: Text('4')),
                title: Text('Проверка и документы'),
                subtitle: Text('Откройте меню ⋮ справа от инструментов: '
                    'там есть проверка обмера, PDF и импорт.'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Понятно'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _layers = <(String, IconData)>[
    ('План', Icons.architecture_outlined),
    ('Пол', Icons.grid_4x4_outlined),
    ('Объекты', Icons.chair_alt_outlined),
    ('Электрика', Icons.electrical_services_outlined),
    ('Инженерия', Icons.plumbing_outlined),
    ('Материалы', Icons.inventory_2_outlined),
  ];

  void _selectView(ZMeasureViewMode value) {
    if (value == ZMeasureViewMode.twoD) {
      if (_view != value) setState(() => _view = value);
      return;
    }
    if (value == ZMeasureViewMode.threeD) {
      widget.onOpen3D();
      return;
    }
    if (value == ZMeasureViewMode.photo) {
      widget.onOpenPhoto();
    }
  }

  void _selectLayer(int value) {
    setState(() {
      _view = ZMeasureViewMode.twoD;
      _layer = value.clamp(0, _layers.length - 1).toInt();
    });
  }

  Future<void> _openCatalogSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .88,
        child: MasterEquipmentScreen(
          projectTitle: widget.project.name,
          embedded: true,
          onAdd: (item) {
            () async {
              final object = EquipmentPlacementService.addCatalogItem(
                floor: widget.floor,
                item: item,
              );
              try {
                await widget.onChanged();
                if (!mounted) return;
                setState(() {
                  _view = ZMeasureViewMode.twoD;
                  _layer = 2;
                });
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1200),
                      content: Text(
                        '${item.name} добавлен. Перемещай и вращай его прямо на плане.',
                      ),
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
            }();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_layer == 5) {
      return Scaffold(
        backgroundColor: ZamerColors.background,
        appBar: ZWorkspaceHeader(
          projectName: widget.project.name,
          floorName: widget.floor.name,
          modeLabel: 'ЗАМЕР',
          onCheck: widget.onOpenReview,
          onUndo: widget.onUndo,
          onRedo: widget.onRedo,
          canUndo: widget.canUndo,
          canRedo: widget.canRedo,
          onMore: widget.onMore,
        ),
        body: Column(
          children: [
            Expanded(
              child: MaterialsMasterScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
                onClose: () => _selectLayer(0),
              ),
            ),
            ZWorkspacePrimaryNav(
              selectedIndex: 0,
              onSelected: widget.onPrimaryMode,
              onHome: widget.onHome,
              onProfile: widget.onProfile,
            ),
          ],
        ),
      );
    }

    final pages = <Widget>[
      // Persistent plan renderer for all tool modes. No second CAD screen.
      PlanEditorProductionScreen(
        floor: widget.floor,
        onChanged: widget.onChanged,
        planTool: _planTool,
        onOpenObjects: () => _selectLayer(2),
        onOpenReview: widget.onOpenReview,
        onOpenPlanGeometry: () => _selectPlanTool(MeasurePlanTool.precision),
        onOpen3D: widget.onOpen3D,
        onOpenFloors: widget.onOpenFloors,
        onOpenSettings: widget.onMore,
        onOpenMaterials: () => _selectLayer(5),
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        canUndo: widget.canUndo,
        canRedo: widget.canRedo,
      ),
      MeasureFloorPlanLayerScreen(
        floor: widget.floor,
        onChanged: widget.onChanged,
      ),
      PlanningObjectsScreen(
        floor: widget.floor,
        onChanged: widget.onChanged,
        embedded: true,
      ),
      ElectricalScreen(floor: widget.floor, onChanged: widget.onChanged),
      EngineeringScreen(floor: widget.floor, onChanged: widget.onChanged),
      MaterialsMasterScreen(
        floor: widget.floor,
        onChanged: widget.onChanged,
      ),
    ];

    return Scaffold(
      backgroundColor: ZamerColors.background,
      appBar: ZWorkspaceHeader(
        projectName: widget.project.name,
        floorName: widget.floor.name,
        modeLabel: 'ЗАМЕР',
        onCheck: widget.onOpenReview,
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        canUndo: widget.canUndo,
        canRedo: widget.canRedo,
        onMore: widget.onMore,
      ),
      body: Column(
        children: [
          if (_layer != 0) ...[
            ZWorkspaceContextStrip(
              icon: _layers[_layer].$2,
              title: _layers[_layer].$1,
              subtitle: switch (_layer) {
                0 => 'Геометрия, проёмы, размеры и помещения',
                1 => 'Раскладка покрытия прямо на измеренном плане',
                2 => 'Добавление, перемещение и вращение объектов на плане',
                3 => 'Розетки, выключатели, свет и группы',
                4 => 'Вода, канализация, отопление и трассы',
                _ => 'Отделка стен, пола и потолка',
              },
              metrics: [
                ZWorkspaceMetric(
                  icon: Icons.square_foot_outlined,
                  value: '${widget.floor.walls.length}',
                  label: 'стен',
                ),
                ZWorkspaceMetric(
                  icon: Icons.chair_alt_outlined,
                  value: '${widget.floor.planObjects.length}',
                  label: 'объектов',
                ),
                ZWorkspaceMetric(
                  icon: Icons.electrical_services_outlined,
                  value: '${widget.floor.electricalPoints.length}',
                  label: 'точек',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ZMeasureViewTabs(
                      value: _view,
                      enabledModes: const [
                        ZMeasureViewMode.twoD,
                        ZMeasureViewMode.threeD,
                        ZMeasureViewMode.photo,
                      ],
                      onChanged: _selectView,
                    ),
                  ),
                  if (_layer == 2) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _openCatalogSheet,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Каталог'),
                    ),
                  ],
                ],
              ),
            ),
  
          ],
          ZWorkspaceSubnav(
            items: _layers,
            selectedIndex: _layer,
            onSelected: _selectLayer,
          ),
          if (_layer == 0) _planToolbar(),
          Expanded(
            child: IndexedStack(index: _layer, children: pages),
          ),
          ZWorkspacePrimaryNav(
            selectedIndex: 0,
            onSelected: widget.onPrimaryMode,
            onHome: widget.onHome,
            onProfile: widget.onProfile,
          ),
        ],
      ),
    );
  }
}
