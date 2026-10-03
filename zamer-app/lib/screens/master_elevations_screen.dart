import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_store.dart';
import 'master_live_elevations_screen.dart';

/// Production entry point for the approved master elevations UI.
///
/// The public constructor stays compatible with the review routes, while the
/// page itself is backed by the real floor model and persists edits.
class MasterElevationsScreen extends StatelessWidget {
  const MasterElevationsScreen({
    super.key,
    required this.floor,
    required this.projectTitle,
    this.onBack,
  });

  final FloorPlan floor;
  final String projectTitle;
  final VoidCallback? onBack;

  Future<void> _persistFloor() async {
    final store = ProjectStore();
    final projects = await store.load();
    for (final project in projects) {
      final index = project.floors.indexWhere((item) => item.id == floor.id);
      if (index < 0) continue;
      project.floors[index] = FloorPlan.fromJson(floor.toJson());
      await store.save(projects);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = MeasureProject(
      id: 'runtime:${floor.id}',
      name: projectTitle,
      floors: [floor],
    );
    return MasterLiveElevationsScreen(
      project: project,
      floor: floor,
      onChanged: _persistFloor,
    );
  }
}
