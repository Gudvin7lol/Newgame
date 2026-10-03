import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/measurement_review_service.dart';
import 'measurement_review_screen.dart';

class MasterControlScreen extends StatelessWidget {
  const MasterControlScreen({
    super.key,
    required this.projectTitle,
    required this.floor,
    this.onBack,
    this.onOpenMeasure,
    this.onOpenProfile,
  });

  final String projectTitle;
  final FloorPlan floor;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMeasure;
  final VoidCallback? onOpenProfile;

  void _openReview(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => MeasurementReviewScreen(floor: floor)),
    );
  }

  void _showIssues(
    BuildContext context,
    String title,
    Iterable<MeasurementIssue> issues,
  ) {
    final list = issues.toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: ZamerTypography.h3),
              const SizedBox(height: 10),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Проблем не найдено', style: ZamerTypography.bodySmall),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_rounded, color: ZamerColors.warning),
                      title: Text(list[index].description),
                      subtitle: list[index].deltaMm == null
                          ? null
                          : Text('Расхождение: ${list[index].deltaMm!.abs().round()} мм'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openReview(context);
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Открыть полный контроль'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issues = MeasurementReviewService.review(floor);
    final rooms = GeometryService.roomFaces(floor);
    final geometryIssues = issues.where(
      (issue) =>
          issue.kind == MeasurementIssueKind.openContour ||
          issue.kind == MeasurementIssueKind.intersection ||
          issue.kind == MeasurementIssueKind.acuteAngle,
    );
    final discrepancyIssues = issues.where(
      (issue) => issue.kind == MeasurementIssueKind.discrepancy,
    );
    final sourceIssues = issues.where(
      (issue) =>
          issue.kind == MeasurementIssueKind.missingOffset ||
          issue.kind == MeasurementIssueKind.missingHeight ||
          issue.kind == MeasurementIssueKind.missingDiagonal,
    );
    final openingCount = floor.walls.fold<int>(0, (sum, wall) => sum + wall.openings.length);
    final hardErrors = issues.where(
      (issue) =>
          issue.kind == MeasurementIssueKind.openContour ||
          issue.kind == MeasurementIssueKind.intersection,
    ).length;
    final warnings = issues.length - hardErrors;
    final checked = issues.isEmpty;

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Контроль',
              onBack: onBack ?? () => Navigator.maybePop(context),
              trailing: IconButton(
                tooltip: 'Полный список ошибок',
                onPressed: () => _openReview(context),
                icon: const Icon(Icons.fact_check_outlined),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                children: [
                  Text(projectTitle, style: ZamerTypography.h4),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (checked ? ZamerColors.success : hardErrors > 0 ? ZamerColors.danger : ZamerColors.warning)
                          .withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (checked ? ZamerColors.success : hardErrors > 0 ? ZamerColors.danger : ZamerColors.warning)
                            .withValues(alpha: .60),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: checked
                              ? ZamerColors.success
                              : hardErrors > 0
                                  ? ZamerColors.danger
                                  : ZamerColors.warning,
                          child: Icon(
                            checked ? Icons.check_rounded : Icons.priority_high_rounded,
                            color: ZamerColors.accentInk,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                checked ? 'Проект проверен' : 'Требуется проверка',
                                style: ZamerTypography.h4,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Ошибок $hardErrors  •  предупреждений $warnings',
                                style: ZamerTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Проверки проекта', style: ZamerTypography.h4),
                  const SizedBox(height: 8),
                  _CheckRow(
                    status: geometryIssues.isEmpty ? _CheckStatus.ok : _CheckStatus.error,
                    icon: Icons.crop_free_rounded,
                    title: 'Контуры и геометрия',
                    subtitle: geometryIssues.isEmpty
                        ? '${rooms.length} помещений без критических ошибок'
                        : '${geometryIssues.length} проблем геометрии',
                    onTap: () => _showIssues(context, 'Контуры и геометрия', geometryIssues),
                  ),
                  const SizedBox(height: 8),
                  _CheckRow(
                    status: discrepancyIssues.isEmpty ? _CheckStatus.ok : _CheckStatus.warning,
                    icon: Icons.functions_rounded,
                    title: 'Суммы размеров',
                    subtitle: discrepancyIssues.isEmpty
                        ? 'Расхождений не найдено'
                        : '${discrepancyIssues.length} расхождений',
                    onTap: () => _showIssues(context, 'Расхождения размеров', discrepancyIssues),
                  ),
                  const SizedBox(height: 8),
                  _CheckRow(
                    status: _CheckStatus.ok,
                    icon: Icons.door_front_door_outlined,
                    title: 'Проёмы',
                    subtitle: '$openingCount дверей/окон в проекте',
                    onTap: () => _openReview(context),
                  ),
                  const SizedBox(height: 8),
                  _CheckRow(
                    status: sourceIssues.isEmpty ? _CheckStatus.ok : _CheckStatus.warning,
                    icon: Icons.storage_outlined,
                    title: 'Источники размеров',
                    subtitle: sourceIssues.isEmpty
                        ? 'Обязательные размеры подтверждены'
                        : '${sourceIssues.length} размеров требуют подтверждения',
                    onTap: () => _showIssues(context, 'Источники размеров', sourceIssues),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => _openReview(context),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Показать на плане'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(top: BorderSide(color: ZamerColors.outline)),
          ),
          child: Row(
            children: [
              _BottomItem(
                icon: Icons.folder_outlined,
                label: 'Проект',
                selected: false,
                onTap: onBack ?? () => Navigator.maybePop(context),
              ),
              _BottomItem(
                icon: Icons.straighten_outlined,
                label: 'Замер',
                selected: false,
                onTap: onOpenMeasure ?? () => Navigator.maybePop(context),
              ),
              const _BottomItem(
                icon: Icons.verified_user_outlined,
                label: 'Контроль',
                selected: true,
              ),
              _BottomItem(
                icon: Icons.person_outline_rounded,
                label: 'Профиль',
                selected: false,
                onTap: onOpenProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CheckStatus { ok, warning, error }

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.status,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final _CheckStatus status;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _CheckStatus.ok => ZamerColors.success,
      _CheckStatus.warning => ZamerColors.warning,
      _CheckStatus.error => ZamerColors.danger,
    };
    final statusIcon = switch (status) {
      _CheckStatus.ok => Icons.check_rounded,
      _CheckStatus.warning => Icons.priority_high_rounded,
      _CheckStatus.error => Icons.close_rounded,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ZMasterPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Icon(statusIcon, color: ZamerColors.accentInk, size: 19),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZamerColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: ZamerColors.outline),
                ),
                child: Icon(icon, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ZamerTypography.bodySmall.copyWith(
                        color: ZamerColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: ZamerTypography.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null && !selected ? .45 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: ZamerTypography.caption.copyWith(
                    color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
