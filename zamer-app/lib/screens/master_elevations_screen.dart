import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';

class MasterElevationsScreen extends StatefulWidget {
  const MasterElevationsScreen({
    super.key,
    required this.floor,
    required this.projectTitle,
    this.onBack,
  });

  final FloorPlan floor;
  final String projectTitle;
  final VoidCallback? onBack;

  @override
  State<MasterElevationsScreen> createState() => _MasterElevationsScreenState();
}

class _MasterElevationsScreenState extends State<MasterElevationsScreen> {
  int _mode = 0;
  int _wall = 0;
  int _bottom = 0;
  int _finish = 0;

  static const _wallNames = ['Стена A', 'Стена B', 'Стена C', 'Стена D'];

  double get _wallWidthMm {
    if (widget.floor.walls.isEmpty) return 3120;
    final wall = widget.floor.walls[_wall % widget.floor.walls.length];
    final length = widget.floor.wallLengthMm(wall);
    return length <= 0 ? 3120 : length;
  }

  String _fmt(double value) => value.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ' ',
      );

  @override
  Widget build(BuildContext context) {
    final width = _wallWidthMm;
    final height = widget.floor.defaultHeightMm <= 0
        ? 2700.0
        : widget.floor.defaultHeightMm;
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.projectTitle,
              subtitle: 'Развёртки',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: () {},
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                children: [
                  ZMasterSegmentedControl(
                    labels: const ['Стены', 'Пол', 'Потолок'],
                    selectedIndex: _mode,
                    onSelected: (index) => setState(() => _mode = index),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: ZamerColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ZamerColors.outline),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Помещение: Гостиная',
                                  style: ZamerTypography.bodySmall,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SquareButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => setState(() {
                          _wall = (_wall - 1 + 4) % 4;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _SquareButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => setState(() => _wall = (_wall + 1) % 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: i == _wall
                                ? FilledButton(
                                    onPressed: () {},
                                    child: Text(_wallNames[i]),
                                  )
                                : OutlinedButton(
                                    onPressed: () => setState(() => _wall = i),
                                    child: Text(_wallNames[i]),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  ZMasterPanel(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      height: 240,
                      child: CustomPaint(
                        painter: _ElevationPainter(
                          wallWidthMm: width,
                          wallHeightMm: height,
                          accent: ZamerColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Покрытие стены',
                          style: ZamerTypography.h4,
                        ),
                      ),
                      _SquareButton(icon: Icons.edit_outlined, onTap: () {}),
                      const SizedBox(width: 6),
                      _SquareButton(icon: Icons.add_rounded, onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: Row(
                      children: [
                        _FinishTile(
                          label: 'Краска',
                          subtitle: 'S=4.2 м²',
                          selected: _finish == 0,
                          pattern: 0,
                          onTap: () => setState(() => _finish = 0),
                        ),
                        const SizedBox(width: 8),
                        _FinishTile(
                          label: 'Обои',
                          subtitle: 'S=6.8 м²',
                          selected: _finish == 1,
                          pattern: 1,
                          onTap: () => setState(() => _finish = 1),
                        ),
                        const SizedBox(width: 8),
                        _FinishTile(
                          label: 'Панели',
                          subtitle: 'S=3.6 м²',
                          selected: _finish == 2,
                          pattern: 2,
                          onTap: () => setState(() => _finish = 2),
                        ),
                        const SizedBox(width: 8),
                        _FinishTile(
                          label: 'Плитка',
                          subtitle: 'S=2.1 м²',
                          selected: _finish == 3,
                          pattern: 3,
                          onTap: () => setState(() => _finish = 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _AccordionRow(
                    icon: Icons.horizontal_rule_rounded,
                    label: 'Плинтус (1)',
                  ),
                  const SizedBox(height: 6),
                  const _AccordionRow(
                    icon: Icons.electrical_services_outlined,
                    label: 'Розетки (3)',
                  ),
                  const SizedBox(height: 6),
                  const _AccordionRow(
                    icon: Icons.toggle_on_outlined,
                    label: 'Выключатели (2)',
                  ),
                  const SizedBox(height: 6),
                  const _AccordionRow(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Светильники (3)',
                  ),
                  const SizedBox(height: 14),
                  Text('Размеры и привязки', style: ZamerTypography.h4),
                  const SizedBox(height: 8),
                  ZMasterPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: _DimensionField(
                            label: 'Ширина стены',
                            value: _fmt(width),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DimensionField(
                            label: 'Высота стены',
                            value: _fmt(height),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: const BoxDecoration(
                color: ZamerColors.surfaceLow,
                border: Border(top: BorderSide(color: ZamerColors.outline)),
              ),
              child: Row(
                children: [
                  _BottomTab(
                    icon: Icons.settings_outlined,
                    label: 'Развёртки',
                    selected: _bottom == 0,
                    onTap: () => setState(() => _bottom = 0),
                  ),
                  _BottomTab(
                    icon: Icons.layers_outlined,
                    label: 'Материалы',
                    selected: _bottom == 1,
                    onTap: () => setState(() => _bottom = 1),
                  ),
                  _BottomTab(
                    icon: Icons.grid_view_rounded,
                    label: 'Раскладка',
                    selected: _bottom == 2,
                    onTap: () => setState(() => _bottom = 2),
                  ),
                  _BottomTab(
                    icon: Icons.description_outlined,
                    label: 'Спецификация',
                    selected: _bottom == 3,
                    onTap: () => setState(() => _bottom = 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 42,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Icon(icon, size: 20),
        ),
      );
}

class _FinishTile extends StatelessWidget {
  const _FinishTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.pattern,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final bool selected;
  final int pattern;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected ? ZamerColors.accent : ZamerColors.outline,
                      width: selected ? 2 : 1,
                    ),
                    gradient: LinearGradient(
                      colors: switch (pattern) {
                        0 => const [Color(0xFFD8D0C6), Color(0xFFBFB6AB)],
                        1 => const [Color(0xFF9E9180), Color(0xFF6F665B)],
                        2 => const [Color(0xFF6B4933), Color(0xFFB38B67)],
                        _ => const [Color(0xFFB9AEA0), Color(0xFF81786F)],
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: ZamerTypography.caption.copyWith(
                  color: ZamerColors.textPrimary,
                ),
              ),
              Text(subtitle, style: ZamerTypography.caption),
            ],
          ),
        ),
      );
}

class _AccordionRow extends StatelessWidget {
  const _AccordionRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: ZamerTypography.bodySmall)),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      );
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label, мм', style: ZamerTypography.caption),
          const SizedBox(height: 5),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: ZamerColors.surfaceInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Text(
              value,
              style: ZamerTypography.bodySmall.copyWith(
                color: ZamerColors.textPrimary,
              ),
            ),
          ),
        ],
      );
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: ZamerColors.accent) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? ZamerColors.accent
                      : ZamerColors.textPrimary,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: ZamerTypography.caption.copyWith(
                    color: selected
                        ? ZamerColors.accent
                        : ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ElevationPainter extends CustomPainter {
  const _ElevationPainter({
    required this.wallWidthMm,
    required this.wallHeightMm,
    required this.accent,
  });

  final double wallWidthMm;
  final double wallHeightMm;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;
    const marginLeft = 36.0;
    const marginTop = 24.0;
    final wall = Rect.fromLTWH(
      marginLeft,
      marginTop + 18,
      size.width - marginLeft - 12,
      size.height - marginTop - 52,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB8AEA3);
    canvas.drawRect(wall, paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5B4030);
    final media = Rect.fromCenter(
      center: Offset(wall.center.dx + wall.width * .08, wall.center.dy + 10),
      width: wall.width * .34,
      height: wall.height * .28,
    );
    canvas.drawRect(media, paint);

    paint.color = const Color(0xFF7A553A);
    canvas.drawRect(
      Rect.fromLTWH(
        wall.left + wall.width * .25,
        wall.bottom - wall.height * .18,
        wall.width * .50,
        wall.height * .12,
      ),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..color = ZamerColors.textPrimary
      ..strokeWidth = 1;
    canvas.drawLine(Offset(wall.left, 12), Offset(wall.right, 12), paint);
    canvas.drawLine(Offset(16, wall.top), Offset(16, wall.bottom), paint);

    final text = TextPainter(textDirection: TextDirection.ltr);
    text.text = TextSpan(
      text: wallWidthMm.round().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (match) => ' ',
          ),
      style: const TextStyle(color: ZamerColors.textPrimary, fontSize: 11),
    );
    text.layout();
    text.paint(canvas, Offset(wall.center.dx - text.width / 2, 0));

    text.text = TextSpan(
      text: wallHeightMm.round().toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (match) => ' ',
          ),
      style: const TextStyle(color: ZamerColors.textPrimary, fontSize: 11),
    );
    text.layout();
    canvas.save();
    canvas.translate(4, wall.center.dy + text.width / 2);
    canvas.rotate(-1.5708);
    text.paint(canvas, Offset.zero);
    canvas.restore();

    paint
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(wall.left, wall.bottom + 12),
      Offset(wall.right, wall.bottom + 12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.wallWidthMm != wallWidthMm ||
      oldDelegate.wallHeightMm != wallHeightMm ||
      oldDelegate.accent != accent;
}
