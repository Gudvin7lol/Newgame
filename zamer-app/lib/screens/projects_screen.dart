import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import 'device_diagnostics_screen.dart';
import 'floors_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _store = ProjectStore();
  final _projects = <MeasureProject>[];
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _loading = true;
  bool _unreadable = false;
  bool _showAllProjects = false;
  String? _dataWarning;

  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final result = await _store.loadWithStatus();
    final loaded = <MeasureProject>[...result.projects];

    // Every build contains exactly one ready-made room for quick regression
    // testing on the phone. When the build changes, the previous demo is
    // replaced; real user projects are never touched.
    if (!result.unreadable) {
      var changed = false;
      final before = loaded.length;
      loaded.removeWhere(
        (project) =>
            project.id.startsWith(DemoProjectFactory.demoPrefix) &&
            project.id != DemoProjectFactory.projectId,
      );
      changed = loaded.length != before;
      if (!loaded.any((project) => project.id == DemoProjectFactory.projectId)) {
        loaded.insert(0, DemoProjectFactory.create());
        changed = true;
      }
      if (changed) {
        try {
          await _store.save(loaded);
        } catch (_) {
          // A demo project must never prevent access to real projects.
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _loading = false;
      _unreadable = result.unreadable;
      _dataWarning = result.unreadable
          ? 'Сохранение не читается. Импортируй ранее сохранённую копию проекта.'
          : result.recovered
          ? 'Проекты восстановлены из локальной резервной записи. Сохрани важные объекты в файл.'
          : null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcome());
  }

  Future<void> _showWelcome({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool('welcome_v10_seen') ?? false)) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.architecture_outlined, size: 42),
        title: const Text('Замер • 1.5.6'),
        content: const Text(
          'Обмер, планировка, 3D, оснащение, развёртки, инженерия и рабочая документация собраны в одном проекте.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    await prefs.setBool('welcome_v10_seen', true);
  }

  Future<void> _save() => _store.save(_projects);

  Future<void> _startFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Начать с пустого списка?'),
        content: const Text(
          'Повреждённое локальное сохранение будет заменено. Сначала попробуй импортировать копию из файла.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Начать заново'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _save();
      if (!mounted) return;
      setState(() {
        _unreadable = false;
        _dataWarning = null;
      });
    } catch (e) {
      _error(e);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is FormatException
              ? error.message
              : 'Не удалось выполнить операцию: $error',
        ),
      ),
    );
  }

  Future<void> _export(MeasureProject project) async {
    try {
      final bytes = await ProjectBackupService.encodePortable(project);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/zip')],
        fileNameOverrides: ['zamer-${project.id}.zip'],
        text: 'Полная копия проекта «${project.name}» с фотографиями',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _import() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
        allowMultiple: false,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      if (file.size > ProjectBackupService.maxPortableBytes) {
        throw const FormatException('Файл больше 100 МБ');
      }
      final bytes = await file.xFile.readAsBytes();
      final portable = file.name.toLowerCase().endsWith('.zip')
          ? ProjectBackupService.decodePortable(bytes)
          : null;
      final project = portable?.project ?? ProjectBackupService.decode(bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Восстановить проект?'),
          content: Text(
            '«${project.name}» • ${project.floors.length} этаж(а). Проект добавится отдельной копией.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final id = _id('p');
      final copy = portable == null
          ? ProjectBackupService.importAsCopy(project, id)
          : await portable.importAsCopy(
              id,
              await getApplicationDocumentsDirectory(),
            );
      _projects.insert(0, copy);
      try {
        await _save();
      } catch (_) {
        _projects.remove(copy);
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _unreadable = false;
        _dataWarning = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект восстановлен как отдельная копия')),
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<String?> _textDialog(
    String title,
    String label,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _create({String initialName = 'Квартира'}) async {
    final name = await _textDialog('Новый проект', 'Название', initialName);
    if (name == null || name.isEmpty) return;
    final floor = FloorPlan(id: _id('f'), name: 'Этаж 1');
    final project = MeasureProject(id: _id('p'), name: name, floors: [floor]);
    setState(() => _projects.insert(0, project));
    try {
      await _save();
    } catch (e) {
      setState(() => _projects.remove(project));
      _error(e);
      return;
    }
    if (!mounted) return;
    await _open(project);
  }

  Future<void> _open(MeasureProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorsScreen(project: project, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(MeasureProject project) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text(project.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final index = _projects.indexOf(project);
    setState(() => _projects.remove(project));
    try {
      await _save();
    } catch (e) {
      setState(() => _projects.insert(index, project));
      _error(e);
    }
  }

  Future<void> _openDiagnostics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceDiagnosticsScreen(projects: _projects),
      ),
    );
  }

  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Импорт проекта'),
                subtitle: const Text('ZIP или JSON резервной копии'),
                onTap: () {
                  Navigator.pop(context);
                  _import();
                },
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Проверка устройства'),
                subtitle: const Text('Диагностика 2D, 3D и файлов проекта'),
                onTap: () {
                  Navigator.pop(context);
                  _openDiagnostics();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('О приложении'),
                onTap: () {
                  Navigator.pop(context);
                  _showWelcome(force: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToProjects() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      math.min(360, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<MeasureProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    final projects = _projects.where((project) {
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.address.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (query.isNotEmpty || _showAllProjects || projects.length <= 3) {
      return projects;
    }
    return projects.take(3).toList();
  }

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Сегодня';
    if (difference == 1) return 'Вчера';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  int _roomCount(MeasureProject project) => project.floors.fold<int>(
    0,
    (sum, floor) => sum + floor.roomMetas.length,
  );

  int _wallCount(MeasureProject project) => project.floors.fold<int>(
    0,
    (sum, floor) => sum + floor.walls.length,
  );

  Widget _sectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: .1,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _projectCard(MeasureProject project) {
    final floor = project.floors.isEmpty ? null : project.floors.first;
    final rooms = _roomCount(project);
    final walls = _wallCount(project);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(project),
        child: SizedBox(
          height: 118,
          child: Row(
            children: [
              SizedBox(
                width: 122,
                height: double.infinity,
                child: CustomPaint(
                  painter: _ProjectPlanPreviewPainter(floor: floor),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9091014),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x553B4A52)),
                      ),
                      child: Text(
                        '${project.floors.length} эт.',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE8E1D9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 4, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
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
                      const SizedBox(height: 2),
                      Text(
                        project.address.trim().isEmpty
                            ? _dateLabel(project.createdAt)
                            : project.address.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF96A0A5),
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          _MetaChip(
                            icon: Icons.meeting_room_outlined,
                            label: '$rooms помещ.',
                          ),
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

  @override
  Widget build(BuildContext context) {
    final projects = _visibleProjects;
    final queryActive = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ЗАМЕР',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Проекты и быстрый доступ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF87949A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Настройки и сервис',
                        onPressed: _showMore,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Поиск проектов…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: queryActive
                          ? IconButton(
                              tooltip: 'Очистить поиск',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                    ),
                  ),
                  if (_dataWarning != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF3A2D25),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFF1C79E),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dataWarning!),
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
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          filled: true,
                          icon: Icons.add_box_outlined,
                          title: 'Новый проект',
                          subtitle: 'Начать с чистого плана',
                          onTap: _unreadable ? null : () => _create(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.file_download_outlined,
                          title: 'Импорт проекта',
                          subtitle: 'ZIP или JSON копия',
                          onTap: _import,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive || _projects.length <= 3
                        ? null
                        : TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllProjects = !_showAllProjects;
                              });
                            },
                            child: Text(_showAllProjects ? 'Свернуть' : 'Все'),
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (projects.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              queryActive
                                  ? Icons.search_off_rounded
                                  : Icons.home_work_outlined,
                              size: 38,
                              color: const Color(0xFF6F7B80),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              queryActive
                                  ? 'Ничего не найдено'
                                  : 'Пока нет проектов',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              queryActive
                                  ? 'Попробуй другое название или адрес.'
                                  : 'Создай первый проект или импортируй резервную копию.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A969C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...projects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _projectCard(project),
                      ),
                    ),
                  if (!queryActive) ...[
                    const SizedBox(height: 14),
                    _sectionTitle('Шаблоны'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 142,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _TemplateCard(
                            icon: Icons.apartment_outlined,
                            title: 'Квартира',
                            subtitle: 'Обмер и отделка',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Квартира'),
                          ),
                          _TemplateCard(
                            icon: Icons.cottage_outlined,
                            title: 'Дом',
                            subtitle: 'Этажи и инженерия',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Дом'),
                          ),
                          _TemplateCard(
                            icon: Icons.storefront_outlined,
                            title: 'Коммерция',
                            subtitle: 'Помещения и смета',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Коммерция'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Проекты',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_open_outlined),
            label: 'Импорт',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: 'Проверка',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Ещё',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              _scrollToProjects();
            case 2:
              _import();
            case 3:
              _openDiagnostics();
            case 4:
              _showMore();
          }
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final foreground = filled
        ? Theme.of(context).colorScheme.onPrimary
        : const Color(0xFFE9E5E0);
    return Material(
      color: filled ? accent : const Color(0xFF111A1F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: filled ? accent : const Color(0xFF2A3941),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled
                      ? const Color(0xB322170F)
                      : const Color(0xFF849197),
                  fontSize: 10.5,
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 148,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF253038), Color(0xFF12191D)],
                    ),
                  ),
                ),
                Positioned(
                  right: -10,
                  top: -12,
                  child: Icon(
                    icon,
                    size: 92,
                    color: const Color(0x18F1C79E),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF211A15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6B5645)),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: const Color(0xFFF1C79E),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF8B979C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1519),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF26343B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFB5BDC0)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFB5BDC0),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPlanPreviewPainter extends CustomPainter {
  const _ProjectPlanPreviewPainter({required this.floor});

  final FloorPlan? floor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF1B2226);
    canvas.drawRect(Offset.zero & size, background);

    final currentFloor = floor;
    if (currentFloor == null || currentFloor.nodes.length < 2) {
      final placeholder = Paint()
        ..color = const Color(0xFF3D474C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final rect = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        placeholder,
      );
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        placeholder,
      );
      return;
    }

    var minX = currentFloor.nodes.first.xMm;
    var maxX = minX;
    var minY = currentFloor.nodes.first.yMm;
    var maxY = minY;
    for (final node in currentFloor.nodes.skip(1)) {
      minX = math.min(minX, node.xMm);
      maxX = math.max(maxX, node.xMm);
      minY = math.min(minY, node.yMm);
      maxY = math.max(maxY, node.yMm);
    }

    final worldWidth = math.max(1.0, maxX - minX);
    final worldHeight = math.max(1.0, maxY - minY);
    const padding = 13.0;
    final scale = math.min(
      (size.width - padding * 2) / worldWidth,
      (size.height - padding * 2) / worldHeight,
    );
    final drawnWidth = worldWidth * scale;
    final drawnHeight = worldHeight * scale;
    final originX = (size.width - drawnWidth) / 2;
    final originY = (size.height - drawnHeight) / 2;

    Offset mapNode(PlanNode node) => Offset(
      originX + (node.xMm - minX) * scale,
      originY + (node.yMm - minY) * scale,
    );

    final grid = Paint()
      ..color = const Color(0xFF202B30)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final wall in currentFloor.walls) {
      final start = currentFloor.nodeById(wall.startNodeId);
      final end = currentFloor.nodeById(wall.endNodeId);
      if (start == null || end == null) continue;
      final color = wall.demolition || wall.projectLayer == ProjectLayer.demolition
          ? const Color(0xFFE66B61)
          : wall.projectLayer == ProjectLayer.proposed
          ? const Color(0xFFF1C79E)
          : const Color(0xFFDDE2E4);
      final paint = Paint()
        ..color = color
        ..strokeWidth = (wall.thicknessMm * scale).clamp(1.35, 4.2)
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(mapNode(start), mapNode(end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectPlanPreviewPainter oldDelegate) =>
      oldDelegate.floor != floor;
}
