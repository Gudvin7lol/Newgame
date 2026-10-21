import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_mode_context.dart';
import '../widgets/workspace_navigation.dart';
import '../widgets/zamer_ui_kit_v2.dart';
import '../widgets/zamer_fan_profiles_v2.dart';
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
  int _categoryIndex = 0;
  bool _taskActivated = false;
  String? _selectionKind;
  String _activeFanCommand = 'select';
  final ValueNotifier<String?> _objectFanCommands = ValueNotifier(null);
  int _objectCommandSerial = 0;
  OpeningType? _preferredOpeningType;
  ElectricalMode _electricalMode = ElectricalMode.select;
  ElectricalPointType _electricalType = ElectricalPointType.socket;
  ZMeasureViewMode _view = ZMeasureViewMode.twoD;
  MeasurePlanTool _planTool = MeasurePlanTool.select;

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
    _planTool = widget.planToolRequest.value == MeasurePlanTool.overview
        ? MeasurePlanTool.select : widget.planToolRequest.value;
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
    _objectFanCommands.dispose();
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
      _selectionKind = null;
      _taskActivated = true;
      _categoryIndex = switch (tool) {
        MeasurePlanTool.partition => 1,
        MeasurePlanTool.openings => 2,
        MeasurePlanTool.demolition => 3,
        MeasurePlanTool.dimensions => 4,
        _ => 0,
      };
      _activeFanCommand = switch (tool) {
        MeasurePlanTool.exterior || MeasurePlanTool.partition => 'straight',
        MeasurePlanTool.arc || MeasurePlanTool.precision => 'arc',
        MeasurePlanTool.openings => 'opening',
        MeasurePlanTool.nodes => 'nodes',
        MeasurePlanTool.demolition => 'segment',
        MeasurePlanTool.dimensions => 'measure',
        _ => 'select',
      };
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
          ],
        ),
      ],
    ),
  );

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
    // Re-selecting the active domain must preserve the current task and
    // any partially drawn geometry, as required by UI Kit 1.2.
    if (value == _layer) return;
    setState(() {
      _view = ZMeasureViewMode.twoD;
      _layer = value.clamp(0, _layers.length - 1).toInt();
      _categoryIndex = 0;
      _taskActivated = false;
      _selectionKind = null;
      _activeFanCommand = 'select';
      // Entry into a section always starts in selection, not construction.
      _planTool = MeasurePlanTool.select;
      _electricalMode = ElectricalMode.select;
      _electricalType = ElectricalPointType.socket;
    });
  }

  String get _fanContext {
    if (_layer == 0) {
      if (_selectionKind == 'wall') return 'plan.wall.selected';
      if (_selectionKind == 'node') return 'plan.nodes.edit';
      if (_selectionKind == 'door') return 'plan.door.selected';
      if (_selectionKind == 'window') return 'plan.window.selected';
      if (_selectionKind == 'room') return 'plan.room.selected';
      if (!_taskActivated) return 'plan.idle';
      return switch (_categoryIndex) {
        0 || 1 => 'plan.wall.create',
        2 => 'plan.opening.create',
        3 => 'plan.demolition.create',
        _ => 'plan.dimension.create',
      };
    }
    if (_layer == 1) return switch (_categoryIndex) {
      1 => 'floor.underlay.create',
      2 => 'floor.plinth.create',
      _ => 'floor.idle',
    };
    if (_layer == 2) return _selectionKind == 'object'
        ? 'objects.object.selected' : 'objects.idle';
    return switch (_categoryIndex) {
      0 || 1 => 'electrical.point.create',
      2 => 'electrical.light.create',
      3 => 'electrical.line.create',
      5 => 'electrical.group.create',
      _ => 'electrical.idle',
    };
  }

  static const _workingCommands = <String>{
    'select', 'wall', 'opening', 'straight', 'arc',
    'move', 'nodes', 'moveNode', 'measure',
    'door', 'window', 'segment', 'whole',
    'linearDimension', 'chainDimension',
    'add', 'point', 'singlePoint',
    'light', 'line', 'route',
    'rotate', 'duplicate', 'delete',
  };

  Set<String> get _availableFanActions {
    if (_layer == 2) {
      return _selectionKind == 'object'
          ? const {'select', 'move', 'rotate', 'duplicate', 'delete'}
          : const {'select', 'add'};
    }
    if (_layer == 0) {
      return const {'select', 'wall', 'opening', 'straight',
        'arc', 'move', 'nodes', 'moveNode', 'measure',
        'door', 'window', 'segment', 'whole',
        'linearDimension', 'chainDimension'};
    }
    if (_layer == 3) {
      return const {'select','point','singlePoint',
        'light','line','route'};
    }
    // The floor plan has working editing controls of its own. Future
    // radial operations remain locked until wired to their actual handler.
    return const {'select'};
  }

  void _selectTask(int value) {
    final options = ZamerKitNavigation.categories(_layer);
    if (value < 0 || value >= options.length) return;
    if (_taskActivated && value == _categoryIndex) return;
    setState(() {
      _categoryIndex = value;
      _taskActivated = true;
      _selectionKind = null;
      _activeFanCommand = 'select';
      _planTool = MeasurePlanTool.select;
      _preferredOpeningType = null;
      if (_layer == 3) {
        _electricalMode = ElectricalMode.select;
        _electricalType = switch (value) {
          1 => ElectricalPointType.switchPoint,
          2 => ElectricalPointType.ceilingLight,
          4 => ElectricalPointType.panel,
          _ => ElectricalPointType.socket,
        };
      }
    });
  }

  void _fanCommand(String id) {
    if (!_workingCommands.contains(id)) return;
    if (_layer == 0) {
      final planTool = switch (id) {
        'select' || 'move' => MeasurePlanTool.select,
        'wall' => MeasurePlanTool.exterior,
        'straight' => _categoryIndex == 1
            ? MeasurePlanTool.partition : MeasurePlanTool.exterior,
        'arc' => MeasurePlanTool.arc,
        'opening' || 'door' || 'window' => MeasurePlanTool.openings,
        'nodes' || 'moveNode' => MeasurePlanTool.nodes,
        'segment' || 'whole' => MeasurePlanTool.demolition,
        'measure' || 'linearDimension' || 'chainDimension' =>
          MeasurePlanTool.dimensions,
        _ => MeasurePlanTool.select,
      };
      setState(() {
        _planTool = planTool;
        _activeFanCommand = id;
        _preferredOpeningType = id == 'door' ? OpeningType.door
          : id == 'window' ? OpeningType.window : null;
        if (id == 'wall' || id == 'opening') {
          _taskActivated = true;
          _categoryIndex = id == 'wall' ? 0 : 2;
        }
        if (id == 'door' || id == 'window') _categoryIndex = 2;
        if (id == 'select') _selectionKind = null;
      });
      return;
    }
    if (_layer == 2) {
      if (id == 'add') {
        _openCatalogSheet();
        return;
      }
      if (_selectionKind == 'object' ||
          id == 'select' || id == 'move') {
        _objectFanCommands.value = '${++_objectCommandSerial}:$id';
        setState(() => _activeFanCommand = id);
      }
      return;
    }
    if (_layer == 3) {
      setState(() {
        _activeFanCommand = id;
        _electricalMode = switch (id) {
          'line' || 'route' => ElectricalMode.wire,
          'point' || 'singlePoint' || 'light' => ElectricalMode.add,
          _ => ElectricalMode.select,
        };
        if (id == 'light') _electricalType = ElectricalPointType.ceilingLight;
      });
      return;
    }
    if (id == 'select') {
      setState(() => _activeFanCommand = id);
    }
  }

  Widget _kitDomains() => Container(
    color: ZamerKitColors.bg,
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
    child: Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: KeyedSubtree(
            key: ValueKey('kit-v2-domain-$i'),
            child: ZamerKitSegment(
              label: ZamerKitNavigation.domains[i],
              icon: _layers[i].$2,
              selected: _layer == i,
              onTap: () => _selectLayer(i),
            ),
          )),
        ],
      ],
    ),
  );

  Widget _kitTasks() {
    final current = _layer < 4 ? _layer : 0;
    final categories = ZamerKitNavigation.categories(current);
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: ZamerKitColors.bg,
        border: Border(bottom: BorderSide(color: ZamerKitColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              key: const ValueKey('kit-v2-tasks'),
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 4),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final selected = _categoryIndex == index && _taskActivated;
                final icon = switch (current) {
                  0 => [Icons.border_outer_rounded, Icons.view_week_outlined,
                    Icons.door_front_door_outlined, Icons.auto_delete_outlined,
                    Icons.straighten_outlined][index],
                  1 => [Icons.grid_on_outlined, Icons.layers_outlined,
                    Icons.format_color_fill_outlined][index],
                  2 => Icons.chair_alt_outlined,
                  _ => [Icons.power_outlined, Icons.toggle_on_outlined,
                    Icons.lightbulb_outline, Icons.polyline_outlined,
                    Icons.electrical_services_outlined, Icons.hub_outlined][index],
                };
                return KeyedSubtree(
                  key: ValueKey('kit-v2-task-$index'),
                  child: ZamerKitSegment(
                    label: categories[index],
                    icon: icon,
                    selected: selected,
                    onTap: () => _selectTask(index),
                  ),
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('kit-v2-task-overflow'),
            onPressed: _showMoreTools,
            icon: const Icon(Icons.more_vert_rounded,
              color: ZamerKitColors.peach),
            tooltip: 'Все инструменты и разделы',
          ),
        ],
      ),
    );
  }

  void _showMoreTools() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerKitColors.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Инструменты замера',
                style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ZamerKitColors.text)),
              const SizedBox(height: 12),
              // Retain engineering and materials features without crowding
              // the four approved top-level tabs.
              ZWorkspaceSubnav(
                items: _layers,
                selectedIndex: _layer,
                onSelected: (value) {
                  Navigator.pop(ctx);
                  _selectLayer(value);
                },
              ),
              const SizedBox(height: 12),
              ZMeasureViewTabs(
                value: _view,
                enabledModes: const [
                  ZMeasureViewMode.twoD,
                  ZMeasureViewMode.threeD,
                  ZMeasureViewMode.photo,
                ],
                onChanged: (mode) {
                  Navigator.pop(ctx);
                  _selectView(mode);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Единый каталог мебели'),
                onTap: () { Navigator.pop(ctx); _openCatalogSheet(); },
              ),
            ],
          ),
        ),
      ),
    );
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
          singleFurnitureView: true,
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
        nativeKitV2: true,
        preferredOpeningType: _preferredOpeningType,
        onSelectionChanged: (kind) {
          if (mounted && kind != _selectionKind) {
            setState(() => _selectionKind = kind);
          }
        },
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
        fanCommand: _objectFanCommands,
        onSelectedObjectChanged: (object) {
          if (!mounted) return;
          final kind = object == null ? null : 'object';
          if (kind != _selectionKind) {
            setState(() {
              _selectionKind = kind;
              _activeFanCommand = 'select';
            });
          }
        },
      ),
      ElectricalScreen(
        floor: widget.floor,
        onChanged: widget.onChanged,
        requestedMode: _electricalMode,
        requestedType: _electricalType,
      ),
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
          _kitDomains(),
          if (_layer < 4)
            _kitTasks()
          else
            Container(
              height: 56,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: ZamerKitColors.bg,
              child: Text(_layers[_layer].$1,
                style: const TextStyle(color: ZamerKitColors.muted,
                  fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(index: _layer, children: pages),
                ),
                if (_layer < 4)
                  Positioned(
                    right: 64,
                    bottom: 18,
                    child: ZamerKitFan(
                      key: const ValueKey('zamer-live-native-v2-fan'),
                      contextId: '${_fanContext}:${_categoryIndex}',
                      selectedCommand: _activeFanCommand,
                      first: ZamerFanProfilesV2.of(_fanContext,
                        enabledActions: _availableFanActions).first,
                      second: ZamerFanProfilesV2.of(_fanContext,
                        enabledActions: _availableFanActions).second,
                      outer: ZamerFanProfilesV2.of(_fanContext,
                        enabledActions: _availableFanActions).outer,
                      onCommand: _fanCommand,
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
