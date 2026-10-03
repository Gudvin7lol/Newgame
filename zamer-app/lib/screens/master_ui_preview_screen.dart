import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/equipment_placement_service.dart';
import '../services/object_catalog.dart';
import '../services/project_store.dart';
import 'floor_workspace_screen.dart';
import 'master_3d_screen.dart';
import 'master_control_screen.dart';
import 'master_documentation_screen.dart';
import 'master_elevations_production_screen.dart';
import 'master_equipment_screen.dart';
import 'master_object_placement_workspace.dart';
import 'master_photo_screen.dart';
import 'master_profile_screen.dart';
import 'projects_screen.dart';

/// Production master shell. Every page works on the same persisted project.
class MasterUiPreviewScreen extends StatefulWidget {
  const MasterUiPreviewScreen({super.key});

  @override
  State<MasterUiPreviewScreen> createState() => _MasterUiPreviewScreenState();
}

class _MasterUiPreviewScreenState extends State<MasterUiPreviewScreen> {
  final ProjectStore _store = ProjectStore();
  final List<MeasureProject> _projects = <MeasureProject>[];
  MeasureProject? _project;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    try {
      final result = await _store.loadWithStatus();
      if (result.unreadable) {
        throw StateError('Локальный файл проектов повреждён. Импортируй резервную копию в разделе «Проекты».');
      }
      final loaded = <MeasureProject>[...result.projects];
      MeasureProject? current;
      for (final candidate in loaded.reversed) {
        if (!candidate.id.startsWith(DemoProjectFactory.demoPrefix)) {
          current = candidate;
          break;
        }
      }
      current ??= loaded.cast<MeasureProject?>().firstWhere(
            (candidate) => candidate?.id == DemoProjectFactory.projectId,
            orElse: () => null,
          );
      if (current == null) {
        current = DemoProjectFactory.create();
        loaded.add(current);
        await _store.save(loaded);
      }
      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(loaded);
        _project = current;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
    }
  }

  Future<void> _save() async {
    await _store.save(_projects);
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openProjects() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectsScreen()),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadProject();
  }

  Future<void> _addEquipment(ObjectCatalogItem item) async {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    final floor = project.floors.first;
    final object = EquipmentPlacementService.addCatalogItem(
      floor: floor,
      item: item,
    );
    try {
      await _save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} добавлен в ${floor.name}'),
          action: SnackBarAction(label: 'РАЗМЕСТИТЬ', onPressed: _openPlacement),
        ),
      );
    } catch (error) {
      EquipmentPlacementService.removeObject(floor: floor, object: object);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить объект: $error')),
      );
    }
  }

  void _openMeasure() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      FloorWorkspaceScreen(
        project: project,
        floor: project.floors.first,
        onChanged: _save,
        initialMode: 0,
      ),
    );
  }

  void _open3D() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      Master3DScreen(
        floor: project.floors.first,
        projectTitle: project.name,
        onOpen2D: () {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) => _openMeasure());
        },
      ),
    );
  }

  void _openEquipment() {
    final project = _project;
    if (project == null) return;
    _open(
      MasterEquipmentScreen(
        projectTitle: project.name,
        onAdd: _addEquipment,
      ),
    );
  }

  void _openPlacement() {
    final project = _project;
    if (project == null || project.floors.isEmpty || !mounted) return;
    final floor = project.floors.first;
    _open(
      Scaffold(
        backgroundColor: ZamerColors.background,
        appBar: AppBar(
          title: Text('${project.name} • размещение'),
          actions: [
            IconButton(
              tooltip: 'Открыть 3D',
              onPressed: _open3D,
              icon: const Icon(Icons.view_in_ar_outlined),
            ),
          ],
        ),
        body: MasterObjectPlacementWorkspace(
          floor: floor,
          onChanged: _save,
        ),
      ),
    );
  }

  void _openElevations() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      MasterElevationsProductionScreen(
        project: project,
        floor: project.floors.first,
        onChanged: _save,
      ),
    );
  }

  void _openPhoto() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      MasterPhotoScreen(
        projectTitle: project.name,
        floor: project.floors.first,
        onChanged: _save,
        onOpenMeasure: _openMeasure,
        onOpenProfile: _openProfile,
      ),
    );
  }

  void _openControl() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      MasterControlScreen(
        projectTitle: project.name,
        floor: project.floors.first,
        onOpenMeasure: _openMeasure,
        onOpenProfile: _openProfile,
      ),
    );
  }

  void _openDocumentation() {
    final project = _project;
    if (project == null || project.floors.isEmpty) return;
    _open(
      MasterDocumentationScreen(
        project: project,
        floor: project.floors.first,
        onOpenMeasure: _openMeasure,
        onOpenProfile: _openProfile,
      ),
    );
  }

  void _openProfile() {
    final project = _project;
    if (project == null) return;
    _open(
      MasterProfileScreen(
        project: project,
        projectCount: _projects.length,
        onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onOpenMeasure: _openMeasure,
        onOpen3D: _open3D,
        onOpenElevations: _openElevations,
      ),
    );
  }

  Widget _loadingView() => const Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_loadError != null || _project == null || _project!.floors.isEmpty) {
      return Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44),
                  const SizedBox(height: 12),
                  Text(_loadError ?? 'В проекте нет этажей', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _openProjects, child: const Text('Открыть проекты')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      _loadProject();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final project = _project!;
    final floor = project.floors.first;
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ZAMER', style: ZamerTypography.h1.copyWith(letterSpacing: 2)),
                      const SizedBox(height: 3),
                      Text(
                        'РАБОЧИЙ ПРОЕКТ',
                        style: ZamerTypography.caption.copyWith(
                          color: ZamerColors.accent,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Проекты',
                  onPressed: _openProjects,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Профиль',
                  onPressed: _openProfile,
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZamerColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: ZamerColors.accent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: ZamerTypography.h3),
                        const SizedBox(height: 3),
                        Text(
                          '${floor.name} • ${floor.walls.length} стен • ${floor.planObjects.length} объектов',
                          style: ZamerTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProductionTile(
              title: 'ЗАМЕР',
              subtitle: 'План, стены, проёмы, размеры и геометрия',
              icon: Icons.straighten_outlined,
              onTap: _openMeasure,
            ),
            _ProductionTile(
              title: '3D ВИД',
              subtitle: 'Обзор, прогулка, разрез, свет и рендер',
              icon: Icons.view_in_ar_outlined,
              onTap: _open3D,
            ),
            _ProductionTile(
              title: 'ОСНАЩЕНИЕ',
              subtitle: 'Поиск, фильтры и реальные модели каталога',
              icon: Icons.chair_alt_outlined,
              onTap: _openEquipment,
            ),
            _ProductionTile(
              title: 'РАЗМЕЩЕНИЕ',
              subtitle: 'Перемещение, поворот, копирование и удаление',
              icon: Icons.open_with_rounded,
              onTap: _openPlacement,
            ),
            _ProductionTile(
              title: 'РАЗВЁРТКИ',
              subtitle: 'Реальные стены, проёмы, электрика и отделка',
              icon: Icons.view_carousel_outlined,
              onTap: _openElevations,
            ),
            _ProductionTile(
              title: 'ФОТО И ЗАМЕТКИ',
              subtitle: 'Камера, галерея, помещения и сохранение заметок',
              icon: Icons.camera_alt_outlined,
              onTap: _openPhoto,
            ),
            _ProductionTile(
              title: 'КОНТРОЛЬ',
              subtitle: 'Реальные ошибки обмера и источники размеров',
              icon: Icons.verified_user_outlined,
              onTap: _openControl,
            ),
            _ProductionTile(
              title: 'ДОКУМЕНТАЦИЯ',
              subtitle: 'PDF-комплект, предпросмотр и экспорт',
              icon: Icons.description_outlined,
              onTap: _openDocumentation,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionTile extends StatelessWidget {
  const _ProductionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: ZamerColors.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ZamerColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: ZamerColors.accentInk, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: ZamerTypography.h4),
                        const SizedBox(height: 3),
                        Text(subtitle, style: ZamerTypography.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
}
