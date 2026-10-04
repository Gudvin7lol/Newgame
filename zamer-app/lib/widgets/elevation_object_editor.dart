import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';
import '../services/object_catalog.dart';

/// Edits real wall-bound project objects from the selected elevation.
///
/// The object remains the same [PlanObject] used by Measure and 3D. Exact wall
/// placement is delegated to [EquipmentPlacementService], which also keeps a
/// linked lighting point synchronized for sconces and other fixed lights.
class ElevationObjectEditor extends StatelessWidget {
  const ElevationObjectEditor({
    super.key,
    required this.floor,
    required this.run,
    required this.onChanged,
  });

  final FloorPlan floor;
  final ElevationRun run;
  final Future<void> Function() onChanged;

  List<({PlanObject object, String wallId, double offsetMm, int wallSide})>
      _objects() {
    final result =
        <({PlanObject object, String wallId, double offsetMm, int wallSide})>[];
    for (final object in floor.planObjects) {
      if (object.layer == ProjectLayer.demolition || object.catalogId.isEmpty) {
        continue;
      }
      final item = ObjectCatalog.byId(object.catalogId);
      final wallBound =
          item.mount == CatalogMount.wall || object.type == PlanObjectType.radiator;
      if (!wallBound) continue;
      final mount = EquipmentPlacementService.wallMountForObject(
        floor: floor,
        object: object,
      );
      if (mount == null) continue;

      for (final edge in run.edges) {
        if (edge.wallId != mount.wallId) continue;
        final wall = floor.wallById(edge.wallId);
        if (wall == null) break;
        final insideSide = edge.fromNodeId == wall.startNodeId ? 1 : -1;
        if (mount.wallSide == insideSide) {
          result.add((
            object: object,
            wallId: mount.wallId,
            offsetMm: mount.wallOffsetMm,
            wallSide: insideSide,
          ));
        }
        break;
      }
    }
    result.sort((a, b) => a.offsetMm.compareTo(b.offsetMm));
    return result;
  }

  Future<void> _edit(
    BuildContext context,
    ({PlanObject object, String wallId, double offsetMm, int wallSide}) mounted,
  ) async {
    final object = mounted.object;
    final wall = floor.wallById(mounted.wallId);
    if (wall == null) return;
    final wallLength = floor.wallLengthMm(wall);
    final offsetController = TextEditingController(
      text: mounted.offsetMm.round().toString(),
    );
    final elevationController = TextEditingController(
      text: object.elevationMm.round().toString(),
    );

    final action = await showDialog<_ObjectEditAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(object.label.isEmpty ? 'Настенный объект' : object.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${object.widthMm.round()} × ${object.heightMm.round()} мм',
              style: ZamerTypography.caption,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: offsetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'От начала стены',
                suffixText: 'мм',
                helperText: '0…${wallLength.round()} мм',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: elevationController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Низ объекта от чистого пола',
                suffixText: 'мм',
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _ObjectEditAction.delete),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ObjectEditAction.save),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (action == _ObjectEditAction.delete) {
      EquipmentPlacementService.removeObject(floor: floor, object: object);
      await onChanged();
      offsetController.dispose();
      elevationController.dispose();
      return;
    }
    if (action != _ObjectEditAction.save) {
      offsetController.dispose();
      elevationController.dispose();
      return;
    }

    final offset = double.tryParse(offsetController.text.replaceAll(',', '.'));
    final elevation =
        double.tryParse(elevationController.text.replaceAll(',', '.'));
    offsetController.dispose();
    elevationController.dispose();
    if (offset == null ||
        elevation == null ||
        !offset.isFinite ||
        !elevation.isFinite ||
        offset < 0 ||
        offset > wallLength ||
        elevation < 0 ||
        elevation + object.heightMm > 6000) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проверь привязку и высоту объекта.')),
        );
      }
      return;
    }

    final placed = EquipmentPlacementService.placeWallObjectAt(
      floor: floor,
      object: object,
      wallId: mounted.wallId,
      wallOffsetMm: offset,
      wallSide: mounted.wallSide,
      elevationMm: elevation,
    );
    if (!placed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объект не удалось привязать к стене.')),
        );
      }
      return;
    }
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final objects = _objects();
    if (objects.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        scrollDirection: Axis.horizontal,
        itemCount: objects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final mounted = objects[index];
          final object = mounted.object;
          return ActionChip(
            avatar: Icon(
              object.type == PlanObjectType.lighting
                  ? Icons.light_outlined
                  : object.type == PlanObjectType.radiator
                      ? Icons.heat_pump_outlined
                      : Icons.inventory_2_outlined,
              size: 16,
            ),
            label: Text(
              '${object.label.isEmpty ? 'Объект' : object.label}  '
              '${mounted.offsetMm.round()} / +${object.elevationMm.round()} мм',
            ),
            side: const BorderSide(color: ZamerColors.outline),
            backgroundColor: ZamerColors.surface,
            labelStyle: ZamerTypography.caption.copyWith(
              color: ZamerColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            onPressed: () => _edit(context, mounted),
          );
        },
      ),
    );
  }
}

enum _ObjectEditAction { save, delete }
