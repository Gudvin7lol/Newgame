import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';

class MasterControlScreen extends StatefulWidget {
  const MasterControlScreen({super.key, required this.projectTitle, this.onBack});

  final String projectTitle;
  final VoidCallback? onBack;

  @override
  State<MasterControlScreen> createState() => _MasterControlScreenState();
}

class _MasterControlScreenState extends State<MasterControlScreen> {
  int _bottom = 2;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: 'Контроль',
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
                trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                  children: [
                    Text(widget.projectTitle, style: ZamerTypography.h4),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZamerColors.success.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZamerColors.success.withValues(alpha: .55)),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: ZamerColors.success,
                            child: Icon(Icons.check_rounded, color: Color(0xFF102317), size: 30),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Проект проверен', style: ZamerTypography.h4),
                                SizedBox(height: 3),
                                Text('Ошибок 0  •  предупреждений 2', style: ZamerTypography.caption),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Проверки проекта', style: ZamerTypography.h4),
                    const SizedBox(height: 8),
                    const _CheckRow(
                      status: _CheckStatus.ok,
                      icon: Icons.crop_free_rounded,
                      title: 'Контуры помещений',
                      subtitle: '6 из 6 замкнуто',
                    ),
                    const SizedBox(height: 8),
                    const _CheckRow(
                      status: _CheckStatus.warning,
                      icon: Icons.functions_rounded,
                      title: 'Суммы размеров',
                      subtitle: '1 расхождение  •  12 мм',
                    ),
                    const SizedBox(height: 8),
                    const _CheckRow(
                      status: _CheckStatus.ok,
                      icon: Icons.door_front_door_outlined,
                      title: 'Проёмы',
                      subtitle: 'Двери и окна привязаны',
                    ),
                    const SizedBox(height: 8),
                    const _CheckRow(
                      status: _CheckStatus.warning,
                      icon: Icons.storage_outlined,
                      title: 'Источники размеров',
                      subtitle: '3 размера требуют проверки',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {},
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
                _BottomItem(icon: Icons.folder_outlined, label: 'Проект', selected: _bottom == 0, onTap: () => setState(() => _bottom = 0)),
                _BottomItem(icon: Icons.straighten_outlined, label: 'Замер', selected: _bottom == 1, onTap: () => setState(() => _bottom = 1)),
                _BottomItem(icon: Icons.verified_user_outlined, label: 'Контроль', selected: _bottom == 2, onTap: () => setState(() => _bottom = 2)),
                _BottomItem(icon: Icons.person_outline_rounded, label: 'Профиль', selected: _bottom == 3, onTap: () => setState(() => _bottom = 3)),
              ],
            ),
          ),
        ),
      );
}

enum _CheckStatus { ok, warning, error }

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.status, required this.icon, required this.title, required this.subtitle});
  final _CheckStatus status;
  final IconData icon;
  final String title;
  final String subtitle;

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
    return ZMasterPanel(
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
                Text(title, style: ZamerTypography.bodySmall.copyWith(color: ZamerColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: ZamerTypography.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
              const SizedBox(height: 3),
              Text(label, style: ZamerTypography.caption.copyWith(color: selected ? ZamerColors.accent : ZamerColors.textSecondary)),
            ],
          ),
        ),
      );
}
