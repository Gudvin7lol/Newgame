import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/herringbone_layout.dart';

void main() {
  double distance(math.Point<double> a, math.Point<double> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  test('herringbone uses true 1380x193 rectangular planks', () {
    const length = 1380.0;
    const width = 193.0;
    final boards = buildHerringboneBoards(
      minX: -2500,
      minY: -2500,
      maxX: 2500,
      maxY: 2500,
      plankLength: length,
      plankWidth: width,
    );

    expect(boards, isNotEmpty);
    expect(boards.map((board) => board.variant).toSet(), {0, 1});

    for (final board in boards.take(20)) {
      expect(board.points.length, 4);
      expect(distance(board.points[0], board.points[1]), closeTo(length, .001));
      expect(distance(board.points[1], board.points[2]), closeTo(width, .001));
      expect(distance(board.points[2], board.points[3]), closeTo(length, .001));
      expect(distance(board.points[3], board.points[0]), closeTo(width, .001));
    }
  });

  test('one herringbone motif meets at the same physical corner', () {
    final boards = buildHerringboneBoards(
      minX: 0,
      minY: 0,
      maxX: 100,
      maxY: 100,
      plankLength: 1380,
      plankWidth: 193,
      maxBoards: 2,
    );
    expect(boards.length, 2);

    // End of +45 plank equals the short-side end of the -45 plank.
    final a = boards[0].points[1];
    final b = boards[1].points[3];
    expect(a.x, closeTo(b.x, .001));
    expect(a.y, closeTo(b.y, .001));
  });
}
