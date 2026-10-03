import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/home_concept_assets.dart';
import '../design_system/zamer_components.dart';
import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/geometry_service.dart';
import '../services/project_backup_service.dart';
import '../services/project_store.dart';
import '../services/report_service.dart';
import 'floor_workspace_screen.dart';
import 'master_profile_screen.dart';
import 'projects_screen.dart';
import 'scan_plan_screen.dart';

const _bg = Color(0xFF050B10);
const _surface = Color(0xFF0D171D);
const _outline = Color(0xFF26343B);
const _muted = Color(0xFF9EA8AE);
const _lastOpenedProjectKey = 'zamer.last_opened_project_id';
const _rememberLastProjectKey = 'zamer.home.remember_last_project';
const _showDemoProjectKey = 'zamer.home.show_demo_project';

enum _ProjectFilter { all, work, demo }

/// Production Home aligned with the field workflow.
///
/// A project opens directly into Measure. Floors are managed inside Measure,
/// while Equipment is a Measure layer rather than a top-level destination.
class ProductionHomeScreen extends StatefulWidget {
  const ProductionHomeScreen({super.key});

  @override
  State<ProductionHomeScreen> createState() => _ProductionHomeScreenState();
}

class _ProductionHomeScreenState extends State<ProductionHomeScreen> {
  final ProjectStore _store = ProjectStore();
  final TextEditingController _search = TextEditingController();
  final List<MeasureProject> _projects = <MeasureProject>[];

  bool _loading = true;
  bool _unreadable = false;
  bool _rememberLastProject = true;
  bool _showDemoProject = true;
  String? _lastOpenedProjectId;
  _ProjectFilter _filter = _ProjectFilter.all;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final result = await _store.loadWithStatus();
    final loaded = <MeasureProject>[...result.projects];
    final remember = preferences.getBool(_rememberLastProjectKey) ?? true;
    final showDemo = preferences.getBool(_showDemoProjectKey) ?? true;

    if (!result.unreadable) {
      loaded.removeWhere(
        (project) => project.id.startsWith(DemoProjectFactory.demoPrefix),
      );
      if (showDemo) loaded.insert(0, DemoProjectFactory.create());
      try {
        await _store.save(loaded);
      } catch (_) {
        // Demo refresh must never block local projects.
      }
    }

    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _rememberLastProject = remember;
      _showDemoProject = showDemo;
      _lastOpenedProjectId = remember
          ? preferences.getString(_lastOpenedProjectKey)
          : null;
      _unreadable = result.unreadable;
      _loading = false;
    });
  }

  Future<void> _save() => _store.save(_projects);

  Future<void> _rememberOpened(MeasureProject project) async {
    _lastOpenedProjectId = project.id;
    if (mounted) setState(() {});
    if (!_rememberLastProject) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastOpenedProjectKey, project.id);
  }

  MeasureProject? get _currentProject {
    final remembered = _rememberLastProject ? _lastOpenedProjectId : null;
    if (remembered != null) {
      for (final project in _projects) {
        if (project.id == remembered) return project;
      }
    }
    final work = _projects
        .where((p) => !p.id.startsWith(DemoProjectFactory.demoPrefix))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (work.isNotEmpty) return work.first;
    return _projects.isEmpty ? null : _projects.first;
  }

  List<MeasureProject> get _visibleProjects {
    final query = _search.text.trim().toLowerCase();
    final result = _projects.where((project) {
      final demo = project.id.startsWith(DemoProjectFactory.demoPrefix);
      if (_filter == _ProjectFilter.work && demo) return false;
      if (_filter == _ProjectFilter.demo && !demo) return false;
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.address.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  double _area(MeasureProject project) {
    var total = 0.0;
    for (final floor in project.floors) {
      for (final room in GeometryService.roomFaces(floor)) {
        total += room.areaM2;
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

  Future<void> _openProject(
    MeasureProject project, {
    int mode = 0,
  }) async {
    if (project.floors.isEmpty) {
      project.floors.add(FloorPlan(id: _id('f'), name: 'Этаж 1'));
      await _save();
    }
    await _rememberOpened(project);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: project.floors.first,
          onChanged: _save,
          initialMode: mode.clamp(0, 2),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openWorkspace(int mode) async {
    var project = _currentProject;
    if (project == null) {
      project = await _createProject(openAfterCreate: false);
    }
    if (project == null || !mounted) return;
    await _openProject(project, mode: mode);
  }

  Future<String?> _nameDialog({
    required String title,
    required String initial,
    String action = 'Сохранить',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<MeasureProject?> _createProject({
    String initialName = 'Квартира',
    bool openAfterCreate = true,
  }) async {
    if (_unreadable) {
      _message('Сначала восстановите повреждённое хранилище проектов.');
      return null;
    }
    final name = await _nameDialog(
      title: 'Новый проект',
      initial: initialName,
      action: 'Создать',
    );
    if (name == null || name.isEmpty) return null;
    final project = MeasureProject(
      id: _id('p'),
      name: name,
      floors: [FloorPlan(id: _id('f'), name: 'Этаж 1')],
    );
    setState(() => _projects.insert(0, project));
    try {
      await _save();
      await _rememberOpened(project);
      if (openAfterCreate && mounted) await _openProject(project);
      return project;
    } catch (error) {
      if (mounted) setState(() => _projects.remove(project));
      _error(error);
      return null;
    }
  }

  Future<void> _createAndScan() async {
    final project = await _createProject(
      initialName: 'Новый замер',
      openAfterCreate: false,
    );
    if (project == null || !mounted) return;
    final floor = project.floors.first;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScanPlanScreen(floor: floor, onChanged: _save),
      ),
    );
    if (mounted) await _openProject(project);
  }

  Future<void> _importPlan() async {
    final project = await _createProject(
      initialName: 'Импорт плана',
      openAfterCreate: false,
    );
    if (project == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScanPlanScreen(
          floor: project!.floors.first,
          onChanged: _save,
        ),
      ),
    );
    if (mounted) await _openProject(project);
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
      final copy = portable == null
          ? ProjectBackupService.importAsCopy(decoded, _id('p'))
          : await portable.importAsCopy(
              _id('p'),
              await getApplicationDocumentsDirectory(),
            );
      if (!mounted) return;
      setState(() {
        _projects.insert(0, copy);
        _unreadable = false;
      });
      await _save();
      await _rememberOpened(copy);
      _message('Проект восстановлен.');
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _rename(MeasureProject project) async {
    if (project.id.startsWith(DemoProjectFactory.demoPrefix)) {
      _message('Демо-проект нельзя переименовать.');
      return;
    }
    final next = await _nameDialog(
      title: 'Переименовать проект',
      initial: project.name,
    );
    if (next == null || next.isEmpty || next == project.name) return;
    final previous = project.name;
    setState(() => project.name = next);
    try {
      await _save();
    } catch (error) {
      if (mounted) setState(() => project.name = previous);
      _error(error);
    }
  }

  Future<void> _duplicate(MeasureProject project) async {
    final copy = ProjectBackupService.importAsCopy(project, _id('p'));
    setState(() => _projects.insert(0, copy));
    try {
      await _save();
      await _rememberOpened(copy);
      _message('Создана копия проекта.');
    } catch (error) {
      if (mounted) setState(() => _projects.remove(copy));
      _error(error);
    }
  }

  Future<void> _delete(MeasureProject project) async {
    if (project.id.startsWith(DemoProjectFactory.demoPrefix)) {
      _message('Демо-проект можно скрыть в настройках Главной.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('«${project.name}» будет удалён с устройства.'),
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
      if (_lastOpenedProjectId == project.id) {
        _lastOpenedProjectId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lastOpenedProjectKey);
      }
    } catch (error) {
      if (mounted) setState(() => _projects.insert(index, project));
      _error(error);
    }
  }

  Future<void> _sharePdf(MeasureProject project) async {
    if (project.floors.isEmpty) return;
    try {
      await ReportService.shareFloorPdf(project, project.floors.first);
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _projectMenu(MeasureProject project) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.edit_outlined,
                label: 'Переименовать',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _rename(project);
                },
              ),
              _SheetAction(
                icon: Icons.copy_all_outlined,
                label: 'Создать копию',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _duplicate(project);
                },
              ),
              _SheetAction(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF проекта',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _sharePdf(project);
                },
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Удалить',
                destructive: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _delete(project);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _filters() async {
    final value = await showModalBottomSheet<_ProjectFilter>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Фильтр проектов', style: ZamerTypography.h3),
              const SizedBox(height: 8),
              for (final item in _ProjectFilter.values)
                RadioListTile<_ProjectFilter>(
                  value: item,
                  groupValue: _filter,
                  title: Text(switch (item) {
                    _ProjectFilter.all => 'Все проекты',
                    _ProjectFilter.work => 'Только рабочие',
                    _ProjectFilter.demo => 'Только демо',
                  }),
                  onChanged: (next) => Navigator.pop(sheetContext, next),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _filter = value);
  }

  Future<void> _openProfile() async {
    final project = _currentProject;
    if (project == null) {
      _message('Сначала создайте проект.');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (profileContext) => MasterProfileScreen(
          project: project,
          projectCount: _projects.length,
          onHome: () => Navigator.pop(profileContext),
          onOpenMeasure: () {
            Navigator.pop(profileContext);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openProject(project, mode: 0),
            );
          },
          onOpen3D: () {
            Navigator.pop(profileContext);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openProject(project, mode: 1),
            );
          },
          onOpenElevations: () {
            Navigator.pop(profileContext);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openProject(project, mode: 2),
            );
          },
        ),
      ),
    );
  }

  Future<void> _settings() async {
    var remember = _rememberLastProject;
    var demo = _showDemoProject;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Запоминать последний проект'),
                  value: remember,
                  onChanged: (value) async {
                    setSheet(() => remember = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_rememberLastProjectKey, value);
                    if (!value) await prefs.remove(_lastOpenedProjectKey);
                    if (mounted) {
                      setState(() => _rememberLastProject = value);
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Показывать демо-проект'),
                  value: demo,
                  onChanged: (value) async {
                    setSheet(() => demo = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_showDemoProjectKey, value);
                    if (!mounted) return;
                    setState(() {
                      _showDemoProject = value;
                      _projects.removeWhere(
                        (p) => p.id.startsWith(DemoProjectFactory.demoPrefix),
                      );
                      if (value) _projects.insert(0, DemoProjectFactory.create());
                    });
                    if (!_unreadable) await _save();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _error(Object error) => _message('Не удалось выполнить операцию: $error');

  @override
  Widget build(BuildContext context) {
    final current = _currentProject;
    final visible = _visibleProjects;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const ZLoadingState(title: 'Загружаем проекты')
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    _Header(onSettings: _settings),
                    const SizedBox(height: 18),
                    _SearchField(
                      controller: _search,
                      onFilter: _filters,
                    ),
                    const SizedBox(height: 24),
                    Text('Продолжить работу', style: ZamerTypography.h2),
                    const SizedBox(height: 12),
                    if (current == null)
                      ZEmptyState(
                        icon: Icons.home_work_outlined,
                        title: 'Рабочего проекта пока нет',
                        subtitle: 'Создайте проект или восстановите резервную копию.',
                        actionLabel: 'Создать проект',
                        onAction: () => _createProject(),
                      )
                    else
                      _ActiveProjectCard(
                        project: current,
                        area: _area(current),
                        rooms: _roomCount(current),
                        onOpen: () => _openProject(current),
                        onMore: () => _projectMenu(current),
                      ),
                    const SizedBox(height: 24),
                    Text('Быстрые действия', style: ZamerTypography.h2),
                    const SizedBox(height: 12),
                    _QuickGrid(
                      onNew: () => _createProject(),
                      onScan: _createAndScan,
                      onImport: _importPlan,
                      onRestore: _importBackup,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Недавние проекты', style: ZamerTypography.h2),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ProjectsScreen(),
                              ),
                            );
                            await _load();
                          },
                          child: const Text('Все'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 48,
                              color: _muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Проектов по фильтру нет',
                              style: ZamerTypography.h3,
                            ),
                          ],
                        ),
                      )
                    else
                      for (final project in visible.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ProjectRow(
                            project: project,
                            area: _area(project),
                            onOpen: () => _openProject(project),
                            onMore: () => _projectMenu(project),
                          ),
                        ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _PrimaryHomeNav(
        onMeasure: () => _openWorkspace(0),
        on3D: () => _openWorkspace(1),
        onElevations: () => _openWorkspace(2),
        onProfile: _openProfile,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              HomeConceptAssets.logo,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ЗАМЕР', style: ZamerTypography.h1),
                const SizedBox(height: 2),
                Text(
                  'Обмер • проект • рабочая документация',
                  style: ZamerTypography.bodySmall.copyWith(color: _muted),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Настройки',
            onPressed: onSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onFilter});

  final TextEditingController controller;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Проект, адрес или заказчик…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Фильтр',
            onPressed: onFilter,
            icon: const Icon(Icons.tune_rounded),
          ),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _outline),
          ),
        ),
      );
}

class _ActiveProjectCard extends StatelessWidget {
  const _ActiveProjectCard({
    required this.project,
    required this.area,
    required this.rooms,
    required this.onOpen,
    required this.onMore,
  });

  final MeasureProject project;
  final double area;
  final int rooms;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        child: Material(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 154,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        HomeConceptAssets.currentProject,
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE6000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ZamerColors.beige,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'АКТИВНЫЙ ПРОЕКТ',
                            style: TextStyle(
                              color: _bg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 8,
                        child: IconButton.filledTonal(
                          tooltip: 'Действия проекта',
                          onPressed: onMore,
                          icon: const Icon(Icons.more_horiz_rounded),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.h2,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _Metric(
                              icon: Icons.square_foot_outlined,
                              text: '${area.toStringAsFixed(1)} м²',
                            ),
                            _Metric(
                              icon: Icons.grid_view_outlined,
                              text: '$rooms помещений',
                            ),
                            _Metric(
                              icon: Icons.layers_outlined,
                              text: '${project.floors.length} этаж.',
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Продолжить'),
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
          Text(text, style: ZamerTypography.caption),
        ],
      );
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.onNew,
    required this.onScan,
    required this.onImport,
    required this.onRestore,
  });

  final VoidCallback onNew;
  final VoidCallback onScan;
  final VoidCallback onImport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, VoidCallback)>[
      (Icons.add_rounded, 'Новый проект', 'Пустой или шаблон', onNew),
      (Icons.document_scanner_outlined, 'Сканировать', 'Фото или план БТИ', onScan),
      (Icons.upload_file_outlined, 'Импорт плана', 'PDF, DWG или фото', onImport),
      (Icons.settings_backup_restore_rounded, 'Восстановить', 'ZIP или JSON копия', onRestore),
    ];
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.65,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Material(
          color: index == 0 ? ZamerColors.beige : _surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: item.$4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: index == 0 ? ZamerColors.beige : _outline,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    item.$1,
                    color: index == 0 ? _bg : ZamerColors.textPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.bodySmall.copyWith(
                            color: index == 0 ? _bg : ZamerColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption.copyWith(
                            color: index == 0
                                ? _bg.withValues(alpha: .7)
                                : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.area,
    required this.onOpen,
    required this.onMore,
  });

  final MeasureProject project;
  final double area;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Material(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              border: Border.all(color: _outline),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: ZamerColors.beige),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZamerTypography.h4,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${area.toStringAsFixed(1)} м² • ${project.floors.length} эт.',
                        style: ZamerTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Действия проекта',
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(
          icon,
          color: destructive ? Colors.redAccent : ZamerColors.textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: destructive ? Colors.redAccent : ZamerColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _PrimaryHomeNav extends StatelessWidget {
  const _PrimaryHomeNav({
    required this.onMeasure,
    required this.on3D,
    required this.onElevations,
    required this.onProfile,
  });

  final VoidCallback onMeasure;
  final VoidCallback on3D;
  final VoidCallback onElevations;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.home_rounded, 'Главная', null),
      (Icons.architecture_outlined, 'Замер', onMeasure),
      (Icons.view_in_ar_outlined, '3D', on3D),
      (Icons.view_carousel_outlined, 'Развёртки', onElevations),
      (Icons.person_outline_rounded, 'Профиль', onProfile),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _outline)),
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
                      Icon(
                        items[i].$1,
                        size: 21,
                        color: i == 0 ? ZamerColors.beige : ZamerColors.gray300,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                          color: i == 0 ? ZamerColors.beige : ZamerColors.gray300,
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
