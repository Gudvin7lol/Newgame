import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../design_system/home_concept_assets.dart';
import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/geometry_service.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import 'floor_workspace_screen.dart';
import 'floors_screen.dart';
import 'scan_plan_screen.dart';

const _homeBackground = Color(0xFF050B10);
const _homeSurface = Color(0xFF0D171D);
const _homeSurfaceHigh = Color(0xFF111D23);
const _homeOutline = Color(0xFF26343B);
const _homeMuted = Color(0xFFB2BBC2);

TextStyle _display(TextStyle source) => source.copyWith(
      fontFamily: 'sans-serif-medium',
      letterSpacing: -.18,
    );

TextStyle _body(TextStyle source) => source.copyWith(
      fontFamily: 'sans-serif',
      letterSpacing: -.05,
    );

class HomeConceptScreen extends StatefulWidget {
  const HomeConceptScreen({super.key});

  @override
  State<HomeConceptScreen> createState() => _HomeConceptScreenState();
}

class _HomeConceptScreenState extends State<HomeConceptScreen> {
  final ProjectStore _store = ProjectStore();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _projectsKey = GlobalKey();
  final List<MeasureProject> _projects = <MeasureProject>[];

  bool _loading = true;
  bool _unreadable = false;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _loading = false;
      _unreadable = result.unreadable;
    });
  }

  Future<void> _save() => _store.save(_projects);

  MeasureProject? get _currentProject {
    final real = _projects
        .where((project) => project.id != DemoProjectFactory.projectId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (real.isNotEmpty) return real.first;
    return _projects.isEmpty ? null : _projects.first;
  }

  List<MeasureProject> get _recentProjects {
    final copy = [..._projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(3).toList();
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

  int _photoCount(MeasureProject project) {
    var total = 0;
    for (final floor in project.floors) {
      for (final room in floor.roomMetas) {
        total += room.photoPaths.length;
      }
    }
    return total;
  }

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(value.year, value.month, value.day);
    final days = a.difference(b).inDays;
    if (days == 0) return 'Сегодня, ${_timeLabel(value)}';
    if (days == 1) return 'Вчера, ${_timeLabel(value)}';
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

  Future<void> _openWorkspace(int mode) async {
    var project = _currentProject;
    if (project == null || project.floors.isEmpty) {
      await _createProject(initialName: 'Квартира');
      project = _currentProject;
    }
    if (!mounted || project == null || project.floors.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorWorkspaceScreen(
          project: project!,
          floor: project.floors.first,
          onChanged: _save,
          initialMode: mode,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<String?> _nameDialog(String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
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
    return value;
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
      _showError(error);
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
      _showError(error);
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
      if (picked == null) return;
      final file = picked.files.single;
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
      if (!mounted) return;
      setState(() {
        _projects.insert(0, copy);
        _unreadable = false;
      });
      await _save();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось выполнить операцию: $error')),
    );
  }

  Future<void> _showLearning() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _HomeSheet(
        children: [
          _SheetRow(
            icon: Icons.architecture_outlined,
            label: 'Первый замер',
            onTap: () => Navigator.pop(sheetContext),
          ),
          _SheetRow(
            icon: Icons.view_in_ar_outlined,
            label: 'Работа с 3D',
            onTap: () => Navigator.pop(sheetContext),
          ),
          _SheetRow(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Документация и экспорт',
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  }

  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _HomeSheet(
        children: [
          _SheetRow(
            icon: Icons.upload_file_outlined,
            label: 'Импорт плана',
            onTap: () {
              Navigator.pop(sheetContext);
              _importPlan();
            },
          ),
          _SheetRow(
            icon: Icons.settings_backup_restore_rounded,
            label: 'Восстановить проект',
            onTap: () {
              Navigator.pop(sheetContext);
              _importBackup();
            },
          ),
          _SheetRow(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  }

  void _scrollToProjects() {
    final context = _projectsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentProject;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _homeBackground,
        canvasColor: _homeBackground,
      ),
      child: Scaffold(
        backgroundColor: _homeBackground,
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const ZLoadingState(title: 'Загружаем проекты')
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _BrandHeader(onSettings: _showMore),
                    const SizedBox(height: 18),
                    if (current != null) ...[
                      _CurrentProjectCard(
                        project: current,
                        area: _areaM2(current),
                        photos: _photoCount(current),
                        onTap: () => _openProject(current),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _NewProjectButton(
                      onTap: _unreadable ? null : _createProject,
                    ),
                    const SizedBox(height: 14),
                    _WorkspaceShortcuts(
                      onMeasure: () => _openWorkspace(0),
                      on3d: () => _openWorkspace(1),
                      onEquipment: () => _openWorkspace(2),
                      onElevations: () => _openWorkspace(3),
                      onMore: _showMore,
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      key: _projectsKey,
                      title: 'МОИ ПРОЕКТЫ',
                      onAll: _scrollToProjects,
                    ),
                    const SizedBox(height: 10),
                    if (_recentProjects.isEmpty)
                      ZEmptyState(
                        icon: Icons.home_work_outlined,
                        title: 'Проектов пока нет',
                        subtitle: 'Создай новый проект, и он появится здесь.',
                        actionLabel: 'Создать проект',
                        onAction: _createProject,
                      )
                    else
                      ..._recentProjects.map(
                        (project) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProjectRow(
                            project: project,
                            area: _areaM2(project),
                            photos: _photoCount(project),
                            onTap: () => _openProject(project),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      title: 'ШАБЛОНЫ',
                      onAll: () => _createProject(initialName: 'Квартира'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TemplateCard(
                            title: 'Квартира',
                            onTap: () => _createProject(initialName: 'Квартира'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TemplateCard(
                            title: 'Дом',
                            onTap: () => _createProject(initialName: 'Дом'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TemplateCard(
                            title: 'Коммерция',
                            onTap: () =>
                                _createProject(initialName: 'Коммерция'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: _HomeBottomNav(
          onProjects: _scrollToProjects,
          onCatalog: () => _openWorkspace(2),
          onLearning: _showLearning,
          onMore: _showMore,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              HomeConceptAssets.logo,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ЗАМЕР',
                  style: _display(ZamerTypography.h1).copyWith(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ПРОФЕССИОНАЛЬНЫЙ ЗАМЕР\nДЛЯ РЕАЛЬНЫХ ПРОЕКТОВ',
                  style: _body(ZamerTypography.caption).copyWith(
                    color: _homeMuted,
                    height: 1.18,
                    letterSpacing: .25,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _homeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _homeOutline),
            ),
            child: IconButton(
              tooltip: 'Настройки',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      );
}

class _CurrentProjectCard extends StatelessWidget {
  const _CurrentProjectCard({
    required this.project,
    required this.area,
    required this.photos,
    required this.onTap,
  });

  final MeasureProject project;
  final double area;
  final int photos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeOutline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ТЕКУЩИЙ ПРОЕКТ',
                        style: _body(ZamerTypography.caption).copyWith(
                          color: _homeMuted,
                          letterSpacing: .35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _display(ZamerTypography.h3).copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: _homeMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _homeMuted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              project.address.trim().isEmpty
                                  ? 'Светлая, ${_safeTime(project.createdAt)}'
                                  : project.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _body(ZamerTypography.bodySmall).copyWith(
                                color: _homeMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _Metric(
                            icon: Icons.square_foot_outlined,
                            text: '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                          ),
                          _Metric(
                            icon: Icons.photo_library_outlined,
                            text: '$photos фото',
                          ),
                          const _Metric(
                            icon: Icons.description_outlined,
                            text: '3D',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 126,
                    height: 92,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          HomeConceptAssets.currentProject,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(7),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _homeBackground.withValues(alpha: .78),
                              shape: BoxShape.circle,
                              border: Border.all(color: _homeOutline),
                            ),
                            child: const Icon(Icons.chevron_right_rounded),
                          ),
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

String _safeTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _NewProjectButton extends StatelessWidget {
  const _NewProjectButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.beige,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _homeBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: ZamerColors.beige,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Новый проект',
                    style: _display(ZamerTypography.h4).copyWith(
                      color: _homeBackground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _homeBackground,
                  size: 26,
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      );
}

class _WorkspaceShortcuts extends StatelessWidget {
  const _WorkspaceShortcuts({
    required this.onMeasure,
    required this.on3d,
    required this.onEquipment,
    required this.onElevations,
    required this.onMore,
  });

  final VoidCallback onMeasure;
  final VoidCallback on3d;
  final VoidCallback onEquipment;
  final VoidCallback onElevations;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.straighten_outlined, 'Замер', onMeasure),
      (Icons.view_in_ar_outlined, '3D', on3d),
      (Icons.chair_alt_outlined, 'Оснащение', onEquipment),
      (Icons.view_carousel_outlined, 'Развёртки', onElevations),
      (Icons.apps_rounded, 'Ещё', onMore),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _Shortcut(
              icon: items[i].$1,
              label: items[i].$2,
              onTap: items[i].$3,
              selected: i == 0,
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? ZamerColors.beige : _homeOutline,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ZamerColors.beige.withValues(alpha: .10),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? ZamerColors.beige : ZamerColors.gray300,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: _body(ZamerTypography.caption).copyWith(
                      color: selected ? ZamerColors.beige : ZamerColors.gray300,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    super.key,
    required this.title,
    required this.onAll,
  });

  final String title;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: _display(ZamerTypography.h5).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: .3,
              ),
            ),
          ),
          TextButton(
            onPressed: onAll,
            style: TextButton.styleFrom(
              foregroundColor: ZamerColors.beige,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(48, 48),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Все'),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      );
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.area,
    required this.photos,
    required this.onTap,
  });

  final MeasureProject project;
  final double area;
  final int photos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _homeOutline),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13),
                  ),
                  child: Image.memory(
                    HomeConceptAssets.currentProject,
                    width: 114,
                    height: 86,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                                style: _display(ZamerTypography.h5).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: _homeMuted,
                            ),
                          ],
                        ),
                        Text(
                          _projectDate(project.createdAt),
                          style: _body(ZamerTypography.caption).copyWith(
                            color: _homeMuted,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _Metric(
                              icon: Icons.square_foot_outlined,
                              text:
                                  '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                            ),
                            const SizedBox(width: 16),
                            _Metric(
                              icon: Icons.photo_library_outlined,
                              text: '$photos фото',
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

String _projectDate(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final days = today.difference(date).inDays;
  if (days == 0) return 'Сегодня, ${_safeTime(value)}';
  if (days == 1) return 'Вчера, ${_safeTime(value)}';
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ZamerColors.gray300),
          const SizedBox(width: 5),
          Text(
            text,
            style: _body(ZamerTypography.caption).copyWith(
              color: ZamerColors.gray300,
            ),
          ),
        ],
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _homeOutline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.memory(
                    HomeConceptAssets.currentProject,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      title,
                      style: _body(ZamerTypography.caption).copyWith(
                        color: ZamerColors.white,
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

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.onProjects,
    required this.onCatalog,
    required this.onLearning,
    required this.onMore,
  });

  final VoidCallback onProjects;
  final VoidCallback onCatalog;
  final VoidCallback onLearning;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.home_rounded, 'Главная', null),
      (Icons.folder_outlined, 'Проекты', onProjects),
      (Icons.chat_bubble_outline_rounded, 'Каталог', onCatalog),
      (Icons.school_outlined, 'Обучение', onLearning),
      (Icons.apps_rounded, 'Ещё', onMore),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: _homeBackground,
          border: Border(top: BorderSide(color: _homeOutline)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: items[i].$3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? ZamerColors.beige.withValues(alpha: .10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: i == 0
                              ? Border.all(color: ZamerColors.beige)
                              : null,
                        ),
                        child: Icon(
                          items[i].$1,
                          color: i == 0
                              ? ZamerColors.beige
                              : ZamerColors.gray300,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(ZamerTypography.caption).copyWith(
                          color: i == 0
                              ? ZamerColors.beige
                              : ZamerColors.gray300,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSheet extends StatelessWidget {
  const _HomeSheet({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
      );
}
