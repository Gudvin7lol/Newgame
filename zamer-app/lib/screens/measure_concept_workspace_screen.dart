import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import 'plan_editor_production_screen.dart';

/// Production shell for the approved UI KIT 02 «Замер» concept.
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
    required this.onOpenAR,
    required this.onOpenPhoto,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
    required this.onOpenMaterials,
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
  final VoidCallback onOpenAR;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenMaterials;
  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onCatalog;

  @override
  State<MeasureConceptWorkspaceScreen> createState() =>
      _MeasureConceptWorkspaceScreenState();
}

class _MeasureConceptWorkspaceScreenState
    extends State<MeasureConceptWorkspaceScreen> {
  ZMeasureViewMode _view = ZMeasureViewMode.twoD;

  void _selectView(ZMeasureViewMode value) {
    setState(() => _view = value);
    switch (value) {
      case ZMeasureViewMode.twoD:
        return;
      case ZMeasureViewMode.threeD:
        widget.onOpen3D();
      case ZMeasureViewMode.ar:
        widget.onOpenAR();
      case ZMeasureViewMode.photo:
        widget.onOpenPhoto();
    }
  }

  Future<void> _showTutorial() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Обучение', style: ZamerTypography.h3),
              SizedBox(height: 12),
              _TutorialRow(
                number: '1',
                title: 'Стены',
                text: 'Поставь первую точку и задай геометрию стены.',
              ),
              _TutorialRow(
                number: '2',
                title: 'Проёмы',
                text: 'Выбери стену и добавь дверь или окно.',
              ),
              _TutorialRow(
                number: '3',
                title: 'Проверка',
                text: 'Проверь размеры и диагонали перед экспортом.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ConceptHeader(
              projectName: widget.project.name,
              onBack: () => Navigator.maybePop(context),
              onUndo: widget.canUndo ? widget.onUndo : null,
              onRedo: widget.canRedo ? widget.onRedo : null,
              onMore: widget.onMore,
              onSave: widget.onChanged,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 1, 10, 5),
              child: ZMeasureViewTabs(value: _view, onChanged: _selectView),
            ),
            const Divider(height: 1, color: ZamerColors.outlineSoft),
            Expanded(
              child: PlanEditorProductionScreen(
                floor: widget.floor,
                onChanged: widget.onChanged,
                onOpenObjects: widget.onOpenObjects,
                onOpenReview: widget.onOpenReview,
                onOpenAdvanced: widget.onOpenGeometry,
                onOpen3D: widget.onOpen3D,
                onOpenFloors: widget.onOpenFloors,
                onOpenSettings: widget.onOpenSettings,
                onOpenMaterials: widget.onOpenMaterials,
                onUndo: widget.onUndo,
                onRedo: widget.onRedo,
                canUndo: widget.canUndo,
                canRedo: widget.canRedo,
              ),
            ),
            _ConceptBottomNav(
              onHome: widget.onHome,
              onProjects: widget.onProjects,
              onAdd: widget.onOpenObjects,
              onCatalog: widget.onCatalog,
              onTutorial: _showTutorial,
              onMore: widget.onMore,
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
    required this.onUndo,
    required this.onRedo,
    required this.onMore,
    required this.onSave,
  });

  final String projectName;
  final VoidCallback onBack;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onMore;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
        child: Row(
          children: [
            _HeaderSquare(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ЗАМЕР',
                    maxLines: 1,
                    style: ZamerTypography.h1.copyWith(
                      fontSize: 25,
                      height: .98,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZamerTypography.caption.copyWith(
                            color: ZamerColors.textSecondary,
                            fontSize: 9.8,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 11,
                        color: ZamerColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _HeaderSquare(icon: Icons.undo_rounded, onTap: onUndo),
            const SizedBox(width: 4),
            _HeaderSquare(icon: Icons.redo_rounded, onTap: onRedo),
            const SizedBox(width: 4),
            _HeaderSquare(icon: Icons.more_horiz_rounded, onTap: onMore),
            const SizedBox(width: 6),
            SizedBox(
              height: 39,
              width: 79,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ZamerColors.accent,
                  foregroundColor: ZamerColors.accentInk,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => onSave(),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 9.6, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSquare extends StatelessWidget {
  const _HeaderSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .28 : 1,
        child: Material(
          color: ZamerColors.surfaceLow,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZamerColors.outlineSoft),
              ),
              child: Icon(icon, size: 16, color: ZamerColors.textPrimary),
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
    required this.onTutorial,
    required this.onMore,
  });
  final VoidCallback onHome;
  final VoidCallback onProjects;
  final VoidCallback onAdd;
  final VoidCallback onCatalog;
  final VoidCallback onTutorial;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF031119),
        border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
      ),
      child: Row(
        children: [
          _BottomItem(
            icon: Icons.home_rounded,
            label: 'Главная',
            active: true,
            onTap: onHome,
          ),
          _BottomItem(
            icon: Icons.folder_outlined,
            label: 'Проекты',
            onTap: onProjects,
          ),
          Expanded(
            child: InkWell(
              onTap: onAdd,
              child: Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: ZamerColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 29,
                    color: ZamerColors.accentInk,
                  ),
                ),
              ),
            ),
          ),
          _BottomItem(
            icon: Icons.shopping_bag_outlined,
            label: 'Каталог',
            onTap: onCatalog,
          ),
          _BottomItem(
            icon: Icons.school_outlined,
            label: 'Обучение',
            onTap: onTutorial,
          ),
          _BottomItem(
            icon: Icons.grid_view_rounded,
            label: 'Ещё',
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: active ? ZamerColors.accent : ZamerColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color:
                      active ? ZamerColors.accent : ZamerColors.textSecondary,
                  fontSize: 7.7,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

class _TutorialRow extends StatelessWidget {
  const _TutorialRow({
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ZamerColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: ZamerColors.accentInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZamerTypography.bodySmall),
                  const SizedBox(height: 2),
                  Text(text, style: ZamerTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
}
