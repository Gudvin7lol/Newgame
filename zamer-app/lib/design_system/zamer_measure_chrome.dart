import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

enum ZMeasureViewMode { twoD, threeD, photo }

enum ZMeasureTool {
  walls,
  openings,
  objects,
  dimensions,
  text,
  layers,
}

extension ZMeasureToolMeta on ZMeasureTool {
  String get label => switch (this) {
    ZMeasureTool.walls => 'Стены',
    ZMeasureTool.openings => 'Проёмы',
    ZMeasureTool.objects => 'Объекты',
    ZMeasureTool.dimensions => 'Размеры',
    ZMeasureTool.text => 'Текст',
    ZMeasureTool.layers => 'Слои',
  };

  IconData get icon => switch (this) {
    ZMeasureTool.walls => Icons.view_week_outlined,
    ZMeasureTool.openings => Icons.door_front_door_outlined,
    ZMeasureTool.objects => Icons.chair_alt_outlined,
    ZMeasureTool.dimensions => Icons.straighten_outlined,
    ZMeasureTool.text => Icons.title_rounded,
    ZMeasureTool.layers => Icons.layers_outlined,
  };
}

class ZMeasureViewTabs extends StatelessWidget {
  const ZMeasureViewTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ZMeasureViewMode value;
  final ValueChanged<ZMeasureViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('2D', ZMeasureViewMode.twoD),
          _tab('3D', ZMeasureViewMode.threeD),
          _tab('Фото', ZMeasureViewMode.photo),
        ],
      ),
    );
  }

  Widget _tab(String label, ZMeasureViewMode mode) {
    final selected = mode == value;
    return Material(
      color: selected ? ZamerColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(ZamerRadius.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(mode),
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 28),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? ZamerColors.accentInk
                  : ZamerColors.textSecondary,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class ZMeasureToolRail extends StatelessWidget {
  const ZMeasureToolRail({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabledTools = ZMeasureTool.values,
  });

  final ZMeasureTool value;
  final ValueChanged<ZMeasureTool> onChanged;
  final List<ZMeasureTool> enabledTools;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tool in enabledTools) ...[
            _item(tool),
            if (tool != enabledTools.last) const SizedBox(height: 3),
          ],
        ],
      ),
    );
  }

  Widget _item(ZMeasureTool tool) {
    final selected = tool == value;
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;

    return Tooltip(
      message: tool.label,
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(tool),
          child: SizedBox(
            width: 44,
            height: 45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, size: 18, color: foreground),
                const SizedBox(height: 2),
                Text(
                  tool.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 7.6,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

class ZMeasureCanvasAction extends StatelessWidget {
  const ZMeasureCanvasAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? ZamerColors.accent : ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Opacity(
            opacity: onPressed == null ? .4 : 1,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
                border: Border.all(
                  color: active ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Icon(icon, size: 18, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
