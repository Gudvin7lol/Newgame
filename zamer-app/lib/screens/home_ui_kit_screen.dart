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
import 'floors_screen.dart';
import 'scan_plan_screen.dart';

/// Approved compact Home page from the master Zamer UI board.
///
/// The hierarchy intentionally mirrors the reference screen:
/// brand -> search -> two primary actions -> recent projects -> templates ->
/// master navigation. Extra project/cloud/backup actions live in sheets instead
/// of expanding the home page.
class HomeUiKitScreen extends StatefulWidget {
  const HomeUiKitScreen({super.key});

  @override
  State<HomeUiKitScreen> createState() => _HomeUiKitScreenState();
}

class _HomeUiKitScreenState extends State<HomeUiKitScreen> {
  final ProjectStore _store = ProjectStore();
  final List<MeasureProject> _projects = <MeasureProject>[];
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _unreadable = false;
  String? _warning;

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
        // Demo refresh must not prevent the user's real projects from opening.
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

  Future<void> _open(MeasureProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorsScreen(project: project, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<String?> _projectNameDialog(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый проект'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
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

  Future<void> _create({String initialName = 'Квартира'}) async {
    if (_unreadable) return;
    final name = await _projectNameDialog(initialName);
    if (name == null || name.isEmpty) return;
    final project = MeasureProject(
      id: _id('p'),
      name: name,
      floors: [FloorPlan(id: _id('f'), name: 'Этаж 1')],
    );
    setState(() => _projects.insert(0, project));
    try {
      await _save();
      if (!mounted) return;
      await _open(project);
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
      final project = portable?.project ?? ProjectBackupService.decode(bytes);
      final id = _id('p');
      final copy = portable == null
          ? ProjectBackupService.importAsCopy(project, id)
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
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _delete(MeasureProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text(project.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
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

  Future<void> _showProjectMenu(MeasureProject project) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: project.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.folder_open_outlined,
              title: 'Открыть',
              onTap: () {
                Navigator.pop(sheetContext);
                _open(project);
              },
            ),
            ZActionTile(
              icon: Icons.archive_outlined,
              title: 'Экспорт ZIP',
              onTap: () {
                Navigator.pop(sheetContext);
                _export(project);
              },
            ),
            ZActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Удалить',
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

  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Настройки',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZActionTile(
              icon: Icons.settings_backup_restore_rounded,
              title: 'Восстановить проект',
              subtitle: 'ZIP или JSON резервной копии',
              onTap: () {
                Navigator.pop(sheetContext);
                _importBackup();
              },
            ),
            ZActionTile(
              icon: Icons.cloud_outlined,
              title: 'Облако и синхронизация',
              subtitle: 'Подготовлено под следующий этап',
              onTap: () => Navigator.pop(sheetContext),
            ),
            ZActionTile(
              icon: Icons.info_outline,
              title: 'О приложении',
              subtitle: 'Замер 1.5.6',
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  List<MeasureProject> get _visibleProjects {
    final query = _searchController.text.trim().toLowerCase();
    final items = _projects.where((project) {
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.address.toLowerCase().contains(query) ||
          project.client.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  MeasureProject? get _lastProject {
    final real = _projects
        .where((project) => project.id != DemoProjectFactory.projectId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (real.isNotEmpty) return real.first;
    if (_projects.isEmpty) return null;
    return _projects.first;
  }

  double _area(MeasureProject project) {
    var value = 0.0;
    for (final floor in project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        value += face.areaM2;
      }
    }
    return value;
  }

  int _photoCount(MeasureProject project) {
    var value = 0;
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        value += room.photoPaths.length;
      }
    }
    return value;
  }

  String? _firstPhoto(MeasureProject project) {
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
    final days = today.difference(date).inDays;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (days == 0) return 'Сегодня, $time';
    if (days == 1) return 'Вчера, $time';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget _projectCard(MeasureProject project) {
    final area = _area(project);
    final photos = _photoCount(project);
    return Material(
      color: ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(project),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZamerRadius.sm),
            border: Border.all(color: ZamerColors.outlineSoft),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                height: double.infinity,
                child: ZProjectThumbnail(
                  photoPath: _firstPhoto(project),
                  fallbackKind: project.name.length % 3,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 2, 7),
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
                                color: ZamerColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Действия проекта',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 30,
                              height: 30,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => _showProjectMenu(project),
                            icon: const Icon(Icons.more_horiz_rounded, size: 17),
                          ),
                        ],
                      ),
                      Text(
                        _dateLabel(project.createdAt),
                        style: ZamerTypography.caption,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          ZMetaChip(
                            icon: Icons.square_foot_outlined,
                            label:
                                '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                          ),
                          const SizedBox(width: ZamerSpace.md),
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

  void _openLastProject() {
    final project = _lastProject;
    if (project == null) {
      _create();
    } else {
      _open(project);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = _visibleProjects;
    final queryActive = _searchController.text.trim().isNotEmpty;
    final recent = projects.take(queryActive ? projects.length : 4).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const ZLoadingState(title: 'Загружаем проекты')
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ЗАМЕР',
                          style: TextStyle(
                            color: ZamerColors.textPrimary,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
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
                        icon: const Icon(Icons.settings_outlined, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Поиск проектов…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: queryActive
                            ? IconButton(
                                tooltip: 'Очистить',
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded, size: 17),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (_warning != null) ...[
                    const SizedBox(height: 7),
                    ZCard(
                      padding: const EdgeInsets.all(9),
                      backgroundColor: ZamerColors.warning.withValues(alpha: .07),
                      borderColor: ZamerColors.warning.withValues(alpha: .30),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: ZamerColors.warning,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(_warning!, style: ZamerTypography.caption),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!queryActive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _HomeActionButton(
                            filled: true,
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Новый проект',
                            onTap: _unreadable ? null : () => _create(),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _HomeActionButton(
                            icon: Icons.upload_file_outlined,
                            label: 'Импорт плана',
                            onTap: _unreadable ? null : _importPlan,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ZSectionTitle(
                    queryActive ? 'Результаты поиска' : 'Недавние проекты',
                    trailing: queryActive
                        ? null
                        : TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              minimumSize: const Size(42, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Все ›'),
                          ),
                  ),
                  const SizedBox(height: 7),
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
                      onAction: queryActive ? null : () => _create(),
                    )
                  else
                    ...recent.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _projectCard(project),
                      ),
                    ),
                  if (!queryActive) ...[
                    const SizedBox(height: 5),
                    ZSectionTitle(
                      'Шаблоны',
                      trailing: TextButton(
                        onPressed: () => _create(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(42, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Все ›'),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 88,
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
        onProjects: _openLastProject,
        onCatalog: _openLastProject,
        onLearn: _openLastProject,
        onMore: _showMore,
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled
        ? ZamerColors.accentInk
        : ZamerColors.textPrimary;
    return Material(
      color: filled ? ZamerColors.accent : ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .42 : 1,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZamerRadius.sm),
              border: Border.all(
                color: filled ? ZamerColors.accent : ZamerColors.outline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
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
