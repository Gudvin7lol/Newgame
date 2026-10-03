import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';

class MasterPhotoScreen extends StatefulWidget {
  const MasterPhotoScreen({super.key, required this.projectTitle, this.onBack});

  final String projectTitle;
  final VoidCallback? onBack;

  @override
  State<MasterPhotoScreen> createState() => _MasterPhotoScreenState();
}

class _MasterPhotoScreenState extends State<MasterPhotoScreen> {
  int _filter = 0;
  int _bottom = 2;

  static const _filters = [
    ('Все', Icons.grid_view_rounded),
    ('Фото', Icons.image_outlined),
    ('Видео', Icons.videocam_outlined),
    ('Файлы', Icons.attach_file_rounded),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Column(
            children: [
              ZMasterTopBar(
                title: 'Фото и заметки',
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
                trailing: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 92),
                  children: [
                    ZMasterPanel(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const _RoomPreview(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.projectTitle, style: ZamerTypography.h4),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: ZamerColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: ZamerColors.outline),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.weekend_outlined, size: 19, color: ZamerColors.accent),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Гостиная / стена W-04', style: ZamerTypography.bodySmall),
                                            Text('28 фото  •  4 заметки', style: ZamerTypography.caption),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < _filters.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: i == _filter
                                  ? FilledButton.icon(
                                      onPressed: () => setState(() => _filter = i),
                                      icon: Icon(_filters[i].$2, size: 17),
                                      label: Text(_filters[i].$1),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: () => setState(() => _filter = i),
                                      icon: Icon(_filters[i].$2, size: 17),
                                      label: Text(_filters[i].$1),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: .84,
                      children: const [
                        _PhotoTile(
                          icon: Icons.electrical_services_outlined,
                          title: 'Стена W-04',
                          subtitle: '25.09.2024, 14:32',
                          measurement: '300 мм',
                          tone: 0,
                        ),
                        _PhotoTile(
                          icon: Icons.window_outlined,
                          title: 'Оконный проём',
                          subtitle: '25.09.2024, 13:17',
                          tone: 1,
                        ),
                        _PhotoTile(
                          icon: Icons.square_foot_outlined,
                          title: 'Примыкание к полу',
                          subtitle: '24.09.2024, 16:08',
                          tone: 2,
                        ),
                        _PhotoTile(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Потолок',
                          subtitle: '24.09.2024, 15:21',
                          tone: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: ZamerColors.accent,
          foregroundColor: ZamerColors.accentInk,
          child: const Icon(Icons.camera_alt_rounded),
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
                _BottomItem(icon: Icons.camera_alt_outlined, label: 'Фото', selected: _bottom == 2, onTap: () => setState(() => _bottom = 2)),
                _BottomItem(icon: Icons.person_outline_rounded, label: 'Профиль', selected: _bottom == 3, onTap: () => setState(() => _bottom = 3)),
              ],
            ),
          ),
        ),
      );
}

class _RoomPreview extends StatelessWidget {
  const _RoomPreview();

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFBDAE9B), Color(0xFF60584F)],
          ),
        ),
        child: const Icon(Icons.chair_outlined, size: 44, color: Color(0xFFF1E7DA)),
      );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.measurement,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int tone;
  final String? measurement;

  @override
  Widget build(BuildContext context) {
    final tones = <List<Color>>[
      const [Color(0xFFB5AA9C), Color(0xFF6F675F)],
      const [Color(0xFF7FA0B4), Color(0xFF5E6B72)],
      const [Color(0xFF9D9389), Color(0xFF5D5650)],
      const [Color(0xFF8B837A), Color(0xFF403D39)],
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tones[tone % tones.length],
              ),
            ),
          ),
          Center(child: Icon(icon, size: 48, color: Colors.white54)),
          if (measurement != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ZamerColors.surface.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: ZamerColors.accent),
                ),
                child: Text(measurement!, style: ZamerTypography.caption.copyWith(color: ZamerColors.textPrimary)),
              ),
            ),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 18),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZamerTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(subtitle, style: ZamerTypography.caption.copyWith(color: Colors.white70)),
              ],
            ),
          ),
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
              Icon(icon, size: 23, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
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
