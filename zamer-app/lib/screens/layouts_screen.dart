import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/layout_service.dart';
import '../widgets/floor_layout_painter.dart';

class LayoutsScreen extends StatefulWidget {
  const LayoutsScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<LayoutsScreen> createState() => _LayoutsScreenState();
}

class _LayoutsScreenState extends State<LayoutsScreen> {
  String? _faceKey;
  FloorLayoutKind _kind = FloorLayoutKind.laminate;
  Timer? _saveTimer;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  List<RoomFace> _carpetFaces(List<RoomFace> faces, RoomFace active) {
    final ids = widget.floor.carpetRoomIds;
    if (!ids.contains(widget.floor.roomMetaByKey(active.key)?.id))
      return [active];
    return faces
        .where((f) => ids.contains(widget.floor.roomMetaByKey(f.key)?.id))
        .toList();
  }

  void _syncCarpet(RoomMaterialSettings source) {
    for (final meta in widget.floor.roomMetas) {
      if (!widget.floor.carpetRoomIds.contains(meta.id) ||
          identical(meta.materials, source))
        continue;
      LayoutService.copyFloorPattern(source, meta.materials);
    }
  }

  Future<void> _changedLayout(RoomMaterialSettings source) async {
    _syncCarpet(source);
    await widget.onChanged();
  }

  void _queueSave(RoomMaterialSettings source) {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 350),
      () => _changedLayout(source),
    );
  }

  Future<void> _chooseCarpet(
    List<RoomFace> faces,
    RoomFace current,
    RoomMaterialSettings source,
  ) async {
    final choices = widget.floor.carpetRoomIds.toSet()
      ..add(widget.floor.roomMetaByKey(current.key)!.id);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Единая раскладка по помещениям',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Выбери комнаты с одним направлением, форматом и швами.',
                ),
                for (final face in faces)
                  CheckboxListTile(
                    title: Text(widget.floor.roomMetaByKey(face.key)!.name),
                    value: choices.contains(
                      widget.floor.roomMetaByKey(face.key)!.id,
                    ),
                    onChanged: (value) => setModal(() {
                      final id = widget.floor.roomMetaByKey(face.key)!.id;
                      if (value == true) {
                        choices.add(id);
                      } else {
                        choices.remove(id);
                      }
                    }),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, Set.of(choices)),
                  child: const Text('Применить'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>{}),
                  child: const Text('Разъединить комнаты'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    final group = result.length >= 2 ? result : <String>{};
    widget.floor.carpetRoomIds
      ..clear()
      ..addAll(group);
    if (group.isNotEmpty) {
      widget.floor.carpetAnchorX = current.centroid.x;
      widget.floor.carpetAnchorY = current.centroid.y;
      _syncCarpet(source);
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<double?> _number(String title, double value, String suffix) {
    final c = TextEditingController(
      text: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
    );
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(c.text.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(RoomMaterialSettings s, String field) async {
    double? v;
    if (field == 'angle')
      v = await _number('Направление раскладки', s.floorDirectionDeg, '°');
    if (field == 'plankL')
      v = await _number('Длина панели', s.laminatePlankLengthMm, 'мм');
    if (field == 'plankW')
      v = await _number('Ширина панели', s.laminatePlankWidthMm, 'мм');
    if (field == 'lamX')
      v = await _number('Сдвиг ламината по X', s.laminateOffsetXMm, 'мм');
    if (field == 'lamY')
      v = await _number('Сдвиг ламината по Y', s.laminateOffsetYMm, 'мм');
    if (field == 'rollW')
      v = await _number('Ширина рулона подложки', s.underlayRollWidthMm, 'мм');
    if (field == 'sheetW')
      v = await _number('Ширина листа', s.underlaySheetWidthMm, 'мм');
    if (field == 'sheetH')
      v = await _number('Длина листа', s.underlaySheetHeightMm, 'мм');
    if (field == 'undX')
      v = await _number('Сдвиг подложки по X', s.underlayOffsetXMm, 'мм');
    if (field == 'undY')
      v = await _number('Сдвиг подложки по Y', s.underlayOffsetYMm, 'мм');
    if (field == 'tileW')
      v = await _number('Ширина плитки', s.tileWidthMm, 'мм');
    if (field == 'tileH')
      v = await _number('Высота плитки', s.tileHeightMm, 'мм');
    if (field == 'offX')
      v = await _number('Сдвиг раскладки по X', s.tileOffsetXMm, 'мм');
    if (field == 'offY')
      v = await _number('Сдвиг раскладки по Y', s.tileOffsetYMm, 'мм');
    if (field == 'grout')
      v = await _number('Ширина плиточного шва', s.floorTileGroutMm, 'мм');
    if (field == 'minCut')
      v = await _number(
        'Минимальная желательная подрезка',
        s.tileMinCutMm,
        'мм',
      );
    if (v == null ||
        (v <= 0 &&
            !{
              'angle',
              'offX',
              'offY',
              'lamX',
              'lamY',
              'undX',
              'undY',
            }.contains(field)))
      return;
    // A sub-millimetre format can schedule millions of paint operations on
    // every frame. Keep editable formats within practical product sizes.
    final minimum = switch (field) {
      'plankL' => 100.0,
      'plankW' => 40.0,
      'rollW' || 'sheetW' || 'sheetH' || 'tileW' || 'tileH' => 20.0,
      _ => 0.0,
    };
    if (minimum > 0 && (v < minimum || v > 10000)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Допустимый размер: ${minimum.round()}–10000 мм'),
          ),
        );
      return;
    }
    if (field == 'angle') s.floorDirectionDeg = v;
    if (field == 'plankL') s.laminatePlankLengthMm = v;
    if (field == 'plankW') s.laminatePlankWidthMm = v;
    if (field == 'lamX') s.laminateOffsetXMm = v;
    if (field == 'lamY') s.laminateOffsetYMm = v;
    if (field == 'rollW') s.underlayRollWidthMm = v;
    if (field == 'sheetW') s.underlaySheetWidthMm = v;
    if (field == 'sheetH') s.underlaySheetHeightMm = v;
    if (field == 'undX') s.underlayOffsetXMm = v;
    if (field == 'undY') s.underlayOffsetYMm = v;
    if (field == 'tileW') s.tileWidthMm = v;
    if (field == 'tileH') s.tileHeightMm = v;
    if (field == 'offX') s.tileOffsetXMm = v;
    if (field == 'offY') s.tileOffsetYMm = v;
    if (field == 'grout') s.floorTileGroutMm = v.clamp(0.5, 50);
    if (field == 'minCut') s.tileMinCutMm = v;
    await _changedLayout(s);
    if (mounted) setState(() {});
  }

  Future<void> _autoBalance(RoomFace face, RoomMaterialSettings s) async {
    final group = _carpetFaces(GeometryService.roomFaces(widget.floor), face);
    final best = group.length > 1
        ? LayoutService.originForGroup(
            group,
            s,
            math.Point(widget.floor.carpetAnchorX, widget.floor.carpetAnchorY),
            'best',
            'tile',
          )
        : LayoutService.originFor(face, s, 'best', 'tile');
    s.tileOffsetXMm = best.xMm;
    s.tileOffsetYMm = best.yMm;
    await _changedLayout(s);
    if (mounted) setState(() {});
  }

  Future<void> _align(
    RoomFace face,
    RoomMaterialSettings s,
    String mode,
  ) async {
    final kind = _kind.name;
    final group = _carpetFaces(GeometryService.roomFaces(widget.floor), face);
    final origin = group.length > 1
        ? LayoutService.originForGroup(
            group,
            s,
            math.Point(widget.floor.carpetAnchorX, widget.floor.carpetAnchorY),
            mode,
            kind,
          )
        : LayoutService.originFor(face, s, mode, kind);
    setState(() {
      switch (_kind) {
        case FloorLayoutKind.laminate:
          s.laminateOffsetXMm = origin.xMm;
          s.laminateOffsetYMm = origin.yMm;
        case FloorLayoutKind.underlay:
          s.underlayOffsetXMm = origin.xMm;
          s.underlayOffsetYMm = origin.yMm;
        case FloorLayoutKind.tile:
          s.tileOffsetXMm = origin.xMm;
          s.tileOffsetYMm = origin.yMm;
      }
    });
    await _changedLayout(s);
  }

  double _wrapped(double offset, double module) =>
      module > 0 ? offset % module : offset;

  void _normalizeOffsets(RoomMaterialSettings s) {
    switch (_kind) {
      case FloorLayoutKind.laminate:
        s.laminateOffsetXMm = _wrapped(
          s.laminateOffsetXMm,
          s.laminatePlankLengthMm,
        );
        s.laminateOffsetYMm = _wrapped(
          s.laminateOffsetYMm,
          s.laminatePlankWidthMm,
        );
      case FloorLayoutKind.underlay:
        s.underlayOffsetXMm = _wrapped(
          s.underlayOffsetXMm,
          s.underlayMode == 'sheet'
              ? s.underlaySheetWidthMm
              : s.underlayRollWidthMm,
        );
        s.underlayOffsetYMm = _wrapped(
          s.underlayOffsetYMm,
          s.underlayMode == 'sheet'
              ? s.underlaySheetHeightMm
              : s.underlayRollWidthMm,
        );
      case FloorLayoutKind.tile:
        s.tileOffsetXMm = _wrapped(s.tileOffsetXMm, s.tileWidthMm);
        s.tileOffsetYMm = _wrapped(s.tileOffsetYMm, s.tileHeightMm);
    }
  }

  void _nudge(RoomMaterialSettings s, double dx, double dy) {
    setState(() {
      switch (_kind) {
        case FloorLayoutKind.laminate:
          s.laminateOffsetXMm += dx;
          s.laminateOffsetYMm += dy;
          break;
        case FloorLayoutKind.underlay:
          s.underlayOffsetXMm += dx;
          s.underlayOffsetYMm += dy;
          break;
        case FloorLayoutKind.tile:
          s.tileOffsetXMm += dx;
          s.tileOffsetYMm += dy;
          break;
      }
      _normalizeOffsets(s);
    });
    _queueSave(s);
  }

  void _pan(RoomMaterialSettings s, DragUpdateDetails d, double scale) {
    final extra = _kind == FloorLayoutKind.tile && s.tilePattern == 'diagonal'
        ? 45.0
        : 0.0;
    final a = (s.floorDirectionDeg + extra) * math.pi / 180;
    final localDxPx = d.delta.dx * math.cos(a) + d.delta.dy * math.sin(a);
    final localDyPx = -d.delta.dx * math.sin(a) + d.delta.dy * math.cos(a);
    final dx = localDxPx / math.max(scale, 0.0001);
    final dy = localDyPx / math.max(scale, 0.0001);
    setState(() {
      switch (_kind) {
        case FloorLayoutKind.laminate:
          s.laminateOffsetXMm += dx;
          s.laminateOffsetYMm += dy;
          break;
        case FloorLayoutKind.underlay:
          s.underlayOffsetXMm += dx;
          s.underlayOffsetYMm += dy;
          break;
        case FloorLayoutKind.tile:
          s.tileOffsetXMm += dx;
          s.tileOffsetYMm += dy;
          break;
      }
      _normalizeOffsets(s);
    });
  }

  Future<void> _panEnd(RoomMaterialSettings s) async {
    _saveTimer?.cancel();
    await _changedLayout(s);
    if (mounted) setState(() {});
  }

  Future<void> _rotate(RoomMaterialSettings s, double delta) async {
    s.floorDirectionDeg = (s.floorDirectionDeg + delta) % 360;
    if (s.floorDirectionDeg < 0) s.floorDirectionDeg += 360;
    await _changedLayout(s);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty)
      return const Center(
        child: Text('Сначала создай хотя бы одно замкнутое помещение.'),
      );
    _faceKey ??= faces.first.key;
    final face = faces.firstWhere(
      (e) => e.key == _faceKey,
      orElse: () => faces.first,
    );
    final meta = widget.floor.roomMetaByKey(face.key)!;
    final s = meta.materials;
    final carpetFaces = _carpetFaces(faces, face);
    final carpetAnchor = carpetFaces.length > 1
        ? math.Point<double>(
            widget.floor.carpetAnchorX,
            widget.floor.carpetAnchorY,
          )
        : null;
    final area = face.areaM2;
    final laminatePieces =
        (area *
                (1 + s.floorWastePct / 100) /
                math.max(
                  0.001,
                  s.laminatePlankLengthMm * s.laminatePlankWidthMm / 1000000,
                ))
            .ceil();
    final underlayPacks = s.underlayMode == 'sheet'
        ? (area /
                  math.max(
                    0.001,
                    s.underlaySheetWidthMm * s.underlaySheetHeightMm / 1000000,
                  ))
              .ceil()
        : (area / math.max(0.1, s.underlayRollM2)).ceil();
    final tilePieces =
        (area *
                (1 + s.floorTileWastePct / 100) /
                math.max(0.001, s.tileWidthMm * s.tileHeightMm / 1000000))
            .ceil();
    final cuts = LayoutService.cutsFor(face, s);
    final nonZero = [
      cuts.leftMm,
      cuts.rightMm,
      cuts.topMm,
      cuts.bottomMm,
    ].where((v) => v > 0.5).toList();
    final minCut = nonZero.isEmpty
        ? double.infinity
        : nonZero.reduce((a, b) => math.min(a, b).toDouble());
    final thin = minCut.isFinite && minCut < s.tileMinCutMm;
    final laminateRows = LayoutService.laminateRows(face, s);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Материалы и раскладка',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Один рисунок пола для плана и 3D',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171F23),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2A3941)),
                    ),
                    child: Text(
                      '${meta.name} • ${face.areaM2.toStringAsFixed(1)} м²',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF1C79E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: face.key,
                decoration: const InputDecoration(labelText: 'Помещение'),
                items: faces
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.key,
                        child: Text(
                          '${widget.floor.roomMetaByKey(f.key)?.name ?? 'Помещение'} • ${f.areaM2.toStringAsFixed(2)} м²',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _faceKey = v),
              ),
              if (faces.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _chooseCarpet(faces, face, s),
                    icon: const Icon(Icons.layers_outlined, size: 18),
                    label: Text(
                      widget.floor.carpetRoomIds.isEmpty
                          ? 'Единый ковёр по помещениям'
                          : 'Единый ковёр • ${widget.floor.carpetRoomIds.length} помещения',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SegmentedButton<FloorLayoutKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: FloorLayoutKind.laminate,
                    icon: Icon(Icons.view_agenda_outlined),
                    label: Text('Ламинат'),
                  ),
                  ButtonSegment(
                    value: FloorLayoutKind.underlay,
                    icon: Icon(Icons.layers_outlined),
                    label: Text('Подложка'),
                  ),
                  ButtonSegment(
                    value: FloorLayoutKind.tile,
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Плитка'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (v) async {
                  setState(() => _kind = v.first);
                  if (_kind == FloorLayoutKind.laminate) {
                    s.floorMode = 'laminate';
                    s.floorTile = false;
                  } else if (_kind == FloorLayoutKind.tile) {
                    s.floorMode = 'tile';
                    s.floorTile = true;
                  }
                  await _changedLayout(s);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              color: const Color(0xFF0B1115),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFF243139)),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, c) {
                  final scale = carpetFaces.length > 1
                      ? LayoutService.groupPreviewScale(
                          carpetFaces,
                          c.maxWidth,
                          c.maxHeight,
                        )
                      : LayoutService.previewScale(
                          face,
                          c.maxWidth,
                          c.maxHeight,
                        );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => _pan(s, d, scale),
                    onPanEnd: (_) => _panEnd(s),
                    child: CustomPaint(
                      painter: FloorLayoutPainter(
                        floor: widget.floor,
                        face: face,
                        settings: s,
                        kind: _kind,
                        selectedFaces: carpetFaces,
                        worldAnchor: carpetAnchor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(
          height: math.min(300, MediaQuery.sizeOf(context).height * .32),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Card(
                color: const Color(0xFF11191E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFF243139)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _setting(
                              'Направление',
                              '${s.floorDirectionDeg.round()}°',
                              () => _edit(s, 'angle'),
                            ),
                          ),
                          if (_kind == FloorLayoutKind.laminate)
                            Expanded(
                              child: _setting(
                                'Панель',
                                '${s.laminatePlankLengthMm.round()}×${s.laminatePlankWidthMm.round()}',
                                () async {
                                  await _edit(s, 'plankL');
                                  await _edit(s, 'plankW');
                                },
                              ),
                            ),
                          if (_kind == FloorLayoutKind.underlay)
                            Expanded(
                              child: _setting(
                                s.underlayMode == 'sheet' ? 'Лист' : 'Рулон',
                                s.underlayMode == 'sheet'
                                    ? '${s.underlaySheetWidthMm.round()}×${s.underlaySheetHeightMm.round()}'
                                    : '${s.underlayRollWidthMm.round()} мм',
                                () async {
                                  if (s.underlayMode == 'sheet') {
                                    await _edit(s, 'sheetW');
                                    await _edit(s, 'sheetH');
                                  } else {
                                    await _edit(s, 'rollW');
                                  }
                                },
                              ),
                            ),
                          if (_kind == FloorLayoutKind.tile)
                            Expanded(
                              child: _setting(
                                'Плитка',
                                '${s.tileWidthMm.round()}×${s.tileHeightMm.round()}',
                                () async {
                                  await _edit(s, 'tileW');
                                  await _edit(s, 'tileH');
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _rotate(s, -90),
                            icon: const Icon(Icons.rotate_90_degrees_ccw),
                            label: const Text('-90°'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _rotate(s, 90),
                            icon: const Icon(Icons.rotate_90_degrees_cw),
                            label: const Text('+90°'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _align(face, s, 'symmetric'),
                            icon: const Icon(Icons.align_horizontal_center),
                            label: const Text('От центра'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _align(face, s, 'balanced'),
                            icon: const Icon(Icons.grid_4x4),
                            label: const Text('Без узких подрезок'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_kind == FloorLayoutKind.laminate) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Поперёк направления: ${laminateRows.crossSpanMm.round()} мм • примерно ${laminateRows.rows} рядов по ${s.laminatePlankWidthMm.round()} мм',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'straight',
                              label: Text('Обычная'),
                            ),
                            ButtonSegment(
                              value: 'herringbone',
                              label: Text('Ёлочка'),
                            ),
                          ],
                          selected: {s.laminatePattern},
                          onSelectionChanged: (v) async {
                            s.laminatePattern = v.first;
                            await _changedLayout(s);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        if (s.laminatePattern == 'straight')
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'half', label: Text('1/2')),
                              ButtonSegment(value: 'third', label: Text('1/3')),
                              ButtonSegment(
                                value: 'straight',
                                label: Text('Без смещения'),
                              ),
                            ],
                            selected: {s.laminateOffsetMode},
                            onSelectionChanged: (v) async {
                              s.laminateOffsetMode = v.first;
                              await _changedLayout(s);
                              setState(() {});
                            },
                          ),
                        const SizedBox(height: 8),
                        _offsetControls(
                          s,
                          'lamX',
                          'lamY',
                          s.laminateOffsetXMm,
                          s.laminateOffsetYMm,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Раскладку можно двигать пальцем по плану.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_kind == FloorLayoutKind.underlay) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'roll',
                              label: Text('Рулонная'),
                            ),
                            ButtonSegment(
                              value: 'sheet',
                              label: Text('Листовая'),
                            ),
                          ],
                          selected: {s.underlayMode},
                          onSelectionChanged: (v) async {
                            s.underlayMode = v.first;
                            await _changedLayout(s);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        _offsetControls(
                          s,
                          'undX',
                          'undY',
                          s.underlayOffsetXMm,
                          s.underlayOffsetYMm,
                        ),
                        if (s.underlayMode == 'sheet')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Листы укладываются со смещением каждого второго ряда на 1/2 листа.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                      if (_kind == FloorLayoutKind.tile) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'straight',
                              label: Text('Прямая'),
                            ),
                            ButtonSegment(value: 'half', label: Text('1/2')),
                            ButtonSegment(
                              value: 'diagonal',
                              label: Text('Диагональ'),
                            ),
                          ],
                          selected: {s.tilePattern},
                          onSelectionChanged: (v) async {
                            s.tilePattern = v.first;
                            await _changedLayout(s);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _autoBalance(face, s),
                              icon: const Icon(Icons.center_focus_strong),
                              label: const Text('Авто без узких'),
                            ),
                            OutlinedButton(
                              onPressed: () => _edit(s, 'grout'),
                              child: Text(
                                'Шов ${s.floorTileGroutMm.toStringAsFixed(s.floorTileGroutMm % 1 == 0 ? 0 : 1)} мм',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _edit(s, 'minCut'),
                              child: Text('Мин. ${s.tileMinCutMm.round()}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _offsetControls(
                          s,
                          'offX',
                          'offY',
                          s.tileOffsetXMm,
                          s.tileOffsetYMm,
                        ),
                        Text(
                          'Можно также тянуть раскладку пальцем прямо на плане.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: thin
                                ? const Color(0xFF38241A)
                                : const Color(0xFF173127),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Подрезки по габариту: слева ${cuts.leftMm.round()} • справа ${cuts.rightMm.round()} • сверху ${cuts.topMm.round()} • снизу ${cuts.bottomMm.round()} мм${thin ? '  • есть узкая подрезка' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: thin
                                  ? const Color(0xFFF0A06A)
                                  : const Color(0xFF8AC8AE),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _kind == FloorLayoutKind.laminate
                            ? 'Ориентировочно: $laminatePieces панелей + ${s.floorWastePct.round()}% запас'
                            : _kind == FloorLayoutKind.underlay
                            ? (s.underlayMode == 'sheet'
                                  ? 'Ориентировочно: $underlayPacks листов'
                                  : 'Ориентировочно: $underlayPacks рул. по ${s.underlayRollM2.toStringAsFixed(1)} м²')
                            : 'Ориентировочно: $tilePieces плиток + ${s.floorTileWastePct.round()}% запас',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _offsetControls(
    RoomMaterialSettings s,
    String xField,
    String yField,
    double x,
    double y,
  ) => Row(
    children: [
      Expanded(
        child: _setting('Сдвиг X', '${x.round()} мм', () => _edit(s, xField)),
      ),
      IconButton(
        onPressed: () => _nudge(s, -10, 0),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        onPressed: () => _nudge(s, 10, 0),
        icon: const Icon(Icons.chevron_right),
      ),
      Expanded(
        child: _setting('Сдвиг Y', '${y.round()} мм', () => _edit(s, yField)),
      ),
      IconButton(
        onPressed: () => _nudge(s, 0, -10),
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
      IconButton(
        onPressed: () => _nudge(s, 0, 10),
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    ],
  );

  Widget _setting(String label, String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}
