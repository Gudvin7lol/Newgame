import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';

class MasterDocumentationScreen extends StatefulWidget {
  const MasterDocumentationScreen({super.key, required this.projectTitle, this.onBack});

  final String projectTitle;
  final VoidCallback? onBack;

  @override
  State<MasterDocumentationScreen> createState() => _MasterDocumentationScreenState();
}

class _MasterDocumentationScreenState extends State<MasterDocumentationScreen> {
  int _bottom = 2;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: 'Документация',
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
                trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  children: [
                    Text(widget.projectTitle, style: ZamerTypography.h2),
                    const SizedBox(height: 5),
                    Text('3 комнаты  •  82.6 м²  •  Обновлено 12.03.2024', style: ZamerTypography.bodySmall),
                    const SizedBox(height: 14),
                    const _DocumentCard(
                      icon: Icons.architecture_outlined,
                      title: 'План 2D',
                      subtitle: 'Обмерный план\nс размерами',
                      status: 'Готов',
                      tone: 0,
                    ),
                    const SizedBox(height: 8),
                    const _DocumentCard(
                      icon: Icons.view_in_ar_outlined,
                      title: '3D виды',
                      subtitle: 'Визуализации\nпомещений',
                      status: 'Готово',
                      tone: 1,
                    ),
                    const SizedBox(height: 8),
                    const _DocumentCard(
                      icon: Icons.view_carousel_outlined,
                      title: 'Развёртки',
                      subtitle: 'Развёртки стен\nвсех помещений',
                      status: '6 / 6',
                      tone: 2,
                    ),
                    const SizedBox(height: 8),
                    const _DocumentCard(
                      icon: Icons.table_chart_outlined,
                      title: 'Спецификация',
                      subtitle: 'Ведомость материалов\nи оборудования',
                      status: 'Готово',
                      tone: 3,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Собрать PDF-комплект'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {},
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
          selected: _bottom,
          onSelected: (index) => setState(() => _bottom = index),
        ),
      );
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
                  Positioned.fill(
                    child: CustomPaint(painter: _PreviewLines(tone: tone)),
                  ),
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
                      color: status.contains('/')
                          ? ZamerColors.accent.withValues(alpha: .14)
                          : ZamerColors.success.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: status.contains('/') ? ZamerColors.accent : ZamerColors.success,
                      ),
                    ),
                    child: Text(
                      status,
                      style: ZamerTypography.caption.copyWith(
                        color: status.contains('/') ? ZamerColors.accent : ZamerColors.success,
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
  const _BottomNav({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

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
              _NavItem(icon: Icons.home_outlined, label: 'Проект', selected: selected == 0, onTap: () => onSelected(0)),
              _NavItem(icon: Icons.straighten_outlined, label: 'Замер', selected: selected == 1, onTap: () => onSelected(1)),
              _NavItem(icon: Icons.description_outlined, label: 'Документы', selected: selected == 2, onTap: () => onSelected(2)),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Профиль', selected: selected == 3, onTap: () => onSelected(3)),
            ],
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
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
                Text(label, style: ZamerTypography.caption.copyWith(color: selected ? ZamerColors.accent : ZamerColors.textSecondary)),
              ],
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
    final p = Paint()
      ..color = (tone.isEven ? ZamerColors.textMuted : ZamerColors.accent).withValues(alpha: .32)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), p);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 10), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewLines oldDelegate) => oldDelegate.tone != tone;
}
