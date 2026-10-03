import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import 'planning_objects_screen.dart';

/// Functional bridge between the approved Equipment UI and the live plan.
///
/// The plan page owns direct touch placement. The object list exposes the
/// destructive/edit operations that must also survive a cold restart.
class MasterObjectPlacementWorkspace extends StatefulWidget {
  const MasterObjectPlacementWorkspace({
    super.key,
    required this.floor,
    required this.onChanged,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<MasterObjectPlacementWorkspace> createState() =>
      _MasterObjectPlacementWorkspaceState();
}

class _MasterObjectPlacementWorkspaceState
    extends State<MasterObjectPlacementWorkspace> {
  int _page = 0;

  Future<void> _persist(VoidCallback mutation) async {
    mutation();
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _duplicate(PlanObject object) async {
    await _persist(
      () => EquipmentPlacementService.duplicateObject(
        floor: widget.floor,
        source: object,
      ),
    );
  }

  Future<void> _rotate(PlanObject object) async {
    await _persist(() => EquipmentPlacementService.rotateBy(object, 90));
  }

  Future<void> _delete(PlanObject object) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить объект?'),
        content: Text(_title(object)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _persist(
      () => EquipmentPlacementService.removeObject(
        floor: widget.floor,
        object: object,
      ),
    );
  }

  String _title(PlanObject object) {
    final label = object.label.trim();
    return label.isEmpty ? object.type.label : label;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(
              bottom: BorderSide(color: ZamerColors.outline),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.architecture_outlined),
                      label: Text('План'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Объекты'),
                    ),
                  ],
                  selected: {_page},
                  onSelectionChanged: (selection) =>
                      setState(() => _page = selection.first),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 42),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ZamerColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZamerColors.outline),
                ),
                child: Text(
                  '${widget.floor.planObjects.length}',
                  textAlign: TextAlign.center,
                  style: ZamerTypography.bodySmall.copyWith(
                    color: ZamerColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _page == 0
              ? PlanningObjectsScreen(
                  key: ValueKey(
                    'placement-${widget.floor.planObjects.length}-${widget.floor.electricalPoints.length}',
                  ),
                  floor: widget.floor,
                  onChanged: widget.onChanged,
                )
              : _buildObjectList(),
        ),
      ],
    );
  }

  Widget _buildObjectList() {
    final objects = widget.floor.planObjects.reversed.toList(growable: false);
    if (objects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chair_alt_outlined, size: 42),
              const SizedBox(height: 12),
              Text('Объектов пока нет', style: ZamerTypography.h3),
              const SizedBox(height: 6),
              Text(
                'Добавь модель в каталоге или переключись на «План».',
                textAlign: TextAlign.center,
                style: ZamerTypography.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: objects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final object = objects[index];
        return Material(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _page = 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ZamerColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      object.type == PlanObjectType.sanitary
                          ? Icons.plumbing_outlined
                          : object.type == PlanObjectType.lighting
                              ? Icons.lightbulb_outline_rounded
                              : Icons.chair_alt_outlined,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(object),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.bodySmall.copyWith(
                            color: ZamerColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${object.widthMm.round()} × ${object.depthMm.round()} × ${object.heightMm.round()} мм',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'X ${object.xMm.round()} • Y ${object.yMm.round()} • ${object.rotationDeg.round()}°',
                          style: ZamerTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Повернуть на 90°',
                    onPressed: () => _rotate(object),
                    icon: const Icon(Icons.rotate_right_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Дублировать',
                    onPressed: () => _duplicate(object),
                    icon: const Icon(Icons.content_copy_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Удалить',
                    onPressed: () => _delete(object),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
