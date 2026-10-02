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
    final decoration = BoxDecoration(
      color: backgroundColor ?? ZamerColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outline),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            child: ListTile(
              minLeadingWidth: 26,
              horizontalTitleGap: 10,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(icon, color: ZamerColors.accent, size: 20),
              title: Text(
                title,
                style: const TextStyle(
                  color: ZamerColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: subtitle == null
                  ? null
                  : Text(subtitle!, style: ZamerTypography.caption),
              trailing:
                  trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: ZamerColors.textMuted,
                  ),
            ),
          ),
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
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return ActionChip(
      onPressed: onTap,
      avatar: icon == null
          ? null
          : Icon(icon, size: ZamerSize.iconSm, color: foreground),
      label: Text(label),
      backgroundColor: selected ? ZamerColors.accent : ZamerColors.surface,
      side: BorderSide(
        color: selected ? ZamerColors.accent : ZamerColors.outline,
      ),
      labelStyle: TextStyle(
        color: foreground,
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZamerRadius.md),
      ),
    );
  }
}

/// Compact icon + label action used by toolbars on the five master pages.
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
        color: selected ? ZamerColors.accent : ZamerColors.surfaceHigh,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .4 : 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: ZamerSpace.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZamerRadius.md),
                border: Border.all(
                  color: selected
                      ? ZamerColors.accent
                      : ZamerColors.outlineSoft,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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

class ZPanel extends StatelessWidget {
  const ZPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZamerSpace.md),
    this.color = ZamerColors.surfaceLow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(ZamerRadius.lg),
    clipBehavior: Clip.antiAlias,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: ZamerColors.outline),
      ),
      child: child,
    ),
  );
}

class ZMeasureBadge extends StatelessWidget {
  const ZMeasureBadge(this.value, {super.key, this.calculated = false});

  final String value;
  final bool calculated;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: calculated
          ? ZamerColors.info.withValues(alpha: .16)
          : ZamerColors.surfaceHighest.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      border: Border.all(
        color: calculated
            ? ZamerColors.info.withValues(alpha: .65)
            : ZamerColors.outline,
      ),
    ),
    child: Text(value, style: ZamerTypography.measurement),
  );
}

class ZPropertyRow extends StatelessWidget {
  const ZPropertyRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: ZamerColors.textMuted),
              const SizedBox(width: ZamerSpace.sm),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: ZamerColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: ZamerSpace.md),
            Text(
              value,
              style: const TextStyle(
                color: ZamerColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: ZamerColors.textFaint,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ZLayerToggle extends StatelessWidget {
  const ZLayerToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.locked = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ZamerColors.outlineSoft)),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: ZamerColors.textMuted),
          const SizedBox(width: ZamerSpace.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ZamerColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (locked)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: ZamerColors.textFaint,
            ),
          ),
        Switch.adaptive(value: value, onChanged: locked ? null : onChanged),
      ],
    ),
  );
}

class ZObjectCardFrame extends StatelessWidget {
  const ZObjectCardFrame({
    super.key,
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.favorite = false,
    this.onFavorite,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Material(
    color: ZamerColors.surface,
    borderRadius: BorderRadius.circular(ZamerRadius.md),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ZamerColors.outline),
          borderRadius: BorderRadius.circular(ZamerRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: ZamerColors.surfaceHigh, child: preview),
                  if (onFavorite != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onFavorite,
                        icon: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: favorite
                              ? ZamerColors.danger
                              : ZamerColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ZLoadingState extends StatelessWidget {
  const ZLoadingState({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
  });

  final String title;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ZamerSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: ZCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 38,
                child: CircularProgressIndicator(value: progress),
              ),
              const SizedBox(height: ZamerSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ZamerTypography.sectionTitle,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: ZamerSpace.xs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: ZamerTypography.caption,
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: ZamerSpace.md),
                LinearProgressIndicator(value: progress),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class ZEmptyState extends StatelessWidget {
  const ZEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ZamerSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ZamerColors.textFaint),
            const SizedBox(height: ZamerSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ZamerTypography.sectionTitle,
            ),
            const SizedBox(height: ZamerSpace.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: ZamerTypography.caption,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: ZamerSpace.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

class ZErrorState extends StatelessWidget {
  const ZErrorState({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ZamerSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: ZCard(
          borderColor: ZamerColors.danger.withValues(alpha: .55),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: ZamerColors.danger,
              ),
              const SizedBox(height: ZamerSpace.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ZamerTypography.sectionTitle,
              ),
              const SizedBox(height: ZamerSpace.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: ZamerTypography.caption,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: ZamerSpace.lg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
