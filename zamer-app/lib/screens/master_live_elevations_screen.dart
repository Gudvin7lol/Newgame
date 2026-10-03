import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import 'electrical_screen.dart';
import 'layouts_screen.dart';
import 'master_live_pages.dart';
import 'materials_screen.dart';

class MasterLiveElevationsScreen extends StatefulWidget {
  const MasterLiveElevationsScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<MasterLiveElevationsScreen> createState() =>
      _MasterLiveElevationsScreenState();
}

class _MasterLiveElevationsScreenState
    extends State<MasterLiveElevationsScreen> {
  int _roomIndex = 0;
  int _runIndex = 0;

  List<RoomFace> get _faces {
    GeometryService.syncRoomMetadata(widget.floor);
    return GeometryService.roomFaces(widget.floor);
  }

  RoomFace? get _face {
    final faces = _faces;
    if (faces.isEmpty) return null;
    _roomIndex = _roomIndex.clamp(0, faces.length - 1).toInt();
    return faces[_roomIndex];
  }

  RoomMeta? get _meta {
    final face = _face;
    if (face == null) return null;
    return widget.floor.roomMetaByKey(face.key);
  }

  List<ElevationRun> get _runs {
    final face = _face;
    if (face == null) return const [];
    return GeometryService.elevationRuns(widget.floor, face);
  }

  ElevationRun? get _run {
    final runs = _runs;
    if (runs.isEmpty) return null;
    _runIndex = _runIndex.clamp(0, runs.length - 1).toInt();
    return runs[_runIndex];
  }

  Future<void> _openMaterials() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialsScreen(
          floor: widget.floor,
          project: widget.project,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openLayouts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LayoutsScreen(
          floor: widget.floor,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openElectrical() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ElectricalScreen(
          floor: widget.floor,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openDocs() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterLiveDocumentationScreen(
          project: widget.project,
          floor: widget.floor,
        ),
      ),
    );
  }

  Future<void> _toggleTile(bool value) async {
    final meta = _meta;
    if (meta == null) return;
    meta.materials.wallTile = value;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  List<PlanWall> _wallsFor(ElevationRun? run) {
    if (run == null) return const [];
    final ids = run.edges.map((edge) => edge.wallId).toSet();
    return widget.floor.walls.where((wall) => ids.contains(wall.id)).toList();
  }

  int _electricalCount(ElevationRun? run, String needle) {
    final wallIds = _wallsFor(run).map((wall) => wall.id).toSet();
    return widget.floor.electricalPoints.where((point) {
      if (!wallIds.contains(point.wallId)) return false;
      return point.type.name.toLowerCase().contains(needle);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final faces = _faces;
    final face = _face;
    final meta = _meta;
    final runs = _runs;
    final run = _run;

    if (face == null || meta == null || runs.isEmpty || run == null) {
      return Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: widget.project.name,
                subtitle: 'Развёртки',
                onBack: () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text('Сначала создай замкнутое помещение в Замере'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final height = GeometryService.roomHeightMm(widget.floor, face);
    final wallIds = _wallsFor(run);
    final openingCount = wallIds.fold<int>(
      0,
      (sum, wall) => sum + wall.openings.length,
    );
    final material = MaterialCatalog.byId(meta.materials.wallMaterialId);
    final socketCount = _electricalCount(run, 'socket');
    final switchCount = _electricalCount(run, 'switch');
    final lightCount = _electricalCount(run, 'light');

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.project.name,
              subtitle: 'Развёртки',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
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
                  DropdownButtonFormField<int>(
                    initialValue: _roomIndex,
                    decoration: const InputDecoration(labelText: 'Помещение'),
                    items: [
                      for (var i = 0; i < faces.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            widget.floor.roomMetaByKey(faces[i].key)?.name ??
                                'Помещение ${i + 1}',
                          ),
                        ),
                    ],
                    onChanged: (index) => setState(() {
                      _roomIndex = index ?? 0;
                      _runIndex = 0;
                    }),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: runs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, index) {
                        final selected = index == _runIndex;
                        final label = String.fromCharCode(65 + (index % 26));
                        return selected
                            ? FilledButton(
                                onPressed: () {},
                                child: Text('Стена $label'),
                              )
                            : OutlinedButton(
                                onPressed: () =>
                                    setState(() => _runIndex = index),
                                child: Text('Стена $label'),
                              );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ZMasterPanel(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      height: 230,
                      child: CustomPaint(
                        painter: _LiveElevationPainter(
                          widthMm: run.lengthMm,
                          heightMm: height,
                          openings: openingCount,
                          tiled: meta.materials.wallTileEnabledFor(run.id),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Покрытие стены', style: ZamerTypography.h4),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Редактор материалов',
                        onPressed: _openMaterials,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FinishCard(
                          title: material?.name ?? 'Материал стены',
                          subtitle: meta.materials.wallTile
                              ? 'Базовый слой'
                              : 'Активно',
                          selected: !meta.materials.wallTile,
                          icon: Icons.format_paint_outlined,
                          onTap: () => _toggleTile(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FinishCard(
                          title: 'Плитка',
                          subtitle: meta.materials.wallTile
                              ? '${meta.materials.wallTileWidthMm.round()} × ${meta.materials.wallTileHeightMm.round()} мм'
                              : 'Выключена',
                          selected: meta.materials.wallTile,
                          icon: Icons.grid_view_rounded,
                          onTap: () => _toggleTile(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ActionRow(
                    icon: Icons.door_front_door_outlined,
                    label: 'Проёмы ($openingCount)',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 6),
                  _ActionRow(
                    icon: Icons.electrical_services_outlined,
                    label: 'Розетки ($socketCount)',
                    onTap: _openElectrical,
                  ),
                  const SizedBox(height: 6),
                  _ActionRow(
                    icon: Icons.toggle_on_outlined,
                    label: 'Выключатели ($switchCount)',
                    onTap: _openElectrical,
                  ),
                  const SizedBox(height: 6),
                  _ActionRow(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Светильники ($lightCount)',
                    onTap: _openElectrical,
                  ),
                  const SizedBox(height: 14),
                  Text('Размеры и привязки', style: ZamerTypography.h4),
                  const SizedBox(height: 8),
                  ZMasterPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: _Dimension(
                            label: 'Ширина стены',
                            value: '${run.lengthMm.round()} мм',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Dimension(
                            label: 'Высота стены',
                            value: '${height.round()} мм',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: const BoxDecoration(
                color: ZamerColors.surfaceLow,
                border: Border(top: BorderSide(color: ZamerColors.outline)),
              ),
              child: Row(
                children: [
                  _BottomAction(
                    icon: Icons.view_carousel_outlined,
                    label: 'Развёртки',
                    selected: true,
                    onTap: () {},
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
                    onTap: _openDocs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 86,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? ZamerColors.accent : ZamerColors.outline,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? ZamerColors.accent : ZamerColors.textMuted,
                  size: 28,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZamerTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: ZamerTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: ZamerTypography.bodySmall)),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      );
}

class _Dimension extends StatelessWidget {
  const _Dimension({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ZamerTypography.caption),
          const SizedBox(height: 5),
          Text(value, style: ZamerTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? ZamerColors.accent : ZamerColors.textPrimary,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
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

class _LiveElevationPainter extends CustomPainter {
  const _LiveElevationPainter({
    required this.widthMm,
    required this.heightMm,
    required this.openings,
    required this.tiled,
  });
  final double widthMm;
  final double heightMm;
  final int openings;
  final bool tiled;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 24.0;
    final rect = Rect.fromLTWH(
      left,
      top + 16,
      size.width - left - 10,
      size.height - top - 48,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0xFFB9AFA4));
    if (tiled) {
      final grid = Paint()
        ..color = const Color(0x556B6258)
        ..strokeWidth = .8;
      for (var x = rect.left + 28; x < rect.right; x += 28) {
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      }
      for (var y = rect.top + 24; y < rect.bottom; y += 24) {
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      }
    }
    final openingPaint = Paint()..color = ZamerColors.background;
    for (var i = 0; i < openings.clamp(0, 4); i++) {
      final w = rect.width / (openings + 2);
      final x = rect.left + w * (i + 1);
      canvas.drawRect(
        Rect.fromLTWH(x, rect.bottom - rect.height * .62, w * .55, rect.height * .62),
        openingPaint,
      );
    }
    final line = Paint()
      ..color = ZamerColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, line);
    _dimension(canvas, Offset(rect.left, rect.top - 10), Offset(rect.right, rect.top - 10), '${widthMm.round()}');
    _dimension(canvas, Offset(rect.left - 12, rect.top), Offset(rect.left - 12, rect.bottom), '${heightMm.round()}');
  }

  void _dimension(Canvas canvas, Offset a, Offset b, String text) {
    final paint = Paint()
      ..color = ZamerColors.accent
      ..strokeWidth = 1;
    canvas.drawLine(a, b, paint);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: ZamerColors.accent, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, (a + b) / 2 - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LiveElevationPainter oldDelegate) =>
      oldDelegate.widthMm != widthMm ||
      oldDelegate.heightMm != heightMm ||
      oldDelegate.openings != openings ||
      oldDelegate.tiled != tiled;
}
