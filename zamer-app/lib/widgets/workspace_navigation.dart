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
        ZamerSpace.xs,
        ZamerSpace.sm,
        ZamerSpace.xs,
      ),
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(
          top: BorderSide(color: ZamerColors.outlineSoft),
          bottom: BorderSide(color: ZamerColors.outlineSoft),
        ),
      ),
      child: SizedBox(
        height: ZamerSize.minTouch,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: ZamerSpace.xxs),
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
      scale: .97,
      child: Material(
        color: selected ? ZamerColors.accent : ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(
                color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: ZamerSize.iconSm, color: foreground),
                const SizedBox(width: ZamerSpace.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption.copyWith(
                    color: foreground,
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

/// One visual source of truth for the five production destinations.
///
/// Home and Profile can use the same component as the workspace pages, so the
/// application keeps one navigation geometry and one selected-state language.
class ZPrimaryAppNav extends StatelessWidget {
  const ZPrimaryAppNav({
    super.key,
    required this.selectedIndex,
    required this.onHome,
    required this.onMeasure,
    required this.on3D,
    required this.onElevations,
    required this.onProfile,
  });

  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onMeasure;
  final VoidCallback on3D;
  final VoidCallback onElevations;
  final VoidCallback onProfile;

  static const items = <(IconData icon, String label)>[
    (Icons.home_outlined, 'Главная'),
    (Icons.architecture_outlined, 'Замер'),
    (Icons.view_in_ar_outlined, '3D'),
    (Icons.view_carousel_outlined, 'Развёртки'),
    (Icons.person_outline_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final callbacks = <VoidCallback>[
      onHome,
      onMeasure,
      on3D,
      onElevations,
      onProfile,
    ];
    final active = selectedIndex.clamp(0, items.length - 1).toInt();
    return SafeArea(
      top: false,
      child: Container(
        height: ZamerSize.bottomNavigation,
        decoration: const BoxDecoration(
          color: ZamerColors.surfaceLow,
          border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _PrimaryNavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: i == active,
                  onTap: callbacks[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Primary navigation for Measure/3D/Elevations workspace pages.
/// Equipment remains a functional Measure layer, not a top-level destination.
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

  @override
  Widget build(BuildContext context) => ZPrimaryAppNav(
        selectedIndex: selectedIndex.clamp(0, 2).toInt() + 1,
        onHome: onHome,
        onMeasure: () => onSelected(0),
        on3D: () => onSelected(1),
        onElevations: () => onSelected(2),
        onProfile: onProfile,
      );
}

/// Preview/review navigation follows the production information architecture.
class ZMasterBottomNav extends StatelessWidget {
  const ZMasterBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ZPrimaryAppNav(
        selectedIndex: selectedIndex,
        onHome: () => onSelected(0),
        onMeasure: () => onSelected(1),
        on3D: () => onSelected(2),
        onElevations: () => onSelected(3),
        onProfile: () => onSelected(4),
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
      scale: .95,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              top: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 36 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: ZamerColors.accent,
                  borderRadius: BorderRadius.circular(ZamerRadius.pill),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 42,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? ZamerColors.accent.withValues(alpha: .14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(ZamerRadius.md),
                    border: selected
                        ? Border.all(
                            color: ZamerColors.accent.withValues(alpha: .52),
                          )
                        : null,
                  ),
                  child: Icon(icon, size: 20, color: foreground),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption.copyWith(
                    color: foreground,
                    fontSize: 9.2,
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
