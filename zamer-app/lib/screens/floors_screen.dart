import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import 'estimate_screen.dart';
import 'floor_workspace_screen.dart';

class FloorsScreen extends StatefulWidget {
  const FloorsScreen({
    super.key,
    required this.project,
    required this.onChanged,
  });

  final MeasureProject project;
  final Future<void> Function() onChanged;

  @override
  State<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends State<FloorsScreen> {
  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';

  List<FloorPlan> _floorSnapshot() => widget.project.floors
      .map((floor) => FloorPlan.fromJson(floor.toJson()))
      .toList();

  Future<void> _createRevision({String? label}) async {
    final defaultLabel = 'Версия ${widget.project.revisions.length + 1}';
    final name =
        label ??
        await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            final controller = TextEditingController(text: defaultLabel);
            return AlertDialog(
              title: const Text('Сохранить версию'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Название версии',
                  prefixIcon: Icon(Icons.history_rounded),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  ),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
    if (name == null || name.isEmpty) return;
    widget.project.revisions.add(
      ProjectRevision(
        label: name,
        createdAt: DateTime.now(),
        floors: _floorSnapshot(),
        unitPrices: Map.of(widget.project.unitPrices),
        workRates: Map.of(widget.project.workRates),
      ),
    );
    if (widget.project.revisions.length > 8) {
      widget.project.revisions.removeAt(0);
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _restoreRevision(ProjectRevision revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Восстановить «${revision.label}»?'),
        content: const Text(
          'Текущий план сначала сохранится отдельной версией.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.project.revisions.add(
      ProjectRevision(
        label: 'Перед восстановлением',
        createdAt: DateTime.now(),
        floors: _floorSnapshot(),
        unitPrices: Map.of(widget.project.unitPrices),
        workRates: Map.of(widget.project.workRates),
      ),
    );
    if (widget.project.revisions.length > 8) {
      widget.project.revisions.removeAt(0);
    }
    widget.project.floors
      ..clear()
      ..addAll(
        revision.floors.map((floor) => FloorPlan.fromJson(floor.toJson())),
      );
    widget.project.unitPrices
      ..clear()
      ..addAll(revision.unitPrices);
    widget.project.workRates
      ..clear()
      ..addAll(revision.workRates);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _showRevisions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .75,
        child: ZSheetFrame(
          title: 'Версии проекта',
          description:
              'Можно хранить до 8 контрольных снимков проекта и вернуться к любому из них.',
          child: Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _createRevision();
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Сохранить текущую версию'),
                  ),
                ),
                const SizedBox(height: ZamerSpace.md),
                Expanded(
                  child: widget.project.revisions.isEmpty
                      ? const ZEmptyState(
                          icon: Icons.history_toggle_off_outlined,
                          title: 'Версий пока нет',
                          subtitle:
                              'Сохрани контрольную версию перед крупными изменениями планировки.',
                        )
                      : ListView.separated(
                          itemCount: widget.project.revisions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: ZamerSpace.sm),
                          itemBuilder: (_, index) {
                            final revision = widget.project.revisions.reversed
                                .elementAt(index);
                            return ZCard(
                              padding: EdgeInsets.zero,
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await _restoreRevision(revision);
                              },
                              child: ListTile(
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: ZamerColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(
                                      ZamerRadius.sm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: ZamerColors.accent,
                                    size: 19,
                                  ),
                                ),
                                title: Text(
                                  revision.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${revision.createdAt.toLocal().toString().substring(0, 16)} • ${revision.floors.length} эт.',
                                ),
                                trailing: const Icon(Icons.restore_rounded),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FloorPlan _copyFloor(FloorPlan source, String name) => FloorPlan(
    id: _id('f'),
    name: name,
    defaultHeightMm: source.defaultHeightMm,
    notes: source.notes,
    nodes: source.nodes.map((e) => PlanNode.fromJson(e.toJson())).toList(),
    walls: source.walls.map((e) => PlanWall.fromJson(e.toJson())).toList(),
    measures: source.measures
        .map((e) => ControlMeasure.fromJson(e.toJson()))
        .toList(),
    roomMetas: source.roomMetas
        .map((e) => RoomMeta.fromJson(e.toJson()))
        .toList(),
    electricalPoints: source.electricalPoints
        .map((e) => ElectricalPoint.fromJson(e.toJson()))
        .toList(),
    electricalRuns: source.electricalRuns
        .map((e) => ElectricalRun.fromJson(e.toJson()))
        .toList(),
    serviceRuns: source.serviceRuns
        .map((e) => ServiceRun.fromJson(e.toJson()))
        .toList(),
    planObjects: source.planObjects
        .map((e) => PlanObject.fromJson(e.toJson()))
        .toList(),
    defaultSocketHeightMm: source.defaultSocketHeightMm,
    defaultSwitchHeightMm: source.defaultSwitchHeightMm,
    defaultWallLightHeightMm: source.defaultWallLightHeightMm,
  );

  Future<void> _addFloor() async {
    final defaultName = 'Этаж ${widget.project.floors.length + 1}';
    final c = TextEditingController(text: defaultName);
    var copyPrevious = widget.project.floors.isNotEmpty;
    final result = await showDialog<({String name, bool copy})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Новый этаж'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
              ),
              if (widget.project.floors.isNotEmpty) ...[
                const SizedBox(height: ZamerSpace.md),
                Container(
                  decoration: BoxDecoration(
                    color: ZamerColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(ZamerRadius.md),
                    border: Border.all(color: ZamerColors.outlineSoft),
                  ),
                  child: SwitchListTile.adaptive(
                    value: copyPrevious,
                    onChanged: (v) => setModal(() => copyPrevious = v),
                    title: const Text('Скопировать предыдущий этаж'),
                    subtitle: const Text(
                      'Планировка, проёмы, электрика, объекты и настройки будут продублированы.',
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = c.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  (name: name, copy: copyPrevious),
                );
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final floor = result.copy && widget.project.floors.isNotEmpty
        ? _copyFloor(widget.project.floors.last, result.name)
        : FloorPlan(id: _id('f'), name: result.name);
    setState(() => widget.project.floors.add(floor));
    await widget.onChanged();
  }

  Future<void> _open(FloorPlan floor) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorWorkspaceScreen(
          project: widget.project,
          floor: floor,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.project.floors;
    final totalRooms = floors.fold<int>(
      0,
      (sum, floor) => sum + GeometryService.roomFaces(floor).length,
    );
    final totalWalls = floors.fold<int>(
      0,
      (sum, floor) => sum + floor.walls.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name),
            const Text('Этажи проекта', style: ZamerTypography.caption),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Автосмета',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EstimateScreen(
                  project: widget.project,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Версии проекта',
            onPressed: _showRevisions,
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: ZamerSpace.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFloor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить этаж'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.sm,
              ZamerSpace.md,
              ZamerSpace.sm,
            ),
            decoration: const BoxDecoration(
              color: ZamerColors.surfaceLow,
              border: Border(
                bottom: BorderSide(color: ZamerColors.outlineSoft),
              ),
            ),
            child: Row(
              children: [
                _ProjectStat(
                  icon: Icons.layers_outlined,
                  value: '${floors.length}',
                  label: 'этажей',
                ),
                const SizedBox(width: ZamerSpace.sm),
                _ProjectStat(
                  icon: Icons.grid_view_outlined,
                  value: '$totalRooms',
                  label: 'помещений',
                ),
                const SizedBox(width: ZamerSpace.sm),
                _ProjectStat(
                  icon: Icons.square_foot_outlined,
                  value: '$totalWalls',
                  label: 'стен',
                ),
              ],
            ),
          ),
          Expanded(
            child: floors.isEmpty
                ? ZEmptyState(
                    icon: Icons.layers_clear_outlined,
                    title: 'В проекте пока нет этажей',
                    subtitle:
                        'Создай первый этаж, чтобы перейти к обмеру, 3D, оснащению и развёрткам.',
                    actionLabel: 'Создать этаж',
                    onAction: _addFloor,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      ZamerSpace.md,
                      ZamerSpace.md,
                      ZamerSpace.md,
                      100,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(ZamerSpace.md),
                        decoration: BoxDecoration(
                          color: ZamerColors.info.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(ZamerRadius.md),
                          border: Border.all(
                            color: ZamerColors.info.withValues(alpha: .25),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.copy_all_outlined,
                              color: ZamerColors.info,
                              size: 19,
                            ),
                            SizedBox(width: ZamerSpace.sm),
                            Expanded(
                              child: Text(
                                'Новый этаж по умолчанию можно создать копией предыдущего: геометрия, проёмы и инженерия сохранятся, а затем их можно изменить.',
                                style: ZamerTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZamerSpace.md),
                      for (var i = 0; i < floors.length; i++) ...[
                        _FloorCard(
                          index: i,
                          floor: floors[i],
                          roomCount: GeometryService.roomFaces(
                            floors[i],
                          ).length,
                          onTap: () => _open(floors[i]),
                        ),
                        if (i < floors.length - 1)
                          const SizedBox(height: ZamerSpace.sm),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FloorCard extends StatelessWidget {
  const _FloorCard({
    required this.index,
    required this.floor,
    required this.roomCount,
    required this.onTap,
  });

  final int index;
  final FloorPlan floor;
  final int roomCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZCard(
    padding: EdgeInsets.zero,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(ZamerSpace.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZamerColors.accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(
                color: ZamerColors.accent.withValues(alpha: .3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: ZamerColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'ЭТ',
                  style: TextStyle(
                    color: ZamerColors.textMuted,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZamerSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  floor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ZamerColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: ZamerSpace.md,
                  runSpacing: ZamerSpace.xs,
                  children: [
                    _FloorMeta(
                      icon: Icons.square_foot_outlined,
                      value: '${floor.walls.length} стен',
                    ),
                    _FloorMeta(
                      icon: Icons.grid_view_outlined,
                      value: '$roomCount пом.',
                    ),
                    _FloorMeta(
                      icon: Icons.height,
                      value: '${floor.defaultHeightMm.round()} мм',
                    ),
                    if (floor.planObjects.isNotEmpty)
                      _FloorMeta(
                        icon: Icons.chair_alt_outlined,
                        value: '${floor.planObjects.length} объектов',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: ZamerSpace.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: ZamerColors.textMuted,
          ),
        ],
      ),
    ),
  );
}

class _FloorMeta extends StatelessWidget {
  const _FloorMeta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: ZamerColors.textFaint),
      const SizedBox(width: 4),
      Text(value, style: ZamerTypography.caption),
    ],
  );
}

class _ProjectStat extends StatelessWidget {
  const _ProjectStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZamerSpace.sm,
        vertical: ZamerSpace.xs,
      ),
      decoration: BoxDecoration(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        border: Border.all(color: ZamerColors.outlineSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: ZamerColors.textMuted),
          const SizedBox(width: 5),
          Text(value, style: ZamerTypography.measurement),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ZamerColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
