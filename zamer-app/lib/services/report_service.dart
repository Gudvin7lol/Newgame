import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../widgets/floor_plan_painter.dart';
import '../widgets/electrical_plan_painter.dart';
import 'geometry_service.dart';
import 'material_service.dart';
import 'engineering_service.dart';
import 'estimate_service.dart';
import 'measurement_review_service.dart';

class ReportService {
  static Future<void> shareFloorPdf(
    MeasureProject project,
    FloorPlan floor,
  ) async {
    final bytes = await buildFloorPdf(project, floor);
    final safe = '${project.name}_${floor.name}'.replaceAll(
      RegExp(r'[^a-zA-Zа-яА-Я0-9_-]+'),
      '_',
    );
    await Printing.sharePdf(bytes: bytes, filename: 'Замер_$safe.pdf');
  }

  static Future<Uint8List> buildFloorPdf(
    MeasureProject project,
    FloorPlan floor,
  ) async {
    GeometryService.syncRoomMetadata(floor);
    final doc = pw.Document();
    final summary = await _renderSummary(project, floor);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(summary), fit: pw.BoxFit.cover),
      ),
    );

    final plan = await _renderPlan(project, floor);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(plan), fit: pw.BoxFit.cover),
      ),
    );

    final faces = GeometryService.roomFaces(floor);
    for (final face in faces) {
      final room = await _renderRoom(project, floor, face);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(room), fit: pw.BoxFit.cover),
        ),
      );
    }

    if (floor.electricalPoints.isNotEmpty) {
      final electrical = await _renderElectrical(project, floor);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(electrical), fit: pw.BoxFit.cover),
        ),
      );
    }

    if (faces.isNotEmpty || floor.serviceRuns.isNotEmpty) {
      for (var start = 0; start < math.max(1, faces.length); start += 9) {
        final engineering = await _renderEngineering(
          project,
          floor,
          faces.skip(start).take(9).toList(),
          start,
        );
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) =>
                pw.Image(pw.MemoryImage(engineering), fit: pw.BoxFit.cover),
          ),
        );
      }
    }
    final issues = MeasurementReviewService.review(floor);
    final dimensionLines = <String>[];
    for (final wall in floor.walls) {
      final record = floor.dimensionRecords['wall:${wall.id}:length'];
      dimensionLines.add(
        'Стена ${wall.id}: ${floor.wallLengthMm(wall).round()} мм • '
        '${record?.source.label ?? 'расчётный размер'}'
        '${record == null ? '' : ' • ${record.author} • ${record.recordedAt.toLocal().toString().split('.').first}'}',
      );
      for (final opening in wall.openings) {
        for (final (label, key, value) in [
          ('отступ', 'offset', opening.offsetFromStartMm),
          ('высота', 'height', opening.heightMm),
        ]) {
          final entry = floor.dimensionRecords['opening:${opening.id}:$key'];
          dimensionLines.add(
            'Проём ${opening.id}, $label: ${value.round()} мм • '
            '${entry?.source.label ?? 'расчётный размер'}',
          );
        }
      }
    }
    for (final measure in floor.measures) {
      final source = floor.dimensionRecords['control:${measure.id}'];
      dimensionLines.add(
        'Контроль ${measure.id}: ${measure.measuredMm.round()} мм • '
        '${source?.source.label ?? 'источник не указан'}',
      );
    }
    for (final room in floor.roomMetas) {
      final source = floor.dimensionRecords['room:${room.id}:height'];
      dimensionLines.add(
        '${room.name}, высота: '
        '${(room.ceilingHeightMm ?? floor.defaultHeightMm).round()} мм • '
        '${source?.source.label ?? 'расчётный размер'}',
      );
    }
    for (var start = 0; start < issues.length; start += 22) {
      final sheet = await _renderReviewSheet(
        project,
        'Проверка обмера',
        issues.skip(start).take(22).map((e) => e.description).toList(),
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(sheet), fit: pw.BoxFit.cover),
        ),
      );
    }
    for (var start = 0; start < dimensionLines.length; start += 28) {
      final sheet = await _renderReviewSheet(
        project,
        'Источники размеров',
        dimensionLines.skip(start).take(28).toList(),
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(sheet), fit: pw.BoxFit.cover),
        ),
      );
    }
    final estimate = EstimateService.build(project);
    for (var start = 0; start < estimate.lines.length; start += 25) {
      final sheet = await _renderEstimate(project, estimate, start);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(sheet), fit: pw.BoxFit.cover),
        ),
      );
    }
    final works = EstimateService.buildWork(project);
    for (var start = 0; start < works.lines.length; start += 25) {
      final sheet = await _renderEstimate(
        project,
        works,
        start,
        title: 'Смета работ',
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(sheet), fit: pw.BoxFit.cover),
        ),
      );
    }

    return doc.save();
  }

  static Future<Uint8List> _renderReviewSheet(
    MeasureProject project,
    String title,
    List<String> lines,
  ) async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _text(canvas, project.name, const Offset(70, 60), 19, FontWeight.w600);
    _text(canvas, title, const Offset(70, 115), 34, FontWeight.w800);
    _text(
      canvas,
      'Расхождения проверяются на объекте; план не исправляется автоматически.',
      const Offset(70, 165),
      16,
      FontWeight.w400,
    );
    var y = 230.0;
    for (final line in lines) {
      _text(canvas, line, Offset(70, y), 18, FontWeight.w500, maxWidth: 1100);
      y += 55;
    }
    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderSummary(
    MeasureProject project,
    FloorPlan floor,
  ) async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final faces = GeometryService.roomFaces(floor);
    final totalArea = faces.fold<double>(0, (s, f) => s + f.areaM2);
    final totalWalls = faces.fold<double>(
      0,
      (s, f) => s + GeometryService.roomNetWallAreaM2(floor, f),
    );

    _text(canvas, 'ОБМЕРНЫЙ ПЛАН', const Offset(80, 80), 42, FontWeight.w900);
    _text(canvas, project.name, const Offset(80, 145), 34, FontWeight.w800);
    _text(
      canvas,
      floor.name,
      const Offset(80, 198),
      24,
      FontWeight.w600,
      color: const Color(0xFF5C6570),
    );
    if (project.address.isNotEmpty)
      _text(
        canvas,
        project.address,
        const Offset(80, 240),
        20,
        FontWeight.w400,
        color: const Color(0xFF747D88),
      );

    var y = 320.0;
    final metrics = [
      ['Помещений', '${faces.length}'],
      ['Площадь пола', '${totalArea.toStringAsFixed(2)} м²'],
      ['Чистая площадь стен', '${totalWalls.toStringAsFixed(2)} м²'],
      ['Стен / сегментов', '${floor.walls.length}'],
      ['Высота по умолчанию', '${floor.defaultHeightMm.round()} мм'],
      ['Электроточек', '${floor.electricalPoints.length}'],
      ['Кабельных линий', '${floor.electricalRuns.length}'],
    ];
    for (final m in metrics) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(80, y, 1080, 86),
          const Radius.circular(18),
        ),
        Paint()..color = const Color(0xFFF3F5F8),
      );
      _text(
        canvas,
        m[0],
        Offset(110, y + 24),
        22,
        FontWeight.w500,
        color: const Color(0xFF656D78),
      );
      _textRight(canvas, m[1], Offset(1130, y + 24), 24, FontWeight.w800);
      y += 104;
    }

    y += 28;
    _text(canvas, 'Экспликация помещений', Offset(80, y), 28, FontWeight.w800);
    y += 48;
    for (var i = 0; i < faces.length; i++) {
      final f = faces[i];
      final meta = floor.roomMetaByKey(f.key);
      _text(
        canvas,
        '${i + 1}. ${meta?.name ?? 'Помещение ${i + 1}'}',
        Offset(90, y),
        20,
        FontWeight.w600,
      );
      _textRight(
        canvas,
        '${f.areaM2.toStringAsFixed(2)} м²',
        Offset(1130, y),
        20,
        FontWeight.w700,
      );
      y += 38;
      if (y > 1600) break;
    }

    _text(
      canvas,
      'Создано в приложении «Замер» v1.1',
      const Offset(80, 1680),
      16,
      FontWeight.w400,
      color: const Color(0xFF8A919B),
    );
    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderPlan(
    MeasureProject project,
    FloorPlan floor,
  ) async {
    const size = Size(1754, 1240);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _text(
      canvas,
      '${project.name} • ${floor.name}',
      const Offset(60, 42),
      28,
      FontWeight.w800,
    );
    _text(
      canvas,
      'Общий план с толщиной стен и перегородками',
      const Offset(60, 83),
      18,
      FontWeight.w400,
      color: const Color(0xFF6B7480),
    );

    const rect = Rect.fromLTWH(60, 130, 1634, 1030);
    _paintFloorInto(canvas, floor, rect);
    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderRoom(
    MeasureProject project,
    FloorPlan floor,
    RoomFace face,
  ) async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final meta = floor.roomMetaByKey(face.key)!;
    final wallArea = GeometryService.roomNetWallAreaM2(floor, face);
    final h = GeometryService.roomHeightMm(floor, face);
    final runs = GeometryService.elevationRuns(floor, face);

    _text(
      canvas,
      project.name,
      const Offset(70, 55),
      18,
      FontWeight.w600,
      color: const Color(0xFF6B7480),
    );
    _text(canvas, meta.name, const Offset(70, 95), 36, FontWeight.w900);
    _textRight(
      canvas,
      '${face.areaM2.toStringAsFixed(2)} м²',
      const Offset(1170, 105),
      28,
      FontWeight.w800,
      color: const Color(0xFF1769E8),
    );

    final rows = [
      ['Высота', '${h.round()} мм'],
      ['Периметр', '${face.perimeterM.toStringAsFixed(2)} м'],
      ['Чистая площадь стен', '${wallArea.toStringAsFixed(2)} м²'],
      [
        'Плинтус',
        '${GeometryService.roomSkirtingM(floor, face).toStringAsFixed(2)} м',
      ],
      ['Количество стен', '${runs.length}'],
      ['Пирог пола', '${meta.floorBuildUpMm.toStringAsFixed(1)} мм'],
      ['Пирог стен', '${meta.wallBuildUpMm.toStringAsFixed(1)} мм'],
      [
        'Чистовая высота',
        '${(h - meta.floorBuildUpMm - meta.ceiling.dropMm).toStringAsFixed(1)} мм',
      ],
    ];
    var y = 175.0;
    for (final r in rows) {
      _text(
        canvas,
        r[0],
        Offset(80, y),
        19,
        FontWeight.w500,
        color: const Color(0xFF68717D),
      );
      _textRight(canvas, r[1], Offset(1160, y), 20, FontWeight.w700);
      y += 42;
    }

    y += 28;
    _text(canvas, 'Материалы', Offset(70, y), 26, FontWeight.w800);
    y += 44;
    final estimates = MaterialService.roomEstimates(floor, face, meta);
    for (final e in estimates.take(10)) {
      _text(canvas, e.name, Offset(80, y), 18, FontWeight.w600);
      final right =
          '${e.quantity.toStringAsFixed(e.quantity >= 100 ? 0 : 2)} ${e.unit}${e.packages != null ? ' • ${e.packages} ${e.packageLabel ?? 'уп.'}' : ''}';
      _textRight(canvas, right, Offset(1160, y), 18, FontWeight.w700);
      y += 37;
    }

    y += 24;
    _text(canvas, 'Развёртки стен', Offset(70, y), 26, FontWeight.w800);
    y += 44;
    for (var i = 0; i < runs.length && i < 10; i++) {
      final run = runs[i];
      final openings = run.edges.fold<int>(
        0,
        (sum, edge) =>
            sum + (floor.wallById(edge.wallId)?.openings.length ?? 0),
      );
      final label = run.isCurved
          ? 'Радиусная стена ${String.fromCharCode(65 + i)}'
          : 'Стена ${String.fromCharCode(65 + i)}';
      _text(canvas, label, Offset(80, y), 18, FontWeight.w700);
      final radius = run.isCurved && run.radiusMm != null
          ? ' • R ${run.radiusMm!.round()}'
          : '';
      _textRight(
        canvas,
        '${run.lengthMm.round()} × ${h.round()} мм$radius • проёмов $openings',
        Offset(1160, y),
        18,
        FontWeight.w600,
      );
      y += 35;
    }

    if (meta.notes.trim().isNotEmpty) {
      y += 24;
      _text(canvas, 'Заметки', Offset(70, y), 24, FontWeight.w800);
      y += 36;
      _text(
        canvas,
        meta.notes.trim(),
        Offset(80, y),
        17,
        FontWeight.w400,
        maxWidth: 1080,
      );
    }

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderEngineering(
    MeasureProject project,
    FloorPlan floor,
    List<RoomFace> faces,
    int start,
  ) async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _text(
      canvas,
      '${project.name} • ${floor.name}',
      const Offset(70, 55),
      18,
      FontWeight.w600,
    );
    _text(
      canvas,
      'Потолки и тёплый пол',
      const Offset(70, 105),
      35,
      FontWeight.w800,
    );
    var y = 180.0;
    for (var i = 0; i < faces.length; i++) {
      final face = faces[i];
      final meta = floor.roomMetaByKey(face.key);
      if (meta == null) continue;
      final ceiling = meta.ceiling;
      final heating = EngineeringService.warmFloor(face, meta.heating);
      final finish = switch (ceiling.finish) {
        'stretch' => 'Натяжной',
        'drywall' => 'ГКЛ',
        _ => 'Покраска',
      };
      final zoneArea = ceiling.zones.fold<double>(
        0,
        (sum, zone) => sum + EngineeringService.zoneAreaM2(face, zone),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(70, y, 1100, 124),
          const Radius.circular(14),
        ),
        Paint()..color = const Color(0xFFF2F5F5),
      );
      _text(
        canvas,
        '${start + i + 1}. ${meta.name}',
        Offset(90, y + 10),
        20,
        FontWeight.w800,
        maxWidth: 850,
      );
      _text(
        canvas,
        '$finish • ${face.areaM2.toStringAsFixed(2)} м² • '
        'низ ${(GeometryService.roomHeightMm(floor, face) - ceiling.dropMm).round()} мм',
        Offset(90, y + 42),
        18,
        FontWeight.w500,
      );
      _text(
        canvas,
        'Зоны ${zoneArea.toStringAsFixed(2)} м² • '
        'тёплый пол ${heating.areaM2.toStringAsFixed(2)} м² • '
        '${heating.pipeM.toStringAsFixed(1)} м / ${heating.circuits} конт.',
        Offset(90, y + 72),
        18,
        FontWeight.w500,
      );
      y += 138;
    }
    if (start == 0) {
      y += 20;
      _text(canvas, 'Инженерные трассы', Offset(70, y), 26, FontWeight.w800);
      y += 50;
      for (final entry in EngineeringService.routeLengths(floor).entries) {
        _text(canvas, entry.key.label, Offset(90, y), 19, FontWeight.w500);
        _textRight(
          canvas,
          '${entry.value.toStringAsFixed(2)} м',
          Offset(1150, y),
          19,
          FontWeight.w700,
        );
        y += 36;
      }
    }
    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderEstimate(
    MeasureProject project,
    ProjectEstimate estimate,
    int start, {
    String title = 'Смета материалов',
  }) async {
    const size = Size(1240, 1754);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _text(canvas, project.name, const Offset(70, 60), 19, FontWeight.w600);
    _text(canvas, title, const Offset(70, 105), 36, FontWeight.w800);
    _text(
      canvas,
      'Расценки пользователя • позиции без цены отмечены отдельно',
      const Offset(70, 160),
      17,
      FontWeight.w400,
    );
    var y = 230.0;
    for (final line in estimate.lines.skip(start).take(25)) {
      _text(
        canvas,
        line.name,
        Offset(70, y),
        17,
        FontWeight.w600,
        maxWidth: 640,
      );
      _textRight(
        canvas,
        '${line.quantity.toStringAsFixed(2)} ${line.unit}',
        Offset(900, y),
        17,
        FontWeight.w500,
      );
      _textRight(
        canvas,
        line.unitPrice == 0 ? '—' : '${line.total.toStringAsFixed(2)} ₽',
        Offset(1160, y),
        17,
        FontWeight.w700,
      );
      y += 51;
    }
    if (start + 25 >= estimate.lines.length) {
      _text(
        canvas,
        'Итого по оценённым позициям',
        const Offset(70, 1600),
        22,
        FontWeight.w800,
      );
      _textRight(
        canvas,
        '${estimate.pricedTotal.toStringAsFixed(2)} ₽',
        const Offset(1160, 1600),
        22,
        FontWeight.w800,
      );
      _text(
        canvas,
        'Без цены: ${estimate.unpricedCount} позиций',
        const Offset(70, 1645),
        17,
        FontWeight.w500,
      );
    }
    return _toPng(recorder, size);
  }

  static Future<Uint8List> _renderElectrical(
    MeasureProject project,
    FloorPlan floor,
  ) async {
    const size = Size(1754, 1240);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _text(
      canvas,
      '${project.name} • ${floor.name}',
      const Offset(60, 42),
      28,
      FontWeight.w800,
    );
    _text(
      canvas,
      'План электрики',
      const Offset(60, 83),
      20,
      FontWeight.w600,
      color: const Color(0xFF6B7480),
    );

    const rect = Rect.fromLTWH(60, 130, 1180, 1030);
    final points = <math.Point<double>>[];
    for (final n in floor.nodes) points.add(math.Point(n.xMm, n.yMm));
    for (final e in floor.electricalPoints)
      points.add(math.Point(e.xMm, e.yMm));
    if (points.isNotEmpty) {
      var minX = points.first.x,
          maxX = points.first.x,
          minY = points.first.y,
          maxY = points.first.y;
      for (final p in points.skip(1)) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
      final spanX = math.max(1000.0, maxX - minX + 700);
      final spanY = math.max(1000.0, maxY - minY + 700);
      final scale = math.min(rect.width / spanX, rect.height / spanY);
      final origin =
          rect.center -
          Offset(((minX + maxX) / 2) * scale, ((minY + maxY) / 2) * scale);
      canvas.save();
      canvas.clipRect(rect);
      ElectricalPlanPainter(
        floor: floor,
        scale: scale,
        origin: origin,
      ).paint(canvas, rect.size);
      canvas.restore();
    }

    final counts = <String, int>{};
    for (final e in floor.electricalPoints)
      counts[e.type.label] = (counts[e.type.label] ?? 0) + 1;
    var y = 150.0;
    _text(
      canvas,
      'Ведомость точек',
      const Offset(1290, 145),
      22,
      FontWeight.w800,
    );
    y += 42;
    for (final e in counts.entries) {
      _text(canvas, e.key, Offset(1290, y), 17, FontWeight.w500);
      _textRight(canvas, '${e.value}', Offset(1680, y), 17, FontWeight.w800);
      y += 32;
    }
    y += 22;
    _text(canvas, 'Кабель', Offset(1290, y), 22, FontWeight.w800);
    y += 40;
    final totals = <String, double>{};
    final byId = {for (final e in floor.electricalPoints) e.id: e};
    for (final run in floor.electricalRuns) {
      final a = byId[run.startPointId];
      final b = byId[run.endPointId];
      if (a == null || b == null) continue;
      final base = run.routeMode == 'orthogonal'
          ? (a.xMm - b.xMm).abs() + (a.yMm - b.yMm).abs()
          : math.sqrt(math.pow(a.xMm - b.xMm, 2) + math.pow(a.yMm - b.yMm, 2));
      final meters = base / 1000 * (1 + run.reservePct / 100);
      totals[run.cable] = (totals[run.cable] ?? 0) + meters;
    }
    for (final e in totals.entries) {
      _text(canvas, e.key, Offset(1290, y), 16, FontWeight.w500, maxWidth: 280);
      _textRight(
        canvas,
        '${e.value.toStringAsFixed(1)} м',
        Offset(1680, y),
        16,
        FontWeight.w800,
      );
      y += 36;
    }
    return _toPng(recorder, size);
  }

  static void _paintFloorInto(Canvas canvas, FloorPlan floor, Rect rect) {
    if (floor.nodes.isEmpty) return;
    var minX = floor.nodes.first.xMm;
    var maxX = floor.nodes.first.xMm;
    var minY = floor.nodes.first.yMm;
    var maxY = floor.nodes.first.yMm;
    for (final n in floor.nodes.skip(1)) {
      minX = math.min(minX, n.xMm);
      maxX = math.max(maxX, n.xMm);
      minY = math.min(minY, n.yMm);
      maxY = math.max(maxY, n.yMm);
    }
    final spanX = math.max(1000.0, maxX - minX + 1000);
    final spanY = math.max(1000.0, maxY - minY + 1000);
    final scale = math.min(rect.width / spanX, rect.height / spanY);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final origin = rect.center - Offset(cx * scale, cy * scale);
    canvas.save();
    canvas.clipRect(rect);
    FloorPlanPainter(
      floor: floor,
      mmToPx: scale,
      origin: origin,
      showNodes: false,
      showDimensions: true,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  static Future<Uint8List> _toPng(
    ui.PictureRecorder recorder,
    Size size,
  ) async {
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset p,
    double size,
    FontWeight weight, {
    Color color = const Color(0xFF171A1F),
    double maxWidth = 1000,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 6,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, p);
  }

  static void _textRight(
    Canvas canvas,
    String text,
    Offset p,
    double size,
    FontWeight weight, {
    Color color = const Color(0xFF171A1F),
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(p.dx - tp.width, p.dy));
  }
}
