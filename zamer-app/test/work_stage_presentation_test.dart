import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/work_stage_presentation_service.dart';
import 'package:zamer_app/services/work_status_service.dart';

WorkTask work(String id, int day, {
  String? predecessor,
  List<String>? prerequisites,
  List<String>? coStage,
}) => WorkTask(
  id: id, title: id,
  start: DateTime(2026, 11, day),
  finish: DateTime(2026, 11, day),
  quantity: 10, unit: 'м²', hours: 4,
  predecessorId: predecessor,
  requiredPredecessorIds: prerequisites,
  coStageTaskIds: coStage,
);

void main() {
  test('predecessors appear before successors even with inconsistent dates', () {
    final base = work('Основание', 16);
    final prime = work('Грунтование', 10, predecessor: base.id);
    final finish = work('Окраска', 4,
      prerequisites: [prime.id]);
    final ordered = WorkStagePresentationService.order(
      [finish, prime, base]);
    expect(ordered.map((t) => t.id).toList(),
      ['Основание', 'Грунтование', 'Окраска']);
  });

  test('independent stages keep deterministic date and name order', () {
    final a = work('А', 2);
    final b = work('Б', 1, coStage: ['А']);
    final c = work('В', 1, coStage: ['Б']);
    expect(WorkStagePresentationService.order([a, c, b])
      .map((t) => t.id).toList(), ['Б', 'В', 'А']);
  });

  test('out-of-group predecessor does not hide in-group task', () {
    final b = work('Отделка', 3, predecessor: 'электрика');
    final a = work('Контроль', 5, predecessor: 'Отделка');
    expect(WorkStagePresentationService.order([a, b])
      .map((t) => t.id).toList(), ['Отделка', 'Контроль']);
  });

  test('legacy cyclic dependencies remain visible, with no infinite loop', () {
    final a = work('А', 4, predecessor: 'Б');
    final b = work('Б', 2, predecessor: 'А');
    final result = WorkStagePresentationService.order([a, b]);
    expect(result.map((t) => t.id).toSet(), {'А', 'Б'});
    expect(result.length, 2);
  });

  test('compact progress weighs acceptance by expected labor hours', () {
    final short = work('inspection', 2);
    final long = work('plaster', 3);
    short.hours = 2;
    long.hours = 18;
    short.quantity = 1;
    short.done = 1;
    short.accepted = 1;
    expect(WorkStagePresentationService.acceptedProgress([short, long]),
        closeTo(.10, .0001));
    long.accepted = long.quantity / 2;
    expect(WorkStagePresentationService.acceptedProgress([short, long]),
        closeTo(.55, .0001));
    long.needsQuantityReview = true;
    expect(WorkStagePresentationService.acceptedProgress([short, long]),
        closeTo(.10, .0001));
    long.needsQuantityReview = false;
    expect(WorkStagePresentationService.acceptedProgress([]), 0);
  });

  test('compact current task favors work underway over future plan', () {
    final now = DateTime(2026, 11, 10);
    final future = work('next week', 18);
    final current = work('on site', 9);
    current.done = 2;
    final planned = work('planned', 14);
    final board = WorkBoard(tasks: [planned, future, current]);
    expect(WorkStagePresentationService.currentTask(
      board, board.tasks, at: now)?.id, 'on site');

    current.accepted = current.quantity;
    current.done = current.quantity;
    expect(WorkStagePresentationService.currentTask(
      board, board.tasks, at: now)?.id, 'planned');
    planned.done = planned.quantity;
    planned.accepted = planned.quantity;
    future.done = future.quantity;
    future.accepted = future.quantity;
    expect(WorkStagePresentationService.currentTask(
      board, board.tasks, at: now), isNull);
  });

  test('attention-only tasks are reserved for Control, never shown as next work', () {
    final review = work('review', 2);
    review.needsQuantityReview = true;
    final task = work('electrical', 4);
    final board = WorkBoard(tasks: [review, task]);
    expect(WorkStatusService.state(board, review),
      WorkState.quantityReview);
    expect(WorkStagePresentationService.currentTask(
      board, board.tasks, at: DateTime(2026, 11, 4))?.id, 'electrical');
  });

  test('preexisting task list is not mutated when calculating display order', () {
    final late = work('Поздняя', 9);
    final early = work('Ранняя', 2);
    final source = [late, early];
    final sorted = WorkStagePresentationService.order(source);
    expect(source.first.id, 'Поздняя');
    expect(sorted.first.id, 'Ранняя');
    expect(sorted.last.id, 'Поздняя');
  });
}
