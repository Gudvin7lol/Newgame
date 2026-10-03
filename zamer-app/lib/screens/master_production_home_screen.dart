import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';
import '../services/object_catalog.dart';
import '../services/project_store.dart';
import 'floor_workspace_screen.dart';
import 'master_3d_screen.dart';
import 'master_elevations_screen.dart';
import 'master_equipment_screen.dart';
import 'master_live_pages.dart';

class MasterProductionHomeScreen extends StatefulWidget {
  const MasterProductionHomeScreen({super.key});

  @override
  State<MasterProductionHomeScreen> createState() => _MasterProductionHomeScreenState();
}

class _MasterProductionHomeScreenState extends State<MasterProductionHomeScreen> {
  final ProjectStore _store = ProjectStore();
  final List<MeasureProject> _projects = <MeasureProject>[];
  bool _loading = true;
  bool _unreadable = false;
  String? _selectedProjectId;

  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _store.loadWithStatus();
    final loaded = <MeasureProject>[...result.projects];
    if (!result.unreadable &&
        !loaded.any((project) => project.id == DemoProjectFactory.projectId)) {
      loaded.insert(0, DemoProjectFactory.create());
      try {
        await _store.save(loaded);
      } catch (_) {
        // The demo project must not block access to the user's real projects.
      }
    }
    if (!mounted) return;
    setState(() {
      _projects
        ..clear()
        ..addAll(loaded);
      _selectedProjectId = loaded.isEmpty ? null : loaded.first.id;
      _loading = false;
      _unreadable = result.unreadable;
    });
  }

  Future<void> _save() => _store.save(_projects);

  MeasureProject? get _selectedProject {
    if (_projects.isEmpty) return null;
    final id = _selectedProjectId;
    if (id != null) {
      for (final project in _projects) {
        if (project.id == id) return project;
      }
    }
    return _projects.first;
  }

  FloorPlan? _floorFor(MeasureProject? project) {
    if (project == null) return null;
    if (project.floors.isEmpty) {
      project.floors.add(FloorPlan(id: _id('f'), name: 'Этаж 1'));
    }
    return project.floors.first;
  }

  Future<void> _createProject() async {
    if (_unreadable) return;
    final controller = TextEditingController(text: 'Новый проект');
    final name = await showDialog<String>(
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final project = MeasureProject(
      id: _id('p'),
      name: name,
      floors: [FloorPlan(id: _id('f'), name: 'Этаж 1')],
    );
    setState(() {
      _projects.insert(0, project);
      _selectedProjectId = project.id;
    });
    await _save();
  }

  Future<void> _addEquipment(
    MeasureProject project,
    FloorPlan floor,
    ObjectCatalogItem item,
  ) async {
    final object = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: item,
    );
    try {
      GeometryService.syncRoomMetadata(floor);
      await _save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} добавлен в ${project.name}')),
      );
    } catch (error) {
      EquipmentPlacementService.removeObject(floor: floor, object: object);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить объект: $error')),
      );
    }
  }

  Future<void> _openMeasure(MeasureProject project, FloorPlan floor) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: floor,
          onChanged: _save,
          initialMode: 0,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _open3D(MeasureProject project, FloorPlan floor) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Master3DScreen(
          floor: floor,
          projectTitle: project.name,
          onOpen2D: () {
            Navigator.pop(context);
            _openMeasure(project, floor);
          },
          onOpenAr: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AR включим после стабилизации camera API')),
          ),
        ),
      ),
    );
  }

  Future<void> _openEquipment(MeasureProject project, FloorPlan floor) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterEquipmentScreen(
          projectTitle: project.name,
          onAdd: (item) => _addEquipment(project, floor, item),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openElevations(MeasureProject project, FloorPlan floor) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterElevationsScreen(
          floor: floor,
          projectTitle: project.name,
        ),
      ),
    );
  }

  Future<void> _openPhoto(MeasureProject project, FloorPlan floor) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterLivePhotoScreen(
          project: project,
          floor: floor,
          onChanged: _save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openDocuments(MeasureProject project, FloorPlan floor) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterLiveDocumentationScreen(project: project, floor: floor),
      ),
    );
  }

  void _openControl(MeasureProject project, FloorPlan floor) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterLiveControlScreen(project: project, floor: floor),
      ),
    );
  }

  void _openProfile() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MasterLiveProfileScreen(projectCount: _projects.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    final floor = _floorFor(project);
    final realProjects = _projects
        .where((item) => item.id != DemoProjectFactory.projectId)
        .toList();

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ЗАМЕР', style: ZamerTypography.h1.copyWith(letterSpacing: 1.5)),
                            const SizedBox(height: 3),
                            Text(
                              'РАБОЧЕЕ ПРОСТРАНСТВО',
                              style: ZamerTypography.caption.copyWith(
                                color: ZamerColors.accent,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Профиль',
                        onPressed: _openProfile,
                        icon: const Icon(Icons.person_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_unreadable)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZamerColors.danger.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZamerColors.danger),
                      ),
                      child: const Text(
                        'Хранилище проектов повреждено. Создание новых проектов отключено, пока данные не восстановлены.',
                      ),
                    ),
                  ZMasterPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_open_outlined, color: ZamerColors.accent),
                            const SizedBox(width: 9),
                            Expanded(child: Text('Текущий проект', style: ZamerTypography.h4)),
                            Text('${realProjects.length} ваших', style: ZamerTypography.caption),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_projects.isEmpty)
                          const Text('Проектов пока нет', style: ZamerTypography.bodySmall)
                        else
                          DropdownButtonFormField<String>(
                            initialValue: project?.id,
                            decoration: const InputDecoration(labelText: 'Проект'),
                            items: [
                              for (final item in _projects)
                                DropdownMenuItem(value: item.id, child: Text(item.name)),
                            ],
                            onChanged: (id) => setState(() => _selectedProjectId = id),
                          ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _unreadable ? null : _createProject,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Новый проект'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (project != null && floor != null) ...[
                    Row(
                      children: [
                        Expanded(child: Text(project.name, style: ZamerTypography.h2)),
                        Text(floor.name, style: ZamerTypography.caption),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        _WorkspaceTile(
                          icon: Icons.straighten_outlined,
                          title: 'Замер',
                          subtitle: '2D, стены, проёмы и размеры',
                          onTap: () => _openMeasure(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.view_in_ar_outlined,
                          title: '3D',
                          subtitle: 'Обзор, прогулка и рендер',
                          onTap: () => _open3D(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.chair_alt_outlined,
                          title: 'Оснащение',
                          subtitle: '${floor.planObjects.length} объектов',
                          onTap: () => _openEquipment(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.view_carousel_outlined,
                          title: 'Развёртки',
                          subtitle: 'Стены, пол и отделка',
                          onTap: () => _openElevations(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.camera_alt_outlined,
                          title: 'Фото',
                          subtitle: 'Фотофиксация и заметки',
                          onTap: () => _openPhoto(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.description_outlined,
                          title: 'Документы',
                          subtitle: 'PDF и предпросмотр',
                          onTap: () => _openDocuments(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Контроль',
                          subtitle: 'Проверка геометрии и размеров',
                          onTap: () => _openControl(project, floor),
                        ),
                        _WorkspaceTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Профиль',
                          subtitle: 'Настройки приложения',
                          onTap: _openProfile,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZamerColors.accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: ZamerColors.accent, size: 22),
                ),
                const Spacer(),
                Text(title, style: ZamerTypography.h4),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZamerTypography.caption,
                ),
              ],
            ),
          ),
        ),
      );
}
