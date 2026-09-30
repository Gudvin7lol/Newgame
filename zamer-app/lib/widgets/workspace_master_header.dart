import 'package:flutter/material.dart';

import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';

/// Shared project header for the four working master pages.
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
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 56,
      titleSpacing: ZamerSpace.sm,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            floorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZamerTypography.h5.copyWith(
              color: ZamerColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
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
              const SizedBox(width: ZamerSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZamerColors.accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(ZamerRadius.pill),
                  border: Border.all(
                    color: ZamerColors.accent.withValues(alpha: .32),
                  ),
                ),
                child: Text(
                  modeLabel,
                  style: ZamerTypography.caption.copyWith(
                    color: ZamerColors.accent,
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
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
        const SizedBox(width: 2),
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
                height: 18,
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
        const SizedBox(width: 2),
        _HeaderAction(
          tooltip: 'Действия проекта',
          icon: Icons.more_vert_rounded,
          onPressed: onMore,
        ),
        const SizedBox(width: 6),
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
    return ZPressEffect(
      enabled: onPressed != null,
      scale: .90,
      child: SizedBox(
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
      ),
    );
  }
}
