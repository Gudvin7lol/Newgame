from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'
SCREEN = APP / 'lib/screens/projects_screen.dart'
DEMO = APP / 'lib/services/demo_project_factory.dart'

pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+66' in pubspec:
    print('1.5.6+66 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+65' not in pubspec:
    raise SystemExit('unexpected version, refusing +66 visual patch')

text = SCREEN.read_text()

# Real project photos are the correct source for the concept-style recent-project thumbnails.
if "import 'dart:io';" not in text:
    text = text.replace(
        "import 'dart:math' as math;\n",
        "import 'dart:io';\nimport 'dart:math' as math;\n",
        1,
    )

# Project photo lookup.
date_marker = "  String _dateLabel(DateTime value) {"
if date_marker not in text:
    raise SystemExit('date label marker missing')
if 'String? _projectFirstPhoto(MeasureProject project)' not in text:
    helper = r'''  String? _projectFirstPhoto(MeasureProject project) {
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        for (final path in room.photoPaths) {
          if (path.trim().isNotEmpty) return path;
        }
      }
    }
    return null;
  }

'''
    text = text.replace(date_marker, helper + date_marker, 1)

# Date labels in the approved concept include time for recent work.
old_date = r'''  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Сегодня';
    if (difference == 1) return 'Вчера';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
'''
new_date = r'''  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (difference == 0) return 'Сегодня, $time';
    if (difference == 1) return 'Вчера, $time';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
'''
if old_date in text:
    text = text.replace(old_date, new_date, 1)
elif "if (difference == 0) return 'Сегодня, $time';" not in text:
    raise SystemExit('date label body changed unexpectedly')

# Replace the schematic plan preview in recent projects with a photo/fallback interior thumbnail.
text = text.replace(
    """  Widget _projectCard(MeasureProject project) {\n    final floor = project.floors.isEmpty ? null : project.floors.first;\n    final areaM2 = _projectAreaM2(project);\n    final photos = _projectPhotoCount(project);\n""",
    """  Widget _projectCard(MeasureProject project) {\n    final areaM2 = _projectAreaM2(project);\n    final photos = _projectPhotoCount(project);\n    final photoPath = _projectFirstPhoto(project);\n""",
    1,
)
old_preview = r'''              SizedBox(
                width: 96,
                height: double.infinity,
                child: CustomPaint(
                  painter: _ProjectPlanPreviewPainter(floor: floor),
                ),
              ),
'''
new_preview = r'''              SizedBox(
                width: 86,
                height: double.infinity,
                child: _ProjectThumbnail(
                  photoPath: photoPath,
                  fallbackKind: project.name.length % 3,
                ),
              ),
'''
if old_preview in text:
    text = text.replace(old_preview, new_preview, 1)
elif 'child: _ProjectThumbnail(' not in text:
    raise SystemExit('project preview marker missing')

# Dense visual rhythm from the approved phone mockup.
replacements = [
    ("fontSize: 17,\n              fontWeight: FontWeight.w900,", "fontSize: 15.5,\n              fontWeight: FontWeight.w900,"),
    ("height: 88,", "height: 76,"),
    ("borderRadius: BorderRadius.circular(15),", "borderRadius: BorderRadius.circular(12),"),
    ("padding: const EdgeInsets.fromLTRB(11, 9, 2, 8),", "padding: const EdgeInsets.fromLTRB(10, 7, 2, 7),"),
    ("fontSize: 13.5,", "fontSize: 12.2,"),
    ("fontSize: 10.5,\n                          color: Color(0xFF8F9A9F),", "fontSize: 9.4,\n                          color: Color(0xFF8F9A9F),"),
    ("padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),", "padding: const EdgeInsets.fromLTRB(12, 7, 12, 14),"),
    ("fontSize: 29,", "fontSize: 24,"),
    ("letterSpacing: 1.7,", "letterSpacing: 1.25,"),
    ("const SizedBox(height: 9),\n                  TextField(", "const SizedBox(height: 6),\n                  TextField("),
    ("prefixIcon: const Icon(Icons.search_rounded, size: 20),", "prefixIcon: const Icon(Icons.search_rounded, size: 18),"),
    ("icon: const Icon(Icons.close_rounded, size: 19),", "icon: const Icon(Icons.close_rounded, size: 18),"),
    ("icon: const Icon(Icons.tune_rounded, size: 19),", "icon: const Icon(Icons.tune_rounded, size: 18),"),
    ("contentPadding: const EdgeInsets.symmetric(vertical: 11),", "contentPadding: const EdgeInsets.symmetric(vertical: 7),"),
    ("borderRadius: BorderRadius.circular(11),", "borderRadius: BorderRadius.circular(10),"),
    ("const SizedBox(height: 11),\n                  Row(\n                    children: [\n                      Expanded(\n                        child: _QuickActionCard(", "const SizedBox(height: 8),\n                  Row(\n                    children: [\n                      Expanded(\n                        child: _QuickActionCard("),
    ("const SizedBox(height: 21),", "const SizedBox(height: 14),"),
    ("const SizedBox(height: 16),\n                    _sectionTitle(", "const SizedBox(height: 11),\n                    _sectionTitle("),
    ("height: 118,", "height: 98,"),
    ("height: 72,", "height: 58,"),
    ("borderRadius: BorderRadius.circular(13),", "borderRadius: BorderRadius.circular(11),"),
    ("padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),", "padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),"),
    ("Icon(icon, color: foreground, size: 22),", "Icon(icon, color: foreground, size: 19),"),
    ("const SizedBox(height: 6),\n              Text(\n                title,", "const SizedBox(height: 4),\n              Text(\n                title,"),
    ("fontSize: 12.5,", "fontSize: 11.3,"),
    ("width: 126,", "width: 108,"),
    ("fontSize: 10.5,\n                    fontWeight: FontWeight.w800,", "fontSize: 9.5,\n                    fontWeight: FontWeight.w800,"),
    ("fontSize: 9.5,\n          color: Color(0xFFB5BDC0),", "fontSize: 8.8,\n          color: Color(0xFFB5BDC0),"),
    ("height: 64,", "height: 58,"),
    ("width: 31,\n          height: 28,", "width: 29,\n          height: 25,"),
    ("size: 18,\n            color: selected", "size: 17,\n            color: selected"),
    ("fontSize: 8.5,", "fontSize: 8.0,"),
]
for old, new in replacements:
    if old in text:
        text = text.replace(old, new)

# Compact the settings control so the header matches the concept's tight top row.
old_settings = r'''                      IconButton(
                        tooltip: 'Настройки',
                        onPressed: _showMore,
                        icon: const Icon(Icons.settings_outlined),
                      ),
'''
new_settings = r'''                      IconButton(
                        tooltip: 'Настройки',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        onPressed: _showMore,
                        icon: const Icon(Icons.settings_outlined, size: 20),
                      ),
'''
if old_settings in text:
    text = text.replace(old_settings, new_settings, 1)

# Smaller section trailing controls, as on the master concept board.
text = text.replace("child: Text(\n                              _showAllProjects ? 'Свернуть' : 'Все ›',", "style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11)),\n                            child: Text(\n                              _showAllProjects ? 'Свернуть' : 'Все ›',", 1)
text = text.replace("onPressed: _showCreateProjectPanel,\n                        child: const Text('Все ›'),", "onPressed: _showCreateProjectPanel,\n                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11)),\n                        child: const Text('Все ›'),", 1)

# Add photo-aware project thumbnail widget before template cards.
thumb_marker = 'class _TemplateCard extends StatelessWidget {'
if thumb_marker not in text:
    raise SystemExit('template card marker missing')
if 'class _ProjectThumbnail extends StatelessWidget {' not in text:
    thumbnail = r'''class _ProjectThumbnail extends StatelessWidget {
  const _ProjectThumbnail({required this.photoPath, required this.fallbackKind});

  final String? photoPath;
  final int fallbackKind;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null) {
      return ClipRect(
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => CustomPaint(
            painter: _TemplateScenePainter(kind: fallbackKind),
          ),
        ),
      );
    }
    return CustomPaint(painter: _TemplateScenePainter(kind: fallbackKind));
  }
}

'''
    text = text.replace(thumb_marker, thumbnail + thumb_marker, 1)

# Upgrade the fallback/template artwork so it reads as a polished interior thumbnail,
# not the flat placeholder seen in +65.
painter_start = text.find('class _TemplateScenePainter extends CustomPainter {')
painter_end = text.find('class _ProjectPlanPreviewPainter extends CustomPainter {', painter_start)
if painter_start < 0 or painter_end < 0:
    raise SystemExit('template painter markers missing')
new_painter = r'''class _TemplateScenePainter extends CustomPainter {
  const _TemplateScenePainter({required this.kind});
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: kind == 2
            ? const [Color(0xFF4D4943), Color(0xFF24282B)]
            : const [Color(0xFF6B6258), Color(0xFF292D2F)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    final floorPath = Path()
      ..moveTo(0, size.height * .60)
      ..lineTo(size.width, size.height * .49)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA98563), Color(0xFF6E513A)],
        ).createShader(Offset.zero & size),
    );

    // Window with frame and soft daylight.
    final windowRect = Rect.fromLTWH(
      size.width * .07,
      size.height * .11,
      size.width * .30,
      size.height * .34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, const Radius.circular(1.5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDE8E8), Color(0xFF98AFB0)],
        ).createShader(windowRect),
    );
    final frame = Paint()
      ..color = const Color(0xFF536064)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(windowRect.center.dx, windowRect.top),
      Offset(windowRect.center.dx, windowRect.bottom),
      frame,
    );
    canvas.drawLine(
      Offset(windowRect.left, windowRect.center.dy),
      Offset(windowRect.right, windowRect.center.dy),
      frame,
    );

    // Rug adds depth and gives the miniature an interior-render feel.
    final rug = Path()
      ..moveTo(size.width * .27, size.height * .66)
      ..lineTo(size.width * .86, size.height * .60)
      ..lineTo(size.width * .95, size.height * .91)
      ..lineTo(size.width * .23, size.height * .92)
      ..close();
    canvas.drawPath(rug, Paint()..color = const Color(0xFF8B7763));

    if (kind == 2) {
      // Commercial variant: desk, low cabinet and task chair.
      canvas.drawRect(
        Rect.fromLTWH(size.width * .34, size.height * .55, size.width * .48, size.height * .08),
        Paint()..color = const Color(0xFF3D342E),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * .38, size.height * .63, size.width * .04, size.height * .20),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * .74, size.height * .63, size.width * .04, size.height * .20),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .50, size.height * .68, size.width * .19, size.height * .18),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFB6AA9D),
      );
    } else {
      // Sofa with separate back and cushions.
      final sofaBody = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .36, size.height * .55, size.width * .49, size.height * .25),
        const Radius.circular(7),
      );
      canvas.drawRRect(sofaBody, Paint()..color = const Color(0xFFD0C4B4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .39, size.height * .45, size.width * .43, size.height * .17),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFBEB1A1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .42, size.height * .53, size.width * .17, size.height * .12),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFE3D9CB),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .62, size.height * .52, size.width * .16, size.height * .12),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFAA9B8A),
      );

      // Coffee table.
      canvas.drawOval(
        Rect.fromLTWH(size.width * .44, size.height * .76, size.width * .31, size.height * .10),
        Paint()..color = const Color(0xFF4A4038),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * .58, size.height * .84, size.width * .025, size.height * .08),
        Paint()..color = const Color(0xFF342D28),
      );
    }

    // Plant/lamp silhouette at the right gives all cards a premium, lived-in feel.
    if (kind == 1) {
      final stem = Paint()
        ..color = const Color(0xFF5D4938)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width * .88, size.height * .71),
        Offset(size.width * .88, size.height * .39),
        stem,
      );
      final leaf = Paint()..color = const Color(0xFF42674B);
      canvas.drawCircle(Offset(size.width * .84, size.height * .37), size.width * .07, leaf);
      canvas.drawCircle(Offset(size.width * .91, size.height * .34), size.width * .06, leaf);
      canvas.drawCircle(Offset(size.width * .88, size.height * .29), size.width * .06, leaf);
    } else {
      canvas.drawLine(
        Offset(size.width * .89, size.height * .73),
        Offset(size.width * .89, size.height * .37),
        Paint()..color = const Color(0xFF4E433C)..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(size.width * .89, size.height * .31),
        size.width * .055,
        Paint()..color = const Color(0xFFE0C39D),
      );
    }

    // Soft highlight over the image, similar to the warm renders in the concept.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0x22000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _TemplateScenePainter oldDelegate) =>
      oldDelegate.kind != kind;
}

'''
text = text[:painter_start] + new_painter + text[painter_end:]

SCREEN.write_text(text)

# Replace the old regression-looking demo card with a concept-like sample project.
demo = DEMO.read_text()
demo = demo.replace("static const buildTag = '1.5.5+46';", "static const buildTag = '1.5.6+66';")
demo = demo.replace("static const projectId = '__zamer_demo_1_5_5_46__';", "static const projectId = '__zamer_demo_1_5_6_66__';")
demo = demo.replace("name: 'Тестовое помещение • $buildTag',", "name: 'Квартира, Калининград',")
demo = demo.replace("address: 'Пробный проект для проверки новой сборки',", "address: '',")
DEMO.write_text(demo)

pubspec = pubspec.replace('version: 1.5.6+65', 'version: 1.5.6+66', 1)
pubspec_path.write_text(pubspec)

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+66 — Главная: визуальное совпадение с мастер-концептом\n\n- Пересобрана плотность главного экрана: компактнее заголовок, поиск, быстрые действия, секции, карточки и нижняя навигация.\n- Недавние проекты теперь используют реальные фото проекта при наличии, а не схематичный план; для проектов без фото добавлен интерьерный fallback-превью.\n- Карточки проектов уменьшены и приведены к пропорциям мастер-концепта, даты получили формат «Сегодня/Вчера, HH:MM».\n- Шаблоны получили более детализированные интерьерные миниатюры и компактные размеры.\n- Демонстрационный проект переименован в нейтральный «Квартира, Калининград», чтобы тестовая сборка визуально не ломала утверждённую главную.\n- Страница 2 не изменялась.\n\n'''
if not changelog.startswith('## 1.5.6+66'):
    changelog_path.write_text(entry + changelog)

print('Applied 1.5.6+66 master-concept visual match')
