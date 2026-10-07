import 'dart:math' as math;

import '../models/models.dart';

class TileCutSummary {
  const TileCutSummary({
    required this.leftMm,
    required this.rightMm,
    required this.topMm,
    required this.bottomMm,
  });

  final double leftMm;
  final double rightMm;
  final double topMm;
  final double bottomMm;

  double get minimumMm => math
      .min(
        math.min(_effective(leftMm), _effective(rightMm)),
        math.min(_effective(topMm), _effective(bottomMm)),
      )
      .toDouble();

  static double _effective(double v) => v <= 0.5 ? double.infinity : v;
}

class BalancedTileOffset {
  const BalancedTileOffset({
    required this.xMm,
    required this.yMm,
    required this.cuts,
  });
  final double xMm;
  final double yMm;
  final TileCutSummary cuts;
}

class LayoutService {
  static void copyFloorPattern(
    RoomMaterialSettings from,
    RoomMaterialSettings to,
  ) {
    to.floorMode = from.floorMode;
    to.floorTile = from.floorTile;
    to.floorDirectionDeg = from.floorDirectionDeg;
    to.laminatePlankLengthMm = from.laminatePlankLengthMm;
    to.laminatePlankWidthMm = from.laminatePlankWidthMm;
    to.laminateOffsetMode = from.laminateOffsetMode;
    to.laminatePattern = from.laminatePattern;
    to.laminateOffsetXMm = from.laminateOffsetXMm;
    to.laminateOffsetYMm = from.laminateOffsetYMm;
    to.underlayMode = from.underlayMode;
    to.underlayRollWidthMm = from.underlayRollWidthMm;
    to.underlaySheetWidthMm = from.underlaySheetWidthMm;
    to.underlaySheetHeightMm = from.underlaySheetHeightMm;
    to.underlayOffsetXMm = from.underlayOffsetXMm;
    to.underlayOffsetYMm = from.underlayOffsetYMm;
    to.tileWidthMm = from.tileWidthMm;
    to.tileHeightMm = from.tileHeightMm;
    to.tilePattern = from.tilePattern;
    to.tileOffsetXMm = from.tileOffsetXMm;
    to.tileOffsetYMm = from.tileOffsetYMm;
    to.floorTileGroutMm = from.floorTileGroutMm;
  }

  static ({double minX, double maxX, double minY, double maxY}) groupBounds(
    List<RoomFace> faces,
    double directionDeg,
    math.Point<double> anchor,
  ) {
    final angle = -directionDeg * math.pi / 180;
    final points = faces
        .expand((face) => finishPolygon(face))
        .map((point) => _rotateAround(point, anchor, angle))
        .toList();
    if (points.isEmpty) return (minX: 0, maxX: 0, minY: 0, maxY: 0);
    return (
      minX: points.map((p) => p.x - anchor.x).reduce(math.min),
      maxX: points.map((p) => p.x - anchor.x).reduce(math.max),
      minY: points.map((p) => p.y - anchor.y).reduce(math.min),
      maxY: points.map((p) => p.y - anchor.y).reduce(math.max),
    );
  }

  static ({double xMm, double yMm}) originForGroup(
    List<RoomFace> faces,
    RoomMaterialSettings s,
    math.Point<double> anchor,
    String mode,
    String kind,
  ) {
    final direction = kind == 'tile' ? tileDirection(s) : s.floorDirectionDeg;
    final b = groupBounds(faces, direction, anchor);
    final mx = kind == 'tile'
        ? s.tileWidthMm
        : kind == 'laminate'
        ? s.laminatePlankLengthMm
        : s.underlayMode == 'sheet'
        ? s.underlaySheetWidthMm
        : s.underlayRollWidthMm;
    final my = kind == 'tile'
        ? s.tileHeightMm
        : kind == 'laminate'
        ? s.laminatePlankWidthMm
        : s.underlayMode == 'sheet'
        ? s.underlaySheetHeightMm
        : s.underlayRollWidthMm;
    double offset(double min, double max, double module) => mode == 'symmetric'
        ? symmetricAxisOffset(min, max, module)
        : bestAxisOffset(min, max, module);
    return (xMm: offset(b.minX, b.maxX, mx), yMm: offset(b.minY, b.maxY, my));
  }

  static double groupPreviewScale(
    List<RoomFace> faces,
    double width,
    double height,
  ) {
    final points = faces.expand(finishPolygon).toList();
    if (points.isEmpty || width <= 40 || height <= 40) return 1;
    final minX = points.map((p) => p.x).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);
    return math.min(
      (width - 36) / math.max(1, maxX - minX),
      (height - 36) / math.max(1, maxY - minY),
    );
  }

  static ({double xMm, double yMm, double minimumCutMm}) balanceWallTiles(
    double lengthMm,
    double fromMm,
    double toMm,
    double tileWidthMm,
    double tileHeightMm, {
    bool staggered = false,
  }) {
    if (lengthMm <= 0 ||
        toMm <= fromMm ||
        tileWidthMm < 20 ||
        tileHeightMm < 20) {
      return (xMm: 0, yMm: 0, minimumCutMm: 0);
    }
    var bestX = 0.0, bestScore = -1.0, bestBalance = double.infinity;
    final step = math.max(1.0, math.min(5.0, tileWidthMm / 24));
    for (var x = 0.0; x < tileWidthMm; x += step) {
      final even = _axisCuts(0, lengthMm, tileWidthMm, x);
      final odd = _axisCuts(0, lengthMm, tileWidthMm, x + tileWidthMm / 2);
      final cuts = staggered
          ? [even.leading, even.trailing, odd.leading, odd.trailing]
          : [even.leading, even.trailing];
      final scores = cuts.map((v) => _edgeScore(v, tileWidthMm)).toList();
      final score = scores.reduce(math.min);
      final balance = (scores[0] - scores[1]).abs();
      if (score > bestScore + .1 ||
          ((score - bestScore).abs() <= .1 && balance < bestBalance)) {
        bestX = x;
        bestScore = score;
        bestBalance = balance;
      }
    }
    final y = bestAxisOffset(0, toMm - fromMm, tileHeightMm);
    final vertical = _axisCuts(0, toMm - fromMm, tileHeightMm, y);
    final minVertical = math.min(
      _edgeScore(vertical.leading, tileHeightMm),
      _edgeScore(vertical.trailing, tileHeightMm),
    );
    return (xMm: bestX, yMm: y, minimumCutMm: math.min(bestScore, minVertical));
  }

  static math.Point<double> _rotateAround(
    math.Point<double> p,
    math.Point<double> c,
    double radians,
  ) {
    final dx = p.x - c.x;
    final dy = p.y - c.y;
    final ca = math.cos(radians);
    final sa = math.sin(radians);
    return math.Point<double>(dx * ca - dy * sa, dx * sa + dy * ca);
  }

  /// Polygon used by finish previews. Tiny acute spikes caused by wall-offset
  /// joins at T-junctions are removed so a partition does not look like a
  /// triangular bite in laminate/tile drawings.
  static List<math.Point<double>> finishPolygon(RoomFace face) {
    if (face.innerPolygon.length < 4) return List.of(face.innerPolygon);
    var pts = List<math.Point<double>>.of(face.innerPolygon);
    for (var pass = 0; pass < 3; pass++) {
      var changed = false;
      final next = <math.Point<double>>[];
      for (var i = 0; i < pts.length; i++) {
        final a = pts[(i - 1 + pts.length) % pts.length];
        final b = pts[i];
        final c = pts[(i + 1) % pts.length];
        final ab = math.Point<double>(b.x - a.x, b.y - a.y);
        final bc = math.Point<double>(c.x - b.x, c.y - b.y);
        final lab = math.sqrt(ab.x * ab.x + ab.y * ab.y);
        final lbc = math.sqrt(bc.x * bc.x + bc.y * bc.y);
        final acx = c.x - a.x;
        final acy = c.y - a.y;
        final lac = math.sqrt(acx * acx + acy * acy);
        if (lab < 0.1 || lbc < 0.1 || lac < 0.1) {
          changed = true;
          continue;
        }
        final cross = (ab.x * bc.y - ab.y * bc.x).abs();
        final distanceToChord = cross / lac;
        final dot = (a.x - b.x) * (c.x - b.x) + (a.y - b.y) * (c.y - b.y);
        final cosAngle = (dot / (lab * lbc)).clamp(-1.0, 1.0).toDouble();
        final angle = math.acos(cosAngle);
        // Keep real recesses and sharp corners. A short edge alone is not an
        // offset artifact: removing it can cut diagonally across a room.
        final almostStraight = angle > 165 * math.pi / 180;
        final tinyJoin =
            math.min(lab, lbc) < 100 && distanceToChord < 12 && almostStraight;
        if (tinyJoin) {
          changed = true;
          continue;
        }
        next.add(b);
      }
      if (!changed || next.length < 3) break;
      pts = next;
    }
    return pts.length >= 3 ? pts : List.of(face.innerPolygon);
  }

  static ({double minX, double maxX, double minY, double maxY}) localBounds(
    RoomFace face,
    double directionDeg, {
    bool finish = true,
  }) {
    final polygon = finish ? finishPolygon(face) : face.innerPolygon;
    if (polygon.isEmpty) return (minX: 0, maxX: 0, minY: 0, maxY: 0);
    final c = face.centroid;
    final angle = -directionDeg * math.pi / 180;
    final pts = polygon.map((p) => _rotateAround(p, c, angle)).toList();
    var minX = pts.first.x;
    var maxX = pts.first.x;
    var minY = pts.first.y;
    var maxY = pts.first.y;
    for (final p in pts.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  static double _positiveMod(double value, double module) {
    if (module <= 0) return 0;
    final r = value % module;
    return r < 0 ? r + module : r;
  }

  static ({double first, double last, double leading, double trailing})
  _axisCuts(double min, double max, double module, double offset) {
    if (module <= 1 || max <= min)
      return (first: min, last: max, leading: 0, trailing: 0);
    final kFirst = ((min - offset) / module).ceil();
    final kLast = ((max - offset) / module).floor();
    final first = offset + kFirst * module;
    final last = offset + kLast * module;
    var leading = first - min;
    var trailing = max - last;
    if (leading < 0.5 || (module - leading).abs() < 0.5) leading = 0;
    if (trailing < 0.5 || (module - trailing).abs() < 0.5) trailing = 0;
    return (first: first, last: last, leading: leading, trailing: trailing);
  }

  static double _edgeScore(double cut, double module) {
    if (cut <= 0.5) return module;
    return math.min(cut, module).toDouble();
  }

  static double bestAxisOffset(
    double min,
    double max,
    double module, {
    double stepMm = 5,
  }) {
    if (module <= 1 || max <= min) return 0;
    final step = math.max(1.0, math.min(stepMm, module / 12)).toDouble();
    var bestOffset = 0.0;
    var bestScore = -1.0;
    var bestBalance = double.infinity;
    for (double o = 0; o < module; o += step) {
      final cuts = _axisCuts(min, max, module, o);
      final a = _edgeScore(cuts.leading, module);
      final b = _edgeScore(cuts.trailing, module);
      final score = math.min(a, b);
      final balance = (a - b).abs();
      if (score > bestScore + 0.1 ||
          ((score - bestScore).abs() <= 0.1 && balance < bestBalance)) {
        bestScore = score;
        bestBalance = balance;
        bestOffset = o;
      }
    }
    return _positiveMod(bestOffset, module);
  }

  /// Center one complete element or a grout seam, choosing the option with
  /// wider cuts on both opposite sides of the room's bounding box.
  static double symmetricAxisOffset(double min, double max, double module) {
    if (module <= 1) return 0;
    final center = (min + max) / 2;
    final seam = _positiveMod(center, module);
    final element = _positiveMod(center - module / 2, module);
    double score(double offset) {
      final c = _axisCuts(min, max, module, offset);
      return math.min(
        _edgeScore(c.leading, module),
        _edgeScore(c.trailing, module),
      );
    }

    return score(element) > score(seam) ? element : seam;
  }

  static ({double xMm, double yMm}) originFor(
    RoomFace face,
    RoomMaterialSettings s,
    String mode,
    String kind,
  ) {
    final direction = kind == 'tile' ? tileDirection(s) : s.floorDirectionDeg;
    final b = localBounds(face, direction);
    final mx = kind == 'tile'
        ? s.tileWidthMm
        : kind == 'laminate'
        ? s.laminatePlankLengthMm
        : s.underlayMode == 'sheet'
        ? s.underlaySheetWidthMm
        : s.underlayRollWidthMm;
    final my = kind == 'tile'
        ? s.tileHeightMm
        : kind == 'laminate'
        ? s.laminatePlankWidthMm
        : s.underlayMode == 'sheet'
        ? s.underlaySheetHeightMm
        : s.underlayRollWidthMm;
    double axis(double min, double max, double module) => mode == 'symmetric'
        ? symmetricAxisOffset(min, max, module)
        : bestAxisOffset(min, max, module);
    return (xMm: axis(b.minX, b.maxX, mx), yMm: axis(b.minY, b.maxY, my));
  }

  static ({double crossSpanMm, int rows}) laminateRows(
    RoomFace face,
    RoomMaterialSettings s,
  ) {
    final b = localBounds(face, s.floorDirectionDeg);
    final span = math.max(0.0, b.maxY - b.minY).toDouble();
    final width = math.max(1.0, s.laminatePlankWidthMm).toDouble();
    return (crossSpanMm: span, rows: math.max(1, (span / width).ceil()));
  }

  static double tileDirection(RoomMaterialSettings s) =>
      s.floorDirectionDeg + (s.tilePattern == 'diagonal' ? 45 : 0);

  static TileCutSummary cutsFor(RoomFace face, RoomMaterialSettings s) {
    final b = localBounds(face, tileDirection(s));
    final x = _axisCuts(
      b.minX,
      b.maxX,
      math.max(1, s.tileWidthMm),
      s.tileOffsetXMm,
    );
    final y = _axisCuts(
      b.minY,
      b.maxY,
      math.max(1, s.tileHeightMm),
      s.tileOffsetYMm,
    );
    return TileCutSummary(
      leftMm: x.leading,
      rightMm: x.trailing,
      topMm: y.leading,
      bottomMm: y.trailing,
    );
  }

  static BalancedTileOffset balancedTileOffset(
    RoomFace face,
    RoomMaterialSettings s,
  ) {
    final b = localBounds(face, tileDirection(s));
    final ox = bestAxisOffset(b.minX, b.maxX, math.max(1, s.tileWidthMm));
    final oy = bestAxisOffset(b.minY, b.maxY, math.max(1, s.tileHeightMm));
    final shadow = RoomMaterialSettings.fromJson(s.toJson())
      ..tileOffsetXMm = ox
      ..tileOffsetYMm = oy;
    return BalancedTileOffset(xMm: ox, yMm: oy, cuts: cutsFor(face, shadow));
  }

  static double previewScale(RoomFace face, double width, double height) {
    final polygon = finishPolygon(face);
    if (polygon.length < 3 || width <= 40 || height <= 40) return 1;
    var minX = polygon.first.x;
    var maxX = minX;
    var minY = polygon.first.y;
    var maxY = minY;
    for (final p in polygon.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final modelW = math.max(1.0, maxX - minX);
    final modelH = math.max(1.0, maxY - minY);
    return math.min((width - 36) / modelW, (height - 36) / modelH).toDouble();
  }
}
