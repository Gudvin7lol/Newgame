import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../services/report_service.dart';
import '../widgets/elevation_painter.dart';
import 'elevations_screen.dart';
import 'layouts_screen.dart';
import 'materials_screen.dart';

class MasterElevationsProductionScreen extends StatefulWidget {
  const MasterElevationsProductionScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    this.onBack,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onBack;

  @override
  State<MasterElevationsProductionScreen> createState() =>
      _MasterElevationsProductionScreenState();
}

class _MasterElevationsProductionScreenState
    extends State<MasterElevationsProductionScreen> {
  int _roomIndex = 0;
  int _runIndex = 0;

  Future<void> _openAdvanced() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Редактор развёрток')),
          body: ElevationsScreen(
            floor: widget.floor,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openMaterials() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Материалы и отделка')),
          body: MaterialsScreen(
            floor: widget.floor,
            project: widget.project,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openLayouts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Раскладка покрытий')),
          body: LayoutsScreen(
            floor: widget.floor,
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickRoom(List<RoomFace> faces) async {
    if (faces.length < 2) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          itemCount: faces.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final meta = widget.floor.roomMetaByKey(faces[index].key);
            return ListTile(
              leading: Icon(
                index == _roomIndex
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: index == _roomIndex ? ZamerColors.accent : null,
              ),
              title: Text(meta?.name ?? 'Помещение ${index + 1}'),
              subtitle: Text('${faces[index].areaM2.toStringAsFixed(2)} м²'),
              onTap: () {
                setState(() {
                  _roomIndex = index;
                  _runIndex = 0;
                });
                Navigator.pop(sheetContext);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty) {
      return Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: widget.project.name,
                subtitle: 'Развёртки',
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_off_outlined, size: 44),
                        SizedBox(height: 12),
                        Text('Сначала замкни помещение в «Замере»'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_roomIndex >= faces.length) _roomIndex = 0;
    final face = faces[_roomIndex];
    final meta = widget.floor.roomMetaByKey(face.key)!;
    final runs = GeometryService.elevationRuns(widget.floor, face);
    if (runs.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_runIndex >= runs.length) _runIndex = 0;
    final run = runs[_runIndex];
    final height = GeometryService.roomHeightMm(widget.floor, face);
    final settings = meta.materials;
    final finish = MaterialCatalog.byId(
      settings.wallTileEnabledFor(run.id)
          ? settings.wallTileMaterialId
          : settings.wallMaterialId,
    );
    final wallArea = (run.lengthMm / 1000) * (height / 1000);

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.project.name,
              subtitle: 'Развёртки',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: _openAdvanced,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                children: [
                  ZMasterSegmentedControl(
                    labels: const ['Стены', 'Пол', 'Потолок'],
                    selectedIndex: 0,
                    onSelected: (index) {
                      if (index == 1) _openLayouts();
                      if (index == 2) _openMaterials();
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _pickRoom(faces),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: ZamerColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ZamerColors.outline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Помещение: ${meta.name}',
                              style: ZamerTypography.bodySmall,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: runs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, index) => SizedBox(
                        width: 92,
                        child: index == _runIndex
                            ? FilledButton(
                                onPressed: () {},
                                child: Text('Стена ${String.fromCharCode(65 + index)}'),
                              )
                            : OutlinedButton(
                                onPressed: () => setState(() => _runIndex = index),
                                child: Text('Стена ${String.fromCharCode(65 + index)}'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ZMasterPanel(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      height: 260,
                      child: CustomPaint(
                        painter: ElevationPainter(
                          floor: widget.floor,
                          face: face,
                          run: run,
                          heightMm: height,
                          settings: settings,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Покрытие стены', style: ZamerTypography.h4)),
                      IconButton.filledTonal(
                        tooltip: 'Редактировать отделку',
                        onPressed: _openMaterials,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Расширенный редактор',
                        onPressed: _openAdvanced,
                        icon: const Icon(Icons.tune_rounded, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ZMasterPanel(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: finish.color,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: ZamerColors.outline),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(finish.name, style: ZamerTypography.h4),
                              const SizedBox(height: 4),
                              Text(
                                'Стена ${String.fromCharCode(65 + _runIndex)} • ${run.lengthMm.round()} × ${height.round()} мм',
                                style: ZamerTypography.caption,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Площадь ≈ ${wallArea.toStringAsFixed(2)} м²',
                                style: ZamerTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ZMasterPanel(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.electrical_services_outlined, color: ZamerColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Инженерия и электрика: ${widget.floor.electricalPoints.length} точек, ${widget.floor.serviceRuns.length} трасс',
                            style: ZamerTypography.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: _openAdvanced,
                          child: const Text('Открыть'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 68,
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(top: BorderSide(color: ZamerColors.outline)),
          ),
          child: Row(
            children: [
              const _BottomAction(
                icon: Icons.settings_suggest_outlined,
                label: 'Развёртки',
                selected: true,
              ),
              _BottomAction(
                icon: Icons.layers_outlined,
                label: 'Материалы',
                onTap: _openMaterials,
              ),
              _BottomAction(
                icon: Icons.grid_view_rounded,
                label: 'Раскладка',
                onTap: _openLayouts,
              ),
              _BottomAction(
                icon: Icons.description_outlined,
                label: 'Спецификация',
                onTap: () => ReportService.shareFloorPdf(widget.project, widget.floor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: ZamerColors.accent) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: ZamerTypography.caption.copyWith(
                    color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
