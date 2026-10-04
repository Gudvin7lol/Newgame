import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

class ElevationOpeningEditor extends StatelessWidget {
  const ElevationOpeningEditor({
    super.key,
    required this.floor,
    required this.face,
    required this.run,
    required this.onChanged,
  });

  final FloorPlan floor;
  final RoomFace face;
  final ElevationRun run;
  final Future<void> Function() onChanged;

  List<_OpeningEntry> _entries() {
    final result = <_OpeningEntry>[];
    var accumulated = 0.0;
    for (final edge in run.edges) {
      final wall = floor.wallById(edge.wallId);
      if (wall == null) continue;
      final segmentLength = GeometryService.wallFaceLengthMm(face, edge);
      for (final opening in wall.openings) {
        final localOffset = GeometryService.openingOffsetFromFaceStart(
          floor,
          face,
          edge,
          opening,
        );
        result.add(
          _OpeningEntry(
            wall: wall,
            edge: edge,
            opening: opening,
            segmentStartMm: accumulated,
            segmentLengthMm: segmentLength,
            runOffsetMm: accumulated + localOffset,
          ),
        );
      }
      accumulated += segmentLength;
    }
    result.sort((a, b) => a.runOffsetMm.compareTo(b.runOffsetMm));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        child: Row(
          children: [
            const Icon(
              Icons.door_front_door_outlined,
              size: 16,
              color: ZamerColors.textFaint,
            ),
            const SizedBox(width: 7),
            Text(
              'На выбранной стене нет дверей или окон',
              style: ZamerTypography.caption,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final opening = entry.opening;
          final icon = opening.type == OpeningType.window
              ? Icons.window_outlined
              : Icons.door_front_door_outlined;
          final title = opening.type == OpeningType.window ? 'Окно' : 'Дверь';
          return ActionChip(
            avatar: Icon(icon, size: 16),
            label: Text(
              '$title • ${entry.runOffsetMm.round()} / '
              '${opening.widthMm.round()}×${opening.heightMm.round()}',
            ),
            onPressed: () => _edit(context, entry),
            side: const BorderSide(color: ZamerColors.outline),
            backgroundColor: ZamerColors.surface,
            labelStyle: ZamerTypography.caption.copyWith(
              color: ZamerColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, _OpeningEntry entry) async {
    var type = entry.opening.type;
    var runOffset = entry.runOffsetMm.round().toString();
    var width = entry.opening.widthMm.round().toString();
    var height = entry.opening.heightMm.round().toString();
    var sill = entry.opening.sillHeightMm.round().toString();

    final result = await showDialog<_OpeningEditResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Проём на развёртке'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<OpeningType>(
                  segments: const [
                    ButtonSegment(
                      value: OpeningType.door,
                      icon: Icon(Icons.door_front_door_outlined),
                      label: Text('Дверь'),
                    ),
                    ButtonSegment(
                      value: OpeningType.window,
                      icon: Icon(Icons.window_outlined),
                      label: Text('Окно'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (values) =>
                      setDialogState(() => type = values.first),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'От начала развёртки',
                  initialValue: runOffset,
                  onChanged: (value) => runOffset = value,
                ),
                const SizedBox(height: 10),
                _Field(
                  label: 'Ширина',
                  initialValue: width,
                  onChanged: (value) => width = value,
                ),
                const SizedBox(height: 10),
                _Field(
                  label: 'Высота',
                  initialValue: height,
                  onChanged: (value) => height = value,
                ),
                if (type == OpeningType.window) ...[
                  const SizedBox(height: 10),
                  _Field(
                    label: 'Подоконник от чистого пола',
                    initialValue: sill,
                    onChanged: (value) => sill = value,
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Все значения в мм. Привязка считается по направлению текущей развёртки.',
                    style: ZamerTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                const _OpeningEditResult.delete(),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Удалить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final parsedOffset = _parse(runOffset);
                final parsedWidth = _parse(width);
                final parsedHeight = _parse(height);
                final parsedSill = type == OpeningType.window ? _parse(sill) : 0.0;
                if (parsedOffset == null ||
                    parsedWidth == null ||
                    parsedHeight == null ||
                    parsedSill == null) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _OpeningEditResult.save(
                    type: type,
                    runOffsetMm: parsedOffset,
                    widthMm: parsedWidth,
                    heightMm: parsedHeight,
                    sillMm: parsedSill,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (result.delete) {
      entry.wall.openings.remove(entry.opening);
      _removeDimensionRecords(entry.opening.id);
      await onChanged();
      return;
    }

    final widthMm = result.widthMm!.clamp(300.0, 6000.0).toDouble();
    final heightMm = result.heightMm!.clamp(300.0, 4500.0).toDouble();
    final maxLocalOffset = (entry.segmentLengthMm - widthMm).clamp(0.0, double.infinity).toDouble();
    final requestedLocal = result.runOffsetMm! - entry.segmentStartMm;
    final faceOffset = requestedLocal.clamp(0.0, maxLocalOffset).toDouble();
    final wallLength = floor.wallLengthMm(entry.wall);
    final faceShift = GeometryService.wallFaceStartShiftMm(
      floor,
      face,
      entry.edge,
    );
    final wallFaceOffset = faceOffset + faceShift;
    final physicalOffset = entry.edge.fromNodeId == entry.wall.startNodeId
        ? wallFaceOffset
        : wallLength - wallFaceOffset - widthMm;
    final maxPhysical = (wallLength - widthMm).clamp(0.0, double.infinity).toDouble();

    entry.opening
      ..type = result.type!
      ..widthMm = widthMm
      ..heightMm = heightMm
      ..sillHeightMm = result.type == OpeningType.window
          ? result.sillMm!.clamp(0.0, 3500.0).toDouble()
          : 0
      ..offsetFromStartMm = physicalOffset.clamp(0.0, maxPhysical).toDouble();

    _record(
      'opening:${entry.opening.id}:offset',
      entry.opening.offsetFromStartMm,
    );
    _record('opening:${entry.opening.id}:width', entry.opening.widthMm);
    _record('opening:${entry.opening.id}:height', entry.opening.heightMm);
    _record('opening:${entry.opening.id}:sill', entry.opening.sillHeightMm);
    await onChanged();
  }

  void _record(String key, double value) {
    final current = floor.dimensionRecords[key];
    if (current == null) {
      floor.dimensionRecords[key] = DimensionRecord(
        valueMm: value,
        source: DimensionSource.manual,
        author: 'Развёртка',
        recordedAt: DateTime.now(),
      );
    } else if ((current.valueMm - value).abs() > .01 ||
        current.source == DimensionSource.calculated) {
      current.revise(value, DimensionSource.manual, 'Развёртка');
    }
  }

  void _removeDimensionRecords(String openingId) {
    for (final suffix in const ['offset', 'width', 'height', 'sill']) {
      floor.dimensionRecords.remove('opening:$openingId:$suffix');
    }
  }

  static double? _parse(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }
}

class _OpeningEntry {
  const _OpeningEntry({
    required this.wall,
    required this.edge,
    required this.opening,
    required this.segmentStartMm,
    required this.segmentLengthMm,
    required this.runOffsetMm,
  });

  final PlanWall wall;
  final FaceEdge edge;
  final WallOpening opening;
  final double segmentStartMm;
  final double segmentLengthMm;
  final double runOffsetMm;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: initialValue,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'мм'),
        onChanged: onChanged,
      );
}

class _OpeningEditResult {
  const _OpeningEditResult.save({
    required this.type,
    required this.runOffsetMm,
    required this.widthMm,
    required this.heightMm,
    required this.sillMm,
  }) : delete = false;

  const _OpeningEditResult.delete()
      : delete = true,
        type = null,
        runOffsetMm = null,
        widthMm = null,
        heightMm = null,
        sillMm = null;

  final bool delete;
  final OpeningType? type;
  final double? runOffsetMm;
  final double? widthMm;
  final double? heightMm;
  final double? sillMm;
}
