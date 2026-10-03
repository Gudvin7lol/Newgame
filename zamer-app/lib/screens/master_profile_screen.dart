import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  int _bottom = 3;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: 'Профиль',
                onBack: widget.onBack,
                onSettings: () {},
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  children: [
                    ZMasterPanel(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: ZamerColors.accent,
                            child: Text(
                              'Д',
                              style: TextStyle(
                                color: ZamerColors.accentInk,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Дима', style: ZamerTypography.h3),
                                const SizedBox(height: 2),
                                Text('Строитель', style: ZamerTypography.bodySmall),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.work_outline_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    Text('12 проектов', style: ZamerTypography.caption),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZamerColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZamerColors.accent, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: ZamerColors.accent, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PRO', style: ZamerTypography.h3.copyWith(color: ZamerColors.accent)),
                                const SizedBox(height: 3),
                                Text('799 ₽ / месяц', style: ZamerTypography.bodySmall),
                                const SizedBox(height: 3),
                                Text('Следующее списание 12 окт', style: ZamerTypography.caption),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 42,
                            child: FilledButton(
                              onPressed: () {},
                              child: const Text('Управлять'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ProfileRow(
                      icon: Icons.cloud_done_outlined,
                      title: 'Синхронизация',
                      subtitle: 'Все данные сохранены',
                      status: Icons.check_circle_rounded,
                    ),
                    const SizedBox(height: 8),
                    const _ProfileRow(
                      icon: Icons.storage_outlined,
                      title: 'Резервная копия',
                      subtitle: 'Сегодня, 09:41  •  248 МБ',
                    ),
                    const SizedBox(height: 8),
                    const _ProfileRow(
                      icon: Icons.devices_outlined,
                      title: 'Устройства',
                      subtitle: '2 подключено',
                    ),
                    const SizedBox(height: 8),
                    const _ProfileRow(
                      icon: Icons.tune_rounded,
                      title: 'Настройки проекта',
                      subtitle: '',
                    ),
                    const SizedBox(height: 8),
                    const _ProfileRow(
                      icon: Icons.headset_mic_outlined,
                      title: 'Поддержка и обратная связь',
                      subtitle: '',
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
                _BottomItem(icon: Icons.home_outlined, label: 'Проект', selected: _bottom == 0, onTap: () => setState(() => _bottom = 0)),
                _BottomItem(icon: Icons.straighten_outlined, label: 'Замер', selected: _bottom == 1, onTap: () => setState(() => _bottom = 1)),
                _BottomItem(icon: Icons.camera_alt_outlined, label: 'Фото', selected: _bottom == 2, onTap: () => setState(() => _bottom = 2)),
                _BottomItem(icon: Icons.person_rounded, label: 'Профиль', selected: _bottom == 3, onTap: () => setState(() => _bottom = 3)),
              ],
            ),
          ),
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? status;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: ZamerTypography.caption),
                  ],
                ],
              ),
            ),
            if (status != null) ...[
              Icon(status, color: ZamerColors.success, size: 20),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
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
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(color: ZamerColors.accent, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      );
}
