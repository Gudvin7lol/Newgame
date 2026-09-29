from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_exact(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found != count:
        raise SystemExit(f'{label}: expected {count} matches, found {found}')
    return text.replace(old, new, count)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+56' in pubspec:
    print('1.5.6+56 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+55' not in pubspec:
    raise SystemExit('unexpected version, refusing +56 patch')

# ---------------------------------------------------------------------------
# Page 2 master concept: dark architectural canvas and readable dimensions.
# ---------------------------------------------------------------------------
painter_path = APP / 'lib/widgets/floor_plan_painter.dart'
painter = painter_path.read_text()
replacements = [
    ('0xFFEEF1F1', '0xFF091014', 'canvas background'),
    ('0xFFDDE3E3', '0xFF172229', 'major grid'),
    ('0xFFF7FAFF', '0xFF0E171B', 'room fill'),
    ('0xFFD8E6FA', '0xFF25343B', 'room outline'),
    ('0xFFF5F7FA', '0xFF0E171B', 'opening cut'),
    ('0xFF56D6A3', '0xFFF1C79E', 'selected wall'),
    ('0xFF55B98C', '0xFF79BCA6', 'proposed wall'),
    ('0xFF4C5561', '0xFF9AA4A9', 'partition wall'),
    ('0xFF65707A', '0xFF8D999F', 'dimension line'),
    ('0xFF46505A', '0xFFD9DEDF', 'dimension text'),
    ('0xEFFFFFFF', '0xE6111A1F', 'opening dimension label bg'),
    ('0xEEFFFFFF', '0xEE111A1F', 'dimension label bg'),
    ('0xFF242930', '0xFFE8E3DD', 'dimension label text'),
    ('0xFF2E6B45', '0xFF91CFB3', 'measure label text'),
    ('0xFF1769E8', '0xFFF1C79E', 'active node'),
    ('0xFF252A30', '0xFFD8DDDF', 'node outline'),
]
for old, new, label in replacements:
    if old not in painter:
        raise SystemExit(f'{label}: color marker missing')
    painter = painter.replace(old, new)
# Existing outer walls and room labels shared the same dark value in the old
# light canvas. On the dark master canvas both intentionally become light.
painter = replace_exact(
    painter,
    'const Color(0xFF20242A)',
    'const Color(0xFFE3E6E7)',
    'existing wall / label light pass',
    count=painter.count('const Color(0xFF20242A)'),
)
# Nodes should be dark discs with a light outline, not white blobs.
painter = replace_exact(
    painter,
    'active ? const Color(0xFFF1C79E) : Colors.white',
    "active ? const Color(0xFFF1C79E) : const Color(0xFF111A1F)",
    'node fill',
)
painter_path.write_text(painter)

# ---------------------------------------------------------------------------
# Editor chrome: compact master-concept toolbars and visible dark snap state.
# ---------------------------------------------------------------------------
editor_path = APP / 'lib/screens/plan_editor_screen.dart'
editor = editor_path.read_text()
editor = replace_exact(
    editor,
    '''            Positioned(
              left: 10,
              right: 10,
              top: 8,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),''',
    '''            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Card(
                elevation: 0,
                color: const Color(0xF2111A1F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF2A3941)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),''',
    'compact top toolbar',
)
editor = replace_exact(
    editor,
    '''                top: 78,
                left: 18,
                child: Card(
                  color: const Color(0xFFF0F5FF),''',
    '''                top: 70,
                left: 18,
                child: Card(
                  elevation: 0,
                  color: const Color(0xF2111A1F),''',
    'dark snap card',
)
editor = replace_exact(
    editor,
    '''                        const Icon(
                          Icons.link,
                          size: 16,
                          color: Color(0xFF315DA8),
                        ),''',
    '''                        const Icon(
                          Icons.link,
                          size: 16,
                          color: Color(0xFFF1C79E),
                        ),''',
    'snap icon accent',
)
editor = replace_exact(
    editor,
    '''                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF315DA8),
                          ),''',
    '''                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF1C79E),
                          ),''',
    'snap text accent',
)
editor = replace_exact(
    editor,
    '''            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: SafeArea(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(8),''',
    '''            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: SafeArea(
                child: Card(
                  elevation: 0,
                  color: const Color(0xF5111A1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF2A3941)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),''',
    'compact bottom toolbelt',
)
old_mode = '''  Widget _modeButton(PlanMode mode, IconData icon, String label) {
    final active = _mode == mode;
    final button = active
        ? FilledButton.icon(
            onPressed: () => setState(() => _mode = mode),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1),
          )
        : OutlinedButton.icon(
            onPressed: () => setState(() {
              _mode = mode;
              _activeNodeId = null;
              _measureStartNodeId = null;
              _selectedNodeId = null;
              _dragNodeId = null;
              _lastNodeSnap = null;
            }),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1),
          );
    return SizedBox(width: 132, child: button);
  }
'''
new_mode = '''  Widget _modeButton(PlanMode mode, IconData icon, String label) {
    final active = _mode == mode;
    final foreground = active
        ? const Color(0xFF22170F)
        : const Color(0xFFD6DCDE);
    return SizedBox(
      width: 82,
      height: 58,
      child: Material(
        color: active ? const Color(0xFFF1C79E) : const Color(0xFF0D1519),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
            color: active
                ? const Color(0xFFF1C79E)
                : const Color(0xFF2A3941),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            _mode = mode;
            if (!active) {
              _activeNodeId = null;
              _measureStartNodeId = null;
              _selectedNodeId = null;
              _dragNodeId = null;
              _lastNodeSnap = null;
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
'''
editor = replace_exact(editor, old_mode, new_mode, 'compact mode tile')
# Master concept uses shorter working labels in the toolbelt.
for old, new in [
    ("'Навигация',", "'Обзор',"),
    ("'Наружная',", "'Стены',"),
    ("'Перегородка',", "'Перег.',"),
    ("'Демонтаж',", "'Демонтаж',"),
    ("'Размер',", "'Размеры',"),
]:
    if old != new and old in editor:
        editor = editor.replace(old, new, 1)
editor_path.write_text(editor)

# Version and release notes.
pubspec_path.write_text(pubspec.replace('version: 1.5.6+55', 'version: 1.5.6+56', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+56 — Замер / 2D по мастер-концепту

- Экран редактора плана переведён на визуальный стандарт страницы 2 мастер-концепта: тёмный архитектурный холст, спокойная сетка и компактные плавающие панели.
- Существующие стены стали светлыми на тёмном плане, новая планировка сохраняет отдельный зелёный оттенок, демонтаж остаётся красным, активная стена выделяется тёплым песочным акцентом.
- Размеры, подписи помещений и контрольные измерения получили тёмные полупрозрачные подложки и светлый текст вместо белых прямоугольников.
- Узлы плана стали тёмными с тонким светлым контуром; активный узел использует общий песочный акцент приложения.
- Нижний набор инструментов уменьшен с широких 132-пиксельных кнопок до компактных плиток с иконкой и подписью, поэтому чертёж занимает больше полезной площади.
- Верхняя панель undo/redo, размеров, центрирования, привязок и слоёв уплотнена и приведена к общему языку поверхностей +54/+55.
- Всплывающая индикация привязки больше не выбивается светло-синей карточкой и использует тёмную поверхность с песочным акцентом.

'''
if not changelog.startswith('## 1.5.6+56'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+56 measure UI pass')
