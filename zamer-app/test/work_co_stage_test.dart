import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/work_co_stage_service.dart';
import 'package:zamer_app/services/work_schedule_service.dart';
import 'package:zamer_app/services/work_status_service.dart';

WorkTask task(String id, int start, int finish, {
    String? predecessor, String roomId = 'room-1'}) => WorkTask(
  id: id, title: id, start: DateTime(2026, 11, start),
  finish: DateTime(2026, 11, finish),
  quantity: 10, unit: 'м²', hours: 16,
  floorId: 'floor-1', roomId: roomId,
  predecessorId: predecessor,
);

void main() {
  test('two peers run in parallel and only jointly accepted peers unlock successor', () {
    final elec = task('elec', 2, 4);
    final plumbing = task('plumbing', 2, 6);
    final plaster = task('plaster', 7, 10, predecessor: elec.id);
    final board = WorkBoard(tasks: [elec, plumbing, plaster]);
    expect(WorkCoStageService.link(board, elec.id, plumbing.id), isNull);
    expect(WorkStatusService.canStart(board, elec), isTrue);
    expect(WorkStatusService.canStart(board, plumbing), isTrue);
    expect(WorkStatusService.canStart(board, plaster), isFalse);

    elec.done = elec.quantity;
    elec.accepted = elec.quantity;
    expect(WorkStatusService.canStart(board, plaster), isFalse);
    expect(WorkStatusService.startBlocker(board, plaster),
        contains('plumbing'));
    plumbing.done = plumbing.quantity;
    plumbing.accepted = plumbing.quantity;
    expect(WorkStatusService.canStart(board, plaster), isTrue);
  });

  test('linking parallel stages cascades finish-to-start dates for their common successor', () {
    final elec = task('elec', 2, 3);
    final plumbing = task('plumbing', 2, 9);
    final plaster = task('plaster', 4, 7, predecessor: elec.id);
    final board = WorkBoard(tasks: [elec, plumbing, plaster]);

    expect(WorkCoStageService.link(board, elec.id, plumbing.id), isNull);
    final proposal = WorkSchedulePlanner.preview(
      board: board, taskId: elec.id, start: elec.start,
      finish: elec.finish, predecessorId: elec.predecessorId,
    );
    expect(proposal.isValid, isTrue, reason: proposal.error);
    expect(proposal.changes.map((x) => x.taskId), contains(plaster.id));
    expect(plaster.start, DateTime(2026, 11, 4));
    expect(WorkSchedulePlanner.apply(board, proposal), isNull);
    expect(plaster.start, DateTime(2026, 11, 10));
    expect(plaster.finish, DateTime(2026, 11, 13));
    expect(plaster.baselineStart, DateTime(2026, 11, 4));
  });

  test('co-stage links reject direct and indirect sequential chains', () {
    final a = task('a', 1, 2);
    final b = task('b', 3, 4, predecessor: 'a');
    final c = task('c', 5, 6, predecessor: 'b');
    final board = WorkBoard(tasks: [a, b, c]);
    expect(WorkCoStageService.link(board, 'a', 'b'), isNotNull);
    expect(WorkCoStageService.link(board, 'a', 'c'), isNotNull);
    expect(a.coStageTaskIds, isEmpty);
    expect(c.coStageTaskIds, isEmpty);
  });

  test('co-stage links are room-scoped and keep stable project JSON', () {
    final a = task('a', 2, 3);
    final b = task('b', 2, 4);
    final c = task('c', 2, 4, roomId: 'room-2');
    final board = WorkBoard(tasks: [a, b, c]);
    expect(WorkCoStageService.link(board, 'a', 'c'),
      contains('одному помещению'));
    expect(WorkCoStageService.link(board, 'a', 'b'), isNull);
    expect(WorkCoStageService.link(board, 'a', 'b'), isNull);
    expect(a.coStageTaskIds, ['b']);
    final restored = WorkBoard.fromJson(board.toJson());
    expect(WorkCoStageService.memberIds(restored, 'a'), {'a', 'b'});
    WorkCoStageService.unlink(restored, 'a', 'b');
    expect(WorkCoStageService.memberIds(restored, 'a'), {'a'});
  });

  test('multiple peers form one symmetric acceptance group without cycle', () {
    final a = task('a', 2, 3);
    final b = task('b', 2, 4);
    final c = task('c', 2, 5);
    final after = task('after', 6, 7, predecessor: 'b');
    final board = WorkBoard(tasks: [a, b, c, after]);
    expect(WorkCoStageService.link(board, 'a', 'b'), isNull);
    expect(WorkCoStageService.link(board, 'b', 'c'), isNull);
    expect(WorkCoStageService.memberIds(board, 'a'), {'a', 'b', 'c'});
    expect(WorkCoStageService.expandedPredecessors(board, after),
      {'a', 'b', 'c'});
    expect(WorkStatusService.canStart(board, after), false);
  });

  test('stale preview cannot apply after co-dependent linkage changes', () {
    final a = task('a', 2, 3);
    final b = task('b', 2, 4);
    final after = task('after', 6, 7, predecessor: 'a');
    final board = WorkBoard(tasks: [a, b, after]);
    final preview = WorkSchedulePlanner.preview(
      board: board, taskId: a.id, start: a.start,
      finish: DateTime(2026, 11, 4),
      predecessorId: null,
    );
    expect(preview.isValid, isTrue);
    expect(WorkCoStageService.link(board, 'a', 'b'), isNull);
    expect(WorkSchedulePlanner.apply(board, preview),
      contains('изменился'));
    expect(a.finish, DateTime(2026, 11, 3));
  });
}
