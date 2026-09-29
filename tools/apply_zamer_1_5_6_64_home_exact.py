from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'
SCREEN = APP / 'lib/screens/projects_screen.dart'

pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+64' in pubspec:
    print('1.5.6+64 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+63' not in pubspec:
    raise SystemExit('unexpected version, refusing +64 patch')

text = SCREEN.read_text()
if "import 'scan_plan_screen.dart';" not in text:
    text = text.replace(
        "import 'floors_screen.dart';\n",
        "import 'floors_screen.dart';\nimport 'scan_plan_screen.dart';\n",
        1,
    )

insert_after = "  Future<void> _import() async {"
import_at = text.find(insert_after)
if import_at < 0:
    raise SystemExit('import method marker missing')
next_method = text.find("  Future<String?> _textDialog(", import_at)
if next_method < 0:
    raise SystemExit('text dialog marker missing')
if "Future<void> _importPlan()" not in text:
    method = r'''  Future<void> _importPlan() async {
    if (_unreadable) return;
    final floor = FloorPlan(id: _id('f'), name: 'Этаж 1');
    final project = MeasureProject(
      id: _id('p'),
      name: 'Новый проект',
      floors: [floor],
    );
    setState(() => _projects.insert(0, project));
    try {
      await _save();
    } catch (e) {
      setState(() => _projects.remove(project));
      _error(e);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPlanScreen(floor: floor, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }

'''
    text = text[:next_method] + method + text[next_method:]

project_card_start = text.find("  Widget _projectCard(MeasureProject project) {")
build_start = text.find("  @override\n  Widget build(BuildContext context) {", project_card_start)
if project_card_start < 0 or build_start < 0:
    raise SystemExit('project card/build markers missing')
project_card = r'''  Widget _projectCard(MeasureProject project) {
    final floor = project.floors.isEmpty ? null : project.floors.first;
    final rooms = _roomCount(project);
    final walls = _wallCount(project);
    return Material(
      color: const Color(0xFF11191E),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(project),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF26343B)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: double.infinity,
                child: CustomPaint(
                  painter: _ProjectPlanPreviewPainter(floor: floor),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 2, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                            onSelected: (value) {
                              if (value == 'export') _export(project);
                              if (value == 'delete') _delete(project);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'export',
                                child: Text('Полная копия с фото (ZIP)'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        project.address.trim().isEmpty
                            ? _dateLabel(project.createdAt)
                            : project.address.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF8F9A9F),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.meeting_room_outlined,
                            label: '$rooms пом.',
                          ),
                          const SizedBox(width: 6),
                          _MetaChip(
                            icon: Icons.linear_scale,
                            label: '$walls стен',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

'''
text = text[:project_card_start] + project_card + text[build_start:]

build_start = text.find("  @override\n  Widget build(BuildContext context) {")
helper_start = text.find("class _QuickActionCard extends StatelessWidget {", build_start)
if build_start < 0 or helper_start < 0:
    raise SystemExit('main build/helper markers missing')
new_build = r'''  @override
  Widget build(BuildContext context) {
    final projects = _visibleProjects;
    final queryActive = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF080D10),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ЗАМЕР',
                          style: TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.7,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Настройки',
                        onPressed: _showMore,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Поиск проектов…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: queryActive
                          ? IconButton(
                              tooltip: 'Очистить',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded, size: 19),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF131B20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: Color(0xFF28363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: Color(0xFF28363D)),
                      ),
                    ),
                  ),
                  if (_dataWarning != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF33271F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5B4332)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF1C79E)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_dataWarning!, style: const TextStyle(fontSize: 11)),
                                if (_unreadable)
                                  TextButton(
                                    onPressed: _startFresh,
                                    child: const Text('Начать заново'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          filled: true,
                          icon: Icons.add_circle_outline,
                          title: 'Новый проект',
                          onTap: _unreadable ? null : () => _create(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.upload_file_outlined,
                          title: 'Импорт плана',
                          onTap: _unreadable ? null : _importPlan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 21),
                  _sectionTitle(
                    queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive || _projects.length <= 3
                        ? null
                        : TextButton(
                            onPressed: () => setState(() => _showAllProjects = !_showAllProjects),
                            child: Text(_showAllProjects ? 'Свернуть' : 'Все ›'),
                          ),
                  ),
                  const SizedBox(height: 9),
                  if (projects.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11191E),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF26343B)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            queryActive ? Icons.search_off_rounded : Icons.home_work_outlined,
                            size: 34,
                            color: const Color(0xFF6F7B80),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            queryActive ? 'Ничего не найдено' : 'У вас пока нет проектов',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            queryActive
                                ? 'Попробуйте другое название или адрес.'
                                : 'Создайте новый проект или импортируйте план.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8A969C)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...projects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _projectCard(project),
                      ),
                    ),
                  if (!queryActive) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Шаблоны'),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 118,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _TemplateCard(
                            kind: 0,
                            title: 'Квартира',
                            onTap: _unreadable ? null : () => _create(initialName: 'Квартира'),
                          ),
                          _TemplateCard(
                            kind: 1,
                            title: 'Дом',
                            onTap: _unreadable ? null : () => _create(initialName: 'Дом'),
                          ),
                          _TemplateCard(
                            kind: 2,
                            title: 'Коммерция',
                            onTap: _unreadable ? null : () => _create(initialName: 'Коммерция'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: _HomeNavBar(
        onProjects: _scrollToProjects,
        onCatalog: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Каталог открывается внутри проекта в разделе «Оснащение».')),
        ),
        onLearn: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Раздел обучения будет подключён отдельным экраном.')),
        ),
        onMore: _showMore,
      ),
    );
  }
}

'''
text = text[:build_start] + new_build + text[helper_start:]

quick_start = text.find("class _QuickActionCard extends StatelessWidget {")
painter_start = text.find("class _ProjectPlanPreviewPainter extends CustomPainter {", quick_start)
if quick_start < 0 or painter_start < 0:
    raise SystemExit('helper class markers missing')
helpers = r'''class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? const Color(0xFF21170F) : const Color(0xFFE6E2DE);
    return Material(
      color: filled ? const Color(0xFFF1C79E) : const Color(0xFF121A1F),
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: filled ? const Color(0xFFF1C79E) : const Color(0xFF28363D),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.kind,
    required this.title,
    required this.onTap,
  });

  final int kind;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: SizedBox(
      width: 126,
      child: Material(
        color: const Color(0xFF11191E),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _TemplateScenePainter(kind: kind),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: const Color(0xFFB5BDC0)),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          color: Color(0xFFB5BDC0),
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _HomeNavBar extends StatelessWidget {
  const _HomeNavBar({
    required this.onProjects,
    required this.onCatalog,
    required this.onLearn,
    required this.onMore,
  });

  final VoidCallback onProjects;
  final VoidCallback onCatalog;
  final VoidCallback onLearn;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF0C1317),
        border: Border(top: BorderSide(color: Color(0xFF1E2A30))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: _HomeNavItem(icon: Icons.home_rounded, label: 'Главная', selected: true),
          ),
          Expanded(
            child: _HomeNavItem(icon: Icons.folder_outlined, label: 'Проекты', onTap: onProjects),
          ),
          Expanded(
            child: _HomeNavItem(icon: Icons.chair_outlined, label: 'Каталог', onTap: onCatalog),
          ),
          Expanded(
            child: _HomeNavItem(icon: Icons.school_outlined, label: 'Обучение', onTap: onLearn),
          ),
          Expanded(
            child: _HomeNavItem(icon: Icons.grid_view_rounded, label: 'Ещё', onTap: onMore),
          ),
        ],
      ),
    ),
  );
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 31,
          height: 28,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1C79E)),
                )
              : null,
          child: Icon(
            icon,
            size: 18,
            color: selected ? const Color(0xFFF1C79E) : const Color(0xFFAAB3B7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? const Color(0xFFF1C79E) : const Color(0xFFAAB3B7),
          ),
        ),
      ],
    ),
  );
}

class _TemplateScenePainter extends CustomPainter {
  const _TemplateScenePainter({required this.kind});
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5B5046), Color(0xFF24282A)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final floor = Paint()..color = const Color(0xFF8A6D52);
    final floorPath = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width, size.height * .48)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(floorPath, floor);

    final window = Paint()..color = const Color(0xFFCBD3D2);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .08, size.height * .12, size.width * .28, size.height * .30),
      window,
    );
    final frame = Paint()
      ..color = const Color(0xFF536066)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * .22, size.height * .12),
      Offset(size.width * .22, size.height * .42),
      frame,
    );

    final sofa = Paint()..color = kind == 2 ? const Color(0xFFB8A890) : const Color(0xFFD0C3B2);
    final sofaRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .36, size.height * .48, size.width * .48, size.height * .25),
      const Radius.circular(6),
    );
    canvas.drawRRect(sofaRect, sofa);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .39, size.height * .41, size.width * .42, size.height * .13),
      Paint()..color = const Color(0xFFB9AB99),
    );

    if (kind == 1) {
      final plant = Paint()..color = const Color(0xFF426A4A);
      canvas.drawCircle(Offset(size.width * .82, size.height * .31), 10, plant);
      canvas.drawRect(
        Rect.fromLTWH(size.width * .80, size.height * .38, 6, 18),
        Paint()..color = const Color(0xFF5C493A),
      );
    }
    if (kind == 2) {
      final desk = Paint()..color = const Color(0xFF40362F);
      canvas.drawRect(
        Rect.fromLTWH(size.width * .10, size.height * .66, size.width * .35, 7),
        desk,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemplateScenePainter oldDelegate) => oldDelegate.kind != kind;
}

'''
text = text[:quick_start] + helpers + text[painter_start:]
SCREEN.write_text(text)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+63', 'version: 1.5.6+64', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+64 — Главная строго по странице 1\n\n- Главный экран перестроен по странице 1 мастер-концепта: логотип/настройки, поиск, две быстрые карточки, недавние проекты, шаблоны и пятисекционная нижняя навигация.\n- Основное действие теперь корректно называется «Импорт плана» и открывает сценарий переноса изображения плана в новый проект; резервная ZIP/JSON-копия остаётся в сервисном меню.\n- Карточки недавних проектов стали компактнее и ближе к пропорциям макета, с визуальным превью плана слева и короткими метаданными.\n- Шаблоны «Квартира / Дом / Коммерция» получили визуальные мини-сцены вместо абстрактных градиентных плиток.\n- Нижняя навигация повторяет мастер-концепт: «Главная / Проекты / Каталог / Обучение / Ещё».\n- Недоступные пока глобальные разделы каталога и обучения не выдают себя за готовые самостоятельные экраны; приложение сообщает, где функция доступна сейчас.\n\n'''
if not changelog.startswith('## 1.5.6+64'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+64 exact home pass')
