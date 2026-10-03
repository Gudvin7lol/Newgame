import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/measurement_review_service.dart';
import '../services/report_service.dart';

class MasterDocumentationScreen extends StatefulWidget {
  const MasterDocumentationScreen({
    super.key,
    required this.project,
    required this.floor,
    this.onBack,
    this.onOpenMeasure,
    this.onOpenProfile,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMeasure;
  final VoidCallback? onOpenProfile;

  @override
  State<MasterDocumentationScreen> createState() => _MasterDocumentationScreenState();
}

class _MasterDocumentationScreenState extends State<MasterDocumentationScreen> {
  bool _building = false;
  String? _lastError;

  Future<void> _share() async {
    if (_building) return;
    setState(() {
      _building = true;
      _lastError = null;
    });
    try {
      await ReportService.shareFloorPdf(widget.project, widget.floor);
    } catch (error) {
      if (mounted) setState(() => _lastError = '$error');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _preview() async {
    if (_building) return;
    setState(() {
      _building = true;
      _lastError = null;
    });
    try {
      final bytes = await ReportService.buildFloorPdf(widget.project, widget.floor);
      if (!mounted) return;
      final safe = '${widget.project.name}_${widget.floor.name}'.replaceAll(
        RegExp(r'[^a-zA-Zа-яА-Я0-9_-]+'),
        '_',
      );
      await Printing.layoutPdf(
        name: 'Замер_$safe.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (mounted) setState(() => _lastError = '$error');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    final totalArea = faces.fold<double>(0, (sum, face) => sum + face.areaM2);
    final issues = MeasurementReviewService.review(widget.floor);
    final hasPlan = widget.floor.walls.isNotEmpty;
    final has3D = widget.floor.walls.isNotEmpty || widget.floor.planObjects.isNotEmpty;
    final hasElevations = faces.isNotEmpty;
    final hasSpecification = widget.floor.planObjects.isNotEmpty || faces.isNotEmpty;

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Документация',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              trailing: _building
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                children: [
                  Text(widget.project.name, style: ZamerTypography.h2),
                  const SizedBox(height: 5),
                  Text(
                    '${faces.length} помещ.  •  ${totalArea.toStringAsFixed(1)} м²  •  ${widget.floor.name}',
                    style: ZamerTypography.bodySmall,
                  ),
                  if (issues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: ZamerColors.warning.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: ZamerColors.warning.withValues(alpha: .45)),
                      ),
                      child: Text(
                        'В контроль попадут ${issues.length} замечаний по обмеру',
                        style: ZamerTypography.caption.copyWith(color: ZamerColors.warning),
                      ),
                    ),
                  ],
                  if (_lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ошибка PDF: $_lastError',
                      style: ZamerTypography.caption.copyWith(color: ZamerColors.danger),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _DocumentCard(
                    icon: Icons.architecture_outlined,
                    title: 'План 2D',
                    subtitle: 'Обмерный план\nс размерами',
                    ready: hasPlan,
                    status: hasPlan ? '${widget.floor.walls.length} стен' : 'Нет плана',
                    tone: 0,
                  ),
                  const SizedBox(height: 8),
                  _DocumentCard(
                    icon: Icons.view_in_ar_outlined,
                    title: '3D данные',
                    subtitle: 'Геометрия и\nоснащение',
                    ready: has3D,
                    status: has3D ? '${widget.floor.planObjects.length} объектов' : 'Нет данных',
                    tone: 1,
                  ),
                  const SizedBox(height: 8),
                  _DocumentCard(
                    icon: Icons.view_carousel_outlined,
                    title: 'Развёртки',
                    subtitle: 'Развёртки стен\nвсех помещений',
                    ready: hasElevations,
                    status: hasElevations ? '${faces.length} помещ.' : 'Нет помещений',
                    tone: 2,
                  ),
                  const SizedBox(height: 8),
                  _DocumentCard(
                    icon: Icons.table_chart_outlined,
                    title: 'Спецификация',
                    subtitle: 'Материалы и\nоборудование',
                    ready: hasSpecification,
                    status: hasSpecification ? 'Рассчитывается из проекта' : 'Нет данных',
                    tone: 3,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _building || !hasPlan ? null : _share,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(_building ? 'Собираю комплект…' : 'Собрать PDF-комплект'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _building || !hasPlan ? null : _preview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Предпросмотр'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        onProject: widget.onBack ?? () => Navigator.maybePop(context),
        onMeasure: widget.onOpenMeasure,
        onProfile: widget.onOpenProfile,
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ready,
    required this.status,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ready;
  final String status;
  final int tone;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 118,
              height: 84,
              decoration: BoxDecoration(
                color: ZamerColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(icon, size: 42, color: ZamerColors.textMuted)),
                  Positioned.fill(child: CustomPaint(painter: _PreviewLines(tone: tone))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZamerTypography.h4),
                  const SizedBox(height: 3),
                  Text(subtitle, style: ZamerTypography.caption),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (ready ? ZamerColors.success : ZamerColors.warning).withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: ready ? ZamerColors.success : ZamerColors.warning),
                    ),
                    child: Text(
                      status,
                      style: ZamerTypography.caption.copyWith(
                        color: ready ? ZamerColors.success : ZamerColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({this.onProject, this.onMeasure, this.onProfile});

  final VoidCallback? onProject;
  final VoidCallback? onMeasure;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(top: BorderSide(color: ZamerColors.outline)),
          ),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined, label: 'Проект', selected: false, onTap: onProject),
              _NavItem(icon: Icons.straighten_outlined, label: 'Замер', selected: false, onTap: onMeasure),
              const _NavItem(icon: Icons.description_outlined, label: 'Документы', selected: true),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Профиль', selected: false, onTap: onProfile),
            ],
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: selected ? Border.all(color: ZamerColors.accent) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
                  const SizedBox(height: 3),
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
        ),
      );
}

class _PreviewLines extends CustomPainter {
  const _PreviewLines({required this.tone});
  final int tone;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tone.isEven
          ? ZamerColors.textFaint.withValues(alpha: .22)
          : ZamerColors.accent.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewLines oldDelegate) => oldDelegate.tone != tone;
}
