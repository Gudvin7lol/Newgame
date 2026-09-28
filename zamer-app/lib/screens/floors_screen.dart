import 'package:flutter/material.dart';

import '../models/models.dart';
import 'floor_workspace_screen.dart';
import 'estimate_screen.dart';

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
          builder: (context) {
            final controller = TextEditingController(text: defaultLabel);
            return AlertDialog(
              title: const Text('Сохранить версию'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Название версии'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
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
    if (widget.project.revisions.length > 8)
      widget.project.revisions.removeAt(0);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _restoreRevision(ProjectRevision revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Восстановить «${revision.label}»?'),
        content: const Text(
          'Текущий план сначала сохранится отдельной версией.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
    if (widget.project.revisions.length > 8)
      widget.project.revisions.removeAt(0);
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'Версии проекта',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _createRevision();
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить текущую версию'),
              ),
              if (widget.project.revisions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Сохранённых версий пока нет.'),
                ),
              for (final revision in widget.project.revisions.reversed)
                ListTile(
                  title: Text(revision.label),
                  subtitle: Text(
                    '${revision.createdAt.toLocal().toString().substring(0, 16)} • ${revision.floors.length} этаж(а)',
                  ),
                  trailing: const Icon(Icons.restore),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _restoreRevision(revision);
                  },
                ),
            ],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('Новый этаж'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              if (widget.project.floors.isNotEmpty) ...[
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: copyPrevious,
                  onChanged: (v) => setModal(() => copyPrevious = v),
                  title: const Text('Скопировать предыдущий этаж'),
                  subtitle: const Text(
                    'Планировка, проёмы, электрика, объекты и настройки будут продублированы.',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = c.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context, (name: name, copy: copyPrevious));
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Этажи и планировка',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFloor,
        icon: const Icon(Icons.add),
        label: const Text('Этаж'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121C1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF263337)),
            ),
            child: const Row(
              children: [
                Icon(Icons.layers_outlined, color: Color(0xFF56D6A3)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'При создании следующего этажа план предыдущего копируется по умолчанию. Отдельные элементы можно менять после копирования.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...widget.project.floors.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF24483D),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Color(0xFF78E0B7),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    f.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${f.walls.length} стен • ${f.roomMetas.length} помещений • ${f.defaultHeightMm.round()} мм',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(f),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
