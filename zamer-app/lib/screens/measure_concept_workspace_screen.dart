import 'package:flutter/material.dart';

import '../design_system/zamer_press_effect.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import 'plan_editor_concept_screen.dart';

enum _MeasureConceptView { twoD, threeD, ar, photo }

class MeasureConceptWorkspaceScreen extends StatefulWidget {
  const MeasureConceptWorkspaceScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.onMore,
    required this.onOpen3D,
    required this.onOpenPhoto,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
    required this.onHome,
    required this.onProjects,
    required this.onCatalog,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onMore;
  final VoidCallback onOpen3D;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onCatalog;

  @override
  State<MeasureConceptWorkspaceScreen> createState() =>
      _MeasureConceptWorkspaceScreenState();
}

class _MeasureConceptWorkspaceScreenState
    extends State<MeasureConceptWorkspaceScreen> {
  _MeasureConceptView _view = _MeasureConceptView.twoD;

  Future<void> _save() async {
    await widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Проект сохранён'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _renameProject() async {
    final controller = TextEditingController(text: widget.project.name);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название проекта'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название проекта'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == widget.project.name) return;
    widget.project.name = value;
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _selectView(_MeasureConceptView value) {
    if (value == _MeasureConceptView.twoD) {
      setState(() => _view = value);
      return;
    }
    if (value == _MeasureConceptView.threeD) {
      widget.onOpen3D();
      return;
    }
    if (value == _MeasureConceptView.photo) {
      widget.onOpenPhoto();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AR подключим к рабочему сканированию помещения. Интерфейс уже закреплён.'),
      ),
    );
  }

  void _learning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Обучение по инструментам Замера готовится в отдельном разделе.')),
    );
  }

  void _moreBottom() => widget.onMore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ConceptHeader(
              projectName: widget.project.name,
              onBack: () => Navigator.maybePop(context),
              onRename: _renameProject,
              onUndo: widget.canUndo ? widget.onUndo : null,
              onRedo: widget.canRedo ? widget.onRedo : null,
              onMore: widget.onMore,
              onSave: _save,
            ),
            _ViewTabs(value: _view, onChanged: _selectView),
            Expanded(
              child: PlanEditorConceptScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
                onOpenObjects: widget.onOpenObjects,
                onOpenReview: widget.onOpenReview,
                onOpenGeometry: widget.onOpenGeometry,
                onOpen3D: widget.onOpen3D,
                onOpenFloors: widget.onOpenFloors,
                onOpenSettings: widget.onOpenSettings,
              ),
            ),
            _ConceptBottomNav(
              onHome: widget.onHome,
              onProjects: widget.onProjects,
              onAdd: widget.onOpenObjects,
              onCatalog: widget.onCatalog,
              onLearning: _learning,
              onMore: _moreBottom,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptHeader extends StatelessWidget {
  const _ConceptHeader({
    required this.projectName,
    required this.onBack,
    required this.onRename,
    required this.onUndo,
    required this.onRedo,
    required this.onMore,
    required this.onSave,
  });

  final String projectName;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onMore;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
      decoration: const BoxDecoration(
        color: Color(0xFF07151E),
        border: Border(bottom: BorderSide(color: ZamerColors.outlineSoft)),
      ),
      child: Row(
        children: [
          _HeaderSquare(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ЗАМЕР',
                  style: ZamerTypography.h2.copyWith(
                    fontSize: 25,
                    height: 1,
                    color: ZamerColors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: onRename,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption.copyWith(
                            color: ZamerColors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 12, color: ZamerColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _HeaderSquare(icon: Icons.undo_rounded, onTap: onUndo),
          const SizedBox(width: 3),
          _HeaderSquare(icon: Icons.redo_rounded, onTap: onRedo),
          const SizedBox(width: 3),
          _HeaderSquare(icon: Icons.more_horiz_rounded, onTap: onMore),
          const SizedBox(width: 5),
          ZPressEffect(
            scale: .96,
            child: Material(
              color: ZamerColors.accent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onSave,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  child: Text(
                    'Сохранить',
                    style: ZamerTypography.button.copyWith(
                      color: ZamerColors.accentInk,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSquare extends StatelessWidget {
  const _HeaderSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        enabled: onTap != null,
        scale: .92,
        child: Material(
          color: const Color(0xFF0B1B25),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: onTap == null ? .35 : 1,
              child: Container(
                width: 38,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: ZamerColors.outlineSoft),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 19),
              ),
            ),
          ),
        ),
      );
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.value, required this.onChanged});
  final _MeasureConceptView value;
  final ValueChanged<_MeasureConceptView> onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <(_MeasureConceptView, String)>[
      (_MeasureConceptView.twoD, '2D'),
      (_MeasureConceptView.threeD, '3D'),
      (_MeasureConceptView.ar, 'AR'),
      (_MeasureConceptView.photo, 'Фото'),
    ];
    return Container(
      height: 48,
      color: const Color(0xFF07151E),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _ViewTab(
                  label: entry.$2,
                  selected: value == entry.$1,
                  onTap: () => onChanged(entry.$1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZPressEffect(
        scale: .96,
        child: Material(
          color: selected ? ZamerColors.accent : const Color(0xFF0B1B25),
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? ZamerColors.accentInk : ZamerColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
}

class _ConceptBottomNav extends StatelessWidget {
  const _ConceptBottomNav({
    required this.onHome,
    required this.onProjects,
    required this.onAdd,
    required this.onCatalog,
    required this.onLearning,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onAdd;
  final VoidCallback onCatalog;
  final VoidCallback onLearning;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
        decoration: const BoxDecoration(
          color: Color(0xFF07151E),
          border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
        ),
        child: Row(
          children: [
            Expanded(child: _NavItem(icon: Icons.home_rounded, label: 'Главная', selected: true, onTap: onHome)),
            Expanded(child: _NavItem(icon: Icons.folder_outlined, label: 'Проекты', onTap: onProjects)),
            Expanded(
              child: Center(
                child: ZPressEffect(
                  scale: .93,
                  child: Material(
                    color: ZamerColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAdd,
                      child: const SizedBox(
                        width: 54,
                        height: 54,
                        child: Icon(Icons.add_rounded, size: 31, color: ZamerColors.accentInk),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _NavItem(icon: Icons.shopping_bag_outlined, label: 'Каталог', onTap: onCatalog)),
            Expanded(child: _NavItem(icon: Icons.school_outlined, label: 'Обучение', onTap: onLearning)),
            Expanded(child: _NavItem(icon: Icons.grid_view_rounded, label: 'Ещё', onTap: onMore)),
          ],
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: selected ? ZamerColors.accent : ZamerColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 6.9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}
