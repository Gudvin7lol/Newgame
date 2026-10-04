import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/elevation_electrical_editor.dart';
import '../widgets/elevation_engineering_overlay.dart';
import '../widgets/elevation_material_editor.dart';
import '../widgets/elevation_object_editor.dart';
import '../widgets/elevation_painter.dart';
import '../widgets/elevation_radiator_overlay.dart';

/// Production wall elevations backed by the same project model as Measure/3D.
///
/// Layers are not exported snapshots. Electrical points, mounted objects,
/// engineering routes and finishes remain live project data and can be edited
/// without leaving the selected elevation.
class LayeredElevationsScreen extends StatefulWidget {
  const LayeredElevationsScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<LayeredElevationsScreen> createState() =>
      _LayeredElevationsScreenState();
}

class _LayeredElevationsScreenState extends State<LayeredElevationsScreen> {
  int _roomIndex = 0;
  int _wallIndex = 0;
  bool _showOpenings = true;
  bool _showElectrical = true;
  bool _showEngineering = true;
  bool _showObjects = true;
  bool _showMaterials = true;

  Future<void> _changed() async {
    GeometryService.syncRoomMetadata(widget.floor);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  FloorPlan _displayFloor() {
    final copy = FloorPlan.fromJson(widget.floor.toJson());
    if (!_showOpenings) {
      for (final wall in copy.walls) {
        wall.openings.clear();
      }
    }
    if (!_showElectrical) {
      copy.electricalPoints.clear();
      copy.electricalRuns.clear();
    }
    if (!_showEngineering) copy.serviceRuns.clear();
    if (!_showObjects) copy.planObjects.clear();
    if (!_showMaterials) {
      for (final room in copy.roomMetas) {
        room.materials
          ..wallTile = false
          ..wallTileRunEnabled.clear()
          ..wallMaterialId = 'paint-warm-white'
          ..wallTileMaterialId = 'paint-warm-white';
      }
    }
    GeometryService.syncRoomMetadata(copy);
    return copy;
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
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final meta = widget.floor.roomMetaByKey(faces[index].key);
            final selected = index == _roomIndex;
            return ListTile(
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? ZamerColors.accent : null,
              ),
              title: Text(meta?.name ?? 'Помещение ${index + 1}'),
              subtitle: Text('${faces[index].areaM2.toStringAsFixed(2)} м²'),
              onTap: () {
                setState(() {
                  _roomIndex = index;
                  _wallIndex = 0;
                });
                Navigator.pop(sheetContext);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editRoomHeight(RoomFace face, double currentHeight) async {
    var raw = currentHeight.round().toString();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Высота помещения'),
        content: TextFormField(
          autofocus: true,
          initialValue: raw,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Высота от чистого пола',
            suffixText: 'мм',
          ),
          onChanged: (text) => raw = text,
          onFieldSubmitted: (text) => Navigator.pop(
            dialogContext,
            double.tryParse(text.replaceAll(',', '.')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(raw.replaceAll(',', '.')),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null || !value.isFinite || value < 1800 || value > 6000) {
      return;
    }

    final meta = widget.floor.roomMetaByKey(face.key);
    if (meta == null) return;
    final key = 'room:${meta.id}:height';
    final old = widget.floor.dimensionRecords[key];
    if (old == null) {
      widget.floor.dimensionRecords[key] = DimensionRecord(
        valueMm: value,
        source: DimensionSource.manual,
        author: 'Не указан',
        recordedAt: DateTime.now(),
      );
    } else if (old.valueMm != value) {
      old.revise(value, DimensionSource.manual, 'Не указан');
    }
    meta.ceilingHeightMm = value;
    await _changed();
  }

  Widget _layerChip({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => FilterChip(
        selected: value,
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onSelected: onChanged,
        showCheckmark: false,
        selectedColor: ZamerColors.accent,
        backgroundColor: ZamerColors.surface,
        side: BorderSide(
          color: value ? ZamerColors.accent : ZamerColors.outline,
        ),
        labelStyle: TextStyle(
          color: value ? ZamerColors.accentInk : ZamerColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final sourceFaces = GeometryService.roomFaces(widget.floor);
    if (sourceFaces.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'Развёртки появятся после замыкания помещения',
        subtitle:
            'Контур, проёмы, электрика, инженерия, объекты и материалы берутся напрямую из «Замера».',
      );
    }

    if (_roomIndex >= sourceFaces.length) _roomIndex = 0;
    final sourceFace = sourceFaces[_roomIndex];
    final sourceMeta = widget.floor.roomMetaByKey(sourceFace.key);
    final sourceRuns = GeometryService.elevationRuns(widget.floor, sourceFace);
    if (sourceMeta == null || sourceRuns.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'Для помещения нет стен развёртки',
        subtitle: 'Проверь геометрию помещения в «Замере».',
      );
    }
    if (_wallIndex >= sourceRuns.length) _wallIndex = 0;
    final sourceRun = sourceRuns[_wallIndex];
    final sourceHeight = GeometryService.roomHeightMm(widget.floor, sourceFace);

    final displayFloor = _displayFloor();
    final displayFaces = GeometryService.roomFaces(displayFloor);
    if (_roomIndex >= displayFaces.length) _roomIndex = 0;
    final face = displayFaces[_roomIndex];
    final meta = displayFloor.roomMetaByKey(face.key);
    final runs = GeometryService.elevationRuns(displayFloor, face);
    if (meta == null || runs.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'Развёртка не построена',
        subtitle: 'Обнови геометрию помещения в «Замере».',
      );
    }
    if (_wallIndex >= runs.length) _wallIndex = 0;
    final run = runs[_wallIndex];
    final height = GeometryService.roomHeightMm(displayFloor, face);
    final settings = meta.materials;
    final finish = MaterialCatalog.byId(
      settings.wallTileEnabledFor(run.id)
          ? settings.wallTileMaterialId
          : settings.wallMaterialId,
    );

    return ColoredBox(
      color: ZamerColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              height: 54,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: ZamerColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    color: ZamerColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickRoom(sourceFaces),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourceMeta.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZamerTypography.bodySmall.copyWith(
                              color: ZamerColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${sourceFace.areaM2.toStringAsFixed(2)} м² • ${sourceRuns.length} стен',
                            style: ZamerTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editRoomHeight(sourceFace, sourceHeight),
                    icon: const Icon(Icons.height_rounded, size: 17),
                    label: Text('${sourceHeight.round()} мм'),
                  ),
                  IconButton(
                    tooltip: 'Выбрать помещение',
                    onPressed: () => _pickRoom(sourceFaces),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: sourceRuns.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final selected = index == _wallIndex;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _wallIndex = index),
                  showCheckmark: false,
                  label: Text(
                    '${String.fromCharCode(65 + index)}  ${sourceRuns[index].lengthMm.round()} мм',
                  ),
                  selectedColor: ZamerColors.accent,
                  backgroundColor: ZamerColors.surface,
                  labelStyle: TextStyle(
                    color: selected
                        ? ZamerColors.accentInk
                        : ZamerColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _layerChip(
                  label: 'Проёмы',
                  icon: Icons.door_front_door_outlined,
                  value: _showOpenings,
                  onChanged: (v) => setState(() => _showOpenings = v),
                ),
                const SizedBox(width: 6),
                _layerChip(
                  label: 'Электрика',
                  icon: Icons.electrical_services_outlined,
                  value: _showElectrical,
                  onChanged: (v) => setState(() => _showElectrical = v),
                ),
                const SizedBox(width: 6),
                _layerChip(
                  label: 'Инженерия',
                  icon: Icons.plumbing_outlined,
                  value: _showEngineering,
                  onChanged: (v) => setState(() => _showEngineering = v),
                ),
                const SizedBox(width: 6),
                _layerChip(
                  label: 'Объекты',
                  icon: Icons.chair_alt_outlined,
                  value: _showObjects,
                  onChanged: (v) => setState(() => _showObjects = v),
                ),
                const SizedBox(width: 6),
                _layerChip(
                  label: 'Материалы',
                  icon: Icons.inventory_2_outlined,
                  value: _showMaterials,
                  onChanged: (v) => setState(() => _showMaterials = v),
                ),
              ],
            ),
          ),
          if (_showElectrical)
            ElevationElectricalEditor(
              floor: widget.floor,
              run: sourceRun,
              onChanged: _changed,
            ),
          if (_showObjects)
            ElevationObjectEditor(
              floor: widget.floor,
              run: sourceRun,
              onChanged: _changed,
            ),
          if (_showMaterials)
            ElevationMaterialEditor(
              settings: sourceMeta.materials,
              run: sourceRun,
              heightMm: sourceHeight,
              onChanged: _changed,
            ),
          const Divider(height: 1, color: ZamerColors.outlineSoft),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: ZamerColors.surfaceLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZamerColors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(180),
                  child: SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: ElevationPainter(
                            floor: displayFloor,
                            face: face,
                            run: run,
                            heightMm: height,
                            settings: settings,
                          ),
                        ),
                        if (_showObjects)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: ElevationRadiatorOverlayPainter(
                                floor: displayFloor,
                                face: face,
                                run: run,
                                heightMm: height,
                              ),
                            ),
                          ),
                        if (_showEngineering)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: ElevationEngineeringOverlayPainter(
                                floor: displayFloor,
                                face: face,
                                run: run,
                                heightMm: height,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.inventory_2_outlined,
                    title: _showMaterials ? finish.name : 'Материал скрыт',
                    subtitle: '${run.lengthMm.round()} × ${height.round()} мм',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.layers_outlined,
                    title:
                        '${widget.floor.electricalPoints.length} электр. • ${widget.floor.serviceRuns.length} трасс',
                    subtitle:
                        '${widget.floor.planObjects.length} объектов • живые слои',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: ZamerColors.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.caption.copyWith(
                      color: ZamerColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ZamerTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
}
