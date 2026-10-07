from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'
SCREEN = APP / 'lib/screens/projects_screen.dart'

pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+65' in pubspec:
    print('1.5.6+65 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+64' not in pubspec:
    raise SystemExit('unexpected version, refusing +65 page-1 patch')

text = SCREEN.read_text()

# Page 1 master-concept data helpers.
if "import '../services/geometry_service.dart';" not in text:
    text = text.replace(
        "import '../services/demo_project_factory.dart';\n",
        "import '../services/demo_project_factory.dart';\nimport '../services/geometry_service.dart';\n",
        1,
    )

old_fields = """  bool _loading = true;\n  bool _unreadable = false;\n  bool _showAllProjects = false;\n  String? _dataWarning;\n"""
new_fields = """  bool _loading = true;\n  bool _unreadable = false;\n  bool _showAllProjects = false;\n  String _projectTypeFilter = 'Все';\n  String _projectSortMode = 'Дата';\n  String? _dataWarning;\n"""
if old_fields in text:
    text = text.replace(old_fields, new_fields, 1)
elif "String _projectTypeFilter = 'Все';" not in text:
    raise SystemExit('state fields marker missing')

# Insert the supporting Page 1 panels from the master concept.
marker = "  Future<void> _openDiagnostics() async {"
insert_at = text.find(marker)
if insert_at < 0:
    raise SystemExit('diagnostics marker missing')
if 'Future<void> _showCreateProjectPanel()' not in text:
    methods = r'''  Future<void> _showCreateProjectPanel() async {
    if (_unreadable) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F161A),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Создание проекта',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _conceptAction(
                icon: Icons.note_add_outlined,
                title: 'Пустой проект',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _create(initialName: 'Квартира');
                },
              ),
              _conceptAction(
                icon: Icons.dashboard_customize_outlined,
                title: 'Из шаблона',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _create(initialName: 'Квартира');
                },
              ),
              _conceptAction(
                icon: Icons.upload_file_outlined,
                title: 'Импорт плана',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showImportPlanPanel();
                },
              ),
              _conceptAction(
                icon: Icons.document_scanner_outlined,
                title: 'Сканировать',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importPlan();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImportPlanPanel() async {
    if (_unreadable) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F161A),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Импорт планов',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Выберите источник. Масштаб можно откалибровать автоматически или вручную на следующем шаге.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF8F9A9F)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _importSourceChip(sheetContext, Icons.picture_as_pdf_outlined, 'PDF'),
                  _importSourceChip(sheetContext, Icons.architecture_outlined, 'DWG'),
                  _importSourceChip(sheetContext, Icons.photo_camera_outlined, 'Фото'),
                  _importSourceChip(sheetContext, Icons.photo_library_outlined, 'Из галереи'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141D22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF29363C)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.straighten_outlined, size: 19, color: Color(0xFFF1C79E)),
                    SizedBox(width: 9),
                    Expanded(child: Text('Масштабирование')),
                    Text('Авто  /  Вручную', style: TextStyle(fontSize: 11, color: Color(0xFFB9C1C4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _importSourceChip(BuildContext sheetContext, IconData icon, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () {
        Navigator.pop(sheetContext);
        _importPlan();
      },
      child: Container(
        width: 126,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141D22),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFF29363C)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF1C79E)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _showFiltersPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F161A),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Сортировка и фильтры', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['Все', 'Квартиры', 'Дома', 'Коммерция'].map((value) {
                    final selected = _projectTypeFilter == value;
                    return ChoiceChip(
                      label: Text(value),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _projectTypeFilter = value);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['Дата', 'Площадь', 'А-Я'].map((value) {
                    final selected = _projectSortMode == value;
                    return ChoiceChip(
                      label: Text(value),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _projectSortMode = value);
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCloudPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F161A),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Облачное хранилище', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _conceptAction(icon: Icons.sync_rounded, title: 'Синхронизация', onTap: () => Navigator.pop(sheetContext)),
              _conceptAction(icon: Icons.cloud_upload_outlined, title: 'Резервная копия', onTap: () => Navigator.pop(sheetContext)),
              _conceptAction(icon: Icons.devices_outlined, title: 'Доступ с устройств', onTap: () => Navigator.pop(sheetContext)),
              _conceptAction(icon: Icons.person_add_alt_outlined, title: 'Пригласить', onTap: () => Navigator.pop(sheetContext)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conceptAction({required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF141D22),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: const Color(0xFFF1C79E)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }

'''
    text = text[:insert_at] + methods + text[insert_at:]

# More menu: page-1 cloud entry is part of the concept, not a later page.
old_more_anchor = """            children: [\n              ListTile(\n                leading: const Icon(Icons.file_open_outlined),\n"""
new_more_anchor = """            children: [\n              ListTile(\n                leading: const Icon(Icons.cloud_outlined),\n                title: const Text('Облачное хранилище'),\n                subtitle: const Text('Синхронизация, резервная копия и доступ с устройств'),\n                onTap: () {\n                  Navigator.pop(context);\n                  _showCloudPanel();\n                },\n              ),\n              ListTile(\n                leading: const Icon(Icons.file_open_outlined),\n"""
if old_more_anchor in text:
    text = text.replace(old_more_anchor, new_more_anchor, 1)
elif "title: const Text('Облачное хранилище')" not in text:
    raise SystemExit('more menu marker missing')

# Functional sorting/filtering from the supporting panel.
getter_start = text.find("  List<MeasureProject> get _visibleProjects {")
date_start = text.find("  String _dateLabel(DateTime value) {", getter_start)
if getter_start < 0 or date_start < 0:
    raise SystemExit('visible projects getter marker missing')
new_getter = r'''  List<MeasureProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    final projects = _projects.where((project) {
      final searchable = project.name.toLowerCase();
      final matchesQuery = query.isEmpty ||
          searchable.contains(query) ||
          project.address.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      if (_projectTypeFilter == 'Все') return true;
      if (_projectTypeFilter == 'Квартиры') return searchable.contains('кварт');
      if (_projectTypeFilter == 'Дома') return searchable.contains('дом') || searchable.contains('дач');
      if (_projectTypeFilter == 'Коммерция') {
        return searchable.contains('офис') ||
            searchable.contains('коммер') ||
            searchable.contains('магаз') ||
            searchable.contains('кафе');
      }
      return true;
    }).toList();

    if (_projectSortMode == 'Площадь') {
      projects.sort((a, b) => _projectAreaM2(b).compareTo(_projectAreaM2(a)));
    } else if (_projectSortMode == 'А-Я') {
      projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    if (query.isNotEmpty || _showAllProjects || projects.length <= 4) {
      return projects;
    }
    return projects.take(4).toList();
  }

  double _projectAreaM2(MeasureProject project) {
    var total = 0.0;
    for (final floor in project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        total += face.areaM2;
      }
    }
    return total;
  }

  int _projectPhotoCount(MeasureProject project) {
    var total = 0;
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        total += room.photoPaths.length;
      }
    }
    return total;
  }

'''
text = text[:getter_start] + new_getter + text[date_start:]

# Project cards in the concept show area + photo count, not room/wall internals.
text = text.replace(
    """    final rooms = _roomCount(project);\n    final walls = _wallCount(project);\n""",
    """    final areaM2 = _projectAreaM2(project);\n    final photos = _projectPhotoCount(project);\n""",
    1,
)
text = text.replace(
    """                          _MetaChip(\n                            icon: Icons.meeting_room_outlined,\n                            label: '$rooms пом.',\n                          ),\n                          const SizedBox(width: 6),\n                          _MetaChip(\n                            icon: Icons.linear_scale,\n                            label: '$walls стен',\n                          ),\n""",
    """                          _MetaChip(\n                            icon: Icons.square_foot_outlined,\n                            label: '${areaM2.toStringAsFixed(areaM2 >= 100 ? 0 : 1)} м²',\n                          ),\n                          const SizedBox(width: 6),\n                          _MetaChip(\n                            icon: Icons.photo_library_outlined,\n                            label: '$photos фото',\n                          ),\n""",
    1,
)

# Search bar exposes the exact filter/sort panel from page 1.
old_suffix = r'''                      suffixIcon: queryActive
                          ? IconButton(
                              tooltip: 'Очистить',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded, size: 19),
                            )
                          : null,
'''
new_suffix = r'''                      suffixIcon: queryActive
                          ? IconButton(
                              tooltip: 'Очистить',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded, size: 19),
                            )
                          : IconButton(
                              tooltip: 'Сортировка и фильтры',
                              onPressed: _showFiltersPanel,
                              icon: const Icon(Icons.tune_rounded, size: 19),
                            ),
'''
if old_suffix in text:
    text = text.replace(old_suffix, new_suffix, 1)
elif "tooltip: 'Сортировка и фильтры'" not in text:
    raise SystemExit('search suffix marker missing')

text = text.replace(
    "onTap: _unreadable ? null : () => _create(),",
    "onTap: _unreadable ? null : _showCreateProjectPanel,",
    1,
)
text = text.replace(
    "onTap: _unreadable ? null : _importPlan,",
    "onTap: _unreadable ? null : _showImportPlanPanel,",
    1,
)

# Templates section has its own 'Все' link in the master concept.
text = text.replace(
    """                    _sectionTitle('Шаблоны'),\n""",
    """                    _sectionTitle(\n                      'Шаблоны',\n                      trailing: TextButton(\n                        onPressed: _showCreateProjectPanel,\n                        child: const Text('Все ›'),\n                      ),\n                    ),\n""",
    1,
)

# Bump build and record what Page 1 now contains.
pubspec = pubspec.replace('version: 1.5.6+64', 'version: 1.5.6+65', 1)
pubspec_path.write_text(pubspec)

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+65 — Главная: полный мастер-концепт страницы 1\n\n- Завершены все состояния страницы 1 мастер-концепта, а не только центральный экран.\n- «Новый проект» открывает панель «Создание проекта»: пустой проект, шаблон, импорт плана, сканирование.\n- «Импорт плана» получил панель источников PDF / DWG / Фото / Галерея и блок масштабирования Авто / Вручную.\n- Добавлена панель «Сортировка и фильтры»: Все / Квартиры / Дома / Коммерция и Дата / Площадь / А-Я.\n- Карточки недавних проектов показывают площадь и количество фото, как в мастер-концепте.\n- Добавлена панель «Облачное хранилище»: синхронизация, резервная копия, доступ с устройств, приглашение.\n- У секции «Шаблоны» добавлена ссылка «Все», ведущая к сценарию создания проекта.\n\n'''
if not changelog.startswith('## 1.5.6+65'):
    changelog_path.write_text(entry + changelog)

SCREEN.write_text(text)
print('Applied 1.5.6+65 page-1 master-concept completion')
