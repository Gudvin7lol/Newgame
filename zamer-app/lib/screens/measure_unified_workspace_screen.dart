import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../widgets/measure_shared_layer_canvas.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
import '../widgets/workspace_navigation.dart';
import 'electrical_screen.dart';
import 'engineering_screen.dart';
import 'master_equipment_screen.dart';
import 'materials_screen.dart';
import 'measure_floor_plan_layer_screen.dart';
import 'plan_editor_production_screen.dart';
import 'planning_objects_screen.dart';

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
    required this.onOpenGeometry,
    required this.onOpenFloors,
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
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
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

  static const _layers = <(String, IconData)>[
    ('План', Icons.architecture_outlined),
    ('Пол', Icons.grid_4x4_outlined),
    ('Объекты', Icons.chair_alt_outlined),
    ('Электрика', Icons.electrical_services_outlined),
    ('Инженерия', Icons.plumbing_outlined),
    ('Материалы', Icons.inventory_2_outlined),
  ];

  bool get _usesSharedCanvas => _layer >= 2 && _layer <= 4;

  MeasureSharedLayer get _sharedLayer => switch (_layer) {
        3 => MeasureSharedLayer.electrical,
        4 => MeasureSharedLayer.engineering,
        _ => MeasureSharedLayer.objects,
      };

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

  Future<void> _openSharedLayerEditor(MeasureSharedLayer layer) async {
    final title = switch (layer) {
      MeasureSharedLayer.objects => 'Объекты',
      MeasureSharedLayer.electrical => 'Электрика',
      MeasureSharedLayer.engineering => 'Инженерия',
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .70),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .92,
        child: Scaffold(
          backgroundColor: ZamerColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('$title • точный редактор'),
            actions: [
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          body: switch (layer) {
            MeasureSharedLayer.objects => PlanningObjectsScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
              ),
            MeasureSharedLayer.electrical => ElectricalScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
              ),
            MeasureSharedLayer.engineering => EngineeringScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
              ),
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
          ZWorkspaceContextStrip(
            icon: _layers[_layer].$2,
            title: _layers[_layer].$1,
            subtitle: switch (_layer) {
              0 => 'Геометрия, проёмы, размеры и помещения',
              1 => 'Раскладка покрытия прямо на измеренном плане',
              2 => 'Один CAD: выбирай, двигай и вращай объекты на плане',
              3 => 'Один CAD: точки и линии электрики поверх измеренного плана',
              4 => 'Один CAD: вода, канализация и отопление поверх плана',
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
          ZWorkspaceSubnav(
            items: _layers,
            selectedIndex: _layer,
            onSelected: _selectLayer,
          ),
          Expanded(
            child: Stack(
              children: [
                Offstage(
                  offstage: _layer != 0,
                  child: PlanEditorProductionScreen(
                    floor: widget.floor,
                    onChanged: widget.onChanged,
                    onOpenObjects: () => _selectLayer(2),
                    onOpenReview: widget.onOpenReview,
                    onOpenAdvanced: widget.onOpenGeometry,
                    onOpen3D: widget.onOpen3D,
                    onOpenFloors: widget.onOpenFloors,
                    onOpenSettings: widget.onMore,
                    onOpenMaterials: () => _selectLayer(5),
                    onUndo: widget.onUndo,
                    onRedo: widget.onRedo,
                    canUndo: widget.canUndo,
                    canRedo: widget.canRedo,
                  ),
                ),
                Offstage(
                  offstage: _layer != 1,
                  child: MeasureFloorPlanLayerScreen(
                    floor: widget.floor,
                    onChanged: widget.onChanged,
                  ),
                ),
                Offstage(
                  offstage: !_usesSharedCanvas,
                  child: MeasureSharedLayerCanvas(
                    floor: widget.floor,
                    layer: _sharedLayer,
                    onChanged: widget.onChanged,
                    onOpenCatalog: _openCatalogSheet,
                    onOpenAdvancedEditor: () =>
                        _openSharedLayerEditor(_sharedLayer),
                  ),
                ),
                Offstage(
                  offstage: _layer != 5,
                  child: MaterialsScreen(
                    floor: widget.floor,
                    project: widget.project,
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
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
}
