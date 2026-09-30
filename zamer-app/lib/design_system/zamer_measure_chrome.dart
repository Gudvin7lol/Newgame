import 'package:flutter/material.dart';

import 'zamer_press_effect.dart';
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
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('2D', Icons.architecture_outlined, ZMeasureViewMode.twoD),
          _tab('3D', Icons.view_in_ar_outlined, ZMeasureViewMode.threeD),
          _tab('Фото', Icons.camera_alt_outlined, ZMeasureViewMode.photo),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, ZMeasureViewMode mode) {
    final selected = mode == value;
    return ZPressEffect(
      scale: .96,
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(mode),
          child: Container(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: ZamerTypography.caption.copyWith(
                    color: selected
                        ? ZamerColors.accentInk
                        : ZamerColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        border: Border.all(color: ZamerColors.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
      child: ZPressEffect(
        scale: .93,
        child: Material(
          color: selected ? ZamerColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(tool),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool.icon, size: 19, color: foreground),
                  const SizedBox(height: 2),
                  Text(
                    tool.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 7.8,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
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
      child: ZPressEffect(
        enabled: onPressed != null,
        scale: .92,
        child: Material(
          color: active ? ZamerColors.accent : ZamerColors.surfaceLow,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Opacity(
              opacity: onPressed == null ? .4 : 1,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ZamerRadius.sm),
                  border: Border.all(
                    color: active
                        ? ZamerColors.accent
                        : ZamerColors.outlineSoft,
                  ),
                ),
                child: Icon(icon, size: 19, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
