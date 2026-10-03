import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

/// Shared primitives copied from the approved MASTER CONCEPT boards.
/// Keep these deliberately small: screens compose them without inventing
/// another visual language on top.
class ZMasterPanel extends StatelessWidget {
  const ZMasterPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: child,
      );
}

class ZMasterTopBar extends StatelessWidget {
  const ZMasterTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onSettings,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZamerTypography.h5.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZamerTypography.caption,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onSettings != null)
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined, size: 22),
              ),
          ],
        ),
      );
}

class ZMasterSegmentedControl extends StatelessWidget {
  const ZMasterSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 42,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: ZamerColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Material(
                    color: i == selectedIndex
                        ? ZamerColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => onSelected(i),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: ZamerTypography.button.copyWith(
                            color: i == selectedIndex
                                ? ZamerColors.accentInk
                                : ZamerColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class ZMasterToolButton extends StatelessWidget {
  const ZMasterToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textPrimary;
    return Opacity(
      opacity: onTap == null ? .42 : 1,
      child: Material(
        color: selected ? ZamerColors.accent : ZamerColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(
              minHeight: compact ? 58 : 70,
              minWidth: compact ? 54 : 62,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? ZamerColors.accent : ZamerColors.outline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: compact ? 23 : 28),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption.copyWith(
                    color: foreground,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ZMasterVerticalToolButton extends StatelessWidget {
  const ZMasterVerticalToolButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 28),
      color: selected ? ZamerColors.accent : ZamerColors.textPrimary,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: selected
            ? ZamerColors.accent.withValues(alpha: .08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class ZMasterCategoryTile extends StatelessWidget {
  const ZMasterCategoryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? ZamerColors.accentInk
                      : ZamerColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: ZamerTypography.bodySmall.copyWith(
                      color: selected
                          ? ZamerColors.accentInk
                          : ZamerColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class ZMasterSectionTitle extends StatelessWidget {
  const ZMasterSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: ZamerTypography.h5.copyWith(
                color: ZamerColors.accent,
                letterSpacing: .25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}
