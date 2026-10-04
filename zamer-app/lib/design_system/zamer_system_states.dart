import 'package:flutter/material.dart';

import 'zamer_tokens.dart';

enum ZSystemStateKind { empty, loading, success, warning, error }

extension ZSystemStateKindVisuals on ZSystemStateKind {
  Color get color => switch (this) {
        ZSystemStateKind.empty => ZamerColors.textMuted,
        ZSystemStateKind.loading => ZamerColors.accent,
        ZSystemStateKind.success => ZamerColors.success,
        ZSystemStateKind.warning => ZamerColors.warning,
        ZSystemStateKind.error => ZamerColors.danger,
      };

  IconData get icon => switch (this) {
        ZSystemStateKind.empty => Icons.description_outlined,
        ZSystemStateKind.loading => Icons.autorenew_rounded,
        ZSystemStateKind.success => Icons.check_rounded,
        ZSystemStateKind.warning => Icons.warning_amber_rounded,
        ZSystemStateKind.error => Icons.close_rounded,
      };
}

/// Shared visual language for empty, loading, success, warning and error
/// states across Home, Measure, 3D, Elevations and Profile.
class ZSystemStateView extends StatelessWidget {
  const ZSystemStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.icon,
    this.progress,
    this.progressLabel,
    this.remainingLabel,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.preview,
    this.compact = false,
  });

  final ZSystemStateKind kind;
  final String title;
  final String message;
  final IconData? icon;
  final double? progress;
  final String? progressLabel;
  final String? remainingLabel;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? preview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantic = kind.color;
    final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
    final hasPrimary = primaryLabel != null && onPrimary != null;
    final hasSecondary = secondaryLabel != null && onSecondary != null;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? ZamerSpace.md : ZamerSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: EdgeInsets.all(compact ? ZamerSpace.lg : ZamerSpace.xl),
            decoration: BoxDecoration(
              color: ZamerColors.surfaceLow,
              borderRadius: BorderRadius.circular(ZamerRadius.xl),
              border: Border.all(color: ZamerColors.outline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: _StateGlyph(
                    kind: kind,
                    icon: icon ?? kind.icon,
                    color: semantic,
                    progress: normalizedProgress,
                  ),
                ),
                SizedBox(height: compact ? ZamerSpace.md : ZamerSpace.lg),
                if (preview != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZamerRadius.lg),
                    child: preview!,
                  ),
                  const SizedBox(height: ZamerSpace.lg),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: ZamerTypography.h3,
                ),
                const SizedBox(height: ZamerSpace.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: ZamerTypography.bodySmall.copyWith(
                    color: ZamerColors.textMuted,
                  ),
                ),
                if (kind == ZSystemStateKind.loading ||
                    normalizedProgress != null) ...[
                  const SizedBox(height: ZamerSpace.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZamerRadius.pill),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: normalizedProgress,
                      backgroundColor: ZamerColors.surfaceHighest,
                      color: ZamerColors.accent,
                    ),
                  ),
                  const SizedBox(height: ZamerSpace.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          remainingLabel ??
                              (normalizedProgress == null
                                  ? 'Подготавливаем данные…'
                                  : 'Подготовка сцены'),
                          style: ZamerTypography.caption,
                        ),
                      ),
                      if (progressLabel != null || normalizedProgress != null)
                        Text(
                          progressLabel ??
                              '${(normalizedProgress! * 100).round()}%',
                          style: ZamerTypography.technical.copyWith(
                            color: ZamerColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ],
                if (hasPrimary || hasSecondary) ...[
                  const SizedBox(height: ZamerSpace.lg),
                  if (hasPrimary)
                    FilledButton.icon(
                      onPressed: onPrimary,
                      icon: Icon(_primaryIcon(kind)),
                      label: Text(primaryLabel!),
                    ),
                  if (hasPrimary && hasSecondary)
                    const SizedBox(height: ZamerSpace.xs),
                  if (hasSecondary)
                    OutlinedButton.icon(
                      onPressed: onSecondary,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(secondaryLabel!),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _primaryIcon(ZSystemStateKind state) => switch (state) {
        ZSystemStateKind.empty => Icons.add_rounded,
        ZSystemStateKind.loading => Icons.hourglass_top_rounded,
        ZSystemStateKind.success => Icons.folder_open_rounded,
        ZSystemStateKind.warning => Icons.arrow_forward_rounded,
        ZSystemStateKind.error => Icons.refresh_rounded,
      };
}

class _StateGlyph extends StatelessWidget {
  const _StateGlyph({
    required this.kind,
    required this.icon,
    required this.color,
    this.progress,
  });

  final ZSystemStateKind kind;
  final IconData icon;
  final Color color;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    if (kind == ZSystemStateKind.loading) {
      return SizedBox.square(
        dimension: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 58,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                value: progress,
                color: color,
                backgroundColor: ZamerColors.surfaceHighest,
              ),
            ),
            Icon(icon, color: color, size: 24),
          ],
        ),
      );
    }
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .16),
        border: Border.all(color: color.withValues(alpha: .58)),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

/// Inline variant for save/sync warnings and non-blocking results.
class ZSystemStateBanner extends StatelessWidget {
  const ZSystemStateBanner({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final ZSystemStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final semantic = kind.color;
    return Container(
      padding: const EdgeInsets.all(ZamerSpace.sm),
      decoration: BoxDecoration(
        color: semantic.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: semantic.withValues(alpha: .48)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: semantic.withValues(alpha: .18),
            ),
            child: Icon(kind.icon, size: 21, color: semantic),
          ),
          const SizedBox(width: ZamerSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ZamerTypography.bodySmall.copyWith(
                    color: ZamerColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: ZamerTypography.caption),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
