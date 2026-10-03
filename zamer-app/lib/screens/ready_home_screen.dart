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
import 'floors_screen.dart';
import 'projects_screen.dart';
import 'scan_plan_screen.dart';

const _readyHomeBackground = Color(0xFF050B10);
const _readyHomeSurface = Color(0xFF0D171D);
const _readyHomeOutline = Color(0xFF26343B);
const _readyHomeMuted = Color(0xFFB2BBC2);
const _lastOpenedProjectKey = 'zamer.last_opened_project_id';
const _rememberLastProjectKey = 'zamer.home.remember_last_project';
const _showDemoProjectKey = 'zamer.home.show_demo_project';

TextStyle _readyDisplay(TextStyle source) => source.copyWith(
      fontFamily: 'sans-serif-medium',
      letterSpacing: -.18,
    );

TextStyle _readyBody(TextStyle source) => source.copyWith(
      fontFamily: 'sans-serif',
      letterSpacing: -.05,
    );

/// Production entry point for the Home + Measure milestone.
///
/// Unlike the old review shell, every visible action on this page performs a
/// real operation against [ProjectStore] or opens a real production workflow.
class ReadyHomeScreen extends StatefulWidget {
  const ReadyHomeScreen({super.key});

  @override
  State<ReadyHomeScreen> createState() => _ReadyHomeScreenState();
}

class _ReadyHomeScreenState extends State<ReadyHomeScreen> {
  final ProjectStore _store = ProjectStore();
  final ScrollController _scroll = ScrollController();
  final List<MeasureProject> _projects = <MeasureProject>[];

  bool _loading = true;
  bool _unreadable = false;
  bool _rememberLastProject = true;
  bool _showDemoProject = true;
  String? _lastOpenedProjectId;

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
    final preferences = await SharedPreferences.getInstance();
    final result = await _store.loadWithStatus();
    final loaded = <MeasureProject>[...result.projects];

    final rememberLast =
        preferences.getBool(_rememberLastProjectKey) ?? true;
    final showDemo = preferences.getBool(_showDemoProjectKey) ?? true;

    if (!result.unreadable) {
      loaded.removeWhere(
        (project) => project.id.startsWith(DemoProjectFactory.demoPrefix),
      );
      if (showDemo) loaded.insert(0, DemoProjectFactory.create());
      try {
        await _store.save(loaded);
      } catch (_) {
        // A demo refresh must never block access to real local projects.
      }
    }

    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _rememberLastProject = rememberLast;
      _showDemoProject = showDemo;
      _lastOpenedProjectId = rememberLast
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
    final rememberedId = _rememberLastProject ? _lastOpenedProjectId : null;
    if (rememberedId != null) {
      for (final project in _projects) {
        if (project.id == rememberedId) return project;
      }
    }

    final real = _projects
        .where((project) => !project.id.startsWith(DemoProjectFactory.demoPrefix))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (real.isNotEmpty) return real.first;
    return _projects.isEmpty ? null : _projects.first;
  }

  List<MeasureProject> get _recentProjects {
    final copy = [..._projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.take(3).toList(growable: false);
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

  Future<void> _openProject(MeasureProject project) async {
    await _rememberOpened(project);
    if (!mounted) return;
    await Navigator.push<void>(
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
      await _createProject(initialName: 'Квартира', openAfterCreate: false);
      project = _currentProject;
    }
    if (!mounted || project == null || project.floors.isEmpty) return;

    await _rememberOpened(project);
    if (!mounted) return;
    await Navigator.push<void>(
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

  Future<void> _openProjects() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
    );
    await _load();
  }

  Future<String?> _nameDialog({
    required String title,
    required String initial,
    String action = 'Сохранить',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
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
    return value;
  }

  Future<void> _createProject({
    String initialName = 'Квартира',
    bool openAfterCreate = true,
  }) async {
    if (_unreadable) {
      _showMessage('Сначала восстановите повреждённое хранилище проектов.');
      return;
    }
    final name = await _nameDialog(
      title: 'Новый проект',
      initial: initialName,
      action: 'Создать',
    );
    if (name == null || name.isEmpty) return;

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
    } catch (error) {
      if (mounted) setState(() => _projects.remove(project));
      _showError(error);
    }
  }

  Future<void> _renameProject(MeasureProject project) async {
    if (project.id.startsWith(DemoProjectFactory.demoPrefix)) {
      _showMessage('Демо-проект нельзя переименовать. Создайте рабочую копию.');
      return;
    }
    final name = await _nameDialog(
      title: 'Переименовать проект',
      initial: project.name,
    );
    if (name == null || name.isEmpty || name == project.name) return;
    final oldName = project.name;
    setState(() => project.name = name);
    try {
      await _save();
    } catch (error) {
      if (mounted) setState(() => project.name = oldName);
      _showError(error);
    }
  }

  Future<void> _duplicateProject(MeasureProject project) async {
    if (_unreadable) return;
    final copy = ProjectBackupService.importAsCopy(project, _id('p'));
    setState(() => _projects.insert(0, copy));
    try {
      await _save();
      await _rememberOpened(copy);
      _showMessage('Создана копия «${project.name}».');
    } catch (error) {
      if (mounted) setState(() => _projects.remove(copy));
      _showError(error);
    }
  }

  Future<void> _deleteProject(MeasureProject project) async {
    if (project.id.startsWith(DemoProjectFactory.demoPrefix)) {
      _showMessage('Демо-проект отключается в настройках Главной.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('«${project.name}» будет удалён с этого устройства.'),
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
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove(_lastOpenedProjectKey);
      }
    } catch (error) {
      if (mounted) setState(() => _projects.insert(index, project));
      _showError(error);
    }
  }

  Future<void> _showProjectMenu(MeasureProject project) async {
    await _showSheet([
      _SheetAction(
        icon: Icons.edit_outlined,
        label: 'Переименовать',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _renameProject(project);
        },
      ),
      _SheetAction(
        icon: Icons.copy_all_outlined,
        label: 'Создать копию',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _duplicateProject(project);
        },
      ),
      _SheetAction(
        icon: Icons.delete_outline_rounded,
        label: 'Удалить',
        destructive: true,
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _deleteProject(project);
        },
      ),
    ]);
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
      await _rememberOpened(project);
    } catch (error) {
      if (mounted) setState(() => _projects.remove(project));
      _showError(error);
      return;
    }

    if (!mounted) return;
    await Navigator.push<void>(
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
      await _rememberOpened(copy);
      _showMessage('Проект восстановлен.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _shareCurrentPdf() async {
    final project = _currentProject;
    if (project == null || project.floors.isEmpty) {
      _showMessage('Сначала создайте проект.');
      return;
    }
    try {
      await ReportService.shareFloorPdf(project, project.floors.first);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _setRememberLastProject(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberLastProjectKey, value);
    if (!value) {
      await preferences.remove(_lastOpenedProjectKey);
    } else if (_lastOpenedProjectId != null) {
      await preferences.setString(_lastOpenedProjectKey, _lastOpenedProjectId!);
    }
    if (mounted) setState(() => _rememberLastProject = value);
  }

  Future<void> _setShowDemoProject(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showDemoProjectKey, value);
    if (!mounted) return;
    setState(() {
      _showDemoProject = value;
      _projects.removeWhere(
        (project) => project.id.startsWith(DemoProjectFactory.demoPrefix),
      );
      if (value) _projects.insert(0, DemoProjectFactory.create());
    });
    if (!_unreadable) {
      try {
        await _save();
      } catch (error) {
        _showError(error);
      }
    }
  }

  Future<void> _showSettings() async {
    var remember = _rememberLastProject;
    var demo = _showDemoProject;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _readyHomeSurface,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Настройки Главной', style: ZamerTypography.h3),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Запоминать последний проект'),
                  subtitle: const Text(
                    'При запуске текущим становится последний открытый проект',
                  ),
                  value: remember,
                  onChanged: (value) {
                    setSheet(() => remember = value);
                    _setRememberLastProject(value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Показывать демо-проект'),
                  subtitle: const Text(
                    'Демо можно отключить, рабочие проекты не затрагиваются',
                  ),
                  value: demo,
                  onChanged: (value) {
                    setSheet(() => demo = value);
                    _setShowDemoProject(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLearning() async {
    await _showSheet([
      _SheetAction(
        icon: Icons.architecture_outlined,
        label: 'Первый замер',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _openWorkspace(0);
        },
      ),
      _SheetAction(
        icon: Icons.view_in_ar_outlined,
        label: 'Работа с 3D',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _openWorkspace(1);
        },
      ),
      _SheetAction(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Документация и экспорт',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _shareCurrentPdf();
        },
      ),
    ]);
  }

  Future<void> _showMore() async {
    await _showSheet([
      _SheetAction(
        icon: Icons.upload_file_outlined,
        label: 'Импорт плана',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _importPlan();
        },
      ),
      _SheetAction(
        icon: Icons.settings_backup_restore_rounded,
        label: 'Восстановить проект',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _importBackup();
        },
      ),
      _SheetAction(
        icon: Icons.picture_as_pdf_outlined,
        label: 'PDF текущего проекта',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _shareCurrentPdf();
        },
      ),
      _SheetAction(
        icon: Icons.settings_outlined,
        label: 'Настройки',
        onTap: (sheetContext) {
          Navigator.pop(sheetContext);
          _showSettings();
        },
      ),
    ]);
  }

  Future<void> _showTemplates() async {
    await _showSheet([
      for (final title in const ['Квартира', 'Дом', 'Коммерция'])
        _SheetAction(
          icon: Icons.home_work_outlined,
          label: title,
          onTap: (sheetContext) {
            Navigator.pop(sheetContext);
            _createProject(initialName: title);
          },
        ),
    ]);
  }

  Future<void> _showSheet(List<_SheetAction> actions) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _readyHomeSurface,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions)
                _SheetRow(action: action, sheetContext: sheetContext),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(Object error) =>
      _showMessage('Не удалось выполнить операцию: $error');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentProject;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _readyHomeBackground,
        canvasColor: _readyHomeBackground,
      ),
      child: Scaffold(
        backgroundColor: _readyHomeBackground,
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const ZLoadingState(title: 'Загружаем проекты')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      _ReadyBrandHeader(onSettings: _showSettings),
                      const SizedBox(height: 18),
                      if (_unreadable) ...[
                        _WarningCard(onRestore: _importBackup),
                        const SizedBox(height: 12),
                      ],
                      if (current != null) ...[
                        _ReadyCurrentProjectCard(
                          project: current,
                          area: _areaM2(current),
                          photos: _photoCount(current),
                          onTap: () => _openProject(current),
                          onRename: () => _renameProject(current),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _ReadyNewProjectButton(
                        onTap: _unreadable ? null : () => _createProject(),
                      ),
                      const SizedBox(height: 14),
                      _ReadyWorkspaceShortcuts(
                        onMeasure: () => _openWorkspace(0),
                        on3d: () => _openWorkspace(1),
                        onEquipment: () => _openWorkspace(2),
                        onElevations: () => _openWorkspace(3),
                        onMore: _showMore,
                      ),
                      const SizedBox(height: 24),
                      _ReadySectionTitle(
                        title: 'МОИ ПРОЕКТЫ',
                        onAll: _openProjects,
                      ),
                      const SizedBox(height: 10),
                      if (_recentProjects.isEmpty)
                        ZEmptyState(
                          icon: Icons.home_work_outlined,
                          title: 'Проектов пока нет',
                          subtitle: 'Создайте новый проект, и он появится здесь.',
                          actionLabel: 'Создать проект',
                          onAction: () => _createProject(),
                        )
                      else
                        ..._recentProjects.map(
                          (project) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReadyProjectRow(
                              project: project,
                              area: _areaM2(project),
                              photos: _photoCount(project),
                              onTap: () => _openProject(project),
                              onMore: () => _showProjectMenu(project),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      _ReadySectionTitle(
                        title: 'ШАБЛОНЫ',
                        onAll: _showTemplates,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            Expanded(
                              child: _ReadyTemplateCard(
                                title: const ['Квартира', 'Дом', 'Коммерция'][i],
                                onTap: () => _createProject(
                                  initialName:
                                      const ['Квартира', 'Дом', 'Коммерция'][i],
                                ),
                              ),
                            ),
                            if (i != 2) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _ReadyHomeBottomNav(
          onHome: _scrollToTop,
          onProjects: _openProjects,
          onCatalog: () => _openWorkspace(2),
          onLearning: _showLearning,
          onMore: _showMore,
        ),
      ),
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final void Function(BuildContext sheetContext) onTap;
  final bool destructive;
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.action, required this.sheetContext});

  final _SheetAction action;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .985,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => action.onTap(sheetContext),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    action.icon,
                    color: action.destructive
                        ? Colors.redAccent
                        : ZamerColors.gray300,
                    size: 23,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      action.label,
                      style: _readyBody(ZamerTypography.body).copyWith(
                        color: action.destructive
                            ? Colors.redAccent
                            : ZamerColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _readyHomeMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ReadyBrandHeader extends StatelessWidget {
  const _ReadyBrandHeader({required this.onSettings});
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
                  style: _readyDisplay(ZamerTypography.h1).copyWith(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ПРОФЕССИОНАЛЬНЫЙ ЗАМЕР\nДЛЯ РЕАЛЬНЫХ ПРОЕКТОВ',
                  style: _readyBody(ZamerTypography.caption).copyWith(
                    color: _readyHomeMuted,
                    height: 1.18,
                    letterSpacing: .25,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Настройки',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Хранилище проектов повреждено. Новые данные не записываются.',
              ),
            ),
            TextButton(onPressed: onRestore, child: const Text('Восстановить')),
          ],
        ),
      );
}

class _ReadyCurrentProjectCard extends StatelessWidget {
  const _ReadyCurrentProjectCard({
    required this.project,
    required this.area,
    required this.photos,
    required this.onTap,
    required this.onRename,
  });

  final MeasureProject project;
  final double area;
  final int photos;
  final VoidCallback onTap;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        child: Material(
          color: _readyHomeSurface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _readyHomeOutline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ТЕКУЩИЙ ПРОЕКТ',
                          style: _readyBody(ZamerTypography.caption).copyWith(
                            color: _readyHomeMuted,
                            letterSpacing: .35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _readyDisplay(ZamerTypography.h3).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Переименовать проект',
                              onPressed: onRename,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            _ReadyMetric(
                              icon: Icons.square_foot_outlined,
                              text:
                                  '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                            ),
                            _ReadyMetric(
                              icon: Icons.photo_library_outlined,
                              text: '$photos фото',
                            ),
                            _ReadyMetric(
                              icon: Icons.layers_outlined,
                              text: '${project.floors.length} эт.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      HomeConceptAssets.currentProject,
                      width: 116,
                      height: 88,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ReadyNewProjectButton extends StatelessWidget {
  const _ReadyNewProjectButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        enabled: onTap != null,
        scale: .985,
        child: Material(
          color: ZamerColors.beige,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              height: 58,
              child: Row(
                children: [
                  SizedBox(width: 16),
                  CircleAvatar(
                    backgroundColor: _readyHomeBackground,
                    child: Icon(Icons.add_rounded, color: ZamerColors.beige),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Новый проект',
                      style: TextStyle(
                        color: _readyHomeBackground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _readyHomeBackground,
                    size: 26,
                  ),
                  SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ReadyWorkspaceShortcuts extends StatelessWidget {
  const _ReadyWorkspaceShortcuts({
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
            child: ZPressEffect(
              child: Material(
                color: _readyHomeSurface,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: items[i].$3,
                  child: Container(
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: i == 0
                            ? ZamerColors.beige
                            : _readyHomeOutline,
                        width: i == 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].$1,
                          size: 22,
                          color: i == 0
                              ? ZamerColors.beige
                              : ZamerColors.gray300,
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$2,
                            style: _readyBody(ZamerTypography.caption).copyWith(
                              color: i == 0
                                  ? ZamerColors.beige
                                  : ZamerColors.gray300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _ReadySectionTitle extends StatelessWidget {
  const _ReadySectionTitle({required this.title, required this.onAll});
  final String title;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: _readyDisplay(ZamerTypography.h5).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: .3,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onAll,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Все'),
          ),
        ],
      );
}

class _ReadyProjectRow extends StatelessWidget {
  const _ReadyProjectRow({
    required this.project,
    required this.area,
    required this.photos,
    required this.onTap,
    required this.onMore,
  });

  final MeasureProject project;
  final double area;
  final int photos;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Material(
        color: _readyHomeSurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _readyHomeOutline),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13),
                  ),
                  child: Image.memory(
                    HomeConceptAssets.currentProject,
                    width: 108,
                    height: 86,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
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
                                style: _readyDisplay(ZamerTypography.h5).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Действия проекта',
                              onPressed: onMore,
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _ReadyMetric(
                              icon: Icons.square_foot_outlined,
                              text:
                                  '${area.toStringAsFixed(area >= 100 ? 0 : 1)} м²',
                            ),
                            const SizedBox(width: 14),
                            _ReadyMetric(
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

class _ReadyMetric extends StatelessWidget {
  const _ReadyMetric({required this.icon, required this.text});
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
            style: _readyBody(ZamerTypography.caption).copyWith(
              color: ZamerColors.gray300,
            ),
          ),
        ],
      );
}

class _ReadyTemplateCard extends StatelessWidget {
  const _ReadyTemplateCard({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        child: Material(
          color: _readyHomeSurface,
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _readyHomeOutline),
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
                        style: _readyBody(ZamerTypography.caption).copyWith(
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
        ),
      );
}

class _ReadyHomeBottomNav extends StatelessWidget {
  const _ReadyHomeBottomNav({
    required this.onHome,
    required this.onProjects,
    required this.onCatalog,
    required this.onLearning,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onCatalog;
  final VoidCallback onLearning;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.home_rounded, 'Главная', onHome),
      (Icons.folder_outlined, 'Проекты', onProjects),
      (Icons.chair_alt_outlined, 'Каталог', onCatalog),
      (Icons.school_outlined, 'Обучение', onLearning),
      (Icons.apps_rounded, 'Ещё', onMore),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: _readyHomeBackground,
          border: Border(top: BorderSide(color: _readyHomeOutline)),
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
                        style: _readyBody(ZamerTypography.caption).copyWith(
                          color: i == 0
                              ? ZamerColors.beige
                              : ZamerColors.gray300,
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
