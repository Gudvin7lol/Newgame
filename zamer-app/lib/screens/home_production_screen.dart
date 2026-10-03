import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/geometry_service.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import '../widgets/projects_home_widgets.dart';
import 'floor_workspace_screen.dart';
import 'floors_screen.dart';
import 'scan_plan_screen.dart';

/// Canonical Home page from the approved warm ZAMER master UI.
///
/// Reference order:
/// header -> search/filter -> create/import -> recent projects -> templates
/// -> bottom navigation.
class HomeProductionScreen extends StatefulWidget {
  const HomeProductionScreen({super.key});

  @override
  State<HomeProductionScreen> createState() => _HomeProductionScreenState();
}

class _HomeProductionScreenState extends State<HomeProductionScreen> {
  final ProjectStore _store = ProjectStore();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MeasureProject> _projects = <MeasureProject>[];

  bool _loading = true;
  bool _unreadable = false;
  String? _warning;
  int _sortMode = 0;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final result = await _store.loadWithStatus();
    final loaded = <MeasureProject>[...result.projects];
    if (!result.unreadable) {
      loaded.removeWhere(
        (project) =>
            project.id.startsWith(DemoProjectFactory.demoPrefix) &&
            project.id != DemoProjectFactory.projectId,
      );
      if (!loaded.any((project) => project.id == DemoProjectFactory.projectId)) {
        loaded.insert(0, DemoProjectFactory.create());
      }
      try {
        await _store.save(loaded);
      } catch (_) {
        // A demo refresh must never block real projects.
      }
    }
    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _loading = false;
      _unreadable = result.unreadable;
      _warning = result.unreadable
          ? 'Локальное сохранение повреждено. Восстанови резервную копию.'
          : result.recovered
              ? 'Проекты восстановлены из локальной резервной записи.'
              : null;
    });
  }

  Future<void> _save() => _store.save(_projects);

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось выполнить операцию: $error')),
    );
  }

  List<MeasureProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    final items = _projects.where((project) {
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.address.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query);
    }).toList();

    switch (_sortMode) {
      case 1:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 2:
        items.sort((a, b) => _areaM2(b).compareTo(_areaM2(a)));
      default:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return items;
  }

  MeasureProject? get _lastProject {
    final real = _projects
        .where((project) => project.id != DemoProjectFactory.projectId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (real.isNotEmpty) return real.first;
    return _projects.isEmpty ? null : _projects.first;
  }

  double _areaM2(MeasureProject project) {
    var total = 0.0;
    for (final floor in project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        total += face.areaM2;
      }
    }
    return total;
  }

  int _roomCount(MeasureProject project) {
    var total = 0;
    for (final floor in project.floors) {
      total += GeometryService.roomFaces(floor).length;
    }
    return total;
  }

  int _photoCount(MeasureProject project) {
    var total = 0;
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        total += room.photoPaths.length;
      }
    }
    return total;
  }

  String? _firstPhoto(MeasureProject project) {
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        for (final path in room.photoPaths) {
          if (path.trim().isNotEmpty && File(path).existsSync()) return path;
        }
      }
    }
    return null;
  }

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final delta = today.difference(date).inDays;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (delta == 0) return 'Сегодня, $time';
    if (delta == 1) return 'Вчера, $time';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<void> _openProject(MeasureProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorsScreen(project: project, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCatalog() async {
    final project = _lastProject;
    if (project == null || project.floors.isEmpty) {
      await _createProject(initialName: 'Квартира');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: project.floors.first,
          onChanged: _save,
          initialMode: 2,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<String?> _nameDialog(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый проект'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название проекта'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createProject({String initialName = 'Квартира'}) async {
    if (_unreadable) return;
    final name = await _nameDialog(initialName);
    if (name == null || name.isEmpty) return;
    final project = MeasureProject(
      id: _id('p'),
      name: name,
      floors: [FloorPlan(id: _id('f'), name: 'Этаж 1')],
    );
    setState(() => _projects.insert(0, project));
    try {
      await _save();
      if (mounted) await _openProject(project);
    } catch (error) {
      if (mounted) setState(() => _projects.remove(project));
      _error(error);
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
    } catch (error) {
      if (mounted) setState(() => _projects.remove(project));
      _error(error);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScanPlanScreen(floor: floor, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _importBackup() async {
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
      final decoded = portable?.project ?? ProjectBackupService.decode(bytes);
      final id = _id('p');
      final copy = portable == null
          ? ProjectBackupService.importAsCopy(decoded, id)
          : await portable.importAsCopy(
              id,
              await getApplicationDocumentsDirectory(),
            );
      setState(() => _projects.insert(0, copy));
      await _save();
      if (!mounted) return;
      setState(() {
        _unreadable = false;
        _warning = null;
      });
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _exportProject(MeasureProject project) async {
    try {
      final bytes = await ProjectBackupService.encodePortable(project);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/zip')],
        fileNameOverrides: ['zamer-${project.id}.zip'],
        text: 'Полная копия проекта «${project.name}» с фотографиями',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _deleteProject(MeasureProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('«${project.name}» будет удалён из списка проектов.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZamerColors.danger,
              foregroundColor: ZamerColors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final index = _projects.indexOf(project);
    setState(() => _projects.remove(project));
    try {
      await _save();
    } catch (error) {
      if (mounted) setState(() => _projects.insert(index, project));
      _error(error);
    }
  }

  Future<void> _projectMenu(MeasureProject project) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.folder_open_outlined,
                label: 'Открыть проект',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProject(project);
                },
              ),
              _SheetAction(
                icon: Icons.archive_outlined,
                label: 'Экспортировать ZIP',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _exportProject(project);
                },
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить проект',
                danger: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteProject(project);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilters() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: Text('Сортировка', style: ZamerTypography.h2),
              ),
              _SortRow(
                label: 'Сначала последние',
                selected: _sortMode == 0,
                onTap: () => Navigator.pop(sheetContext, 0),
              ),
              _SortRow(
                label: 'По названию',
                selected: _sortMode == 1,
                onTap: () => Navigator.pop(sheetContext, 1),
              ),
              _SortRow(
                label: 'По площади',
                selected: _sortMode == 2,
                onTap: () => Navigator.pop(sheetContext, 2),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sortMode = selected);
  }

  Future<void> _showLearning() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.architecture_outlined,
                label: 'Как сделать первый замер',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _SheetAction(
                icon: Icons.view_in_ar_outlined,
                label: 'Работа с 3D',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _SheetAction(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Документация и экспорт',
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.settings_backup_restore_rounded,
                label: 'Восстановить проект',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importBackup();
                },
              ),
              _SheetAction(
                icon: Icons.cloud_outlined,
                label: 'Облако и синхронизация',
                onTap: () => Navigator.pop(sheetContext),
              ),
              _SheetAction(
                icon: Icons.settings_outlined,
                label: 'Настройки',
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectCard(MeasureProject project) {
    final area = _areaM2(project);
    final rooms = _roomCount(project);
    final photos = _photoCount(project);
    final secondary = project.address.trim().isNotEmpty
        ? project.address.trim()
        : _dateLabel(project.createdAt);

    return SizedBox(
      height: ZamerSize.cardSmall,
      child: Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProject(project),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: ZamerColors.outline),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(ZamerRadius.md - 1),
                  ),
                  child: SizedBox(
                    width: 92,
                    height: double.infinity,
                    child: ZProjectThumbnail(
                      photoPath: _firstPhoto(project),
                      fallbackKind: project.name.length % 3,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                                style: ZamerTypography.bodySmall.copyWith(
                                  color: ZamerColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Действия проекта',
                                onPressed: () => _projectMenu(project),
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _Meta(
                              icon: Icons.square_foot_outlined,
                              label:
                                  '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                            ),
                            if (rooms > 0) ...[
                              const SizedBox(width: 12),
                              _Meta(
                                icon: Icons.meeting_room_outlined,
                                label: '$rooms ${_roomWord(rooms)}',
                              ),
                            ] else if (photos > 0) ...[
                              const SizedBox(width: 12),
                              _Meta(
                                icon: Icons.photo_library_outlined,
                                label: '$photos фото',
                              ),
                            ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queryActive = _searchController.text.trim().isNotEmpty;
    final recent = _visibleProjects.take(queryActive ? 20 : 4).toList();

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const ZLoadingState(title: 'Загружаем проекты')
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SizedBox(
                    height: ZamerSize.topBar,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('ЗАМЕР', style: ZamerTypography.h1),
                        ),
                        IconButton(
                          tooltip: 'Настройки',
                          onPressed: _showMore,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: ZamerTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Поиск проектов…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 21),
                      suffixIcon: IconButton(
                        tooltip: 'Фильтры и сортировка',
                        onPressed: _showFilters,
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _sortMode == 0
                              ? ZamerColors.textSecondary
                              : ZamerColors.accent,
                        ),
                      ),
                    ),
                  ),
                  if (_warning != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZamerColors.warning.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(ZamerRadius.md),
                        border: Border.all(
                          color: ZamerColors.warning.withValues(alpha: .55),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: ZamerColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _warning!,
                              style: ZamerTypography.caption.copyWith(
                                color: ZamerColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!queryActive) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _HomeAction(
                            selected: true,
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Новый проект',
                            onTap: _unreadable ? null : _createProject,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HomeAction(
                            icon: Icons.description_outlined,
                            label: 'Импорт плана',
                            onTap: _unreadable ? null : _importPlan,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive ? null : 'Все ›',
                    onTap: queryActive
                        ? null
                        : () {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                  ),
                  const SizedBox(height: 8),
                  if (recent.isEmpty)
                    ZEmptyState(
                      icon: queryActive
                          ? Icons.search_off_rounded
                          : Icons.home_work_outlined,
                      title: queryActive
                          ? 'Ничего не найдено'
                          : 'Проектов пока нет',
                      subtitle: queryActive
                          ? 'Попробуй другое название или адрес.'
                          : 'Создай новый проект или импортируй план.',
                      actionLabel: queryActive ? null : 'Создать проект',
                      onAction: queryActive ? null : _createProject,
                    )
                  else
                    ...recent.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _projectCard(project),
                      ),
                    ),
                  if (!queryActive) ...[
                    const SizedBox(height: 8),
                    _SectionHeader(
                      title: 'Шаблоны',
                      trailing: 'Все ›',
                      onTap: () => _createProject(initialName: 'Квартира'),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 104,
                      child: Row(
                        children: [
                          Expanded(
                            child: _Template(
                              kind: 0,
                              label: 'Квартира',
                              onTap: () =>
                                  _createProject(initialName: 'Квартира'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Template(
                              kind: 1,
                              label: 'Дом',
                              onTap: () => _createProject(initialName: 'Дом'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Template(
                              kind: 2,
                              label: 'Коммерция',
                              onTap: () =>
                                  _createProject(initialName: 'Коммерция'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: _ProductionBottomNav(
        onProjects: () {
          final project = _lastProject;
          if (project != null) _openProject(project);
        },
        onCatalog: _openCatalog,
        onLearning: _showLearning,
        onMore: _showMore,
      ),
    );
  }
}

String _roomWord(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'комнат';
  if (mod10 == 1) return 'комната';
  if (mod10 >= 2 && mod10 <= 4) return 'комнаты';
  return 'комнат';
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? ZamerColors.accentInk : ZamerColors.textPrimary;
    return Material(
      color: selected ? ZamerColors.accent : ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .42 : 1,
          child: Container(
            height: ZamerSize.cardSmall,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(
                color: selected ? ZamerColors.accent : ZamerColors.outline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.button.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: Text(title, style: ZamerTypography.h3)),
            if (trailing != null)
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  trailing!,
                  style: ZamerTypography.caption.copyWith(
                    color: ZamerColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ZamerColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: ZamerTypography.caption.copyWith(
              color: ZamerColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

class _Template extends StatelessWidget {
  const _Template({
    required this.kind,
    required this.label,
    required this.onTap,
  });

  final int kind;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ZProjectThumbnail(
                    photoPath: null,
                    fallbackKind: kind,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      label,
                      style: ZamerTypography.caption.copyWith(
                        color: ZamerColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProductionBottomNav extends StatelessWidget {
  const _ProductionBottomNav({
    required this.onProjects,
    required this.onCatalog,
    required this.onLearning,
    required this.onMore,
  });

  final VoidCallback onProjects;
  final VoidCallback onCatalog;
  final VoidCallback onLearning;
  final VoidCallback onMore;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, 'Главная'),
    (Icons.folder_outlined, 'Проекты'),
    (Icons.work_outline_rounded, 'Каталог'),
    (Icons.school_outlined, 'Обучение'),
    (Icons.apps_rounded, 'Ещё'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: ZamerSize.bottomNavigation,
          decoration: const BoxDecoration(
            color: ZamerColors.background,
            border: Border(
              top: BorderSide(color: ZamerColors.outlineSoft, width: 1),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _BottomItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: i == 0,
                    onTap: switch (i) {
                      0 => null,
                      1 => onProjects,
                      2 => onCatalog,
                      3 => onLearning,
                      _ => onMore,
                    },
                  ),
                ),
            ],
          ),
        ),
      );
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? ZamerColors.accent : ZamerColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.sm),
              border: selected
                  ? Border.all(color: ZamerColors.accent, width: 1)
                  : null,
              color: selected
                  ? ZamerColors.accent.withValues(alpha: .08)
                  : Colors.transparent,
            ),
            child: Icon(icon, size: 21, color: foreground),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              height: 1.15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: ZamerSize.input,
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger
                      ? ZamerColors.danger
                      : ZamerColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: ZamerTypography.body.copyWith(
                      color: danger
                          ? ZamerColors.danger
                          : ZamerColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? ZamerColors.accent.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: ZamerTypography.body)),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: ZamerColors.accent,
                    size: 20,
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
}
