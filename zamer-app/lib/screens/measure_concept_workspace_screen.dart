import 'package:flutter/material.dart';

import '../design_system/zamer_measure_chrome.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import 'materials_screen.dart';
import 'plan_editor_production_screen.dart';

/// Production shell for the approved UI KIT 02 «Замер» concept.
///
/// For the Home + Measure milestone every visible control either performs a
/// real action or is explicitly disabled. AR stays visible for design
/// continuity but is disabled until a real camera/pose pipeline exists.
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
    this.onOpenAR,
    required this.onOpenPhoto,
    required this.onOpenObjects,
    required this.onOpenReview,
    required this.onOpenGeometry,
    required this.onOpenFloors,
    required this.onOpenSettings,
    this.onOpenMaterials,
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
  final VoidCallback? onOpenAR;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenGeometry;
  final VoidCallback onOpenFloors;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenMaterials;
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
  bool _saving = false;

  void _selectView(ZMeasureViewMode value) {
    if (value == ZMeasureViewMode.twoD) {
      if (_view != value) setState(() => _view = value);
      return;
    }
    if (value == ZMeasureViewMode.threeD) {
      widget.onOpen3D();
      return;
    }
    if (value == ZMeasureViewMode.photo) {
      widget.onOpenPhoto();
      return;
    }
    // AR is intentionally disabled in [ZMeasureViewTabs] for this milestone.
  }

  Future<void> _saveNow() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 900),
            content: Text('Проект сохранён'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить проект: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameProject() async {
    final controller = TextEditingController(text: widget.project.name);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Название проекта'),
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
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == widget.project.name) return;

    final oldName = widget.project.name;
    setState(() => widget.project.name = value);
    try {
      await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => widget.project.name = oldName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось переименовать проект: $error')),
        );
      }
    }
  }

  Future<void> _openMaterials() async {
    final callback = widget.onOpenMaterials;
    if (callback != null) {
      callback();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MaterialsScreen(
          floor: widget.floor,
          project: widget.project,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showMeasureSettings() async {
    final height = TextEditingController(
      text: widget.floor.defaultHeightMm.round().toString(),
    );
    final socket = TextEditingController(
      text: widget.floor.defaultSocketHeightMm.round().toString(),
    );
    final switchHeight = TextEditingController(
      text: widget.floor.defaultSwitchHeightMm.round().toString(),
    );
    final wallLight = TextEditingController(
      text: widget.floor.defaultWallLightHeightMm.round().toString(),
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Настройки замера', style: ZamerTypography.h3),
                const SizedBox(height: 6),
                Text(
                  'Параметры применяются к текущему этажу и сохраняются в проект.',
                  style: ZamerTypography.caption,
                ),
                const SizedBox(height: 14),
                _NumberField(
                  controller: height,
                  label: 'Высота помещения',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: socket,
                        label: 'Розетки',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NumberField(
                        controller: switchHeight,
                        label: 'Выключатели',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _NumberField(
                  controller: wallLight,
                  label: 'Настенные светильники',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'save'),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить настройки'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'floors'),
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Этажи'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'materials'),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Материалы и отделка'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'more'),
                  icon: const Icon(Icons.more_horiz_rounded),
                  label: const Text('Другие действия проекта'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == 'save') {
      final newHeight = double.tryParse(height.text.replaceAll(',', '.'));
      final newSocket = double.tryParse(socket.text.replaceAll(',', '.'));
      final newSwitch =
          double.tryParse(switchHeight.text.replaceAll(',', '.'));
      final newWallLight =
          double.tryParse(wallLight.text.replaceAll(',', '.'));
      if (newHeight != null && newHeight >= 1000 && newHeight <= 10000) {
        widget.floor.defaultHeightMm = newHeight;
      }
      if (newSocket != null && newSocket >= 0 && newSocket <= 4000) {
        widget.floor.defaultSocketHeightMm = newSocket;
      }
      if (newSwitch != null && newSwitch >= 0 && newSwitch <= 4000) {
        widget.floor.defaultSwitchHeightMm = newSwitch;
      }
      if (newWallLight != null && newWallLight >= 0 && newWallLight <= 6000) {
        widget.floor.defaultWallLightHeightMm = newWallLight;
      }
      await _saveNow();
    } else if (result == 'floors') {
      widget.onOpenFloors();
    } else if (result == 'materials') {
      await _openMaterials();
    } else if (result == 'more') {
      widget.onOpenSettings();
    }

    height.dispose();
    socket.dispose();
    switchHeight.dispose();
    wallLight.dispose();
  }

  Future<void> _showTutorial() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Обучение', style: ZamerTypography.h3),
              const SizedBox(height: 12),
              const _TutorialRow(
                number: '1',
                title: 'Стены',
                text: 'Выберите «Стены»: первая точка начинает стену, вторая задаёт её конец.',
              ),
              const _TutorialRow(
                number: '2',
                title: 'Проёмы',
                text: 'Выберите «Проёмы» и нажмите на нужную стену.',
              ),
              const _TutorialRow(
                number: '3',
                title: 'Размеры',
                text: 'Выберите две существующие точки плана для контрольного размера.',
              ),
              const _TutorialRow(
                number: '4',
                title: 'Проверка',
                text: 'Запустите проверку перед PDF, чтобы увидеть незамкнутые контуры и ошибки.',
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onOpenReview();
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Открыть проверку'),
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
              onRename: _renameProject,
              onUndo: widget.canUndo ? widget.onUndo : null,
              onRedo: widget.canRedo ? widget.onRedo : null,
              onMore: widget.onMore,
              onSave: _saveNow,
              saving: _saving,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 1, 10, 5),
              child: ZMeasureViewTabs(
                value: _view,
                enabledModes: const [
                  ZMeasureViewMode.twoD,
                  ZMeasureViewMode.threeD,
                  ZMeasureViewMode.photo,
                ],
                onChanged: _selectView,
              ),
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
                onOpenSettings: _showMeasureSettings,
                onOpenMaterials: _openMaterials,
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

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: 'мм'),
      );
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
    required this.saving,
  });

  final String projectName;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onMore;
  final Future<void> Function() onSave;
  final bool saving;

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
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onRename,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                onPressed: saving ? null : () => onSave(),
                child: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontSize: 9.6,
                          fontWeight: FontWeight.w800,
                        ),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: ZamerColors.textSecondary),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: ZamerColors.textSecondary,
                  fontSize: 7.7,
                  fontWeight: FontWeight.w500,
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
