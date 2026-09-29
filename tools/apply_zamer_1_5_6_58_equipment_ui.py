from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, block: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'{label}: start marker missing')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'{label}: end marker missing')
    return text[:a] + block + text[b:]


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+58' in pubspec:
    print('1.5.6+58 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+57' not in pubspec:
    raise SystemExit('unexpected version, refusing +58 patch')

screen_path = APP / 'lib/screens/planning_objects_screen.dart'
screen = screen_path.read_text()

header_start = '''        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
'''
header_end = '''        Expanded(
          child: LayoutBuilder(
'''
new_header = r'''        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
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
                          'Оснащение',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Выбери объект и размести его касанием по плану',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Открыть каталог',
                    onPressed: _source == _AddSource.catalog ? _chooseModel : null,
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SegmentedButton<_AddSource>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _AddSource.catalog,
                    icon: Icon(Icons.chair_alt_outlined),
                    label: Text('Каталог'),
                  ),
                  ButtonSegment(
                    value: _AddSource.engineering,
                    icon: Icon(Icons.engineering_outlined),
                    label: Text('Инженерия'),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (value) =>
                    setState(() => _source = value.first),
              ),
              const SizedBox(height: 9),
              if (_source == _AddSource.catalog)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A1F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3941)),
                  ),
                  child: Row(
                    children: [
                      _modelPreview(ObjectCatalog.byId(_catalogId), 82),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ObjectCatalog.byId(_catalogId).name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${ObjectCatalog.byId(_catalogId).widthMm.round()} × '
                              '${ObjectCatalog.byId(_catalogId).depthMm.round()} × '
                              '${ObjectCatalog.byId(_catalogId).heightMm.round()} мм',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB3BDC1),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _EquipmentChip(label: _group),
                                _EquipmentChip(
                                  label: ObjectCatalog.byId(_catalogId).mountLabel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Сменить модель',
                        onPressed: _chooseModel,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<PlanObjectType>(
                  value: _engineeringType,
                  decoration: const InputDecoration(
                    labelText: 'Инженерный / конструктивный элемент',
                  ),
                  items: _engineeringTypes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _engineeringType = value ?? _engineeringType,
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ProjectLayer>(
                value: _layer,
                decoration: const InputDecoration(labelText: 'Слой проекта'),
                items: ProjectLayer.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _layer = value ?? _layer),
              ),
            ],
          ),
        ),
'''
screen = replace_between(
    screen,
    header_start,
    header_end,
    new_header,
    'equipment header',
)

screen = replace_once(screen, 'heightFactor: .90,', 'heightFactor: .94,', 'catalog height')
screen = replace_once(screen, 'width: 96,', 'width: 88,', 'category rail width')
screen = replace_once(
    screen,
    'childAspectRatio: .64,',
    'childAspectRatio: .72,',
    'catalog card aspect',
)
screen = replace_once(
    screen,
    "? const Color(0xFF10181B)\n            : const Color(0xFFF7F8FA),",
    "? const Color(0xFF10181B)\n            : const Color(0xFF0B1115),",
    'equipment canvas background',
)
screen = replace_once(
    screen,
    ': const Color(0xFF3B4148);',
    ': const Color(0xFFD6DEE1);',
    'existing wall color',
)
screen = replace_once(
    screen,
    'ProjectLayer.proposed => const Color(0xFF4E68A7),',
    'ProjectLayer.proposed => const Color(0xFFB88862),',
    'proposed object color',
)
screen = replace_once(
    screen,
    'selected ? const Color(0xFF0D5BD7) : color',
    'selected ? const Color(0xFFF1C79E) : color',
    'selected object accent',
)
screen = replace_once(
    screen,
    'color: Color(\n                                                          0xFF77BFA4,\n                                                        ),',
    'color: Color(\n                                                          0xFFB8A28F,\n                                                        ),',
    'catalog group accent',
)

# Add the compact metadata chip used by the selected-object card.
marker = 'class _PlanningPainter extends CustomPainter {'
chip = r'''class _EquipmentChip extends StatelessWidget {
  const _EquipmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3941)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9.5,
          color: Color(0xFFC7CFD2),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

'''
if marker not in screen:
    raise SystemExit('planning painter marker missing')
screen = screen.replace(marker, chip + marker, 1)
screen_path.write_text(screen)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+57', 'version: 1.5.6+58', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+58 — Оснащение по мастер-концепту

- Экран «Оснащение» приведён ближе к странице 4 мастер-концепта без изменения механики установки и перемещения объектов.
- Верхняя техническая карточка заменена компактным заголовком, переключателем «Каталог / Инженерия» и отдельной карточкой выбранной модели с крупным GLB-превью, размерами, категорией и типом крепления.
- Каталог раскрывается почти на весь экран; боковая колонка категорий стала уже, а карточки моделей — визуально шире и плотнее.
- План размещения объектов переведён на тёмный фон, существующие стены стали светлыми, а выбранный объект выделяется общим песочным акцентом приложения.
- Цвет новой мебели на плане согласован с тёплой палитрой мастер-концепта; демонтаж и зелёные направляющие привязки сохраняют отдельную семантику.
- Поиск, реальные GLB-превью, размеры, крепление к полу/стене/потолку, коллизии, перемещение и магнитный поворот 0/90/180/270° сохранены.

'''
if not changelog.startswith('## 1.5.6+58'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+58 equipment UI pass')
