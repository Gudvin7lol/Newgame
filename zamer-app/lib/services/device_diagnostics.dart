import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/floor_3d_painter.dart';
import '../widgets/floor_layout_painter.dart';
import 'geometry_service.dart';
import 'layout_service.dart';
import 'space_check_service.dart';
import 'engineering_service.dart';
import 'measurement_review_service.dart';
import 'project_backup_service.dart';
import 'report_service.dart';

class DiagnosticResult {
  const DiagnosticResult(this.name, this.ok, this.detail, this.elapsedMs);
  final String name;
  final bool ok;
  final String detail;
  final int elapsedMs;
}

class DeviceDiagnostics {
  static FloorPlan _sample() {
    final floor = FloorPlan(id: 'diagnostic', name: 'Diagnostic');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ]);
    return floor;
  }

  static Future<DiagnosticResult> _check(
    String name,
    Future<String> Function() task,
  ) async {
    // Let the progress label appear before work starts on the UI isolate.
    await Future<void>.delayed(const Duration(milliseconds: 24));
    final clock = Stopwatch()..start();
    try {
      final detail = await task();
      return DiagnosticResult(name, true, detail, clock.elapsedMilliseconds);
    } catch (error) {
      return DiagnosticResult(name, false, '$error', clock.elapsedMilliseconds);
    }
  }

  static Future<DiagnosticResult> geometry() =>
      _check('Перегородка и комнаты', () async {
        final floor = _sample();
        final start = GeometryService.ensureAnchor(
          floor,
          const math.Point(1500, 0),
        );
        final end = GeometryService.addWallFromNode(
          floor,
          startNodeId: start.id,
          endPoint: const math.Point(1500, 1200),
          type: WallType.partition,
          thicknessMm: 100,
          material: WallMaterial.drywall,
        );
        final rooms = GeometryService.roomFaces(floor);
        if ((end.yMm - 1200).abs() > 1 || rooms.length != 1) {
          throw StateError(
            'Свободная перегородка: конец ${end.yMm}, комнат ${rooms.length}',
          );
        }
        return 'Конец 1200 мм; комнат ${rooms.length}';
      });

  static Future<DiagnosticResult> layout() =>
      _check('Формат и привязка покрытия', () async {
        final face = GeometryService.roomFaces(_sample()).single;
        final settings = RoomMaterialSettings();
        final rows = LayoutService.laminateRows(face, settings);
        if (rows.rows < 14 || rows.rows > 17) {
          throw StateError('В комнате 3×3 м получилось ${rows.rows} рядов');
        }
        final symmetric = LayoutService.originFor(
          face,
          settings,
          'symmetric',
          'laminate',
        );
        final best = LayoutService.originFor(face, settings, 'best', 'tile');
        if (!symmetric.xMm.isFinite || !best.yMm.isFinite) {
          throw StateError('Привязка вернула некорректные координаты');
        }
        final restored = FloorPlan.fromJson(_sample().toJson());
        if (GeometryService.roomFaces(restored).length != 1) {
          throw StateError('План не восстановился после сериализации');
        }
        return '${rows.rows} рядов по 193 мм, центр/подрезка рассчитаны';
      });

  static Future<DiagnosticResult> floorRender() =>
      _check('Отрисовка покрытий', () async {
        final face = GeometryService.roomFaces(_sample()).single;
        final settings = RoomMaterialSettings();
        const size = Size(720, 720);
        for (final kind in FloorLayoutKind.values) {
          settings.laminatePattern = 'straight';
          final patterns = kind == FloorLayoutKind.laminate
              ? ['straight', 'herringbone']
              : ['default'];
          for (final pattern in patterns) {
            if (kind == FloorLayoutKind.laminate)
              settings.laminatePattern = pattern;
            final recorder = ui.PictureRecorder();
            FloorLayoutPainter(
              face: face,
              settings: settings,
              kind: kind,
            ).paint(Canvas(recorder), size);
            final picture = recorder.endRecording();
            try {
              final image = await picture.toImage(720, 720);
              image.dispose();
            } finally {
              picture.dispose();
            }
          }
        }
        return 'Ламинат, ёлочка, подложка и плитка: 720×720';
      });

  static Future<DiagnosticResult> sceneRender() =>
      _check('Отрисовка 3D', () async {
        final floor = _sample();
        GeometryService.syncRoomMetadata(floor);
        floor.roomMetas.first.materials.laminatePattern = 'herringbone';
        const size = Size(800, 600);
        for (final cutaway in [false, true]) {
          final recorder = ui.PictureRecorder();
          Floor3DPainter(
            floor: floor,
            rotation: -0.65,
            tilt: 0.82,
            zoom: 1,
            cutaway: cutaway,
          ).paint(Canvas(recorder), size);
          final picture = recorder.endRecording();
          try {
            final image = await picture.toImage(800, 600);
            image.dispose();
          } finally {
            picture.dispose();
          }
        }
        return 'Ёлочка, стены открыты/закрыты: 800×600';
      });

  static Future<DiagnosticResult> projectAudit(
    List<MeasureProject> projects,
  ) => _check('Проверка сохранённых планов', () async {
    var floors = 0;
    var rooms = 0;
    var tiny = 0;
    var badWalls = 0;
    var badFormats = 0;
    var spaceIssues = 0;
    for (final project in projects) {
      for (final source in project.floors) {
        // 3D painter may synchronize room metadata. Inspect a clone only.
        final floor = FloorPlan.fromJson(source.toJson());
        floors++;
        for (final wall in floor.walls) {
          if (floor.nodeById(wall.startNodeId) == null ||
              floor.nodeById(wall.endNodeId) == null ||
              floor.wallLengthMm(wall) < 20) {
            badWalls++;
          }
        }
        final faces = GeometryService.roomFaces(floor);
        spaceIssues += SpaceCheckService.inspect(floor).length;
        rooms += faces.length;
        tiny += faces.where((room) => room.areaM2 < 0.7).length;
        for (final meta in floor.roomMetas) {
          final s = meta.materials;
          if (s.laminatePlankLengthMm < 100 ||
              s.laminatePlankWidthMm < 40 ||
              s.tileWidthMm < 20 ||
              s.tileHeightMm < 20 ||
              s.underlayRollWidthMm < 20) {
            badFormats++;
          }
        }
      }
    }
    if (badWalls > 0 || badFormats > 0) {
      throw StateError(
        'Этажей $floors, комнат $rooms; стен с ошибкой $badWalls, форматов $badFormats, маленьких комнат $tiny, коллизий/проходов $spaceIssues',
      );
    }
    return 'Этажей $floors, комнат $rooms, маленьких (<0,7 м²) $tiny, коллизий/проходов $spaceIssues';
  });

  static Future<DiagnosticResult>
  projectRoundTrip() => _check('Обмер, трубы, ZIP и PDF', () async {
    final floor = _sample();
    GeometryService.syncRoomMetadata(floor);
    final face = GeometryService.roomFaces(floor).single;
    final takeoff = EngineeringService.warmFloor(
      face,
      HeatingSpec(enabled: true, spacingMm: 150),
    );
    if (takeoff.pipeM < 40 || takeoff.circuits < 1) {
      throw StateError('Не рассчитан тёплый пол');
    }
    floor.serviceRuns.add(
      ServiceRun(
        id: 'check',
        type: ServiceRunType.coldWater,
        points: [
          ServiceVertex(0, 0),
          ...EngineeringService.orthogonalStep(
            ServiceVertex(0, 0),
            const math.Point<double>(1000, 500),
          ),
        ],
      ),
    );
    final project = MeasureProject(
      id: 'check',
      name: 'Самопроверка',
      floors: [floor],
    );
    final zip = await ProjectBackupService.encodePortable(project);
    final restored = ProjectBackupService.decodePortable(zip).project;
    if (restored.floors.single.serviceRuns.single.points.length != 3) {
      throw StateError('Трасса потерялась при переносе');
    }
    final issues = MeasurementReviewService.review(floor);
    final pdf = await ReportService.buildFloorPdf(project, floor);
    if (pdf.length < 10000) throw StateError('PDF не построен');
    return 'Труба ${takeoff.pipeM.toStringAsFixed(1)} м; '
        'замечаний ${issues.length}; ZIP ${zip.length} Б, PDF ${pdf.length} Б';
  });

  static String report(List<DiagnosticResult> results) {
    final now = DateTime.now().toIso8601String();
    final lines = <String>[
      'Замер 1.3.0 (28) — самопроверка на телефоне',
      'Время: $now',
      'Устройство: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Проверено: ${results.length}; ошибок: ${results.where((r) => !r.ok).length}',
      ...results.map(
        (r) =>
            '${r.ok ? 'OK' : 'ERROR'} ${r.name} (${r.elapsedMs} мс): ${r.detail}',
      ),
      'Ручная проверка: перемещение раскладки; поворот 3D; скрытие стен; двери и окна — требуется запись экрана.',
    ];
    return lines.join('\n');
  }
}
