import 'package:flutter/material.dart';

import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';

class ZWorkspaceLayerLegend extends StatelessWidget {
  const ZWorkspaceLayerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZamerSpace.md,
        vertical: ZamerSpace.xs,
      ),
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(
          bottom: BorderSide(color: ZamerColors.outlineSoft),
        ),
      ),
      child: const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _LayerDot(color: ZamerColors.textSecondary, text: 'Существующее'),
            SizedBox(width: ZamerSpace.lg),
            _LayerDot(color: ZamerColors.danger, text: 'Демонтаж'),
            SizedBox(width: ZamerSpace.lg),
            _LayerDot(color: ZamerColors.success, text: 'Новая планировка'),
          ],
        ),
      ),
    );
  }
}

class ZWorkspaceSubnav extends StatelessWidget {
  const ZWorkspaceSubnav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, IconData)> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.length <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZamerSpace.sm,
        6,
        ZamerSpace.sm,
        6,
      ),
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(3),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (_, i) => _SubnavItem(
            icon: items[i].$2,
            label: items[i].$1,
            selected: selectedIndex == i,
            onTap: () => onSelected(i),
          ),
        ),
      ),
    );
  }
}

class _SubnavItem extends StatelessWidget {
  const _SubnavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return ZPressEffect(
      scale: .96,
      child: Material(
        color: selected ? ZamerColors.accent : ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.sm),
              border: Border.all(
                color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

/// Primary production navigation.
///
/// Equipment is intentionally not a top-level destination anymore. Furniture,
/// electrical, engineering, floors and materials live as functional layers in
/// Measure. This keeps the main navigation aligned with the actual field
/// workflow: project -> measure -> 3D -> documentation -> profile.
class ZWorkspacePrimaryNav extends StatelessWidget {
  const ZWorkspacePrimaryNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onHome,
    required this.onProfile,
  });

  /// Workspace index: 0 = Measure, 1 = 3D, 2 = Elevations.
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onHome;
  final VoidCallback onProfile;

  static const _items = <(IconData icon, String label)>[
    (Icons.home_outlined, 'Главная'),
    (Icons.architecture_outlined, 'Замер'),
    (Icons.view_in_ar_outlined, '3D'),
    (Icons.view_carousel_outlined, 'Развёртки'),
    (Icons.person_outline_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final active = selectedIndex.clamp(0, 2) + 1;
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          color: ZamerColors.surfaceLow,
          border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _PrimaryNavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: i == active,
                  onTap: switch (i) {
                    0 => onHome,
                    1 => () => onSelected(0),
                    2 => () => onSelected(1),
                    3 => () => onSelected(2),
                    _ => onProfile,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Preview/review navigation follows the same production information
/// architecture as the live app.
class ZMasterBottomNav extends StatelessWidget {
  const ZMasterBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(IconData icon, String label)>[
    (Icons.home_outlined, 'Главная'),
    (Icons.architecture_outlined, 'Замер'),
    (Icons.view_in_ar_outlined, '3D'),
    (Icons.view_carousel_outlined, 'Развёртки'),
    (Icons.person_outline_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: 62,
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _PrimaryNavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _PrimaryNavItem extends StatelessWidget {
  const _PrimaryNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accent
        : ZamerColors.textSecondary;
    return ZPressEffect(
      scale: .94,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (selected)
              Positioned(
                top: 0,
                child: Container(
                  width: 30,
                  height: 2,
                  decoration: BoxDecoration(
                    color: ZamerColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? ZamerColors.accent.withValues(alpha: .13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(ZamerRadius.sm),
                    border: selected
                        ? Border.all(
                            color: ZamerColors.accent.withValues(alpha: .55),
                          )
                        : null,
                  ),
                  child: Icon(icon, size: 19, color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 8.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerDot extends StatelessWidget {
  const _LayerDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: ZamerSpace.xxs),
          Text(text, style: ZamerTypography.caption),
        ],
      );
}
