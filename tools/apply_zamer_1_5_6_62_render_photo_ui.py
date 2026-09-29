from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'
SCREEN = APP / 'lib/screens/floor_3d_screen.dart'

pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+62' in pubspec:
    print('1.5.6+62 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+61' not in pubspec:
    raise SystemExit('unexpected version, refusing +62 patch')

text = SCREEN.read_text()

start_marker = "    await showModalBottomSheet<void>(\n      context: context,\n      showDragHandle: true,\n      builder: (context) => SafeArea(\n"
start = text.find(start_marker, text.find('Future<void> _showRenderSheet()'))
if start < 0:
    raise SystemExit('render sheet start marker missing')
end_marker = "  Future<void> _showWalkSettingsSheet() async {"
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit('render sheet end marker missing')

replacement = '''    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E161B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2A3941))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43515A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A211B),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF5A4332)),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Color(0xFFF1C79E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Рендер / Фото',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Финальный GPU-кадр без интерфейса',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _PhotoBadge(),
                ],
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RenderFeatureChip(label: 'PBR'),
                  _RenderFeatureChip(label: 'AO'),
                  _RenderFeatureChip(label: 'Мягкие тени'),
                  _RenderFeatureChip(label: 'Отражения'),
                  _RenderFeatureChip(label: 'Цветокоррекция'),
                ],
              ),
              const SizedBox(height: 14),
              _RenderPresetTile(
                title: 'HD',
                subtitle: '${hdWidth} × ${hdHeight} • быстрый просмотр',
                icon: Icons.hd_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(width: hdWidth, height: hdHeight, label: 'HD');
                },
              ),
              _RenderPresetTile(
                title: '2K',
                subtitle: '${twoKWidth} × ${twoKHeight} • презентация',
                icon: Icons.image_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(
                    width: twoKWidth,
                    height: twoKHeight,
                    label: '2K',
                  );
                },
              ),
              _RenderPresetTile(
                title: '4K Photo',
                subtitle: '${fourKWidth} × ${fourKHeight} • максимум качества',
                icon: Icons.high_quality_outlined,
                accent: true,
                onTap: () {
                  Navigator.pop(context);
                  _exportRender(
                    width: fourKWidth,
                    height: fourKHeight,
                    label: '4K',
                  );
                },
              ),
              const SizedBox(height: 4),
              const Text(
                '4K формируется рендерером в целевом разрешении. Это не увеличение скриншота.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Color(0xFF7F8B91)),
              ),
            ],
          ),
        ),
      ),
    );
  }

'''
text = text[:start] + replacement + text[end:]

text = text.replace("label: 'Рендер',", "label: 'Фото',")
text = text.replace("title: Text('$label • финальный рендер'),", "title: Text('$label • Photo Render'),")
text = text.replace(
    "                  child: ColoredBox(\n                    color: const Color(0xFF111416),",
    "                  child: ColoredBox(\n                    color: const Color(0xFF090E11),",
)
text = text.replace("label: const Text('В 3D'),", "label: const Text('Вернуться в 3D'),")
text = text.replace("label: const Text('Сохранить / поделиться'),", "label: const Text('Сохранить кадр'),")

class_marker = 'class _RenderPresetTile extends StatelessWidget {'
class_at = text.find(class_marker)
if class_at < 0:
    raise SystemExit('render preset class missing')
text = text[:class_at] + '''class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF20352C),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF345A49)),
    ),
    child: const Text(
      'PHOTO',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: Color(0xFF8AC8AE),
      ),
    ),
  );
}

class _RenderFeatureChip extends StatelessWidget {
  const _RenderFeatureChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF141E23),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF26363E)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFFB9C2C6),
      ),
    ),
  );
}

''' + text[class_at:]

text = text.replace(
    '''    required this.icon,\n    required this.onTap,\n  });\n\n  final String title;\n  final String subtitle;\n  final IconData icon;\n  final VoidCallback onTap;\n''',
    '''    required this.icon,\n    required this.onTap,\n    this.accent = false,\n  });\n\n  final String title;\n  final String subtitle;\n  final IconData icon;\n  final VoidCallback onTap;\n  final bool accent;\n''',
    1,
)
old_build = '''  @override\n  Widget build(BuildContext context) => Card(\n    margin: const EdgeInsets.only(bottom: 8),\n    child: ListTile(\n      leading: CircleAvatar(child: Icon(icon)),\n      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),\n      subtitle: Text(subtitle),\n      trailing: const Icon(Icons.chevron_right),\n      onTap: onTap,\n    ),\n  );\n}'''
new_build = '''  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: accent ? const Color(0xFF2A211B) : const Color(0xFF141E23),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: accent ? const Color(0xFF6C503A) : const Color(0xFF26363E),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent ? const Color(0xFFF1C79E) : const Color(0xFF1D2A30),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: accent ? const Color(0xFF22170F) : const Color(0xFFD7DDDF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF8C989D)),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: accent ? const Color(0xFFF1C79E) : const Color(0xFF758187),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}'''
if old_build not in text:
    raise SystemExit('render preset build block missing')
text = text.replace(old_build, new_build, 1)
SCREEN.write_text(text)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+61', 'version: 1.5.6+62', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+62 — Render / Photo по мастер-концепту\n\n- Сценарий финального рендера приведён к визуальному языку мастер-концепта без изменения GPU-ядра.\n- Панель рендера теперь явно показывает Photo-режим и используемые возможности: PBR, AO, мягкие тени, отражения и цветокоррекцию.\n- HD, 2K и настоящий 4K оформлены как отдельные понятные пресеты; 4K Photo выделен как максимальный режим качества.\n- В интерфейсе 3D действие «Рендер» переименовано в более понятное «Фото».\n- Полноэкранный предпросмотр финального кадра получил более чистую тёмную подачу и понятные действия возврата и сохранения.\n- Разрешения рендера, PBR-материалы, AO, тени, отражения и логика освобождения LOD0 после финального кадра не менялись.\n- AR не обозначается как готовая функция до появления технической реализации.\n\n'''
if not changelog.startswith('## 1.5.6+62'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+62 render/photo master-concept pass')
