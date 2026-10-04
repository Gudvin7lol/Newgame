import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

/// Compact editor for wall-mounted electrical points visible on one elevation.
class ElevationElectricalEditor extends StatelessWidget {
  const ElevationElectricalEditor({
    super.key,
    required this.floor,
    required this.run,
    required this.onChanged,
  });

  final FloorPlan floor;
  final ElevationRun run;
  final Future<void> Function() onChanged;

  List<ElectricalPoint> _points() {
    final result = <ElectricalPoint>[];
    for (final point in floor.electricalPoints) {
      if (!point.isWallDevice || point.wallId == null) continue;
      for (final edge in run.edges) {
        if (edge.wallId != point.wallId) continue;
        final wall = floor.wallById(edge.wallId);
        if (wall == null) continue;
        final insideSide = edge.fromNodeId == wall.startNodeId ? 1 : -1;
        if (point.wallSide == insideSide) result.add(point);
        break;
      }
    }
    result.sort(
      (a, b) => (a.wallOffsetMm ?? 0).compareTo(b.wallOffsetMm ?? 0),
    );
    return result;
  }

  Future<void> _edit(BuildContext context, ElectricalPoint point) async {
    final wallId = point.wallId;
    if (wallId == null) return;
    final wall = floor.wallById(wallId);
    if (wall == null) return;
    final wallLength = floor.wallLengthMm(wall);
    final offsetController = TextEditingController(
      text: (point.wallOffsetMm ?? 0).round().toString(),
    );
    final heightController = TextEditingController(
      text: point.heightMm.round().toString(),
    );

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          point.label.isEmpty ? 'Электроточка' : point.label,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: offsetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'От угла стены',
                suffixText: 'мм',
                helperText: '0…${wallLength.round()} мм',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Высота от чистого пола',
                suffixText: 'мм',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (accepted != true) {
      offsetController.dispose();
      heightController.dispose();
      return;
    }

    final offset = double.tryParse(offsetController.text.replaceAll(',', '.'));
    final height = double.tryParse(heightController.text.replaceAll(',', '.'));
    offsetController.dispose();
    heightController.dispose();
    if (offset == null ||
        height == null ||
        !offset.isFinite ||
        !height.isFinite ||
        offset < 0 ||
        offset > wallLength ||
        height < 0 ||
        height > 6000) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проверь смещение и высоту точки.')),
        );
      }
      return;
    }

    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null || wallLength < 1) return;
    final t = offset / wallLength;
    point.wallOffsetMm = offset;
    point.heightMm = height;
    point.xMm = a.xMm + (b.xMm - a.xMm) * t;
    point.yMm = a.yMm + (b.yMm - a.yMm) * t;
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points();
    if (points.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        scrollDirection: Axis.horizontal,
        itemCount: points.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final point = points[index];
          return ActionChip(
            avatar: const Icon(
              Icons.electrical_services_outlined,
              size: 16,
            ),
            label: Text(
              '${point.label.isEmpty ? 'Точка' : point.label}  '
              '${(point.wallOffsetMm ?? 0).round()} / ${point.heightMm.round()} мм',
            ),
            side: const BorderSide(color: ZamerColors.outline),
            backgroundColor: ZamerColors.surface,
            labelStyle: ZamerTypography.caption.copyWith(
              color: ZamerColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            onPressed: () => _edit(context, point),
          );
        },
      ),
    );
  }
}
