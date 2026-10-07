import 'dart:io';

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';

class ZHomeQuickActionCard extends StatelessWidget {
  const ZHomeQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled
        ? ZamerColors.accentInk
        : ZamerColors.textPrimary;
    final secondaryForeground = filled
        ? ZamerColors.accentInk.withValues(alpha: .72)
        : ZamerColors.textMuted;
    return Material(
      color: filled ? ZamerColors.accent : ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .42 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(
              horizontal: ZamerSpace.md,
              vertical: ZamerSpace.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(
                color: filled ? ZamerColors.accent : ZamerColors.outline,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled
                        ? ZamerColors.accentInk.withValues(alpha: .08)
                        : ZamerColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(ZamerRadius.sm),
                    border: Border.all(
                      color: filled
                          ? ZamerColors.accentInk.withValues(alpha: .12)
                          : ZamerColors.outlineSoft,
                    ),
                  ),
                  child: Icon(icon, color: foreground, size: 19),
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
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11.6,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryForeground,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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

class ZActiveProjectCard extends StatelessWidget {
  const ZActiveProjectCard({
    super.key,
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.areaLabel,
    required this.roomsLabel,
    required this.floorsLabel,
    required this.onOpen,
    this.onMore,
  });

  final Widget preview;
  final String title;
  final String subtitle;
  final String areaLabel;
  final String roomsLabel;
  final String floorsLabel;
  final VoidCallback onOpen;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Material(
    color: ZamerColors.surface,
    borderRadius: BorderRadius.circular(ZamerRadius.lg),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZamerRadius.lg),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 122,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          ZamerColors.background.withValues(alpha: .12),
                          ZamerColors.background.withValues(alpha: .88),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: ZamerSpace.md,
                    top: ZamerSpace.md,
                    child: _ActiveBadge(),
                  ),
                  if (onMore != null)
                    Positioned(
                      right: ZamerSpace.xs,
                      top: ZamerSpace.xs,
                      child: IconButton.filledTonal(
                        tooltip: 'Действия проекта',
                        onPressed: onMore,
                        icon: const Icon(Icons.more_horiz_rounded, size: 19),
                      ),
                    ),
                  Positioned(
                    left: ZamerSpace.md,
                    right: ZamerSpace.md,
                    bottom: ZamerSpace.sm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZamerColors.textPrimary,
                            fontSize: 17,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZamerColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZamerSpace.md,
                ZamerSpace.sm,
                ZamerSpace.md,
                ZamerSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: ZamerSpace.md,
                      runSpacing: ZamerSpace.xs,
                      children: [
                        ZMetaChip(
                          icon: Icons.square_foot_outlined,
                          label: areaLabel,
                        ),
                        ZMetaChip(
                          icon: Icons.meeting_room_outlined,
                          label: roomsLabel,
                        ),
                        ZMetaChip(
                          icon: Icons.layers_outlined,
                          label: floorsLabel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZamerSpace.sm),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: const Text('Продолжить'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: ZamerColors.accent,
      borderRadius: BorderRadius.circular(ZamerRadius.pill),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt_rounded, size: 13, color: ZamerColors.accentInk),
        SizedBox(width: 3),
        Text(
          'АКТИВНЫЙ ПРОЕКТ',
          style: TextStyle(
            color: ZamerColors.accentInk,
            fontSize: 8.4,
            fontWeight: FontWeight.w900,
            letterSpacing: .35,
          ),
        ),
      ],
    ),
  );
}

class ZProjectThumbnail extends StatelessWidget {
  const ZProjectThumbnail({
    super.key,
    required this.photoPath,
    required this.fallbackKind,
  });

  final String? photoPath;
  final int fallbackKind;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null) {
      return ClipRect(
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              CustomPaint(painter: _TemplateScenePainter(kind: fallbackKind)),
        ),
      );
    }
    return CustomPaint(painter: _TemplateScenePainter(kind: fallbackKind));
  }
}

class ZProjectTemplateCard extends StatelessWidget {
  const ZProjectTemplateCard({
    super.key,
    required this.kind,
    required this.title,
    required this.onTap,
  });

  final int kind;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: ZamerSpace.sm),
    child: SizedBox(
      width: 108,
      child: Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outline),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ZamerRadius.md - 1),
                    ),
                    child: CustomPaint(
                      painter: _TemplateScenePainter(kind: kind),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZamerSpace.sm,
                    vertical: ZamerSpace.sm,
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
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

class ZMetaChip extends StatelessWidget {
  const ZMetaChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: ZamerColors.textSecondary),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          fontSize: 9.1,
          color: ZamerColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Home-side version of the same five-section navigation used in the project
/// workspace. Until a project is chosen, all working destinations bring the
/// user to the project list instead of pretending a project context exists.
class ZHomeNavBar extends StatelessWidget {
  const ZHomeNavBar({
    super.key,
    required this.onProjects,
    required this.onCatalog,
    required this.onLearn,
    required this.onMore,
  });

  final VoidCallback onProjects;

  // Kept for source compatibility while ProjectsScreen is migrated away from
  // the old home-only navigation actions.
  final VoidCallback onCatalog;
  final VoidCallback onLearn;
  final VoidCallback onMore;

  static const _items = <(IconData icon, String label)>[
    (Icons.home_rounded, 'Главная'),
    (Icons.architecture_outlined, 'Замер'),
    (Icons.view_in_ar_outlined, '3D'),
    (Icons.chair_alt_outlined, 'Оснащение'),
    (Icons.view_carousel_outlined, 'Развёртки'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 60,
      decoration: const BoxDecoration(
        color: ZamerColors.surfaceLow,
        border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _HomeNavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                selected: i == 0,
                onTap: i == 0 ? null : onProjects,
              ),
            ),
        ],
      ),
    ),
  );
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accent
        : ZamerColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? ZamerColors.accent.withValues(alpha: .13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ZamerRadius.sm),
              border: selected
                  ? Border.all(color: ZamerColors.accent.withValues(alpha: .6))
                  : null,
            ),
            child: Icon(icon, size: 19, color: foreground),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.7,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateScenePainter extends CustomPainter {
  const _TemplateScenePainter({required this.kind});

  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: kind == 2
            ? const [Color(0xFF4D4943), Color(0xFF24282B)]
            : const [Color(0xFF6B6258), Color(0xFF292D2F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    final floorPath = Path()
      ..moveTo(0, size.height * .60)
      ..lineTo(size.width, size.height * .49)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA98563), Color(0xFF6E513A)],
        ).createShader(Offset.zero & size),
    );

    final windowRect = Rect.fromLTWH(
      size.width * .07,
      size.height * .11,
      size.width * .30,
      size.height * .34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, const Radius.circular(1.5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDE8E8), Color(0xFF98AFB0)],
        ).createShader(windowRect),
    );
    final frame = Paint()
      ..color = const Color(0xFF536064)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(windowRect.center.dx, windowRect.top),
      Offset(windowRect.center.dx, windowRect.bottom),
      frame,
    );
    canvas.drawLine(
      Offset(windowRect.left, windowRect.center.dy),
      Offset(windowRect.right, windowRect.center.dy),
      frame,
    );

    final rug = Path()
      ..moveTo(size.width * .27, size.height * .66)
      ..lineTo(size.width * .86, size.height * .60)
      ..lineTo(size.width * .95, size.height * .91)
      ..lineTo(size.width * .23, size.height * .92)
      ..close();
    canvas.drawPath(rug, Paint()..color = const Color(0xFF8B7763));

    if (kind == 2) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .34,
          size.height * .55,
          size.width * .48,
          size.height * .08,
        ),
        Paint()..color = const Color(0xFF3D342E),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .38,
          size.height * .63,
          size.width * .04,
          size.height * .20,
        ),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .74,
          size.height * .63,
          size.width * .04,
          size.height * .20,
        ),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .50,
            size.height * .68,
            size.width * .19,
            size.height * .18,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFB6AA9D),
      );
    } else {
      final sofaBody = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .36,
          size.height * .55,
          size.width * .49,
          size.height * .25,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(sofaBody, Paint()..color = const Color(0xFFD0C4B4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .39,
            size.height * .45,
            size.width * .43,
            size.height * .17,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFBEB1A1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .42,
            size.height * .53,
            size.width * .17,
            size.height * .12,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFE3D9CB),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .62,
            size.height * .52,
            size.width * .16,
            size.height * .12,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFAA9B8A),
      );
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * .44,
          size.height * .76,
          size.width * .31,
          size.height * .10,
        ),
        Paint()..color = const Color(0xFF4A4038),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .58,
          size.height * .84,
          size.width * .025,
          size.height * .08,
        ),
        Paint()..color = const Color(0xFF342D28),
      );
    }

    if (kind == 1) {
      final stem = Paint()
        ..color = const Color(0xFF5D4938)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width * .88, size.height * .71),
        Offset(size.width * .88, size.height * .39),
        stem,
      );
      final leaf = Paint()..color = const Color(0xFF42674B);
      canvas.drawCircle(
        Offset(size.width * .84, size.height * .37),
        size.width * .07,
        leaf,
      );
      canvas.drawCircle(
        Offset(size.width * .91, size.height * .34),
        size.width * .06,
        leaf,
      );
      canvas.drawCircle(
        Offset(size.width * .88, size.height * .29),
        size.width * .06,
        leaf,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * .89, size.height * .73),
        Offset(size.width * .89, size.height * .37),
        Paint()
          ..color = const Color(0xFF4E433C)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(size.width * .89, size.height * .31),
        size.width * .055,
        Paint()..color = const Color(0xFFE0C39D),
      );
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0x22000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _TemplateScenePainter oldDelegate) =>
      oldDelegate.kind != kind;
}
