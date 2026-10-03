import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../services/demo_project_factory.dart';
import 'master_3d_screen.dart';
import 'master_equipment_screen.dart';
import 'master_elevations_screen.dart';

class MasterUiPreviewScreen extends StatelessWidget {
  const MasterUiPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final project = DemoProjectFactory.create();
    final floor = project.floors.first;

    void open(Widget screen) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    }

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text(
                'ZAMER',
                style: ZamerTypography.h1.copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                'MASTER UI REVIEW',
                style: ZamerTypography.caption.copyWith(
                  color: ZamerColors.accent,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Временная сборка только для проверки совпадения с утверждённым UI Kit. Рабочий +107 не изменён.',
                style: ZamerTypography.bodySmall,
              ),
              const SizedBox(height: 28),
              _PreviewTile(
                number: '03',
                title: '3D ВИД',
                subtitle: 'UI KIT 03 • просмотр, прогулка и настройки',
                icon: Icons.view_in_ar_outlined,
                onTap: () => open(
                  Master3DScreen(
                    floor: floor,
                    projectTitle: project.name,
                    onOpen2D: () => Navigator.pop(context),
                    onOpenAr: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AR будет подключён после визуального утверждения.')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PreviewTile(
                number: '04',
                title: 'ОСНАЩЕНИЕ',
                subtitle: 'Каталог, категории и карточки объектов',
                icon: Icons.chair_alt_outlined,
                onTap: () => open(
                  MasterEquipmentScreen(projectTitle: project.name),
                ),
              ),
              const SizedBox(height: 12),
              _PreviewTile(
                number: '05',
                title: 'РАЗВЁРТКИ',
                subtitle: 'Стены, отделка, размеры и инженерия',
                icon: Icons.view_carousel_outlined,
                onTap: () => open(
                  MasterElevationsScreen(
                    floor: floor,
                    projectTitle: project.name,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZamerColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZamerColors.outline),
                ),
                child: const Text(
                  'Следом добавляются: Фото и заметки, Документация, Контроль, Профиль и подписка. После визуального утверждения этот UI переносится в production workspace.',
                  style: ZamerTypography.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            minHeight: 92,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZamerColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: ZamerColors.accentInk, size: 29),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number  $title',
                        style: ZamerTypography.h4.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
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
