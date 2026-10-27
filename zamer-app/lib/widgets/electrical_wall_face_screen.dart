import 'package:flutter/material.dart';

import '../models/electrical_wall_face.dart';
import '../models/models.dart';
import '../services/electrical_mounting_service.dart';
import '../services/electrical_wall_face_service.dart';

class ElectricalWallFaceScreen extends StatefulWidget {
  const ElectricalWallFaceScreen({
    super.key,
    required this.floor,
    required this.onSaveFace,
  });

  final FloorPlan floor;
  final Future<void> Function(
      String wallId, int side, WallFaceFinish? finish) onSaveFace;

  @override
  State<ElectricalWallFaceScreen> createState() =>
      _ElectricalWallFaceScreenState();
}

class _ElectricalWallFaceScreenState extends State<ElectricalWallFaceScreen> {
  String? wallId;
  int side = 1;

  @override
  void initState() {
    super.initState();
    wallId = widget.floor.walls
        .where((w) => !w.demolition &&
            w.projectLayer != ProjectLayer.demolition)
        .firstOrNull?.id;
  }

  String mm(double value) => value.toStringAsFixed(1) + ' мм';

  Future<void> _edit() async {
    final id = wallId;
    if (id == null) return;
    final wall = widget.floor.wallById(id);
    if (wall == null) return;
    final previous = ElectricalWallFaceService.saved(wall, side);
    final input = TextEditingController(
        text: previous?.thicknessMm.toStringAsFixed(1) ?? '');
    var source = previous?.source ?? WallFinishSource.unknown;
    final decision = await showDialog<_FaceDecision>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, redraw) => AlertDialog(
          title: const Text('Отделка поверхности'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ElectricalWallFaceService.sideLabel(side)),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('face-thickness-input'),
                controller: input,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Толщина отделки, мм',
                  helperText: 'Ноль указывается явно. Пусто ≠ ноль.',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WallFinishSource>(
                initialValue: source,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Источник'),
                items: const [
                  DropdownMenuItem(value: WallFinishSource.unknown,
                      child: Text('Не подтверждено')),
                  DropdownMenuItem(value: WallFinishSource.design,
                      child: Text('Проект')),
                  DropdownMenuItem(value: WallFinishSource.document,
                      child: Text('Документ')),
                  DropdownMenuItem(value: WallFinishSource.measured,
                      child: Text('Введённый обмер')),
                ],
                onChanged: (value) {
                  if (value != null) redraw(() => source = value);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog,
                  const _FaceDecision(null)),
              child: const Text('Размер неизвестен'),
            ),
            FilledButton(
              key: const ValueKey('face-save'),
              onPressed: () {
                final amount = double.tryParse(input.text.trim()
                    .replaceAll(',', '.'));
                if (amount == null || !amount.isFinite ||
                    amount < 0 || amount > 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(
                        'Укажите толщину отделки от 0 до 500 мм.')),
                  );
                  return;
                }
                Navigator.pop(dialog, _FaceDecision(WallFaceFinish(
                    thicknessMm: amount, source: source)));
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (decision == null || !mounted) return;
    try {
      await widget.onSaveFace(id, side, decision.finish);
      if (mounted) setState(() {});
    } on FormatException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walls = widget.floor.walls.where((w) =>
        !w.demolition && w.projectLayer != ProjectLayer.demolition).toList();
    if (!walls.any((w) => w.id == wallId)) wallId = walls.firstOrNull?.id;
    final wall = wallId == null ? null : widget.floor.wallById(wallId!);
    final finish = wall == null ? null :
        ElectricalWallFaceService.saved(wall, side);
    final points = widget.floor.electricalPoints.where((p) =>
        p.wallId == wallId && p.wallSide == side).toList();
    String? issue;
    if (wall != null) {
      try {
        ElectricalWallFaceService.validate(widget.floor, wall, side, finish);
      } on FormatException catch (e) {
        issue = e.message;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Стороны и отделка стен')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('electrical-wall-faces'),
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Монтажные размеры от чистовой поверхности'),
            const SizedBox(height: 7),
            const Text('Стороны определяются по направлению от начального '
                'узла стены к конечному. Модель не подтверждает фактические '
                'толщины, обмер и пригодность стены к штроблению.'),
            const SizedBox(height: 15),
            if (walls.isEmpty)
              const Text('В плане нет доступных стен.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('face-wall-' + (wallId ?? 'none')),
                isExpanded: true,
                initialValue: wallId,
                decoration: const InputDecoration(labelText: 'Стена'),
                items: [
                  for (var i = 0; i < walls.length; i++)
                    DropdownMenuItem(value: walls[i].id,
                      child: Text('Стена ' + (i+1).toString() +
                          ' · ' + walls[i].id,
                          overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => setState(() => wallId = id),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                key: const ValueKey('face-side-control'),
                segments: const [
                  ButtonSegment(value: 1, label: Text('Левая')),
                  ButtonSegment(value: -1, label: Text('Правая')),
                ],
                selected: {side},
                onSelectionChanged: (v) => setState(() => side = v.first),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ElectricalWallFaceService.sideLabel(side),
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Конструктивная толщина: ' +
                          mm(wall!.thicknessMm) + ' (данные модели)'),
                      Text(finish == null
                          ? 'Толщина отделки: неизвестно'
                          : 'Толщина отделки: ' + mm(finish.thicknessMm),
                          key: const ValueKey('face-finish-status')),
                      Text(finish == null
                          ? 'Плоскость чистовой поверхности не рассчитана'
                          : 'Расстояние ось → чистовая плоскость: ' +
                              mm(wall.thicknessMm / 2 +
                                  finish.thicknessMm)),
                      Text(finish == null
                          ? 'Источник: не указан'
                          : 'Источник: ' + switch(finish.source) {
                              WallFinishSource.unknown => 'не подтверждён',
                              WallFinishSource.design => 'проект',
                              WallFinishSource.document => 'документ',
                              WallFinishSource.measured => 'введённый обмер',
                            }),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const ValueKey('face-edit-button'),
                          onPressed: _edit,
                          icon: const Icon(Icons.straighten),
                          label: const Text('Уточнить отделку'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (issue != null)
                Text(issue,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 15),
              Text('Электроточки на выбранной стороне',
                  style: Theme.of(context).textTheme.titleMedium),
              if (points.isEmpty)
                const Text('На эту сторону не назначены электроточки.'),
              for (final point in points)
                Card(
                  child: ListTile(
                    key: ValueKey('face-device-' + point.id),
                    title: Text(point.label.isEmpty
                        ? point.type.label : point.label),
                    subtitle: Text(_deviceInfo(point, issue)),
                    isThreeLine: true,
                  ),
                ),
              const SizedBox(height: 10),
              const Text('Положительное расстояние от поверхности направлено '
                  'к левой нормали оси стены. Отрицательное к правой. '
                  'Показание не перемещает электроточку. '
                  'Перед монтажом нужны проверка геометрии и база от угла.'),
            ],
          ],
        ),
      ),
    );
  }

  String _deviceInfo(ElectricalPoint point, String? wallProblem) {
    if (wallProblem != null || wallId == null) {
      return 'Плоскость не определена: требуется проверка стены.';
    }
    final projection = ElectricalWallFaceService.project(widget.floor,
        wallId!, side, xMm: point.xMm, yMm: point.yMm);
    final issue = ElectricalMountingService.problem(widget.floor, point);
    return 'От начала оси: ' + mm(projection.uMm) +
        ' · высота: ' + mm(point.heightMm) +
        '\nОт чистовой плоскости: ' +
        (projection.signedDistanceToFaceMm == null
            ? 'неизвестно'
            : mm(projection.signedDistanceToFaceMm!)) +
        '\nМонтажная база: ' + (issue ?? 'актуальна по проекту');
  }
}

class _FaceDecision {
  const _FaceDecision(this.finish);
  final WallFaceFinish? finish;
}
