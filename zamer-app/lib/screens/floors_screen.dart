import 'package:flutter/material.dart';

import '../models/models.dart';
import 'floor_workspace_screen.dart';

/// Compatibility entry point kept for older Home/project routes.
///
/// Floors are no longer a separate user-facing page. Opening a project goes
/// directly into Measure; floor switching and creation live inside Measure.
class FloorsScreen extends StatefulWidget {
  const FloorsScreen({
    super.key,
    required this.project,
    required this.onChanged,
  });

  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends State<FloorsScreen> {
  late final FloorPlan _floor;
  bool _createdFloor = false;

  @override
  void initState() {
    super.initState();
    if (widget.project.floors.isEmpty) {
      _createdFloor = true;
      widget.project.floors.add(
        FloorPlan(
          id: 'f-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Этаж 1',
        ),
      );
    }
    _floor = widget.project.floors.first;
    if (_createdFloor) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.onChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) => FloorWorkspaceScreen(
        project: widget.project,
        floor: _floor,
        onChanged: widget.onChanged,
        initialMode: 0,
      );
}
