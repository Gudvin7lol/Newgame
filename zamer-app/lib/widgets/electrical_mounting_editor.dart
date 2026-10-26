import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_mounting.dart';
import '../services/electrical_mounting_service.dart';

class ElectricalMountingEditor extends StatefulWidget {
  const ElectricalMountingEditor({
    super.key,
    required this.floor,
    required this.point,
  });
  final FloorPlan floor;
  final ElectricalPoint point;

  @override
  State<ElectricalMountingEditor> createState() =>
      _ElectricalMountingEditorState();
}

class _ElectricalMountingEditorState extends State<ElectricalMountingEditor> {
  final distance = TextEditingController(), height = TextEditingController();
  final inset = TextEditingController(), datumName = TextEditingController();
  final floorLevel = TextEditingController(),
      uncertainty = TextEditingController();
  late String datum;
  late String? wallId;
  late int side;
  late MountingSource source;
  String? error;
  PlanWall? get wall => wallId == null ? null : widget.floor.wallById(wallId!);

  String n(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  void initState() {
    super.initState();
    wallId = widget.point.wallId;
    final old = widget.point.mounting;
    final valid =
        ElectricalMountingService.problem(widget.floor, widget.point) == null;
    datum = valid ? old!.datumNodeId : wall?.startNodeId ?? '';
    side = widget.point.wallSide;
    source = valid ? old!.source : MountingSource.unknown;
    distance.text = n(valid ? old!.distanceMm : widget.point.wallOffsetMm ?? 0);
    inset.text = n(valid ? old!.datumInsetMm : 0);
    datumName.text = valid ? old!.datumName : 'Узел A (ось стены)';
    height.text = n(widget.point.heightMm);
    floorLevel.text = old?.finishedFloorAboveSlabMm == null
        ? ''
        : n(old!.finishedFloorAboveSlabMm!);
    uncertainty.text = valid && old?.measurementUncertaintyMm != null
        ? n(old!.measurementUncertaintyMm!)
        : '';
  }

  @override
  void dispose() {
    for (final c in [
      distance,
      height,
      inset,
      datumName,
      floorLevel,
      uncertainty,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double read(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v < 0) {
      throw const FormatException('Введите неотрицательный размер в мм.');
    }
    return v;
  }

  ElectricalMounting draft() {
    if (wall == null) {
      throw const FormatException('Сначала привяжите точку к стене на плане.');
    }
    return ElectricalMounting(
      wallId: wall!.id,
      datumNodeId: datum,
      datumName: datumName.text.trim(),
      datumInsetMm: read(inset),
      distanceMm: read(distance),
      heightAboveFinishedFloorMm: read(height),
      wallSide: side,
      source: source,
      finishedFloorAboveSlabMm: floorLevel.text.trim().isEmpty
          ? null
          : read(floorLevel),
      measurementUncertaintyMm: uncertainty.text.trim().isEmpty
          ? null
          : read(uncertainty),
      geometrySnapshot: ElectricalMountingService.snapshot(widget.floor, wall!),
    );
  }

  Widget field(
    TextEditingController controller,
    String label,
    String key, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => error = null),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'мм',
        helperText: hint,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ElectricalMounting? m;
    MountingPosition? position;
    String? invalid;
    try {
      m = draft();
      position = ElectricalMountingService.resolve(widget.floor, m);
    } on FormatException catch (e) {
      invalid = e.message;
    }
    final oldProblem = ElectricalMountingService.problem(
      widget.floor,
      widget.point,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Монтажная привязка')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const ValueKey('mount-apply'),
                onPressed: () {
                  try {
                    final result = draft();
                    ElectricalMountingService.resolve(widget.floor, result);
                    Navigator.pop(context, result);
                  } on FormatException catch (e) {
                    setState(() => error = e.message);
                  }
                },
                child: const Text('Применить к карточке'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Изменения запишутся после сохранения карточки точки.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.point.label.isEmpty ? widget.point.id : widget.point.label} · ${wall?.id ?? 'Нет стены'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Размер до проекции центра на ось стены. Узел оси не является чистовым углом.',
              ),
              if (widget.point.mounting != null && oldProblem != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    oldProblem,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (wall != null && position != null && m != null) ...[
                SizedBox(
                  height: 145,
                  child: CustomPaint(
                    painter: MountingElevationPainter(
                      length: widget.floor.wallLengthMm(wall!),
                      height:
                          wall!.heightOverrideMm ??
                          widget.floor.defaultHeightMm,
                      offset: position.offsetMm,
                      pointHeight: m.heightAboveFinishedFloorMm,
                      datumOffset: datum == wall!.startNodeId
                          ? m.datumInsetMm
                          : widget.floor.wallLengthMm(wall!) - m.datumInsetMm,
                      distance: m.distanceMm,
                      color: Theme.of(context).colorScheme.primary,
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const Text(
                  'Развёртка по оси · A → B · все размеры в мм',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                key: const ValueKey('mount-wall'),
                isExpanded: true,
                initialValue: wall?.id,
                decoration: const InputDecoration(labelText: 'Стена'),
                items: widget.floor.walls
                    .map(
                      (w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          'Стена ${widget.floor.walls.indexOf(w) + 1} · ${n(widget.floor.wallLengthMm(w))} мм',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null || v == wallId) return;
                  setState(() {
                    wallId = v;
                    datum = wall!.startNodeId;
                    inset.text = '0';
                    distance.text = '0';
                    datumName.text = 'Узел A (ось стены)';
                    source = MountingSource.unknown;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (wall != null)
                DropdownButtonFormField<String>(
                  key: ValueKey('mount-datum-$wallId'),
                  initialValue: datum,
                  decoration: const InputDecoration(
                    labelText: 'Откуда считать',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: wall!.startNodeId,
                      child: const Text('От узла A к B'),
                    ),
                    DropdownMenuItem(
                      value: wall!.endNodeId,
                      child: const Text('От узла B к A'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null || v == datum) return;
                    // Switching the reference must not silently move the point.
                    final currentOffset = position?.offsetMm;
                    setState(() {
                      datum = v;
                      inset.text = '0';
                      if (currentOffset != null) {
                        distance.text = n(
                          v == wall!.startNodeId
                              ? currentOffset
                              : widget.floor.wallLengthMm(wall!) -
                                    currentOffset,
                        );
                      }
                      datumName.text = v == wall!.startNodeId
                          ? 'Узел A (ось стены)'
                          : 'Узел B (ось стены)';
                    });
                  },
                ),
              const SizedBox(height: 16),
              field(
                distance,
                widget.point.modules.length > 1
                    ? 'От базы до центра рамки'
                    : 'От базы до центра',
                'mount-distance',
              ),
              field(height, 'Центр над чистым полом', 'mount-height'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: side == -1,
                title: const Text('Обратная сторона стены'),
                subtitle: Text(
                  side == 1
                      ? 'Выбрана сторона +, слева от A → B'
                      : 'Выбрана сторона −, справа от A → B',
                ),
                onChanged: (v) => setState(() => side = v ? -1 : 1),
              ),
              DropdownButtonFormField<MountingSource>(
                key: const ValueKey('mount-source'),
                initialValue: source,
                decoration: const InputDecoration(
                  labelText: 'Источник размеров',
                ),
                items: const [
                  DropdownMenuItem(
                    value: MountingSource.unknown,
                    child: Text('Не указан'),
                  ),
                  DropdownMenuItem(
                    value: MountingSource.measured,
                    child: Text('Измерено на объекте'),
                  ),
                  DropdownMenuItem(
                    value: MountingSource.document,
                    child: Text('Из документа'),
                  ),
                  DropdownMenuItem(
                    value: MountingSource.designed,
                    child: Text('Задано проектом'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => source = v ?? MountingSource.unknown),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Монтажная база и отметка плиты'),
                tilePadding: EdgeInsets.zero,
                children: [
                  const Text(
                    'Можно задать обмеренную базу вдоль стены. Смещение направлено от выбранного узла внутрь стены. Толщина отделки автоматически не определяется.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('mount-name'),
                    controller: datumName,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Название базы',
                    ),
                  ),
                  const SizedBox(height: 12),
                  field(inset, 'От узла оси до базы', 'mount-inset'),
                  field(
                    floorLevel,
                    'Чистый пол выше плиты',
                    'mount-floor',
                    hint: 'Пусто — отметка плиты неизвестна',
                  ),
                  field(
                    uncertainty,
                    'Погрешность исходного размера',
                    'mount-uncertainty',
                    hint: 'Пусто — не установлена',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  m?.heightAboveSlabMm == null
                      ? 'От плиты: нет данных'
                      : 'Центр над плитой: ${n(m!.heightAboveSlabMm!)} мм',
                ),
              ),
              if (widget.point.modules.length > 1)
                const Text(
                  'Показан центр рамки. Межосевые размеры и вырезы требуют выбранной серии изделия.',
                ),
              if ((error ?? invalid) != null)
                Text(
                  error ?? invalid ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class MountingElevationPainter extends CustomPainter {
  const MountingElevationPainter({
    required this.length,
    required this.height,
    required this.offset,
    required this.pointHeight,
    required this.datumOffset,
    required this.distance,
    required this.color,
    this.textStyle,
  });
  final double length, height, offset, pointHeight, datumOffset, distance;
  final Color color;
  final TextStyle? textStyle;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, top = 12.0, bottom = 112.0;
    final width = size.width - 56;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTRB(left, top, left + width, bottom), paint);
    final x = left + offset / length * width,
        y = bottom - pointHeight / height * (bottom - top);
    final dx = left + datumOffset / length * width;
    canvas.drawCircle(Offset(x, y), 5, paint);
    canvas.drawLine(Offset(dx, 130), Offset(x, 130), paint);
    for (final end in [dx, x]) {
      canvas.drawLine(Offset(end, 125), Offset(end, 135), paint);
    }
    void label(String value, Offset at) {
      final t = TextPainter(
        text: TextSpan(
          text: value,
          style: (textStyle ?? const TextStyle()).copyWith(
            fontSize: 11,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, at);
    }

    label('A', const Offset(7, 103));
    label('B', Offset(left + width + 5, 103));
    label(distance.toString(), Offset((dx + x) / 2 - 14, 113));
    label(
      'h ${pointHeight.toString()}',
      Offset(
        x.clamp(left, left + width - 65).toDouble(),
        (y - 20).clamp(0, 92).toDouble(),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant MountingElevationPainter old) => true;
}
