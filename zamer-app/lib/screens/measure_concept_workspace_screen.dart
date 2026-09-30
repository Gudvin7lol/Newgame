import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../widgets/workspace_master_header.dart';
import '../widgets/workspace_navigation.dart';
import 'elevations_screen.dart';
import 'plan_editor_production_screen.dart';

/// Production shell for the master «Замер» page.
///
/// The shell owns project-level navigation and view switching while the actual
/// 2D geometry work stays in [PlanEditorProductionScreen]. This keeps the
/// approved master UI connected to the real editor instead of a parallel
/// concept-only implementation.
class MeasureConceptWorkspaceScreen extends StatefulWidget {
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
    required this.onOpenPhoto,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
    required this.onHome,
    required this.onProjects,
    required this.onCatalog,
    this.onSelectPrimaryMode,
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
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;

  /// Kept while older callers migrate to the five-section master shell.
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onCatalog;

  /// Project-mode index: 0 = Measure, 1 = 3D, 2 = Equipment, 3 = Elevations.
  final ValueChanged<int>? onSelectPrimaryMode;

  @override
  State<MeasureConceptWorkspaceScreen> createState() =>
      _MeasureConceptWorkspaceScreenState();
}

class _MeasureConceptWorkspaceScreenState
    extends State<MeasureConceptWorkspaceScreen> {
  ZMeasureViewMode _view = ZMeasureViewMode.twoD;

  void _selectView(ZMeasureViewMode value) {
    switch (value) {
      case ZMeasureViewMode.twoD:
        if (_view != value) setState(() => _view = value);
      case ZMeasureViewMode.threeD:
        widget.onOpen3D();
      case ZMeasureViewMode.photo:
        widget.onOpenPhoto();
    }
  }

  void _selectPrimaryMode(int mode) {
    final parentHandler = widget.onSelectPrimaryMode;
    if (parentHandler != null) {
      parentHandler(mode);
      return;
    }

    // Compatibility path for the pre-master caller. Every item still performs
    // real work; no decorative dead buttons are allowed in the production UI.
    switch (mode) {
      case 0:
        return;
      case 1:
        widget.onOpen3D();
      case 2:
        widget.onOpenObjects();
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ElevationsScreen(
              floor: widget.floor,
              onChanged: widget.onChanged,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZamerColors.background,
      appBar: ZWorkspaceHeader(
        projectName: widget.project.name,
        floorName: widget.floor.name,
        modeLabel: 'ЗАМЕР 2D',
        onCheck: widget.onOpenReview,
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        canUndo: widget.canUndo,
        canRedo: widget.canRedo,
        onMore: widget.onMore,
      ),
      body: Column(
        children: [
          _MeasureViewStrip(
            wallCount: widget.floor.walls.length,
            value: _view,
            onChanged: _selectView,
          ),
          Expanded(
            child: PlanEditorProductionScreen(
              floor: widget.floor,
              onChanged: widget.onChanged,
              onOpenObjects: widget.onOpenObjects,
              onOpenReview: widget.onOpenReview,
              onOpenAdvanced: widget.onOpenGeometry,
            ),
          ),
          ZWorkspacePrimaryNav(
            selectedIndex: 0,
            onSelected: _selectPrimaryMode,
            onHome: widget.onHome,
          ),
        ],
      ),
    );
  }
}

class _MeasureViewStrip extends StatelessWidget {
  const _MeasureViewStrip({
    required this.wallCount,
    required this.value,
    required this.onChanged,
  });

  final int wallCount;
  final ZMeasureViewMode value;
  final ValueChanged<ZMeasureViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: ZamerSpace.sm,
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(
          bottom: BorderSide(color: ZamerColors.outlineSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.architecture_outlined,
                  size: 17,
                  color: ZamerColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$wallCount стен',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.caption.copyWith(
                      color: ZamerColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ZMeasureViewTabs(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
