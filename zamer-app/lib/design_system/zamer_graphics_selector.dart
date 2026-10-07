import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

enum ZGraphicsMode { performance, quality, photo }

extension ZGraphicsModeLabel on ZGraphicsMode {
  String get label => switch (this) {
    ZGraphicsMode.performance => 'Performance',
    ZGraphicsMode.quality => 'Quality',
    ZGraphicsMode.photo => 'Photo',
  };

  IconData get icon => switch (this) {
    ZGraphicsMode.performance => Icons.speed_rounded,
    ZGraphicsMode.quality => Icons.auto_awesome_outlined,
    ZGraphicsMode.photo => Icons.photo_camera_outlined,
  };
}

/// Reusable three-mode graphics selector from the master UI specification.
///
/// This widget deliberately knows nothing about the renderer. Screens map the
/// selected UI mode to their realtime/render implementation themselves.
class ZGraphicsModeSelector extends StatelessWidget {
  const ZGraphicsModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = true,
  });

  final ZGraphicsMode value;
  final ValueChanged<ZGraphicsMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZamerColors.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: ZamerColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ZGraphicsMode.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _GraphicsModeItem(
                mode: mode,
                selected: value == mode,
                compact: compact,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _GraphicsModeItem extends StatelessWidget {
  const _GraphicsModeItem({
    required this.mode,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ZGraphicsMode mode;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return Material(
      color: selected ? ZamerColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 7 : 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, size: compact ? 15 : 17, color: foreground),
              const SizedBox(width: 4),
              Text(
                mode.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 9.5 : 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
