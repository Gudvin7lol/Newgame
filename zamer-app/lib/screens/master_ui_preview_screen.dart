import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/demo_project_factory.dart';
import '../services/equipment_placement_service.dart';
import '../services/object_catalog.dart';
import '../services/project_store.dart';
import 'master_3d_screen.dart';
import 'master_control_screen.dart';
import 'master_documentation_screen.dart';
import 'master_elevations_screen.dart';
import 'master_equipment_screen.dart';
import 'master_object_placement_workspace.dart';
import 'master_photo_screen.dart';
import 'master_profile_screen.dart';

/// Master UI connected to the same persisted project model as production.
///
/// This screen used to rebuild a fresh demo project on every build. That made
/// the approved UI look convincing while every edit vanished. The review shell
/// now owns a real project list, saves mutations through [ProjectStore], and
/// lets the master Equipment and 3D pages operate on the same [FloorPlan].
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
        throw StateError('Файл проектов повреждён. Автосохранение отключено.');
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await _store.save(_projects);
    if (mounted) setState(() {});
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
          content: Text('${item.name} добавлен и сохранён'),
          action: SnackBarAction(
            label: 'РАЗМЕСТИТЬ',
            onPressed: _openPlacement,
          ),
        ),
      );
    } catch (error) {
      floor.planObjects.removeWhere((candidate) => candidate.id == object.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить объект: $error')),
      );
    }
  }

  void _open(Widget screen) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
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
              onPressed: () => _open(
                Master3DScreen(
                  floor: floor,
                  projectTitle: project.name,
                  onOpen2D: () => Navigator.pop(context),
                ),
              ),
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

  Widget _loadingView() => Scaffold(
        backgroundColor: ZamerColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZAMER',
                  style: ZamerTypography.h1.copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  'MASTER UI REVIEW',
                  style: ZamerTypography.caption.copyWith(
                    color: ZamerColors.accent,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Center(child: CircularProgressIndicator()),
                const Spacer(),
              ],
            ),
          ),
        ),
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
                  Text(_loadError ?? 'В проекте нет этажей'),
                  const SizedBox(height: 16),
                  FilledButton(
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
    final objectCount = floor.planObjects.length;

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('ZAMER', style: ZamerTypography.h1.copyWith(letterSpacing: 2)),
            const SizedBox(height: 4),
            Text(
              'MASTER UI REVIEW',
              style: ZamerTypography.caption.copyWith(
                color: ZamerColors.accent,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${project.name} • ${floor.name} • $objectCount объектов',
              style: ZamerTypography.bodySmall,
            ),
            const SizedBox(height: 22),
            _PreviewTile(
              title: '3D ВИД',
              subtitle: 'Реальная геометрия и сохранённые объекты проекта',
              icon: Icons.view_in_ar_outlined,
              onTap: () => _open(
                Master3DScreen(
                  floor: floor,
                  projectTitle: project.name,
                  onOpen2D: () => Navigator.pop(context),
                  onOpenAr: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AR ещё не подключён')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'ОСНАЩЕНИЕ',
              subtitle: 'Каталог, поиск, фильтры и сохранение объектов',
              icon: Icons.chair_alt_outlined,
              onTap: () => _open(
                MasterEquipmentScreen(
                  projectTitle: project.name,
                  onAdd: (item) => _addEquipment(item),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'РАЗМЕЩЕНИЕ ОБЪЕКТОВ',
              subtitle: 'Перетаскивание, поворот, копирование и удаление',
              icon: Icons.open_with_rounded,
              onTap: _openPlacement,
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'РАЗВЁРТКИ',
              subtitle: 'Работают на геометрии текущего этажа',
              icon: Icons.view_carousel_outlined,
              onTap: () => _open(
                MasterElevationsScreen(floor: floor, projectTitle: project.name),
              ),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'ФОТО И ЗАМЕТКИ',
              subtitle: 'Следующий блок подключения к хранилищу проекта',
              icon: Icons.camera_alt_outlined,
              onTap: () => _open(MasterPhotoScreen(projectTitle: project.name)),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'КОНТРОЛЬ',
              subtitle: 'Проверки замера и источников размеров',
              icon: Icons.verified_user_outlined,
              onTap: () => _open(MasterControlScreen(projectTitle: project.name)),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'ДОКУМЕНТАЦИЯ',
              subtitle: 'PDF-комплект и статусы готовности',
              icon: Icons.description_outlined,
              onTap: () => _open(MasterDocumentationScreen(projectTitle: project.name)),
            ),
            const SizedBox(height: 10),
            _PreviewTile(
              title: 'ПРОФИЛЬ',
              subtitle: 'Локальные настройки; backend будет подключён отдельно',
              icon: Icons.person_outline_rounded,
              onTap: () => _open(const MasterProfileScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
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
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZamerColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: ZamerColors.accentInk, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ZamerTypography.h4),
                      const SizedBox(height: 4),
                      Text(subtitle, style: ZamerTypography.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}
