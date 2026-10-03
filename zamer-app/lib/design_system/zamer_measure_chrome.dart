import 'package:flutter/material.dart';

import 'zamer_press_effect.dart';
import 'zamer_tokens.dart';

/// View modes from the approved UI KIT 02 selector.
///
/// This is intentionally a value type rather than an enum. Older production
/// workspaces still contain three-mode switch statements, while the approved
/// Measure screen has four visible modes. Keeping the values as constants lets
/// those older routes remain source-compatible while the Measure shell exposes
/// a distinct AR mode instead of silently deleting it.
@immutable
class ZMeasureViewMode {
  const ZMeasureViewMode._(this.name);

  final String name;

  static const twoD = ZMeasureViewMode._('twoD');
  static const threeD = ZMeasureViewMode._('threeD');
  static const ar = ZMeasureViewMode._('ar');
  static const photo = ZMeasureViewMode._('photo');

  static const values = <ZMeasureViewMode>[twoD, threeD, ar, photo];

  @override
  String toString() => 'ZMeasureViewMode.$name';
}

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

/// UI KIT 02 view selector. Modes that are not production-ready can remain
/// visible for design continuity while being clearly disabled instead of
/// pretending to work.
class ZMeasureViewTabs extends StatelessWidget {
  const ZMeasureViewTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabledModes = ZMeasureViewMode.values,
  });

  final ZMeasureViewMode value;
  final ValueChanged<ZMeasureViewMode> onChanged;
  final List<ZMeasureViewMode> enabledModes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        children: [
          Expanded(child: _tab('2D', ZMeasureViewMode.twoD)),
          const SizedBox(width: 4),
          Expanded(child: _tab('3D', ZMeasureViewMode.threeD)),
          const SizedBox(width: 4),
          Expanded(child: _tab('AR', ZMeasureViewMode.ar)),
          const SizedBox(width: 4),
          Expanded(child: _tab('Фото', ZMeasureViewMode.photo)),
        ],
      ),
    );
  }

  Widget _tab(String label, ZMeasureViewMode mode) {
    final selected = mode == value;
    final enabled = enabledModes.contains(mode);
    return Opacity(
      opacity: enabled ? 1 : .38,
      child: Tooltip(
        message: enabled ? label : '$label пока недоступен в этой сборке',
        child: ZPressEffect(
          enabled: enabled,
          scale: .97,
          child: Material(
            color: selected ? ZamerColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(ZamerRadius.sm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => onChanged(mode) : null,
              child: Center(
                child: Text(
                  label,
                  style: ZamerTypography.button.copyWith(
                    fontSize: 13,
                    color: selected
                        ? ZamerColors.accentInk
                        : ZamerColors.textPrimary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
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
    final foreground =
        selected ? ZamerColors.accentInk : ZamerColors.textSecondary;

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
    final foreground =
        active ? ZamerColors.accentInk : ZamerColors.textSecondary;
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
