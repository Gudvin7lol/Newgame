import 'dart:math' as math;

/// One physical plank in a repeating 90-degree herringbone field.
///
/// The points are returned in the caller's units (mm, px, etc.). The layout is
/// built from two real rectangles at +45/-45 degrees. One motif repeats every
/// L*sqrt(2) by W*sqrt(2), so boards meet end-to-side without the arbitrary
/// scaling/overlap that previously made the pattern drift.
class HerringboneBoard {
  const HerringboneBoard(this.points, this.variant);

  final List<math.Point<double>> points;
  final int variant;
}

List<HerringboneBoard> buildHerringboneBoards({
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  required double plankLength,
  required double plankWidth,
  double offsetX = 0,
  double offsetY = 0,
  int maxBoards = 30000,
}) {
  if (!plankLength.isFinite ||
      !plankWidth.isFinite ||
      plankLength <= 0 ||
      plankWidth <= 0 ||
      maxX <= minX ||
      maxY <= minY ||
      maxBoards <= 0) {
    return const <HerringboneBoard>[];
  }

  final r = plankLength / math.sqrt2;
  final q = plankWidth / math.sqrt2;
  final cellX = 2 * r;
  final cellY = 2 * q;

  double wrap(double value, double module) {
    final v = value % module;
    return v < 0 ? v + module : v;
  }

  final ox = wrap(offsetX, cellX);
  final oy = wrap(offsetY, cellY);

  // A motif reaches q to the left/bottom and r+q upward. Keep one extra cell
  // around the requested bounds so a caller can simply clip to its room shape.
  final firstCol = ((minX - ox - 2 * r) / cellX).floor() - 1;
  final lastCol = ((maxX - ox + q) / cellX).ceil() + 1;
  final firstRow = ((minY - oy - r - q) / cellY).floor() - 1;
  final lastRow = ((maxY - oy + q) / cellY).ceil() + 1;

  final result = <HerringboneBoard>[];
  for (var row = firstRow; row <= lastRow && result.length < maxBoards; row++) {
    final y = row * cellY + oy;
    for (var col = firstCol; col <= lastCol && result.length < maxBoards; col++) {
      final x = col * cellX + ox;

      // +45° board.
      result.add(
        HerringboneBoard(
          <math.Point<double>>[
            math.Point<double>(x, y),
            math.Point<double>(x + r, y + r),
            math.Point<double>(x + r - q, y + r + q),
            math.Point<double>(x - q, y + q),
          ],
          0,
        ),
      );
      if (result.length >= maxBoards) break;

      // -45° board. Its short end lands exactly on the long-side end of the
      // first board, producing a true herringbone joint.
      result.add(
        HerringboneBoard(
          <math.Point<double>>[
            math.Point<double>(x + r - q, y + r - q),
            math.Point<double>(x + 2 * r - q, y - q),
            math.Point<double>(x + 2 * r, y),
            math.Point<double>(x + r, y + r),
          ],
          1,
        ),
      );
    }
  }
  return result;
}
