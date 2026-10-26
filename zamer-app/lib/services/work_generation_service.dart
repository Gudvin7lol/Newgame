import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';
import 'geometry_service.dart';
import 'engineering_service.dart';

enum WorkQuantityBasis { floorArea, wallArea, ceilingArea, skirting, package }

class WorkOperation {
  const WorkOperation(this.code, this.title, this.phase, this.basis,
      this.hoursPerUnit, this.requiredCodes, {this.optional = false});
  final String code, title, phase;
  final WorkQuantityBasis basis;
  final double hoursPerUnit;
  /// Required when both operations are selected in the same room.
  final List<String> requiredCodes;
  final bool optional;
}

/// Every entry can be selected in the manual operation catalogue. Only
/// entries supported by the 2D geometry/materials are auto-selected.
class WorkOperationCatalog {
  static const all = <WorkOperation>[
    WorkOperation('survey', 'Обмер и разметка', 'Подготовка', WorkQuantityBasis.package, 2, []),
    WorkOperation('protection', 'Защита и укрытие помещения', 'Подготовка', WorkQuantityBasis.floorArea, .25, ['survey']),
    WorkOperation('demolition', 'Демонтаж старой отделки', 'Демонтаж', WorkQuantityBasis.wallArea, .65, ['protection'], optional: true),
    WorkOperation('partitions', 'Возведение перегородок', 'Конструктив', WorkQuantityBasis.wallArea, 1.5, ['demolition'], optional: true),
    WorkOperation('electrical_rough', 'Электромонтаж: черновой этап', 'Инженерия', WorkQuantityBasis.package, 12, ['partitions'], optional: true),
    WorkOperation('plumbing_rough', 'Сантехника: черновой этап', 'Инженерия', WorkQuantityBasis.package, 12, ['partitions'], optional: true),
    WorkOperation('ventilation', 'Вентиляция и воздуховоды', 'Инженерия', WorkQuantityBasis.package, 10, ['partitions'], optional: true),
    WorkOperation('floor_base', 'Подготовка основания пола', 'Черновые', WorkQuantityBasis.floorArea, .4, ['demolition']),
    WorkOperation('floor_waterproof', 'Гидроизоляция пола', 'Черновые', WorkQuantityBasis.floorArea, .5, ['floor_base'], optional: true),
    WorkOperation('wall_primer', 'Грунтовка стен', 'Стены', WorkQuantityBasis.wallArea, .17, ['demolition', 'electrical_rough', 'plumbing_rough']),
    WorkOperation('wall_plaster', 'Штукатурка стен', 'Стены', WorkQuantityBasis.wallArea, 1.15, ['wall_primer']),
    WorkOperation('wall_waterproof', 'Гидроизоляция стен', 'Стены', WorkQuantityBasis.wallArea, .5, ['wall_plaster'], optional: true),
    WorkOperation('wall_putty', 'Шпаклёвка и шлифовка стен', 'Стены', WorkQuantityBasis.wallArea, .75, ['wall_plaster']),
    WorkOperation('wall_prime_finish', 'Грунтовка перед финишем стен', 'Стены', WorkQuantityBasis.wallArea, .15, ['wall_putty']),
    WorkOperation('wall_paint', 'Окраска стен', 'Стены', WorkQuantityBasis.wallArea, .55, ['wall_prime_finish']),
    WorkOperation('wall_wallpaper', 'Поклейка обоев', 'Стены', WorkQuantityBasis.wallArea, .5, ['wall_prime_finish'], optional: true),
    WorkOperation('wall_tile', 'Укладка плитки стен', 'Стены', WorkQuantityBasis.wallArea, 1.3, ['wall_plaster', 'wall_waterproof']),
    WorkOperation('warm_floor', 'Монтаж тёплого пола', 'Пол', WorkQuantityBasis.floorArea, .65, ['floor_waterproof'], optional: true),
    WorkOperation('screed', 'Устройство стяжки пола', 'Пол', WorkQuantityBasis.floorArea, .85, ['floor_base', 'warm_floor'], optional: true),
    WorkOperation('floor_underlay', 'Укладка подложки', 'Пол', WorkQuantityBasis.floorArea, .18, ['floor_base', 'screed']),
    WorkOperation('floor_laminate', 'Укладка ламината', 'Пол', WorkQuantityBasis.floorArea, .7, ['floor_underlay']),
    WorkOperation('floor_tile', 'Укладка плитки пола', 'Пол', WorkQuantityBasis.floorArea, 1.15, ['floor_base', 'floor_waterproof', 'screed']),
    WorkOperation('ceiling_base', 'Подготовка основания потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .4, ['electrical_rough']),
    WorkOperation('ceiling_gkl', 'Монтаж потолка ГКЛ', 'Потолок', WorkQuantityBasis.ceilingArea, 1.2, ['ceiling_base']),
    WorkOperation('ceiling_stretch', 'Монтаж натяжного потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .75, ['ceiling_base']),
    WorkOperation('ceiling_prime', 'Грунтовка потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .2, ['ceiling_base']),
    WorkOperation('ceiling_paint', 'Окраска потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .55, ['ceiling_prime']),
    WorkOperation('doors', 'Установка межкомнатных дверей', 'Финиш', WorkQuantityBasis.package, 4, ['floor_laminate', 'floor_tile', 'wall_paint'], optional: true),
    WorkOperation('skirting', 'Монтаж плинтуса', 'Финиш', WorkQuantityBasis.skirting, .35, ['floor_laminate', 'floor_tile']),
    WorkOperation('electrical_finish', 'Установка электрофурнитуры и света', 'Финиш', WorkQuantityBasis.package, 6, ['electrical_rough', 'wall_paint', 'ceiling_paint'], optional: true),
    WorkOperation('plumbing_finish', 'Установка сантехприборов', 'Финиш', WorkQuantityBasis.package, 8, ['plumbing_rough', 'wall_tile', 'floor_tile'], optional: true),
    WorkOperation('fixtures', 'Монтаж оборудования и аксессуаров', 'Финиш', WorkQuantityBasis.package, 4, ['wall_paint', 'floor_laminate'], optional: true),
    WorkOperation('cleaning', 'Уборка после ремонта', 'Сдача', WorkQuantityBasis.floorArea, .2, []),
    WorkOperation('acceptance', 'Приёмка помещения', 'Сдача', WorkQuantityBasis.package, 2, ['cleaning']),
  ];
  static final byCode = {for (final op in all) op.code: op};
}

class WorkGenerationPlan {
  const WorkGenerationPlan(this.tasks, this.skippedExisting,
      this.skippedRooms, this.roomsProcessed);
  final List<WorkTask> tasks;
  final int skippedExisting, skippedRooms, roomsProcessed;
  int get reviewCount => tasks.where((t) => t.needsQuantityReview).length;
  double get totalEstimatedHours =>
      tasks.fold<double>(0, (sum, task) => sum + task.hours);
}

class WorkGenerationService {
  /// Preview does not write to the project, geometry or timeline.
  /// Optional work has deliberately unverified scope; the user must
  /// confirm its quantity before reporting progress.
  static WorkGenerationPlan preview(MeasureProject project, {
    DateTime? begin,
    bool includeOptional = false,
    Set<String>? roomIds,
  }) {
    final board = project.workBoard;
    final existing = <String, WorkTask>{
      for (final task in board.tasks)
        if (task.generatedKey != null) task.generatedKey!: task,
    };
    final drafts = <WorkTask>[];
    var duplicates = 0, roomsSkipped = 0, roomsProcessed = 0;
    final started = board.calendar.nextWorkday(begin ?? DateTime.now());
    for (final floor in project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        final room = floor.roomMetaByKey(face.key);
        if (room == null || room.id.isEmpty ||
            face.areaM2 <= 0 || !face.areaM2.isFinite) {
          roomsSkipped++;
          continue;
        }
        if (roomIds != null && !roomIds.contains(room.id)) continue;
        roomsProcessed++;
        final s = room.materials;
        final tileFloor = s.floorMode == 'tile' || s.floorTile;
        final desired = <String>{
          'survey', 'protection', 'floor_base', 'ceiling_base',
          'cleaning', 'acceptance',
          if (s.wallPlaster || s.wallPutty || s.wallPaint || s.wallTile)
            'wall_primer',
          if (s.wallPlaster || s.wallPutty || s.wallPaint || s.wallTile)
            'wall_plaster',
          if (!s.wallTile && (s.wallPutty || s.wallPaint)) 'wall_putty',
          if (!s.wallTile && s.wallPaint) 'wall_prime_finish',
          if (!s.wallTile && s.wallPaint) 'wall_paint',
          if (s.wallTile) 'wall_tile',
          if (room.heating.enabled) 'warm_floor',
          if (tileFloor) 'floor_tile',
          if (!tileFloor) 'floor_underlay',
          if (!tileFloor) 'floor_laminate',
          if (room.ceiling.finish == 'drywall') 'ceiling_gkl',
          if (room.ceiling.finish == 'stretch') 'ceiling_stretch',
          if (room.ceiling.finish != 'stretch' &&
              room.ceiling.finish != 'drywall') 'ceiling_prime',
          if (room.ceiling.finish != 'stretch' &&
              room.ceiling.finish != 'drywall') 'ceiling_paint',
          'skirting',
        };
        if (includeOptional) {
          desired.addAll(WorkOperationCatalog.all
              .where((op) => op.optional && !{
                'wall_wallpaper', // alternate finish to the modeled paint
                'warm_floor', // only if enabled in room specification
                'ceiling_gkl', 'ceiling_stretch',
              }.contains(op.code))
              .where((op) =>
                  (op.code != 'wall_waterproof' || s.wallTile) &&
                  (op.code != 'floor_waterproof' || tileFloor || room.heating.enabled))
              .map((op) => op.code));
          // Keep one floor finish and one ceiling finish, as configured.
        }

        final inRoom = <String, WorkTask>{};
        for (final op in WorkOperationCatalog.all) {
          if (!desired.contains(op.code)) continue;
          final key = 'generated:${floor.id}:${room.id}:${op.code}';
          if (existing[key] case final WorkTask saved) {
            inRoom[op.code] = saved;
            duplicates++;
            continue;
          }
          final area = face.areaM2;
          final quantity = op.code == 'warm_floor'
              ? EngineeringService.warmFloor(face, room.heating).areaM2
              : switch (op.basis) {
            WorkQuantityBasis.floorArea => area,
            WorkQuantityBasis.wallArea =>
              GeometryService.roomNetWallAreaM2(floor, face),
            WorkQuantityBasis.ceilingArea => area,
            WorkQuantityBasis.skirting =>
              GeometryService.roomSkirtingM(floor, face),
            WorkQuantityBasis.package => 1.0,
          };
          if (!quantity.isFinite || quantity <= 0) continue;
          final prior = <WorkTask>[
            for (final code in op.requiredCodes)
              if (inRoom[code] != null) inRoom[code]!,
          ];
          if (op.code == 'cleaning') {
            prior.addAll(inRoom.entries
                .where((entry) => entry.key != 'survey' &&
                    entry.key != 'protection' &&
                    entry.key != 'cleaning' &&
                    entry.key != 'acceptance')
                .map((entry) => entry.value));
          }
          final predecessors = {for (final task in prior) task.id}.toList();
          final latest = prior.isEmpty ? null : prior.reduce(
            (a, b) => a.finish.isAfter(b.finish) ? a : b,
          );
          final taskStart = latest == null
              ? started
              : board.calendar.firstDayAfter(latest.finish, 0);
          final hours = math.max(1.0, quantity * op.hoursPerUnit);
          final days = math.max(1, (hours / 8).ceil());
          final taskFinish = board.calendar.finishForDuration(taskStart, days);
          final task = WorkTask(
            id: key, generatedKey: key, operationCode: op.code,
            title: op.title, category: op.phase,
            floorId: floor.id, roomId: room.id, roomName: room.name,
            start: taskStart, finish: taskFinish,
            quantity: double.parse(quantity.toStringAsFixed(2)),
            hours: double.parse(hours.toStringAsFixed(1)),
            unit: switch (op.basis) {
              WorkQuantityBasis.package => 'компл.',
              WorkQuantityBasis.skirting => 'м',
              _ => 'м²',
            },
            requiredPredecessorIds: predecessors,
            predecessorId: latest?.id,
            needsQuantityReview: includeOptional && op.optional,
          );
          inRoom[op.code] = task;
          drafts.add(task);
        }
      }
    }
    return WorkGenerationPlan(
      List.unmodifiable(drafts), duplicates, roomsSkipped, roomsProcessed);
  }

  /// Checks the entire proposed batch before committing anything.
  static String? apply(WorkBoard board, WorkGenerationPlan plan) {
    final ids = board.tasks.map((t) => t.id).toSet();
    final keys = board.tasks.map((t) => t.generatedKey).toSet();
    final incomingIds = <String>{};
    for (final task in plan.tasks) {
      if (!incomingIds.add(task.id) || ids.contains(task.id) ||
          keys.contains(task.generatedKey)) {
        return 'График изменился. Выполните предварительный расчёт заново.';
      }
    }
    board.tasks.addAll(plan.tasks);
    if (plan.tasks.isNotEmpty) {
      board.log('Автоматически создано задач: ${plan.tasks.length}. '
        'Помещений: ${plan.roomsProcessed}.');
    }
    return null;
  }
}
