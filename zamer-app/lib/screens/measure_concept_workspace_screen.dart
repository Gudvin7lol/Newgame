import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../widgets/workspace_navigation.dart';
import 'elevations_screen.dart';
import 'plan_editor_production_screen.dart';

/// Production shell for the master «Замер» page.
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
      appBar: _MeasureMasterHeader(
        projectName: widget.project.name,
        floorName: widget.floor.name,
        onCheck: widget.onOpenReview,
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        canUndo: widget.canUndo,
        canRedo: widget.canRedo,
        onSave: () {
          widget.onChanged();
        },
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

class _MeasureMasterHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _MeasureMasterHeader({
    required this.projectName,
    required this.floorName,
    required this.onCheck,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onSave,
    required this.onMore,
  });

  final String projectName;
  final String floorName;
  final VoidCallback onCheck;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onSave;
  final VoidCallback onMore;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        leadingWidth: 42,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.maybePop(context),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ЗАМЕР',
                  style: ZamerTypography.caption.copyWith(
                    color: ZamerColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: ZamerColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    floorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.caption.copyWith(fontSize: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZamerTypography.h5.copyWith(
                color: ZamerColors.textPrimary,
                fontWeight: FontWeight.w750,
              ),
            ),
          ],
        ),
        actions: [
          _HeaderButton(
            tooltip: 'Проверка обмера',
            icon: Icons.fact_check_outlined,
            onTap: onCheck,
          ),
          _HeaderButton(
            tooltip: 'Отменить',
            icon: Icons.undo_rounded,
            onTap: canUndo ? onUndo : null,
          ),
          _HeaderButton(
            tooltip: 'Повторить',
            icon: Icons.redo_rounded,
            onTap: canRedo ? onRedo : null,
          ),
          _HeaderButton(
            tooltip: 'Сохранить',
            icon: Icons.save_outlined,
            onTap: onSave,
            accent: true,
          ),
          _HeaderButton(
            tooltip: 'Ещё',
            icon: Icons.more_vert_rounded,
            onTap: onMore,
          ),
          const SizedBox(width: 3),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: ZamerColors.outlineSoft,
          ),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 36,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? ZamerColors.textSecondary.withValues(alpha: .35)
                : accent
                    ? ZamerColors.accent
                    : ZamerColors.textSecondary,
          ),
        ),
      );
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
      height: 50,
      padding: const EdgeInsets.symmetric(
        horizontal: ZamerSpace.sm,
        vertical: 5,
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
                  size: 16,
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
