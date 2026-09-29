import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/geometry_service.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import 'device_diagnostics_screen.dart';
import 'floors_screen.dart';
import 'scan_plan_screen.dart';

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
  String _projectTypeFilter = 'Все';
  String _projectSortMode = 'Дата';
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
      if (!loaded.any(
        (project) => project.id == DemoProjectFactory.projectId,
      )) {
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
        const SnackBar(
          content: Text('Проект восстановлен как отдельная копия'),
        ),
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _importPlan() async {
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

  Future<void> _showCreateProjectPanel() async {
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
                  _importSourceChip(
                    sheetContext,
                    Icons.picture_as_pdf_outlined,
                    'PDF',
                  ),
                  _importSourceChip(
                    sheetContext,
                    Icons.architecture_outlined,
                    'DWG',
                  ),
                  _importSourceChip(
                    sheetContext,
                    Icons.photo_camera_outlined,
                    'Фото',
                  ),
                  _importSourceChip(
                    sheetContext,
                    Icons.photo_library_outlined,
                    'Из галереи',
                  ),
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
                    Icon(
                      Icons.straighten_outlined,
                      size: 19,
                      color: Color(0xFFF1C79E),
                    ),
                    SizedBox(width: 9),
                    Expanded(child: Text('Масштабирование')),
                    Text(
                      'Авто  /  Вручную',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB9C1C4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _importSourceChip(
    BuildContext sheetContext,
    IconData icon,
    String label,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.pop(sheetContext);
        _importPlan();
      },
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141D22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF29363C)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF1C79E)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                const Text(
                  'Сортировка и фильтры',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['Все', 'Квартиры', 'Дома', 'Коммерция'].map((
                    value,
                  ) {
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
              const Text(
                'Облачное хранилище',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _conceptAction(
                icon: Icons.sync_rounded,
                title: 'Синхронизация',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _conceptAction(
                icon: Icons.cloud_upload_outlined,
                title: 'Резервная копия',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _conceptAction(
                icon: Icons.devices_outlined,
                title: 'Доступ с устройств',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _conceptAction(
                icon: Icons.person_add_alt_outlined,
                title: 'Пригласить',
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conceptAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF141D22),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: const Color(0xFFF1C79E)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
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
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('Облачное хранилище'),
                subtitle: const Text(
                  'Синхронизация, резервная копия и доступ с устройств',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCloudPanel();
                },
              ),
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
      math.min(360.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<MeasureProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    final projects = _projects.where((project) {
      final searchable = project.name.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          searchable.contains(query) ||
          project.address.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      if (_projectTypeFilter == 'Все') return true;
      if (_projectTypeFilter == 'Квартиры') return searchable.contains('кварт');
      if (_projectTypeFilter == 'Дома')
        return searchable.contains('дом') || searchable.contains('дач');
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
      projects.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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

  String? _projectFirstPhoto(MeasureProject project) {
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        for (final path in room.photoPaths) {
          if (path.trim().isNotEmpty) return path;
        }
      }
    }
    return null;
  }

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final difference = today.difference(date).inDays;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (difference == 0) return 'Сегодня, $time';
    if (difference == 1) return 'Вчера, $time';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  int _roomCount(MeasureProject project) =>
      project.floors.fold<int>(0, (sum, floor) => sum + floor.roomMetas.length);

  int _wallCount(MeasureProject project) =>
      project.floors.fold<int>(0, (sum, floor) => sum + floor.walls.length);

  Widget _sectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
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
    final areaM2 = _projectAreaM2(project);
    final photos = _projectPhotoCount(project);
    final photoPath = _projectFirstPhoto(project);
    return Material(
      color: const Color(0xFF11191E),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(project),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF26343B)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                height: double.infinity,
                child: _ProjectThumbnail(
                  photoPath: photoPath,
                  fallbackKind: project.name.length % 3,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 2, 7),
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
                                fontSize: 12.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
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
                          fontSize: 9.4,
                          color: Color(0xFF8F9A9F),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.square_foot_outlined,
                            label:
                                '${areaM2.toStringAsFixed(areaM2 >= 100 ? 0 : 1)} м²',
                          ),
                          const SizedBox(width: 6),
                          _MetaChip(
                            icon: Icons.photo_library_outlined,
                            label: '$photos фото',
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
      backgroundColor: const Color(0xFF080D10),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 14),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ЗАМЕР',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.25,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Настройки',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        onPressed: _showMore,
                        icon: const Icon(Icons.settings_outlined, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Поиск проектов…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: queryActive
                          ? IconButton(
                              tooltip: 'Очистить',
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : IconButton(
                              tooltip: 'Сортировка и фильтры',
                              onPressed: _showFiltersPanel,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                            ),
                      filled: true,
                      fillColor: const Color(0xFF131B20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF28363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
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
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFF1C79E),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dataWarning!,
                                  style: const TextStyle(fontSize: 11),
                                ),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          filled: true,
                          icon: Icons.add_circle_outline,
                          title: 'Новый проект',
                          onTap: _unreadable ? null : _showCreateProjectPanel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.upload_file_outlined,
                          title: 'Импорт плана',
                          onTap: _unreadable ? null : _showImportPlanPanel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle(
                    queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive || _projects.length <= 3
                        ? null
                        : TextButton(
                            onPressed: () => setState(
                              () => _showAllProjects = !_showAllProjects,
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text(
                              _showAllProjects ? 'Свернуть' : 'Все ›',
                            ),
                          ),
                  ),
                  const SizedBox(height: 9),
                  if (projects.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11191E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF26343B)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            queryActive
                                ? Icons.search_off_rounded
                                : Icons.home_work_outlined,
                            size: 34,
                            color: const Color(0xFF6F7B80),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            queryActive
                                ? 'Ничего не найдено'
                                : 'У вас пока нет проектов',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            queryActive
                                ? 'Попробуйте другое название или адрес.'
                                : 'Создайте новый проект или импортируйте план.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A969C),
                            ),
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
                    const SizedBox(height: 11),
                    _sectionTitle(
                      'Шаблоны',
                      trailing: TextButton(
                        onPressed: _showCreateProjectPanel,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Все ›'),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 98,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _TemplateCard(
                            kind: 0,
                            title: 'Квартира',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Квартира'),
                          ),
                          _TemplateCard(
                            kind: 1,
                            title: 'Дом',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Дом'),
                          ),
                          _TemplateCard(
                            kind: 2,
                            title: 'Коммерция',
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
      bottomNavigationBar: _HomeNavBar(
        onProjects: _scrollToProjects,
        onCatalog: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Каталог открывается внутри проекта в разделе «Оснащение».',
            ),
          ),
        ),
        onLearn: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Раздел обучения будет подключён отдельным экраном.'),
          ),
        ),
        onMore: _showMore,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
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
    final foreground = filled
        ? const Color(0xFF21170F)
        : const Color(0xFFE6E2DE);
    return Material(
      color: filled ? const Color(0xFFF1C79E) : const Color(0xFF121A1F),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: filled ? const Color(0xFFF1C79E) : const Color(0xFF28363D),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 19),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11.3,
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

class _ProjectThumbnail extends StatelessWidget {
  const _ProjectThumbnail({
    required this.photoPath,
    required this.fallbackKind,
  });

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
          errorBuilder: (_, __, ___) =>
              CustomPaint(painter: _TemplateScenePainter(kind: fallbackKind)),
        ),
      );
    }
    return CustomPaint(painter: _TemplateScenePainter(kind: fallbackKind));
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
      width: 108,
      child: Material(
        color: const Color(0xFF11191E),
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomPaint(painter: _TemplateScenePainter(kind: kind)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
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
          fontSize: 8.8,
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
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF0C1317),
        border: Border(top: BorderSide(color: Color(0xFF1E2A30))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: _HomeNavItem(
              icon: Icons.home_rounded,
              label: 'Главная',
              selected: true,
            ),
          ),
          Expanded(
            child: _HomeNavItem(
              icon: Icons.folder_outlined,
              label: 'Проекты',
              onTap: onProjects,
            ),
          ),
          Expanded(
            child: _HomeNavItem(
              icon: Icons.chair_outlined,
              label: 'Каталог',
              onTap: onCatalog,
            ),
          ),
          Expanded(
            child: _HomeNavItem(
              icon: Icons.school_outlined,
              label: 'Обучение',
              onTap: onLearn,
            ),
          ),
          Expanded(
            child: _HomeNavItem(
              icon: Icons.grid_view_rounded,
              label: 'Ещё',
              onTap: onMore,
            ),
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
          width: 29,
          height: 25,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1C79E)),
                )
              : null,
          child: Icon(
            icon,
            size: 17,
            color: selected ? const Color(0xFFF1C79E) : const Color(0xFFAAB3B7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.0,
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
        Rect.fromLTWH(
          size.width * .34,
          size.height * .55,
          size.width * .48,
          size.height * .08,
        ),
        Paint()..color = const Color(0xFF3D342E),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .38,
          size.height * .63,
          size.width * .04,
          size.height * .20,
        ),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .74,
          size.height * .63,
          size.width * .04,
          size.height * .20,
        ),
        Paint()..color = const Color(0xFF332B27),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .50,
            size.height * .68,
            size.width * .19,
            size.height * .18,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFB6AA9D),
      );
    } else {
      // Sofa with separate back and cushions.
      final sofaBody = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .36,
          size.height * .55,
          size.width * .49,
          size.height * .25,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(sofaBody, Paint()..color = const Color(0xFFD0C4B4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .39,
            size.height * .45,
            size.width * .43,
            size.height * .17,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFBEB1A1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .42,
            size.height * .53,
            size.width * .17,
            size.height * .12,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFE3D9CB),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .62,
            size.height * .52,
            size.width * .16,
            size.height * .12,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFAA9B8A),
      );

      // Coffee table.
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * .44,
          size.height * .76,
          size.width * .31,
          size.height * .10,
        ),
        Paint()..color = const Color(0xFF4A4038),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .58,
          size.height * .84,
          size.width * .025,
          size.height * .08,
        ),
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
      canvas.drawCircle(
        Offset(size.width * .84, size.height * .37),
        size.width * .07,
        leaf,
      );
      canvas.drawCircle(
        Offset(size.width * .91, size.height * .34),
        size.width * .06,
        leaf,
      );
      canvas.drawCircle(
        Offset(size.width * .88, size.height * .29),
        size.width * .06,
        leaf,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * .89, size.height * .73),
        Offset(size.width * .89, size.height * .37),
        Paint()
          ..color = const Color(0xFF4E433C)
          ..strokeWidth = 2,
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
      final color =
          wall.demolition || wall.projectLayer == ProjectLayer.demolition
          ? const Color(0xFFE66B61)
          : wall.projectLayer == ProjectLayer.proposed
          ? const Color(0xFFF1C79E)
          : const Color(0xFFDDE2E4);
      final paint = Paint()
        ..color = color
        ..strokeWidth = (wall.thicknessMm * scale).clamp(1.35, 4.2).toDouble()
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(mapNode(start), mapNode(end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectPlanPreviewPainter oldDelegate) =>
      oldDelegate.floor != floor;
}
