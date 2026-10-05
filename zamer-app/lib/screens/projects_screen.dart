import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/geometry_service.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import '../widgets/projects_home_widgets.dart';
import 'device_diagnostics_screen.dart';
import 'floor_workspace_screen.dart';
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
          // Demo content must never block access to the user's projects.
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
    if (project.floors.isEmpty) {
      project.floors.add(FloorPlan(id: _id('f'), name: 'Этаж 1'));
      await _save();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: project.floors.first,
          onChanged: _save,
        ),
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

  Future<void> _showProjectActions(MeasureProject project) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: project.name,
        description: project.address.trim().isEmpty
            ? _dateLabel(project.createdAt)
            : project.address.trim(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.arrow_forward_rounded,
              title: 'Продолжить работу',
              subtitle: 'Открыть рабочее пространство',
              onTap: () {
                Navigator.pop(sheetContext);
                _open(project);
              },
            ),
            ZActionTile(
              icon: Icons.archive_outlined,
              title: 'Полная копия проекта',
              subtitle: 'ZIP с проектом и фотографиями',
              onTap: () {
                Navigator.pop(sheetContext);
                _export(project);
              },
            ),
            ZActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Удалить проект',
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(project);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateProjectPanel() async {
    if (_unreadable) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Создание проекта',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    );
  }

  Future<void> _showImportPlanPanel() async {
    if (_unreadable) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Импорт планов',
        description:
            'Выберите источник. Масштаб можно откалибровать автоматически или вручную на следующем шаге.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: ZamerSpace.sm,
              runSpacing: ZamerSpace.sm,
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
            const SizedBox(height: ZamerSpace.md),
            ZCard(
              padding: const EdgeInsets.all(ZamerSpace.md),
              backgroundColor: ZamerColors.surfaceHigh,
              child: const Row(
                children: [
                  Icon(
                    Icons.straighten_outlined,
                    size: 19,
                    color: ZamerColors.accent,
                  ),
                  SizedBox(width: ZamerSpace.sm),
                  Expanded(child: Text('Масштабирование')),
                  Text(
                    'Авто  /  Вручную',
                    style: TextStyle(
                      fontSize: 11,
                      color: ZamerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      onTap: () {
        Navigator.pop(sheetContext);
        _importPlan();
      },
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(
          horizontal: ZamerSpace.md,
          vertical: ZamerSpace.md,
        ),
        decoration: BoxDecoration(
          color: ZamerColors.surfaceHigh,
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          border: Border.all(color: ZamerColors.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: ZamerColors.accent),
            const SizedBox(height: ZamerSpace.xs),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => ZSheetFrame(
          title: 'Сортировка и фильтры',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: ZamerSpace.lg),
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
    );
  }

  Future<void> _showCloudPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Облачное хранилище',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    );
  }

  Widget _conceptAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => ZActionTile(icon: icon, title: title, onTap: onTap);

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
      builder: (context) => ZSheetFrame(
        title: 'Ещё',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.cloud_outlined,
              title: 'Облачное хранилище',
              subtitle: 'Синхронизация, резервная копия и доступ с устройств',
              onTap: () {
                Navigator.pop(context);
                _showCloudPanel();
              },
            ),
            ZActionTile(
              icon: Icons.file_open_outlined,
              title: 'Импорт проекта',
              subtitle: 'ZIP или JSON резервной копии',
              onTap: () {
                Navigator.pop(context);
                _import();
              },
            ),
            ZActionTile(
              icon: Icons.fact_check_outlined,
              title: 'Проверка устройства',
              subtitle: 'Диагностика 2D, 3D и файлов проекта',
              onTap: () {
                Navigator.pop(context);
                _openDiagnostics();
              },
            ),
            ZActionTile(
              icon: Icons.info_outline,
              title: 'О приложении',
              onTap: () {
                Navigator.pop(context);
                _showWelcome(force: true);
              },
            ),
          ],
        ),
      ),
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
      if (_projectTypeFilter == 'Дома') {
        return searchable.contains('дом') || searchable.contains('дач');
      }
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

  MeasureProject? get _activeProject {
    if (_projects.isEmpty) return null;
    final userProjects = _projects
        .where((project) => project.id != DemoProjectFactory.projectId)
        .toList();
    final candidates = userProjects.isEmpty ? [..._projects] : userProjects;
    candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidates.first;
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

  int _projectRoomCount(MeasureProject project) {
    var total = 0;
    for (final floor in project.floors) {
      total += GeometryService.roomFaces(floor).length;
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

  Widget _sectionTitle(String title, {Widget? trailing}) =>
      ZSectionTitle(title, trailing: trailing);

  Widget _projectCard(MeasureProject project) {
    final areaM2 = _projectAreaM2(project);
    final rooms = _projectRoomCount(project);
    final photos = _projectPhotoCount(project);
    final photoPath = _projectFirstPhoto(project);
    return Material(
      color: ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(project),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            border: Border.all(color: ZamerColors.outline),
            borderRadius: BorderRadius.circular(ZamerRadius.md),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: double.infinity,
                child: ZProjectThumbnail(
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
                          color: ZamerColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: ZamerSpace.sm,
                        runSpacing: 2,
                        children: [
                          ZMetaChip(
                            icon: Icons.square_foot_outlined,
                            label:
                                '${areaM2.toStringAsFixed(areaM2 >= 100 ? 0 : 1)} м²',
                          ),
                          ZMetaChip(
                            icon: Icons.meeting_room_outlined,
                            label: '$rooms пом.',
                          ),
                          ZMetaChip(
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
    final activeProject = queryActive ? null : _activeProject;
    final recentProjects = activeProject == null
        ? projects
        : projects.where((project) => project.id != activeProject.id).toList();

    void openWorkspaceFromHome() {
      final project = _activeProject;
      if (project == null) {
        _showCreateProjectPanel();
      } else {
        _open(project);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const ZLoadingState(
                title: 'Загружаем проекты',
                subtitle: 'Проверяем локальные данные и резервную запись',
              )
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 18),
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
                                color: ZamerColors.textPrimary,
                                fontSize: 25,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.35,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Обмер • проект • рабочая документация',
                              style: ZamerTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Настройки и данные',
                        onPressed: _showMore,
                        icon: const Icon(Icons.tune_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZamerSpace.md),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Проект, адрес или заказчик…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
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
                    ),
                  ),
                  if (_dataWarning != null) ...[
                    const SizedBox(height: ZamerSpace.sm),
                    ZCard(
                      backgroundColor: ZamerColors.warning.withValues(alpha: .08),
                      borderColor: ZamerColors.warning.withValues(alpha: .35),
                      padding: const EdgeInsets.all(11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: ZamerColors.warning,
                          ),
                          const SizedBox(width: ZamerSpace.sm),
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
                  if (!queryActive && activeProject != null) ...[
                    const SizedBox(height: ZamerSpace.lg),
                    _sectionTitle('Продолжить работу'),
                    const SizedBox(height: ZamerSpace.sm),
                    ZActiveProjectCard(
                      preview: ZProjectThumbnail(
                        photoPath: _projectFirstPhoto(activeProject),
                        fallbackKind: activeProject.name.length % 3,
                      ),
                      title: activeProject.name,
                      subtitle: activeProject.address.trim().isEmpty
                          ? _dateLabel(activeProject.createdAt)
                          : activeProject.address.trim(),
                      areaLabel:
                          '${_projectAreaM2(activeProject).toStringAsFixed(_projectAreaM2(activeProject) >= 100 ? 0 : 1)} м²',
                      roomsLabel: '${_projectRoomCount(activeProject)} помещений',
                      floorsLabel: '${activeProject.floors.length} этаж.',
                      onOpen: () => _open(activeProject),
                      onMore: () => _showProjectActions(activeProject),
                    ),
                  ],
                  if (!queryActive) ...[
                    const SizedBox(height: ZamerSpace.lg),
                    _sectionTitle('Быстрые действия'),
                    const SizedBox(height: ZamerSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ZHomeQuickActionCard(
                            filled: true,
                            icon: Icons.add_rounded,
                            title: 'Новый проект',
                            subtitle: 'Пустой или шаблон',
                            onTap: _unreadable ? null : _showCreateProjectPanel,
                          ),
                        ),
                        const SizedBox(width: ZamerSpace.sm),
                        Expanded(
                          child: ZHomeQuickActionCard(
                            icon: Icons.document_scanner_outlined,
                            title: 'Сканировать',
                            subtitle: 'Фото или план БТИ',
                            onTap: _unreadable ? null : _importPlan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZamerSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ZHomeQuickActionCard(
                            icon: Icons.upload_file_outlined,
                            title: 'Импорт плана',
                            subtitle: 'PDF, DWG или фото',
                            onTap: _unreadable ? null : _showImportPlanPanel,
                          ),
                        ),
                        const SizedBox(width: ZamerSpace.sm),
                        Expanded(
                          child: ZHomeQuickActionCard(
                            icon: Icons.settings_backup_restore_rounded,
                            title: 'Восстановить',
                            subtitle: 'ZIP или JSON копия',
                            onTap: _import,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: ZamerSpace.lg),
                  _sectionTitle(
                    queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive || _projects.length <= 4
                        ? null
                        : TextButton(
                            onPressed: () => setState(
                              () => _showAllProjects = !_showAllProjects,
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: Text(_showAllProjects ? 'Свернуть' : 'Все ›'),
                          ),
                  ),
                  const SizedBox(height: ZamerSpace.sm),
                  if (recentProjects.isEmpty)
                    ZEmptyState(
                      icon: queryActive
                          ? Icons.search_off_rounded
                          : Icons.history_rounded,
                      title: queryActive
                          ? 'Ничего не найдено'
                          : activeProject == null
                          ? 'У вас пока нет проектов'
                          : 'Других проектов пока нет',
                      subtitle: queryActive
                          ? 'Попробуйте другое название, адрес или заказчика.'
                          : activeProject == null
                          ? 'Создайте новый проект или импортируйте существующий.'
                          : 'Активный проект уже показан выше. Новые проекты появятся здесь.',
                      actionLabel: queryActive || _unreadable
                          ? null
                          : 'Создать проект',
                      onAction: queryActive || _unreadable
                          ? null
                          : _showCreateProjectPanel,
                    )
                  else
                    ...recentProjects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: ZamerSpace.sm),
                        child: _projectCard(project),
                      ),
                    ),
                  if (!queryActive) ...[
                    const SizedBox(height: ZamerSpace.md),
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
                    const SizedBox(height: ZamerSpace.sm),
                    SizedBox(
                      height: 102,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ZProjectTemplateCard(
                            kind: 0,
                            title: 'Квартира',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Квартира'),
                          ),
                          ZProjectTemplateCard(
                            kind: 1,
                            title: 'Дом',
                            onTap: _unreadable
                                ? null
                                : () => _create(initialName: 'Дом'),
                          ),
                          ZProjectTemplateCard(
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
      bottomNavigationBar: ZHomeNavBar(
        onProjects: openWorkspaceFromHome,
        onCatalog: openWorkspaceFromHome,
        onLearn: openWorkspaceFromHome,
        onMore: _showMore,
      ),
    );
  }
}
