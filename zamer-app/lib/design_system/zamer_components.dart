import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

class ZCard extends StatelessWidget {
  const ZCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZamerSpace.lg),
    this.onTap,
    this.backgroundColor,
    this.borderColor = ZamerColors.outline,
    this.radius = ZamerRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? ZamerColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class ZSectionTitle extends StatelessWidget {
  const ZSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: ZamerTypography.sectionTitle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ZActionTile extends StatelessWidget {
  const ZActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZamerSpace.sm),
      child: Material(
        color: ZamerColors.surfaceHigh,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
          ),
          leading: Icon(icon, color: ZamerColors.accent),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: ZamerTypography.caption),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class ZSheetFrame extends StatelessWidget {
  const ZSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(
      ZamerSpace.lg,
      ZamerSpace.xxs,
      ZamerSpace.lg,
      ZamerSpace.xl,
    ),
  });

  final String title;
  final String? description;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ZamerTypography.sheetTitle),
            if (description != null) ...[
              const SizedBox(height: ZamerSpace.xs),
              Text(description!, style: ZamerTypography.caption),
            ],
            const SizedBox(height: ZamerSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

class ZStatusChip extends StatelessWidget {
  const ZStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: icon == null ? null : Icon(icon, size: ZamerSize.iconSm),
      label: Text(label),
      backgroundColor: selected
          ? ZamerColors.accent.withValues(alpha: .12)
          : ZamerColors.surface,
      side: BorderSide(
        color: selected ? ZamerColors.accent : ZamerColors.outline,
      ),
      labelStyle: TextStyle(
        color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Compact icon + label action used by toolbars on the working master pages.
class ZToolAction extends StatelessWidget {
  const ZToolAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: ZamerSpace.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
