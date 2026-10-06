import 'package:flutter/material.dart';

import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';

/// Recovery navigation for the approved project structure:
/// Measure / 3D / Elevations. Equipment lives inside Measure.
/// Home and Profile remain reachable without consuming a workspace mode.
class ZRecoveredWorkspacePrimaryNav extends StatelessWidget {
  const ZRecoveredWorkspacePrimaryNav({
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
    final active = selectedIndex.clamp(0, 2).toInt() + 1;
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
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _RecoveredNavItem(
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

class _RecoveredNavItem extends StatelessWidget {
  const _RecoveredNavItem({
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
                width: selected ? 34 : 0,
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
                Icon(icon, size: 19, color: foreground),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: ZamerTypography.caption.copyWith(
                    color: foreground,
                    fontSize: 8.2,
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
