import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/measurement_review_service.dart';
import '../widgets/floor_plan_painter.dart';

class MeasurementReviewScreen extends StatefulWidget {
  const MeasurementReviewScreen({super.key, required this.floor});

  final FloorPlan floor;

  @override
  State<MeasurementReviewScreen> createState() =>
      _MeasurementReviewScreenState();
}

class _MeasurementReviewScreenState extends State<MeasurementReviewScreen> {
  int? _selected;
  MeasurementIssueKind? _filter;

  @override
  Widget build(BuildContext context) {
    final issues = MeasurementReviewService.review(widget.floor);
    final visible = _filter == null
        ? issues
        : issues.where((issue) => issue.kind == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Проверка обмера'),
            Text(widget.floor.name, style: ZamerTypography.caption),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.md,
              0,
            ),
            height: 256,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ZamerColors.surfaceLow,
              borderRadius: BorderRadius.circular(ZamerRadius.lg),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final nodes = widget.floor.nodes;
                if (nodes.isEmpty) {
                  return const ZEmptyState(
                    icon: Icons.architecture_outlined,
                    title: 'План пока пуст',
                    subtitle: 'Построй стены, прежде чем запускать проверку.',
                  );
                }
                final minX = nodes.map((e) => e.xMm).reduce(math.min);
                final minY = nodes.map((e) => e.yMm).reduce(math.min);
                final maxX = nodes.map((e) => e.xMm).reduce(math.max);
                final maxY = nodes.map((e) => e.yMm).reduce(math.max);
                final scale = math.min(
                  (c.maxWidth - 36) / math.max(1, maxX - minX),
                  (c.maxHeight - 36) / math.max(1, maxY - minY),
                );
                final origin = Offset(
                  (c.maxWidth - (maxX - minX) * scale) / 2 - minX * scale,
                  (c.maxHeight - (maxY - minY) * scale) / 2 - minY * scale,
                );
                return CustomPaint(
                  painter: _IssuePainter(
                    widget.floor,
                    visible,
                    _selected,
                    scale,
                    origin,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(ZamerSpace.md),
              decoration: BoxDecoration(
                color: issues.isEmpty
                    ? ZamerColors.success.withValues(alpha: .08)
                    : ZamerColors.warning.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(ZamerRadius.md),
                border: Border.all(
                  color: (issues.isEmpty
                          ? ZamerColors.success
                          : ZamerColors.warning)
                      .withValues(alpha: .35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    issues.isEmpty
                        ? Icons.verified_outlined
                        : Icons.warning_amber_rounded,
                    color: issues.isEmpty
                        ? ZamerColors.success
                        : ZamerColors.warning,
                  ),
                  const SizedBox(width: ZamerSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issues.isEmpty
                              ? 'Доступные проверки пройдены'
                              : 'Найдено ${issues.length} ${_issueWord(issues.length)}',
                          style: const TextStyle(
                            color: ZamerColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _filter == null
                              ? 'Выбери категорию ниже, чтобы локализовать проблему на плане.'
                              : 'Показано: ${_kindLabel(_filter!)} • ${visible.length}',
                          style: ZamerTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (issues.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.md),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Все ${issues.length}',
                    icon: Icons.list_alt_rounded,
                    selected: _filter == null,
                    onTap: () => setState(() {
                      _filter = null;
                      _selected = null;
                    }),
                  ),
                  for (final kind in MeasurementIssueKind.values)
                    if (_countKind(issues, kind) > 0) ...[
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '${_kindShortLabel(kind)} ${_countKind(issues, kind)}',
                        icon: _kindIcon(kind),
                        selected: _filter == kind,
                        onTap: () => setState(() {
                          _filter = kind;
                          _selected = null;
                        }),
                      ),
                    ],
                ],
              ),
            ),
          const SizedBox(height: ZamerSpace.xs),
          Expanded(
            child: issues.isEmpty
                ? const ZEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Критичных замечаний нет',
                    subtitle:
                        'По доступным данным контур и контрольные размеры выглядят согласованно.',
                  )
                : visible.isEmpty
                    ? const ZEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'В этой категории замечаний нет',
                        subtitle: 'Выбери другой тип проверки.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          ZamerSpace.md,
                          0,
                          ZamerSpace.md,
                          ZamerSpace.md,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: ZamerSpace.sm),
                        itemBuilder: (context, i) {
                          final issue = visible[i];
                          final selected = _selected == i;
                          return ZPressEffect(
                            scale: .985,
                            child: ZCard(
                              padding: EdgeInsets.zero,
                              backgroundColor: selected
                                  ? ZamerColors.warning.withValues(alpha: .08)
                                  : ZamerColors.surface,
                              borderColor: selected
                                  ? ZamerColors.warning.withValues(alpha: .55)
                                  : ZamerColors.outline,
                              onTap: () => setState(() => _selected = i),
                              child: Padding(
                                padding: const EdgeInsets.all(ZamerSpace.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? ZamerColors.warning
                                            : ZamerColors.surfaceHigh,
                                        borderRadius: BorderRadius.circular(
                                          ZamerRadius.sm,
                                        ),
                                        border: Border.all(
                                          color: selected
                                              ? ZamerColors.warning
                                              : ZamerColors.outlineSoft,
                                        ),
                                      ),
                                      child: Icon(
                                        _kindIcon(issue.kind),
                                        size: 18,
                                        color: selected
                                            ? ZamerColors.accentInk
                                            : ZamerColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: ZamerSpace.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _kindLabel(issue.kind),
                                            style: ZamerTypography.caption.copyWith(
                                              color: ZamerColors.warning,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            issue.description,
                                            style: const TextStyle(
                                              color: ZamerColors.textPrimary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              height: 1.3,
                                            ),
                                          ),
                                          if (issue.deltaMm != null) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.straighten_rounded,
                                                  size: 14,
                                                  color: ZamerColors.warning,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Отклонение ${issue.deltaMm!.abs().round()} мм',
                                                  style: const TextStyle(
                                                    color: ZamerColors.warning,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: ZamerSpace.xs),
                                    Icon(
                                      selected
                                          ? Icons.my_location_rounded
                                          : Icons.chevron_right_rounded,
                                      size: 18,
                                      color: selected
                                          ? ZamerColors.warning
                                          : ZamerColors.textFaint,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.sm,
              ZamerSpace.md,
              ZamerSpace.md,
            ),
            decoration: const BoxDecoration(
              color: ZamerColors.surfaceLow,
              border: Border(
                top: BorderSide(color: ZamerColors.outlineSoft),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: ZamerColors.info,
                ),
                SizedBox(width: ZamerSpace.sm),
                Expanded(
                  child: Text(
                    'Контроль длины стены и источник размера записываются в карточке стены. Диагонали добавляются инструментом «Размеры».',
                    style: ZamerTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _countKind(
    List<MeasurementIssue> issues,
    MeasurementIssueKind kind,
  ) =>
      issues.where((issue) => issue.kind == kind).length;

  static String _kindLabel(MeasurementIssueKind kind) => switch (kind) {
        MeasurementIssueKind.openContour => 'Незамкнутый контур',
        MeasurementIssueKind.discrepancy => 'Несоответствие размеров',
        MeasurementIssueKind.missingOffset => 'Отступ проёма не подтверждён',
        MeasurementIssueKind.missingHeight => 'Высота не подтверждена',
        MeasurementIssueKind.missingDiagonal => 'Нет контрольной диагонали',
      };

  static String _kindShortLabel(MeasurementIssueKind kind) => switch (kind) {
        MeasurementIssueKind.openContour => 'Контур',
        MeasurementIssueKind.discrepancy => 'Размеры',
        MeasurementIssueKind.missingOffset => 'Отступы',
        MeasurementIssueKind.missingHeight => 'Высоты',
        MeasurementIssueKind.missingDiagonal => 'Диагонали',
      };

  static IconData _kindIcon(MeasurementIssueKind kind) => switch (kind) {
        MeasurementIssueKind.openContour => Icons.polyline_outlined,
        MeasurementIssueKind.discrepancy => Icons.straighten_rounded,
        MeasurementIssueKind.missingOffset => Icons.space_bar_rounded,
        MeasurementIssueKind.missingHeight => Icons.height_rounded,
        MeasurementIssueKind.missingDiagonal => Icons.change_history_rounded,
      };

  static String _issueWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'замечание';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'замечания';
    }
    return 'замечаний';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: Material(
          color: selected ? ZamerColors.accent : ZamerColors.surface,
          borderRadius: BorderRadius.circular(ZamerRadius.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZamerRadius.pill),
                border: Border.all(
                  color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? ZamerColors.accentInk
                        : ZamerColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
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

class _IssuePainter extends CustomPainter {
  const _IssuePainter(
    this.floor,
    this.issues,
    this.selected,
    this.scale,
    this.origin,
  );

  final FloorPlan floor;
  final List<MeasurementIssue> issues;
  final int? selected;
  final double scale;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    FloorPlanPainter(
      floor: floor,
      mmToPx: scale,
      origin: origin,
      showDimensions: false,
      showRoomLabels: false,
      showNodes: false,
    ).paint(canvas, size);
    for (var i = 0; i < issues.length; i++) {
      final p = issues[i].position;
      final q = origin + Offset(p.x * scale, p.y * scale);
      final isSelected = selected == i;
      if (isSelected) {
        canvas.drawCircle(
          q,
          20,
          Paint()..color = ZamerColors.warning.withValues(alpha: .16),
        );
      }
      canvas.drawCircle(
        q,
        isSelected ? 14 : 11,
        Paint()
          ..color = isSelected ? ZamerColors.warning : ZamerColors.danger,
      );
      canvas.drawCircle(
        q,
        isSelected ? 14 : 11,
        Paint()
          ..color = ZamerColors.textPrimary.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: ZamerColors.accentInk,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, q - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _IssuePainter oldDelegate) => true;
}
