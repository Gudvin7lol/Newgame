from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+61' in pubspec:
    print('1.5.6+61 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+60' not in pubspec:
    raise SystemExit('unexpected version, refusing +61 patch')

screen_path = APP / 'lib/screens/layouts_screen.dart'
screen = screen_path.read_text()

screen = replace_once(
    screen,
    '''          child: Column(\n            children: [\n              DropdownButtonFormField<String>(\n''',
    '''          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.stretch,\n            children: [\n              Row(\n                children: [\n                  const Expanded(\n                    child: Column(\n                      crossAxisAlignment: CrossAxisAlignment.start,\n                      children: [\n                        Text(\n                          'Материалы и раскладка',\n                          style: TextStyle(\n                            fontSize: 20,\n                            fontWeight: FontWeight.w900,\n                            letterSpacing: .1,\n                          ),\n                        ),\n                        SizedBox(height: 2),\n                        Text(\n                          'Один рисунок пола для плана и 3D',\n                          style: TextStyle(\n                            fontSize: 11,\n                            color: Color(0xFF8C989D),\n                          ),\n                        ),\n                      ],\n                    ),\n                  ),\n                  Container(\n                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),\n                    decoration: BoxDecoration(\n                      color: const Color(0xFF171F23),\n                      borderRadius: BorderRadius.circular(10),\n                      border: Border.all(color: const Color(0xFF2A3941)),\n                    ),\n                    child: Text(\n                      '${meta.name} • ${face.areaM2.toStringAsFixed(1)} м²',\n                      style: const TextStyle(\n                        fontSize: 10,\n                        fontWeight: FontWeight.w800,\n                        color: Color(0xFFF1C79E),\n                      ),\n                    ),\n                  ),\n                ],\n              ),\n              const SizedBox(height: 10),\n              DropdownButtonFormField<String>(\n''',
    'layouts master header',
)

screen = replace_once(
    screen,
    '''              if (faces.length > 1)\n                TextButton.icon(\n                  onPressed: () => _chooseCarpet(faces, face, s),\n                  icon: const Icon(Icons.layers_outlined),\n                  label: Text(\n                    widget.floor.carpetRoomIds.isEmpty\n                        ? 'Единый ковёр по помещениям'\n                        : 'Единый ковёр: ${widget.floor.carpetRoomIds.length} помещения',\n                  ),\n                ),\n''',
    '''              if (faces.length > 1)\n                Align(\n                  alignment: Alignment.centerLeft,\n                  child: OutlinedButton.icon(\n                    onPressed: () => _chooseCarpet(faces, face, s),\n                    icon: const Icon(Icons.layers_outlined, size: 18),\n                    label: Text(\n                      widget.floor.carpetRoomIds.isEmpty\n                          ? 'Единый ковёр по помещениям'\n                          : 'Единый ковёр • ${widget.floor.carpetRoomIds.length} помещения',\n                    ),\n                  ),\n                ),\n''',
    'carpet control',
)

screen = replace_once(
    screen,
    '''              SegmentedButton<FloorLayoutKind>(\n                segments: const [\n                  ButtonSegment(\n                    value: FloorLayoutKind.laminate,\n                    label: Text('Ламинат'),\n                  ),\n                  ButtonSegment(\n                    value: FloorLayoutKind.underlay,\n                    label: Text('Подложка'),\n                  ),\n                  ButtonSegment(\n                    value: FloorLayoutKind.tile,\n                    label: Text('Плитка'),\n                  ),\n                ],\n''',
    '''              SegmentedButton<FloorLayoutKind>(\n                showSelectedIcon: false,\n                segments: const [\n                  ButtonSegment(\n                    value: FloorLayoutKind.laminate,\n                    icon: Icon(Icons.view_agenda_outlined),\n                    label: Text('Ламинат'),\n                  ),\n                  ButtonSegment(\n                    value: FloorLayoutKind.underlay,\n                    icon: Icon(Icons.layers_outlined),\n                    label: Text('Подложка'),\n                  ),\n                  ButtonSegment(\n                    value: FloorLayoutKind.tile,\n                    icon: Icon(Icons.grid_view_rounded),\n                    label: Text('Плитка'),\n                  ),\n                ],\n''',
    'layout mode segmented control',
)

screen = replace_once(
    screen,
    '''            child: Card(\n              clipBehavior: Clip.antiAlias,\n              child: LayoutBuilder(\n''',
    '''            child: Card(\n              color: const Color(0xFF0B1115),\n              elevation: 0,\n              shape: RoundedRectangleBorder(\n                borderRadius: BorderRadius.circular(18),\n                side: const BorderSide(color: Color(0xFF243139)),\n              ),\n              clipBehavior: Clip.antiAlias,\n              child: LayoutBuilder(\n''',
    'layout preview card',
)

screen = replace_once(
    screen,
    '''              child: Card(\n                child: Padding(\n                  padding: const EdgeInsets.all(10),\n''',
    '''              child: Card(\n                color: const Color(0xFF11191E),\n                elevation: 0,\n                shape: RoundedRectangleBorder(\n                  borderRadius: BorderRadius.circular(18),\n                  side: const BorderSide(color: Color(0xFF243139)),\n                ),\n                child: Padding(\n                  padding: const EdgeInsets.all(12),\n''',
    'layout controls card',
)

screen = screen.replace(
    "color: thin\n                                ? const Color(0xFFFFF1E8)\n                                : const Color(0xFFEEF7F1),",
    "color: thin\n                                ? const Color(0xFF38241A)\n                                : const Color(0xFF173127),",
)
screen = screen.replace(
    "? const Color(0xFF9B4B1B)\n                                  : const Color(0xFF2E6B45),",
    "? const Color(0xFFF0A06A)\n                                  : const Color(0xFF8AC8AE),",
)

screen_path.write_text(screen)

painter_path = APP / 'lib/widgets/floor_layout_painter.dart'
painter = painter_path.read_text()
painter = replace_once(
    painter,
    '''    canvas.drawRect(\n      Offset.zero & size,\n      Paint()..color = const Color(0xFFF6F7F9),\n    );\n''',
    '''    canvas.drawRect(\n      Offset.zero & size,\n      Paint()..color = const Color(0xFF0B1115),\n    );\n    final gridPaint = Paint()\n      ..color = const Color(0xFF162229)\n      ..strokeWidth = .7;\n    const gridStep = 32.0;\n    for (var x = 0.0; x <= size.width; x += gridStep) {\n      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);\n    }\n    for (var y = 0.0; y <= size.height; y += gridStep) {\n      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);\n    }\n''',
    'layout painter background',
)
painter = replace_once(
    painter,
    '    canvas.drawPath(surface, Paint()..color = Colors.white);',
    "    canvas.drawPath(surface, Paint()..color = const Color(0xFF121B20));",
    'layout surface fill',
)
painter = replace_once(
    painter,
    '''        ..color = const Color(0xFF28313A)\n        ..style = PaintingStyle.stroke\n        ..strokeWidth = 2,\n''',
    '''        ..color = const Color(0xFFD4DEE2)\n        ..style = PaintingStyle.stroke\n        ..strokeWidth = 1.6,\n''',
    'layout surface outline',
)
painter = painter.replace('const Color(0xFF98A4AF)', 'const Color(0xFF7A665A)')
painter = painter.replace('const Color(0xFFE5E1DA)', 'const Color(0xFFC9A987)')
painter = painter.replace('const Color(0xFF9B9286)', 'const Color(0xFF79685D)')
painter = painter.replace('const Color(0xFFE4DDD2)', 'const Color(0xFFCBAE91)')
painter = painter.replace('const Color(0xFFDDD5C9)', 'const Color(0xFFBFA184)')
painter = painter.replace('const Color(0xFFE7F0EC)', 'const Color(0xFF244036)')
painter = painter.replace('const Color(0xFFD9E7E0)', 'const Color(0xFF1C332B)')
painter = painter.replace('const Color(0xFF7A9085)', 'const Color(0xFF75AA94)')
painter = painter.replace('const Color(0xFF8E99A5)', 'const Color(0xFF9A877B)')
painter = painter.replace('const Color(0xFFF1F2F4)', 'const Color(0xFFD8C7B8)')
painter_path.write_text(painter)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+60', 'version: 1.5.6+61', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+61 — Материалы и раскладка по мастер-концепту\n\n- Экран «Материалы и раскладка» переведён на общий визуальный язык мастер-концепта.\n- Добавлен компактный заголовок с текущим помещением, площадью и пояснением связи раскладки плана с 3D.\n- Режимы «Ламинат / Подложка / Плитка» получили единые пиктограммы и более ясное активное состояние.\n- Превью раскладки переведено на тёмный чертёжный холст с сеткой, светлым контуром помещения и более читаемыми материалами.\n- Панель параметров стала компактнее и визуально отделена от рабочего холста.\n- Индикация узких подрезок адаптирована под тёмную тему без изменения алгоритма балансировки.\n- Математика направления, anchor, смещений, единого ковра, схем 1/2 и 1/3 и реальной ширины плиточного шва не изменялась.\n\n'''
if not changelog.startswith('## 1.5.6+61'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+61 materials/layout master-concept pass')
