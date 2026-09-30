import 'package:flutter/material.dart';

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
      color: ZamerColors.surfaceLow,
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
      color: ZamerColors.surfaceLow,
      padding: const EdgeInsets.symmetric(vertical: ZamerSpace.xxs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.sm),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(items[i].$1),
                  avatar: Icon(items[i].$2, size: ZamerSize.iconSm),
                  selected: selectedIndex == i,
                  onSelected: (_) => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ZWorkspacePrimaryNav extends StatelessWidget {
  const ZWorkspacePrimaryNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.architecture_outlined),
            label: 'Замер',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_in_ar_outlined),
            label: '3D',
          ),
          NavigationDestination(
            icon: Icon(Icons.chair_alt_outlined),
            label: 'Оснащение',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_carousel_outlined),
            label: 'Развёртки',
          ),
        ],
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
