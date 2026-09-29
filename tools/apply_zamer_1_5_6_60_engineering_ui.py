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
if 'version: 1.5.6+60' in pubspec:
    print('1.5.6+60 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+59' not in pubspec:
    raise SystemExit('unexpected version, refusing +60 patch')

screen_path = APP / 'lib/screens/engineering_screen.dart'
screen = screen_path.read_text()

old_prefix = '''    final meta = widget.floor.roomMetaByKey(face.key)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
'''
new_prefix = '''    final meta = widget.floor.roomMetaByKey(face.key)!;
    final roomName = widget.floor.roomMetaByKey(face.key)?.name ?? 'Помещение';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Инженерия',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Потолки, тёплый пол и инженерные трассы',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171F23),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2A3941)),
                    ),
                    child: Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF1C79E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
'''
screen = replace_once(screen, old_prefix, new_prefix, 'engineering header')

screen = replace_once(
    screen,
    '''              SegmentedButton<_EngineeringTab>(
                segments: const [
                  ButtonSegment(
                    value: _EngineeringTab.ceiling,
                    label: Text('Потолок'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.warmFloor,
                    label: Text('Тёплый пол'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.routes,
                    label: Text('Трубы'),
                  ),
                ],
''',
    '''              SegmentedButton<_EngineeringTab>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _EngineeringTab.ceiling,
                    icon: Icon(Icons.layers_outlined),
                    label: Text('Потолок'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.warmFloor,
                    icon: Icon(Icons.waves_rounded),
                    label: Text('Тёплый пол'),
                  ),
                  ButtonSegment(
                    value: _EngineeringTab.routes,
                    icon: Icon(Icons.route_outlined),
                    label: Text('Трассы'),
                  ),
                ],
''',
    'engineering tabs',
)

screen = replace_once(
    screen,
    '''    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F7F7),
    );
''',
    '''    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B1115),
    );
    final gridPaint = Paint()
      ..color = const Color(0xFF172229)
      ..strokeWidth = .7;
    const gridStep = 32.0;
    for (var x = 0.0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
''',
    'engineering canvas background',
)

screen = replace_once(
    screen,
    '    canvas.drawPath(path, Paint()..color = Colors.white);',
    "    canvas.drawPath(path, Paint()..color = const Color(0xFF111A1F));",
    'engineering room fill',
)
screen = replace_once(
    screen,
    'canvas.drawRect(rect, Paint()..color = const Color(0xFFB8DCCC));',
    'canvas.drawRect(rect, Paint()..color = const Color(0xFF29483E));',
    'ceiling zone fill',
)
screen = replace_once(
    screen,
    '..color = const Color(0xFF247A5D)',
    '..color = const Color(0xFF8AC8AE)',
    'ceiling zone stroke',
)
screen = screen.replace('const Color(0xFFD46A43)', 'const Color(0xFFE89B67)')
screen = replace_once(
    screen,
    '..color = const Color(0xFF26363A)',
    '..color = const Color(0xFFD4DEE2)',
    'engineering room outline',
)
screen = screen.replace('ServiceRunType.coldWater: const Color(0xFF3285D0)', 'ServiceRunType.coldWater: const Color(0xFF62A9E6)')
screen = screen.replace('ServiceRunType.hotWater: const Color(0xFFD7574D)', 'ServiceRunType.hotWater: const Color(0xFFE66E67)')
screen = screen.replace('ServiceRunType.drain: const Color(0xFF83715A)', 'ServiceRunType.drain: const Color(0xFFB69B79)')
screen = screen.replace('ServiceRunType.heating: const Color(0xFFE6913A)', 'ServiceRunType.heating: const Color(0xFFEBA45A)')
screen_path.write_text(screen)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+59', 'version: 1.5.6+60', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+60 — Инженерия по мастер-концепту

- Экран «Инженерия» переведён на общий визуальный язык мастер-концепта без изменения расчётной логики.
- Добавлен компактный заголовок с текущим помещением и единая навигация «Потолок / Тёплый пол / Трассы» с понятными пиктограммами.
- Инженерный план получил тёмный чертёжный фон и ненавязчивую сетку; контур помещения стал светлым и читаемым на всех трёх режимах.
- Потолочные зоны получили более спокойную тёмно-зелёную заливку и контрастный контур, а тёплый пол — более читаемый тёплый акцент.
- Цвета ХВС, ГВС, канализации и отопления сохранены семантически разными, но адаптированы для тёмного холста.
- Геометрия потолочных зон, расчёт тёплого пола, уклон канализации, диаметры труб, 90° трассы и редактирование точек не изменялись.

'''
if not changelog.startswith('## 1.5.6+60'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+60 engineering UI pass')
