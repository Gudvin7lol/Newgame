import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/elevation_painter.dart';

/// Full working elevation view built from the measured model.
///
/// Openings, electrical, mounted objects and wall materials are not separate
/// drawings. They are display layers over the same elevation geometry.
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
  bool _showObjects = true;
  bool _showMaterials = true;

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
    if (!_showObjects) copy.planObjects.clear();
    if (!_showMaterials) {
      for (final room in copy.roomMetas) {
        room.materials
          ..wallTile = false
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
            return ListTile(
              leading: Icon(
                index == _roomIndex
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: index == _roomIndex ? ZamerColors.accent : null,
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

  Widget _layerChip({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
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
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final sourceFaces = GeometryService.roomFaces(widget.floor);
    if (sourceFaces.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'Развёртки появятся после замыкания помещения',
        subtitle:
            'Контур, проёмы, электрика, объекты и материалы берутся напрямую из «Замера».',
      );
    }

    if (_roomIndex >= sourceFaces.length) _roomIndex = 0;
    final sourceFace = sourceFaces[_roomIndex];
    final sourceMeta = widget.floor.roomMetaByKey(sourceFace.key);

    final displayFloor = _displayFloor();
    final displayFaces = GeometryService.roomFaces(displayFloor);
    if (_roomIndex >= displayFaces.length) _roomIndex = 0;
    final face = displayFaces[_roomIndex];
    final meta = displayFloor.roomMetaByKey(face.key)!;
    final runs = GeometryService.elevationRuns(displayFloor, face);
    if (runs.isEmpty) {
      return const ZEmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'Для помещения нет стен развёртки',
        subtitle: 'Проверь геометрию помещения в «Замере».',
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
            child: InkWell(
              onTap: () => _pickRoom(sourceFaces),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourceMeta?.name ?? 'Помещение ${_roomIndex + 1}',
                            style: ZamerTypography.bodySmall.copyWith(
                              color: ZamerColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${sourceFace.areaM2.toStringAsFixed(2)} м² • ${runs.length} стен',
                            style: ZamerTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: runs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final selected = index == _wallIndex;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _wallIndex = index),
                  showCheckmark: false,
                  label: Text(
                    '${String.fromCharCode(65 + index)}  ${runs[index].lengthMm.round()} мм',
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
          const Divider(height: 1, color: ZamerColors.outlineSoft),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: ZamerColors.surfaceLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZamerColors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(140),
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: ElevationPainter(
                        floor: displayFloor,
                        face: face,
                        run: run,
                        heightMm: height,
                        settings: settings,
                      ),
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
                    subtitle:
                        '${run.lengthMm.round()} × ${height.round()} мм',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.layers_outlined,
                    title:
                        '${widget.floor.electricalPoints.length} точек • ${widget.floor.planObjects.length} объектов',
                    subtitle: 'Слои текущего проекта',
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
