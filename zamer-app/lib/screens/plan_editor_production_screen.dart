import 'package:flutter/material.dart';

import '../models/models.dart';
import 'plan_editor_master_v4_screen.dart';
import 'measure_plan_tool.dart';

class PlanEditorProductionScreen extends StatelessWidget {
  const PlanEditorProductionScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.planTool = MeasurePlanTool.overview,
    this.preferredOpeningType,
    this.onSelectionChanged,
    this.nativeKitV2 = false,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenPlanGeometry,
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
  final MeasurePlanTool planTool;
  final OpeningType? preferredOpeningType;
  final ValueChanged<String?>? onSelectionChanged;
  final bool nativeKitV2;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenPlanGeometry;
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
    return PlanEditorMasterV4Screen(
      floor: floor,
      onChanged: onChanged,
      planTool: planTool,
      preferredOpeningType: preferredOpeningType,
      onSelectionChanged: onSelectionChanged,
      nativeKitV2: nativeKitV2,
      onOpenObjects: onOpenObjects,
      onOpenReview: onOpenReview,
      onOpenGeometry: onOpenPlanGeometry,
      onOpen3D: onOpen3D ?? onOpenPlanGeometry,
      onOpenFloors: onOpenFloors ?? onOpenPlanGeometry,
      onOpenSettings: onOpenSettings ?? onOpenPlanGeometry,
      onOpenMaterials: onOpenMaterials ?? onOpenPlanGeometry,
      onUndo: onUndo,
      onRedo: onRedo,
      canUndo: canUndo,
      canRedo: canRedo,
    );
  }
}
