import 'package:flutter/material.dart';

import 'zamer_components.dart';
import 'zamer_tokens.dart';

/// Shared header for the five master workspaces.
///
/// The title, context and trailing action keep the same spacing, radii and
/// palette on 3D, Equipment and Elevations instead of each page inventing a
/// slightly different toolbar.
class ZMasterPageHeader extends StatelessWidget {
  const ZMasterPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ZPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: ZamerSpace.md,
        vertical: ZamerSpace.sm,
      ),
      color: ZamerColors.surfaceLow,
      child: Row(
        children: [
          Container(
            width: ZamerSize.minTouch,
            height: ZamerSize.minTouch,
            decoration: BoxDecoration(
              color: ZamerColors.accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(color: ZamerColors.outlineSoft),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: ZamerColors.accent, size: ZamerSize.iconMd),
          ),
          const SizedBox(width: ZamerSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: ZamerTypography.h3),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: ZamerSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
