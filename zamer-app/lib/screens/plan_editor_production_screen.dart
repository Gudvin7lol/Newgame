import 'package:flutter/material.dart';

import '../models/models.dart';
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
    return PlanEditorMasterV4Screen(
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
    );
  }
}
