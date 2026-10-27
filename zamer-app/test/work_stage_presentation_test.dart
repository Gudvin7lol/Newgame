import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/work_board.dart';
import 'package:zamer_app/services/work_stage_presentation_service.dart';

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
