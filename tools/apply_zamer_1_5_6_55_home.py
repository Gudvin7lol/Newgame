from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


screen_path = APP / 'lib/screens/projects_screen.dart'
screen = screen_path.read_text()
screen = replace_once(
    screen,
    'math.min(360, _scrollController.position.maxScrollExtent)',
    'math.min(360.0, _scrollController.position.maxScrollExtent)',
    'scroll target double',
)
screen = replace_once(
    screen,
    '..strokeWidth = (wall.thicknessMm * scale).clamp(1.35, 4.2)\n',
    '..strokeWidth = (wall.thicknessMm * scale).clamp(1.35, 4.2).toDouble()\n',
    'preview wall stroke double',
)
screen_path.write_text(screen)

pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+55' not in pubspec:
    pubspec = replace_once(
        pubspec,
        'version: 1.5.6+54',
        'version: 1.5.6+55',
        'version bump',
    )
    pubspec_path.write_text(pubspec)

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+55 — Главная по мастер-концепту

- Главный экран перестроен по странице 1 мастер-концепта: собственная шапка ZAMER, живой поиск, две быстрые карточки действий, недавние проекты и шаблоны.
- Карточки проектов вместо технического аватара показывают мини-план первого этажа из реальной геометрии стен; существующие, демонтажные и новые стены различаются визуально.
- Поиск работает по названию проекта, адресу и клиенту; список недавних проектов сортируется по дате создания и разворачивается без перехода на отдельный экран.
- Добавлены рабочие шаблоны «Квартира», «Дом» и «Коммерция», которые создают новый проект с соответствующим названием.
- Нижняя навигация приведена к языку мастер-концепта и оставлена функциональной: проекты, импорт, диагностика и сервисные действия доступны без декоративных пустышек.
- Убран устаревший hero-блок `ZAMER v1.0 Professional`; экран использует визуальный фундамент +54 с тёплым песочным акцентом и плотными тёмными поверхностями.

'''
if not changelog.startswith('## 1.5.6+55'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+55 home finalizer')
