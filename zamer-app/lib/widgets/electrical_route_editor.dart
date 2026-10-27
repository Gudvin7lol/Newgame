import 'package:flutter/material.dart';

import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';
import '../services/electrical_route_service.dart';

class ElectricalRouteEditResult {
  const ElectricalRouteEditResult(this.path, this.reserveMm);
  final ElectricalRoute3d path;
  final double? reserveMm;
}

/// The parent editor owns the final commit and undo entry.
class ElectricalRouteEditor extends StatefulWidget {
  const ElectricalRouteEditor({
    super.key,
    required this.floor,
    required this.cable,
    this.initial,
  });
  final FloorPlan floor;
  final ElectricalCableRecord cable;
  final ElectricalRoute3d? initial;

  @override
  State<ElectricalRouteEditor> createState() => _ElectricalRouteEditorState();
}

class _ElectricalRouteEditorState extends State<ElectricalRouteEditor> {
  late ElectricalRoute3d route;
  late final TextEditingController reserve;
  String? error;

  ElectricalPoint get start => widget.floor.electricalPoints
      .firstWhere((p) => p.id == widget.cable.fromPointId);
  ElectricalPoint get finish => widget.floor.electricalPoints
      .firstWhere((p) => p.id == widget.cable.toPointId);

  @override
  void initState() {
    super.initState();
    route = widget.initial == null
        ? ElectricalRoute3d(
            id: 'route-' + widget.cable.id,
            fromPointId: widget.cable.fromPointId,
            toPointId: widget.cable.toPointId,
            vertices: [ElectricalRouteService.endpoint(start)],
            methods: [],
          )
        : ElectricalRoute3d.fromJson(widget.initial!.toJson());
    reserve = TextEditingController(
      text: widget.cable.explicitReserveMm?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    reserve.dispose();
    super.dispose();
  }

  String fmt(double n) => n == n.truncateToDouble()
      ? n.toStringAsFixed(0)
      : n.toStringAsFixed(2);

  double? reserveValue() {
    final raw = reserve.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || !n.isFinite || n < 0 || n > 10000000) {
      throw const FormatException('Монтажный запас должен быть неотрицательным.');
    }
    return n;
  }

  Future<void> addLeg() async {
    var axis = 'X';
    var method = ElectricalInstallationMethod.unspecified;
    var amount = '';
    final entry = await showDialog<(String, double, ElectricalInstallationMethod)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Новый участок'),
          scrollable: true,
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Укажите ось и длину со знаком, например '
                  'X = 1200, Z = -250. Размеры в мм.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('route-leg-axis'),
                isExpanded: true,
                initialValue: axis,
                decoration: const InputDecoration(labelText: 'Ось'),
                items: const [
                  DropdownMenuItem(value: 'X', child: Text('X · вдоль плана')),
                  DropdownMenuItem(value: 'Y', child: Text('Y · поперёк плана')),
                  DropdownMenuItem(value: 'Z', child: Text('Z · высота')),
                ],
                onChanged: (v) => refresh(() => axis = v ?? 'X'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('route-leg-length'),
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                onChanged: (v) => amount = v,
                decoration: const InputDecoration(
                    labelText: 'Смещение со знаком', suffixText: 'мм'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ElectricalInstallationMethod>(
                key: const ValueKey('route-leg-method'),
                isExpanded: true,
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Прокладка'),
                items: const [
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.unspecified,
                      child: Text('Не уточнена')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.inWall,
                      child: Text('В стене')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.aboveCeiling,
                      child: Text('Над потолком')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.inFloor,
                      child: Text('В полу')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.exposed,
                      child: Text('Открыто')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.conduit,
                      child: Text('В трубе')),
                  DropdownMenuItem(
                      value: ElectricalInstallationMethod.tray,
                      child: Text('В лотке')),
                ],
                onChanged: (v) => refresh(() =>
                    method = v ?? ElectricalInstallationMethod.unspecified),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('route-leg-apply'),
              onPressed: () {
                final mm = double.tryParse(amount.trim().replaceAll(',', '.'));
                if (mm == null || !mm.isFinite || mm == 0) return;
                Navigator.pop(dialog, (axis, mm, method));
              },
              child: const Text('Добавить участок'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || entry == null) return;
    try {
      final next = ElectricalRouteService.step(
        route.vertices.last, entry.$1, entry.$2,
      );
      setState(() {
        route.vertices.add(next);
        route.methods.add(entry.$3);
        error = null;
      });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  void save() {
    try {
      final reserveMm = reserveValue();
      ElectricalRouteService.measure(
        widget.floor, route, reserveMm: reserveMm,
      );
      Navigator.pop(context, ElectricalRouteEditResult(
          ElectricalRoute3d.fromJson(route.toJson()), reserveMm));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = ElectricalRouteService.endpoint(finish);
    final last = route.vertices.last;
    final remaining = ElectricalRouteVertex(
      xMm: target.xMm - last.xMm,
      yMm: target.yMm - last.yMm,
      zMm: target.zMm - last.zMm,
    );
    ElectricalRouteMeasurement? measured;
    String? check;
    try {
      measured = ElectricalRouteService.measure(
        widget.floor, route, reserveMm: reserveValue(),
      );
    } on FormatException catch (e) {
      check = e.message;
    }
    var partialMm = 0.0;
    for (var i = 1; i < route.vertices.length; i++) {
      partialMm += route.vertices[i - 1].distanceTo(route.vertices[i]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Трасса кабеля')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          children: [
            Text('Проектные координаты в мм, Z от чистого пола.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text('От: ' + widget.cable.fromPointId + ' (' +
                fmt(start.xMm) + ', ' + fmt(start.yMm) + ', ' +
                fmt(start.heightMm) + ')'),
            Text('До: ' + widget.cable.toPointId + ' (' +
                fmt(finish.xMm) + ', ' + fmt(finish.yMm) + ', ' +
                fmt(finish.heightMm) + ')'),
            const SizedBox(height: 14),
            DropdownButtonFormField<ElectricalPathSource>(
              key: const ValueKey('route-source'),
              isExpanded: true,
              initialValue: route.source,
              decoration: const InputDecoration(
                  labelText: 'Источник геометрии'),
              items: const [
                DropdownMenuItem(
                    value: ElectricalPathSource.unspecified,
                    child: Text('Не подтверждена')),
                DropdownMenuItem(
                    value: ElectricalPathSource.drawing,
                    child: Text('По проектному плану')),
                DropdownMenuItem(
                    value: ElectricalPathSource.measured,
                    child: Text('Обмерено на объекте')),
              ],
              onChanged: (v) => setState(() =>
                  route.source = v ?? ElectricalPathSource.unspecified),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Участки',
                  style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                key: const ValueKey('route-add-leg'),
                onPressed: addLeg,
                icon: const Icon(Icons.add),
                label: const Text('Участок'),
              ),
            ]),
            if (route.methods.isEmpty)
              const Text('Добавьте горизонтальный или вертикальный '
                  'участок с известным размером.'),
            for (var i = 0; i < route.methods.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text((i + 1).toString()),
                title: Text(fmt(route.vertices[i].distanceTo(
                    route.vertices[i + 1])) + ' мм'),
                subtitle: Text(route.methods[i].name),
              ),
            if (route.methods.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('route-remove-last'),
                  onPressed: () => setState(() {
                    route.methods.removeLast();
                    route.vertices.removeLast();
                    error = null;
                  }),
                  icon: const Icon(Icons.undo),
                  label: const Text('Убрать последний участок'),
                ),
              ),
            const Divider(height: 24),
            Text('Пройдено по геометрии: ' + fmt(partialMm / 1000) + ' м'),
            const SizedBox(height: 8),
            Text('До конца: X ' + fmt(remaining.xMm) + ', Y ' +
                fmt(remaining.yMm) + ', Z ' + fmt(remaining.zMm) + ' мм',
                key: const ValueKey('route-remaining')),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('route-reserve'),
              controller: reserve,
              onChanged: (_) => setState(() => error = null),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Дополнительный монтажный запас',
                suffixText: 'мм',
                helperText: 'Пусто — запас неизвестен, не считается нулём',
              ),
            ),
            if (measured != null) ...[
              const SizedBox(height: 10),
              Text('Длина трассы: ' +
                  fmt(measured.geometricMm / 1000) + ' м'),
              Text(measured.procurementLengthMm == null
                  ? 'Длина с запасом не определена'
                  : 'Длина с запасом: ' +
                      fmt(measured.procurementLengthMm! / 1000) + ' м'),
            ],
            if ((error ?? check) != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error ?? check!,
                  key: const ValueKey('route-validation'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            Text('Расчёт по введённым размерам не подтверждает '
                'соответствие нормативам или фактическому монтажу.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: FilledButton(
            key: const ValueKey('route-save'),
            onPressed: check == null ? save : null,
            child: const Text('Сохранить трассу'),
          ),
        ),
      ),
    );
  }
}
