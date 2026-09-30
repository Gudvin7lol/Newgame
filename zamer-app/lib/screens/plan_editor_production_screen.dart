import 'package:flutter/material.dart';

import '../models/models.dart';
import 'plan_editor_master_screen.dart';

class PlanEditorProductionScreen extends StatelessWidget {
  const PlanEditorProductionScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenAdvanced,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    return PlanEditorMasterScreen(
      floor: floor,
      onChanged: onChanged,
      onOpenObjects: onOpenObjects,
      onOpenReview: onOpenReview,
      onOpenGeometry: onOpenAdvanced,
    );
  }
}
