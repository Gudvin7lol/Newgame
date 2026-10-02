import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_master_page_header.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/layout_service.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/elevation_painter.dart';

class ElevationsScreen extends StatefulWidget {
  const ElevationsScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<ElevationsScreen> createState() => _ElevationsScreenState();
}

class _ElevationsScreenState extends State<ElevationsScreen> {
  String? _faceKey;
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<double?> _number(String title, double value, String suffix) {
    final c = TextEditingController(
      text: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
    );
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(c.text.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTile(RoomMaterialSettings s, String field) async {
    double? v;
    if (field == 'w')
      v = await _number('Ширина плитки', s.wallTileWidthMm, 'мм');
    if (field == 'h')
      v = await _number('Высота плитки', s.wallTileHeightMm, 'мм');
    if (field == 'x')
      v = await _number('Сдвиг плитки по X', s.wallTileOffsetXMm, 'мм');
    if (field == 'y')
      v = await _number('Сдвиг плитки по Y', s.wallTileOffsetYMm, 'мм');
    if (field == 'from')
      v = await _number('Плитка от пола', s.wallTileFromMm, 'мм');
    if (field == 'to')
      v = await _number('Плитка до высоты', s.wallTileToMm, 'мм');
    if (v == null) return;
    if ((field == 'w' || field == 'h') && (v < 20 || v > 10000)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Размер плитки: от 20 до 10000 мм')),
        );
      }
      return;
    }
    if (field == 'w' && v > 0) s.wallTileWidthMm = v;
    if (field == 'h' && v > 0) s.wallTileHeightMm = v;
    if (field == 'x') s.wallTileOffsetXMm = v;
    if (field == 'y') s.wallTileOffsetYMm = v;
    if (field == 'from' && v >= 0) s.wallTileFromMm = v;
    if (field == 'to' && v >= 0) s.wallTileToMm = v;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _tileOptions(
    RoomMaterialSettings s,
    List<ElevationRun> runs,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Плитка на стенах',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _editTile(s, 'w');
                            await _editTile(s, 'h');
                            setModal(() {});
                          },
                          child: Text(
                            '${s.wallTileWidthMm.round()}×${s.wallTileHeightMm.round()} мм',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'straight',
                              label: Text('Прямая'),
                            ),
                            ButtonSegment(value: 'half', label: Text('1/2')),
                          ],
                          selected: {s.wallTilePattern},
                          onSelectionChanged: (v) async {
                            s.wallTilePattern = v.first;
                            await widget.onChanged();
                            setModal(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Шов'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(value: 1.0, label: Text('1 мм')),
                            ButtonSegment(value: 1.5, label: Text('1,5 мм')),
                            ButtonSegment(value: 2.0, label: Text('2 мм')),
                          ],
                          selected: {s.wallTileGroutMm},
                          onSelectionChanged: (v) async {
                            s.wallTileGroutMm = v.first;
                            await widget.onChanged();
                            setModal(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await _editTile(s, 'x');
                          setModal(() {});
                        },
                        child: Text('X ${s.wallTileOffsetXMm.round()}'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await _editTile(s, 'y');
                          setModal(() {});
                        },
                        child: Text('Y ${s.wallTileOffsetYMm.round()}'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await _editTile(s, 'from');
                          setModal(() {});
                        },
                        child: Text('От ${s.wallTileFromMm.round()}'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await _editTile(s, 'to');
                          setModal(() {});
                        },
                        child: Text('До ${s.wallTileToMm.round()} мм'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      s.wallTile = true;
                      for (final run in runs)
                        s.wallTileRunEnabled[run.id] = true;
                      await widget.onChanged();
                      setModal(() {});
                    },
                    icon: const Icon(Icons.select_all),
                    label: const Text('Плитка на все стены помещения'),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      s.wallTile = false;
                      s.wallTileRunEnabled.clear();
                      await widget.onChanged();
                      setModal(() {});
                    },
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text('Убрать плитку со всех стен'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _panRunTileDelta(
    RoomMaterialSettings s,
    ElevationRun run,
    double heightMm,
    Size size,
    Offset delta,
  ) {
    final horizontalMargin = math.min(38.0, size.width * .09);
    final verticalMargin = math.min(34.0, size.height * .12);
    final scale = math.min(
      (size.width - horizontalMargin * 2) / math.max(1, run.lengthMm),
      (size.height - verticalMargin * 2) / math.max(1, heightMm),
    );
    if (scale <= 0 || !scale.isFinite) return;
    final tileW = math.max(1.0, s.wallTileWidthFor(run.id)).toDouble();
    final tileH = math.max(1.0, s.wallTileHeightFor(run.id)).toDouble();
    s.wallTileRunOffsetX[run.id] =
        (s.wallTileXFor(run.id) + delta.dx / scale) % tileW;
    s.wallTileRunOffsetY[run.id] =
        (s.wallTileYFor(run.id) - delta.dy / scale) % tileH;
    setState(() {});
  }

  void _panRunTile(
    RoomMaterialSettings s,
    ElevationRun run,
    double heightMm,
    Size size,
    DragUpdateDetails d,
  ) => _panRunTileDelta(s, run, heightMm, size, d.delta);

  Future<void> _openLargeElevation(
    RoomFace face,
    ElevationRun run,
    double height,
    RoomMaterialSettings settings,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Развёртка • ${run.lengthMm.round()} мм')),
          body: StatefulBuilder(
            builder: (context, refresh) => LayoutBuilder(
              builder: (context, constraints) {
                final drawing = Size(
                  math.max(constraints.maxWidth - 24, run.lengthMm * .25),
                  math.max(constraints.maxHeight * .8, height * .25),
                );
                return InteractiveViewer(
                  constrained: false,
                  minScale: .35,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(240),
                  child: GestureDetector(
                    onPanUpdate: settings.wallTileEnabledFor(run.id)
                        ? (d) {
                            _panRunTile(settings, run, height, drawing, d);
                            refresh(() {});
                          }
                        : null,
                    onPanEnd: settings.wallTileEnabledFor(run.id)
                        ? (_) => widget.onChanged()
                        : null,
                    child: SizedBox.fromSize(
                      size: drawing,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.inferLegacyArcGroups(widget.floor);
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty)
      return const Center(child: Text('Сначала создай замкнутые помещения.'));
    _faceKey ??= faces.first.key;
    final face = faces.firstWhere(
      (f) => f.key == _faceKey,
      orElse: () => faces.first,
    );
    final meta = widget.floor.roomMetaByKey(face.key)!;
    final settings = meta.materials;
    final height = GeometryService.roomHeightMm(widget.floor, face);
    final runs = GeometryService.elevationRuns(widget.floor, face);
    final floorFinish = MaterialCatalog.byId(settings.floorMaterialId);
    final wallFinish = MaterialCatalog.byId(settings.wallMaterialId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZMasterPageHeader(
                icon: Icons.view_agenda_outlined,
                title: 'Развёртки',
                subtitle: '${meta.name} • ${runs.length} стен',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: face.key,
                decoration: const InputDecoration(labelText: 'Помещение'),
                items: faces.map((f) {
                  final m = widget.floor.roomMetaByKey(f.key)!;
                  return DropdownMenuItem(
                    value: f.key,
                    child: Text(
                      '${m.name} • ${f.areaM2.toStringAsFixed(2)} м²',
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _faceKey = v;
                    _page = 0;
                  });
                  _pages.jumpToPage(0);
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: runs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final run = runs[i];
                    final selected = i == _page;
                    final letter = String.fromCharCode(65 + (i % 26));
                    return ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: ZamerColors.accent.withValues(alpha: .12),
                      backgroundColor: ZamerColors.surfaceLow,
                      side: BorderSide(
                        color: selected
                            ? ZamerColors.accent
                            : ZamerColors.outline,
                      ),
                      avatar: CircleAvatar(
                        radius: 13,
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      label: Text('${run.lengthMm.round()} мм'),
                      onSelected: (_) {
                        if (_pages.hasClients) {
                          _pages.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        }
                        setState(() => _page = i);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Предыдущая стена',
                    onPressed: _page > 0
                        ? () => _pages.animateToPage(
                            _page - 1,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Стена ${runs.isEmpty ? 0 : _page + 1} из ${runs.length}',
                  ),
                  IconButton(
                    tooltip: 'Следующая стена',
                    onPressed: _page < runs.length - 1
                        ? () => _pages.animateToPage(
                            _page + 1,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _page = index),
            itemCount: runs.length,
            itemBuilder: (_, i) {
              final run = runs[i];
              final firstWall = widget.floor.wallById(run.edges.first.wallId)!;
              final openings = run.edges.fold<int>(
                0,
                (sum, e) =>
                    sum +
                    (widget.floor.wallById(e.wallId)?.openings.length ?? 0),
              );
              final openingArea = run.edges.fold<double>(0, (sum, e) {
                final wall = widget.floor.wallById(e.wallId);
                if (wall == null) return sum;
                return sum +
                    wall.openings.fold<double>(
                      0,
                      (s, o) => s + o.widthMm * o.heightMm / 1000000,
                    );
              });
              final devices = widget.floor.electricalPoints
                  .where(
                    (p) =>
                        p.wallId != null &&
                        run.edges.any((e) => e.wallId == p.wallId),
                  )
                  .length;
              final gross = run.lengthMm / 1000 * height / 1000;
              final title = run.isCurved
                  ? 'Радиусная стена ${String.fromCharCode(65 + (i % 26))}'
                  : 'Стена ${String.fromCharCode(65 + (i % 26))}';
              return SingleChildScrollView(
                // Keep the elevation page vertically scrollable even while tile
                // editing is enabled. Wall switching is already locked at the
                // PageView level, while the preview GestureDetector owns tile
                // drag gestures inside the drawing area.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ZPanel(
                    padding: EdgeInsets.zero,
                    color: ZamerColors.surfaceLow,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                '${firstWall.thicknessMm.round()} мм • ${firstWall.material.label}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              IconButton(
                                tooltip: 'Открыть развёртку крупно',
                                onPressed: () => _openLargeElevation(
                                  face,
                                  run,
                                  height,
                                  settings,
                                ),
                                icon: const Icon(Icons.open_in_full),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 440,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final size = Size(c.maxWidth, c.maxHeight);
                                return GestureDetector(
                                  key: ValueKey('elevation-preview-${run.id}'),
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate:
                                      settings.wallTileEnabledFor(run.id)
                                      ? (event) => _panRunTileDelta(
                                          settings,
                                          run,
                                          height,
                                          size,
                                          Offset(event.delta.dx, 0),
                                        )
                                      : null,
                                  onHorizontalDragEnd:
                                      settings.wallTileEnabledFor(run.id)
                                      ? (_) => widget.onChanged()
                                      : null,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: ZamerColors.background,
                                      borderRadius: BorderRadius.circular(
                                        ZamerRadius.md,
                                      ),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        ZamerRadius.md,
                                      ),
                                      child: CustomPaint(
                                        painter: ElevationPainter(
                                          floor: widget.floor,
                                          face: face,
                                          run: run,
                                          heightMm: height,
                                          settings: settings,
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _InfoPill(
                                  icon: Icons.height,
                                  text: '${height.round()} мм',
                                ),
                                const SizedBox(width: 6),
                                _InfoPill(
                                  icon: Icons.layers_outlined,
                                  text: floorFinish.name,
                                ),
                                const SizedBox(width: 6),
                                _InfoPill(
                                  icon: Icons.format_paint,
                                  text: wallFinish.name,
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () => _tileOptions(settings, runs),
                                  icon: const Icon(Icons.tune, size: 18),
                                  label: const Text('Плитка'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SwitchListTile.adaptive(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Плитка на этой стене'),
                                  value: settings.wallTileEnabledFor(run.id),
                                  onChanged: (v) async {
                                    settings.wallTileRunEnabled[run.id] = v;
                                    if (v) settings.wallTile = true;
                                    await widget.onChanged();
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  settings.wallTile = true;
                                  for (final r in runs) {
                                    settings.wallTileRunEnabled[r.id] =
                                        r.id == run.id;
                                  }
                                  await widget.onChanged();
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Только эта'),
                              ),
                            ],
                          ),
                        ),
                        if (run.isCurved)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  'Длина по дуге ${run.lengthMm.round()} мм',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (run.radiusMm != null) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    'R ${run.radiusMm!.round()} мм',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (settings.wallTileEnabledFor(run.id))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    settings.wallTileRunRotated[run.id] =
                                        !settings.wallTileRotatedFor(run.id);
                                    await widget.onChanged();
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.rotate_90_degrees_cw),
                                  label: Text(
                                    settings.wallTileRotatedFor(run.id)
                                        ? 'Плитка 90°'
                                        : 'Повернуть 90°',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    settings.wallTileRunMirrored[run.id] =
                                        !settings.wallTileMirroredFor(run.id);
                                    await widget.onChanged();
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.flip),
                                  label: Text(
                                    settings.wallTileMirroredFor(run.id)
                                        ? 'Вернуть раскладку'
                                        : 'Перевернуть раскладку',
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    final b = LayoutService.balanceWallTiles(
                                      run.lengthMm,
                                      settings.wallTileFromMm,
                                      math.min(height, settings.wallTileToMm),
                                      settings.wallTileWidthFor(run.id),
                                      settings.wallTileHeightFor(run.id),
                                      staggered:
                                          settings.wallTilePattern == 'half',
                                    );
                                    settings.wallTileRunOffsetX[run.id] = b.xMm;
                                    settings.wallTileRunOffsetY[run.id] = b.yMm;
                                    await widget.onChanged();
                                    if (mounted) {
                                      setState(() {});
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Минимальная подрезка по габариту: ${b.minimumCutMm.round()} мм',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.auto_fix_high),
                                  label: const Text(
                                    'По технологии • без узких подрезок',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Площадь ${(gross - openingArea).clamp(0, double.infinity).toStringAsFixed(2)} м²',
                              ),
                              Text('Проёмов $openings • электрика $devices'),
                              Text('${i + 1}/${runs.length}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      border: Border.all(color: ZamerColors.outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
