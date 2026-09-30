import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';

class ZWorkspaceContextStrip extends StatelessWidget {
  const ZWorkspaceContextStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<ZWorkspaceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(
          bottom: BorderSide(color: ZamerColors.outlineSoft),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        ZamerSpace.md,
        ZamerSpace.xs,
        ZamerSpace.sm,
        ZamerSpace.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZamerColors.accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(ZamerRadius.sm),
              border: Border.all(
                color: ZamerColors.accent.withValues(alpha: .35),
              ),
            ),
            child: Icon(icon, size: 18, color: ZamerColors.accent),
          ),
          const SizedBox(width: ZamerSpace.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ZamerColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: ZamerSpace.sm),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: ZamerSpace.xxs),
                    _MetricChip(metric: metrics[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ZWorkspaceMetric {
  const ZWorkspaceMetric({
    required this.icon,
    required this.value,
    this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String value;
  final String? label;
  final bool emphasized;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric});

  final ZWorkspaceMetric metric;

  @override
  Widget build(BuildContext context) {
    final foreground = metric.emphasized
        ? ZamerColors.accent
        : ZamerColors.textSecondary;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: metric.emphasized
            ? ZamerColors.accent.withValues(alpha: .10)
            : ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        border: Border.all(
          color: metric.emphasized
              ? ZamerColors.accent.withValues(alpha: .4)
              : ZamerColors.outlineSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(metric.icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            metric.value,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (metric.label != null) ...[
            const SizedBox(width: 3),
            Text(
              metric.label!,
              style: const TextStyle(
                color: ZamerColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
