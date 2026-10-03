import 'package:flutter/material.dart';

import '../models/models.dart';
import 'measure_master_screen.dart';

/// Compatibility entry point for the production Measure workspace.
///
/// The public constructor is kept stable for the surrounding workspace while
/// the visible screen is now the approved warm master composition.
class MeasureConceptWorkspaceScreen extends StatelessWidget {
  const MeasureConceptWorkspaceScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onMore,
    required this.onOpen3D,
    this.onOpenAR,
    required this.onOpenPhoto,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
    this.onOpenMaterials,
    required this.onHome,
    required this.onProjects,
    required this.onCatalog,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onMore;
  final VoidCallback onOpen3D;
  final VoidCallback? onOpenAR;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenMaterials;
  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) => MeasureMasterScreen(
        project: project,
        floor: floor,
        onChanged: onChanged,
        onUndo: onUndo,
        onRedo: onRedo,
        canUndo: canUndo,
        canRedo: canRedo,
        onMore: onMore,
        onOpenObjects: onOpenObjects,
        onOpenGeometry: onOpenGeometry,
        onOpenFloors: onOpenFloors,
        onOpenSettings: onOpenSettings,
      );
}
