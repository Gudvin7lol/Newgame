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
if 'version: 1.5.6+59' in pubspec:
    print('1.5.6+59 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+58' not in pubspec:
    raise SystemExit('unexpected version, refusing +59 patch')

screen_path = APP / 'lib/screens/elevations_screen.dart'
screen = screen_path.read_text()
screen = replace_once(
    screen,
    "          child: Column(\n            children: [\n              DropdownButtonFormField<String>(",
    "          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.stretch,\n            children: [\n              const Text(\n                'Развёртки',\n                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),\n              ),\n              const SizedBox(height: 2),\n              Text(\n                '${meta.name} • ${runs.length} стен',\n                style: const TextStyle(fontSize: 11, color: Color(0xFF8C989D)),\n              ),\n              const SizedBox(height: 10),\n              DropdownButtonFormField<String>(",
    'elevations header',
)
screen = replace_once(
    screen,
    "                      selected: selected,\n                      showCheckmark: false,",
    "                      selected: selected,\n                      showCheckmark: false,\n                      selectedColor: const Color(0xFF3B3028),\n                      backgroundColor: const Color(0xFF111A1F),\n                      side: BorderSide(\n                        color: selected\n                            ? const Color(0xFFF1C79E)\n                            : const Color(0xFF2A3941),\n                      ),",
    'wall choice chips',
)
screen = replace_once(screen, 'height: 410,', 'height: 440,', 'elevation preview height')
screen = replace_once(
    screen,
    "                  child: Card(\n                    child: Column(",
    "                  child: Card(\n                    elevation: 0,\n                    color: const Color(0xFF111A1F),\n                    shape: RoundedRectangleBorder(\n                      borderRadius: BorderRadius.circular(18),\n                      side: const BorderSide(color: Color(0xFF2A3941)),\n                    ),\n                    child: Column(",
    'elevation main card',
)
screen = replace_once(
    screen,
    "                                      color: Colors.white,\n                                      borderRadius: BorderRadius.circular(12),",
    "                                      color: const Color(0xFF0B1115),\n                                      borderRadius: BorderRadius.circular(12),",
    'preview surface',
)
screen = replace_once(
    screen,
    "      color: Theme.of(context).colorScheme.surfaceContainerHighest,\n      borderRadius: BorderRadius.circular(10),",
    "      color: const Color(0xFF172125),\n      borderRadius: BorderRadius.circular(10),\n      border: Border.all(color: const Color(0xFF2A3941)),",
    'info pill surface',
)
screen_path.write_text(screen)

painter_path = APP / 'lib/widgets/elevation_painter.dart'
painter = painter_path.read_text()
painter = replace_once(
    painter,
    "canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);",
    "canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B1115));",
    'painter canvas',
)
painter = replace_once(
    painter,
    "canvas.drawRect(rect, Paint()..color = const Color(0xFFF5F6F8));",
    "canvas.drawRect(rect, Paint()..color = const Color(0xFF172125));",
    'wall surface',
)
painter = replace_once(
    painter,
    "        ..color = const Color(0xFF20242A)\n        ..style = PaintingStyle.stroke",
    "        ..color = const Color(0xFFD4DCDF)\n        ..style = PaintingStyle.stroke",
    'wall outline',
)
painter = replace_once(
    painter,
    "                ? const Color(0xFFD8E9FF)\n                : const Color(0xFFFFE7D2),",
    "                ? const Color(0xFF20384A)\n                : const Color(0xFF4A3426),",
    'opening fills',
)
painter = replace_once(
    painter,
    "            ..color = const Color(0xFF59616D)\n            ..style = PaintingStyle.stroke",
    "            ..color = const Color(0xFFB9C3C7)\n            ..style = PaintingStyle.stroke",
    'opening outline',
)
painter = replace_once(
    painter,
    "    canvas.drawRect(tileRect, Paint()..color = const Color(0xFFF1F3F5));",
    "    canvas.drawRect(tileRect, Paint()..color = const Color(0xFF1B2529));",
    'tile surface',
)
painter = replace_once(
    painter,
    "      ..color = const Color(0xFFB0B7C0)\n      ..style = PaintingStyle.stroke",
    "      ..color = const Color(0xFF718087)\n      ..style = PaintingStyle.stroke",
    'tile grout color',
)
painter = replace_once(
    painter,
    "        ..color = const Color(0xFF8D98A5)\n        ..style = PaintingStyle.stroke",
    "        ..color = const Color(0xFF8E9A9F)\n        ..style = PaintingStyle.stroke",
    'tile boundary',
)
painter = replace_once(
    painter,
    "      ..color = opening ? const Color(0xFF3E8F75) : const Color(0xFF6D7580)",
    "      ..color = opening ? const Color(0xFF55B98C) : const Color(0xFFAAB5BA)",
    'dimension chain',
)
painter = replace_once(
    painter,
    "          color: Color(0xFF252A30),",
    "          color: Color(0xFFDDE4E7),",
    'material badge text',
)
painter = replace_once(
    painter,
    "      Paint()..color = Colors.white.withValues(alpha: .92),",
    "      Paint()..color = const Color(0xEE111A1F),",
    'material badge surface',
)
painter = replace_once(
    painter,
    "    final fill = Paint()..color = const Color(0xFFFFFFFF);",
    "    final fill = Paint()..color = const Color(0xFF172125);",
    'electrical fill',
)
painter = replace_once(
    painter,
    "      ..color = const Color(0xFF6D7580)\n      ..strokeWidth = 1;",
    "      ..color = const Color(0xFFAAB5BA)\n      ..strokeWidth = 1;",
    'dimension line',
)
painter = replace_once(
    painter,
    "          color: Color(0xFF3A414A),\n          fontSize: 10,\n          fontWeight: FontWeight.w600,\n          backgroundColor: Colors.white,",
    "          color: Color(0xFFD5DDE0),\n          fontSize: 10,\n          fontWeight: FontWeight.w700,\n          backgroundColor: Color(0xE60B1115),",
    'dimension text',
)
painter = replace_once(
    painter,
    "          color: const Color(0xFF2A3038),",
    "          color: const Color(0xFFDDE4E7),",
    'labels',
)
painter_path.write_text(painter)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+58', 'version: 1.5.6+59', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+59 — Развёртки по мастер-концепту\n\n- Экран «Развёртки» переведён на визуальный стандарт страницы 5 мастер-концепта: крупная стена на тёмном чертёжном поле и более компактная навигация по стенам.\n- Добавлен явный заголовок помещения и количество стен; переключатели стен получили тёмные поверхности и песочный selected-state.\n- Основная карточка развёртки стала плоской тёмной панелью с тонким контуром, а рабочая область увеличена по высоте.\n- Сам `ElevationPainter` переведён на тёмную архитектурную палитру: стена, проёмы, размеры, подписи, электрика и плиточная сетка остаются читаемыми без белого листа внутри тёмного приложения.\n- Информационные плашки высоты и материалов приведены к общей системе поверхностей ZAMER.\n- Логика плитки, реальный шов, смещения, 90°-поворот, зеркалирование, балансировка подрезок и крупный режим развёртки сохранены.\n\n'''
if not changelog.startswith('## 1.5.6+59'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+59 elevations UI pass')
