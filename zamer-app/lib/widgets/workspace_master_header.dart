import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';

/// Shared project header for the four working master pages.
///
/// Keeps project/floor identity and the most important project actions in one
/// predictable place instead of rebuilding a slightly different AppBar on
/// every screen.
class ZWorkspaceHeader extends StatelessWidget implements PreferredSizeWidget {
  const ZWorkspaceHeader({
    super.key,
    required this.projectName,
    required this.floorName,
    required this.modeLabel,
    required this.onCheck,
    required this.onUndo,
    required this.onRedo,
    required this.onMore,
    this.canUndo = false,
    this.canRedo = false,
  });

  final String projectName;
  final String floorName;
  final String modeLabel;
  final VoidCallback onCheck;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onMore;
  final bool canUndo;
  final bool canRedo;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 62,
      titleSpacing: ZamerSpace.sm,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            floorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZamerColors.textPrimary,
              fontSize: 16.5,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Flexible(
                child: Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption,
                ),
              ),
              const SizedBox(width: ZamerSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ZamerColors.accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(ZamerRadius.pill),
                  border: Border.all(
                    color: ZamerColors.accent.withValues(alpha: .28),
                  ),
                ),
                child: Text(
                  modeLabel,
                  style: const TextStyle(
                    color: ZamerColors.accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _HeaderAction(
          tooltip: 'Проверка обмера',
          icon: Icons.fact_check_outlined,
          onPressed: onCheck,
        ),
        const SizedBox(width: 3),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: ZamerColors.surfaceHigh,
            borderRadius: BorderRadius.circular(ZamerRadius.md),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderAction(
                tooltip: 'Отменить',
                icon: Icons.undo_rounded,
                onPressed: canUndo ? onUndo : null,
                compact: true,
              ),
              const SizedBox(
                height: 20,
                child: VerticalDivider(width: 1, thickness: 1),
              ),
              _HeaderAction(
                tooltip: 'Повторить',
                icon: Icons.redo_rounded,
                onPressed: canRedo ? onRedo : null,
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        _HeaderAction(
          tooltip: 'Действия проекта',
          icon: Icons.more_vert_rounded,
          onPressed: onMore,
        ),
        const SizedBox(width: ZamerSpace.xs),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: ZamerColors.outlineSoft),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 34 : 38,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 19,
        icon: Icon(icon),
      ),
    );
  }
}
