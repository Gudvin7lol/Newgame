import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/professional_measurement_service.dart';
import 'plan_editor_master_v4_screen.dart';

class PlanEditorProductionScreen extends StatelessWidget {
  const PlanEditorProductionScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenAdvanced,
    this.onOpen3D,
    this.onOpenFloors,
    this.onOpenSettings,
    this.onOpenMaterials,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenAdvanced;
  final VoidCallback? onOpen3D;
  final VoidCallback? onOpenFloors;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenMaterials;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  @override
  Widget build(BuildContext context) {
    final audit = ProfessionalMeasurementService.audit(floor);
    final hasGeometry = floor.walls.any((wall) => !wall.demolition);
    final tone = audit.criticalCount > 0
        ? ZamerColors.danger
        : audit.checks.isEmpty && audit.expectedDimensions > 0
            ? ZamerColors.success
            : ZamerColors.warning;
    final percent = (audit.completion * 100).round();

    return Column(
      children: [
        Material(
          color: ZamerColors.surfaceLow,
          child: InkWell(
            onTap: onOpenReview,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: ZamerSpace.md,
                vertical: ZamerSpace.xs,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ZamerColors.outlineSoft),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tone.withValues(alpha: .14),
                    ),
                    child: Icon(
                      audit.criticalCount > 0
                          ? Icons.error_outline_rounded
                          : audit.checks.isEmpty && audit.expectedDimensions > 0
                              ? Icons.verified_outlined
                              : Icons.fact_check_outlined,
                      size: 18,
                      color: tone,
                    ),
                  ),
                  const SizedBox(width: ZamerSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Контроль обмера',
                          style: ZamerTypography.bodySmall.copyWith(
                            color: ZamerColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          !hasGeometry
                              ? 'Постройте стены, чтобы запустить профессиональную проверку'
                              : audit.expectedDimensions == 0
                                  ? '${audit.checks.length} замечаний • размеры ещё не записаны'
                                  : '${audit.confirmedDimensions}/${audit.expectedDimensions} подтверждено • $percent% • ${audit.checks.length} замечаний',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  if (audit.criticalCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ZamerColors.danger.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(ZamerRadius.pill),
                        border: Border.all(
                          color: ZamerColors.danger.withValues(alpha: .45),
                        ),
                      ),
                      child: Text(
                        '${audit.criticalCount}',
                        style: const TextStyle(
                          color: ZamerColors.danger,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZamerSpace.xs),
                  ],
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ZamerColors.textFaint,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: PlanEditorMasterV4Screen(
            floor: floor,
            onChanged: onChanged,
            onOpenObjects: onOpenObjects,
            onOpenReview: onOpenReview,
            onOpenGeometry: onOpenAdvanced,
            onOpen3D: onOpen3D ?? onOpenAdvanced,
            onOpenFloors: onOpenFloors ?? onOpenAdvanced,
            onOpenSettings: onOpenSettings ?? onOpenAdvanced,
            onOpenMaterials: onOpenMaterials ?? onOpenAdvanced,
            onUndo: onUndo,
            onRedo: onRedo,
            canUndo: canUndo,
            canRedo: canRedo,
          ),
        ),
      ],
    );
  }
}
