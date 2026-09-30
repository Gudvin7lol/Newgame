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
      titleSpacing: 8,
      title: Row(
        children: [
          Expanded(
            child: Column(
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
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Проверка обмера',
          onPressed: onCheck,
          icon: const Icon(Icons.fact_check_outlined),
        ),
        IconButton(
          tooltip: 'Отменить',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: 'Повторить',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo_rounded),
        ),
        IconButton(
          tooltip: 'Действия проекта',
          onPressed: onMore,
          icon: const Icon(Icons.more_vert_rounded),
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
