import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/object_catalog.dart';

/// Detailed top-view symbols for the Measure CAD viewport.
///
/// The renderer stays engine-neutral: every symbol is built from the object's
/// authored millimetre bounds, so 2D and 3D keep the same physical footprint.
class TopViewObjectRenderer {
  const TopViewObjectRenderer._();

  static void draw(
    Canvas canvas,
    PlanObject object, {
    required Offset center,
    required double mmToPx,
  }) {
    final width = math.max(8.0, object.widthMm * mmToPx);
    final depth = math.max(8.0, object.depthMm * mmToPx);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: depth,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(object.rotationDeg * math.pi / 180);

    _shadow(canvas, rect);

    final id = object.catalogId;
    final item = ObjectCatalog.byId(id);

    if (id.startsWith('bed-')) {
      _bed(canvas, rect);
    } else if (id == 'sofa-corner') {
      _cornerSofa(canvas, rect);
    } else if (id.startsWith('sofa-') || id == 'sofa-modular') {
      _sofa(canvas, rect, seats: id == 'sofa-2' ? 2 : 3);
    } else if (id == 'armchair' || id == 'lounge-chair') {
      _armchair(canvas, rect);
    } else if (id == 'ottoman') {
      _ottoman(canvas, rect);
    } else if (id == 'table-round' || id == 'coffee-table') {
      _roundTable(canvas, rect);
    } else if (id == 'table-rect' ||
        id == 'dining-table-6' ||
        id == 'dining-table-1800' ||
        id == 'desk' ||
        id == 'office-desk-1400') {
      _table(canvas, rect);
    } else if (id == 'chair' ||
        id == 'dining-chair-upholstered' ||
        id == 'bar-stool') {
      _chair(canvas, rect, upholstered: id != 'chair');
    } else if (id == 'office-chair') {
      _officeChair(canvas, rect);
    } else if (id.startsWith('wardrobe-') ||
        id == 'dresser-1200' ||
        id == 'nightstand' ||
        id == 'chest-tall' ||
        id == 'shelf' ||
        id == 'bookcase-1200' ||
        id == 'tv-console-1600') {
      _storage(canvas, rect, id);
    } else if (id.startsWith('kitchen-')) {
      _kitchen(canvas, rect, id);
    } else if (id == 'fridge') {
      _fridge(canvas, rect);
    } else if (id == 'washer' || id == 'dryer' || id == 'dishwasher') {
      _appliance(canvas, rect, id);
    } else if (id == 'toilet' || id == 'bidet') {
      _toilet(canvas, rect, bidet: id == 'bidet');
    } else if (id == 'sink' || id == 'vanity-800' || id == 'basin-round') {
      _sink(canvas, rect, vanity: id != 'sink');
    } else if (id == 'bath' || id == 'bathtub-freestanding') {
      _bath(canvas, rect, freestanding: id == 'bathtub-freestanding');
    } else if (id == 'shower' ||
        id == 'shower-1200' ||
        id == 'shower-glass-1000') {
      _shower(canvas, rect);
    } else if (id.startsWith('radiator') || id == 'towel-warmer-600') {
      _radiator(canvas, rect, towel: id == 'towel-warmer-600');
    } else if (id == 'tv') {
      _tv(canvas, rect);
    } else if (id.startsWith('plant-')) {
      _plant(canvas, rect);
    } else if (item.type == PlanObjectType.lighting ||
        id.startsWith('chandelier') ||
        id.startsWith('pendant') ||
        id.startsWith('ceiling') ||
        id.startsWith('track-') ||
        id.startsWith('floor-lamp')) {
      _lighting(canvas, rect, id);
    } else {
      _generic(canvas, rect, item.type);
    }

    canvas.restore();
  }

  static const _outline = Color(0xFFF3EFE8);
  static const _outlineSoft = Color(0xFFB8C0C2);
  static const _fabric = Color(0xFFD9D2C7);
  static const _fabricLight = Color(0xFFECE7DE);
  static const _wood = Color(0xFFAA815F);
  static const _woodDark = Color(0xFF78583F);
  static const _metal = Color(0xFF7E898E);
  static const _ceramic = Color(0xFFE9ECE9);
  static const _glass = Color(0xFF75BDE7);
  static const _dark = Color(0xFF27343A);
  static const _green = Color(0xFF647B4D);

  static Paint get _stroke => Paint()
    ..color = _outline.withValues(alpha: .88)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static Paint get _thin => Paint()
    ..color = _outlineSoft.withValues(alpha: .78)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .65;

  static void _shadow(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(1.6, 2.1)),
        Radius.circular(math.max(2, math.min(rect.width, rect.height) * .08)),
      ),
      Paint()..color = Colors.black.withValues(alpha: .20),
    );
  }

  static void _bed(Canvas canvas, Rect r) {
    final radius = Radius.circular(math.max(2, r.shortestSide * .05));
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()..color = _fabric,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(r, radius), _stroke);

    final head = Rect.fromLTWH(r.left, r.top, r.width, r.height * .09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, radius),
      Paint()..color = _woodDark,
    );

    final pillowH = r.height * .17;
    final gap = r.width * .04;
    final pillowW = (r.width - gap * 3) / 2;
    for (var i = 0; i < 2; i++) {
      final pr = Rect.fromLTWH(
        r.left + gap + i * (pillowW + gap),
        r.top + r.height * .11,
        pillowW,
        pillowH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pr, Radius.circular(pr.shortestSide * .18)),
        Paint()..color = _fabricLight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pr, Radius.circular(pr.shortestSide * .18)),
        _thin,
      );
    }

    final duvet = Rect.fromLTRB(
      r.left + r.width * .045,
      r.top + r.height * .33,
      r.right - r.width * .045,
      r.bottom - r.height * .035,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(duvet, Radius.circular(duvet.shortestSide * .05)),
      Paint()..color = const Color(0xFFD4CDC0),
    );
    canvas.drawLine(
      Offset(duvet.left, duvet.top + duvet.height * .18),
      Offset(duvet.right, duvet.top + duvet.height * .18),
      _thin,
    );
  }

  static void _sofa(Canvas canvas, Rect r, {required int seats}) {
    final radius = Radius.circular(r.shortestSide * .13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()..color = _fabric,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(r, radius), _stroke);

    final back = Rect.fromLTRB(
      r.left + r.width * .08,
      r.top + r.height * .05,
      r.right - r.width * .08,
      r.top + r.height * .25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(back, Radius.circular(back.shortestSide * .25)),
      Paint()..color = const Color(0xFFC6BCAF),
    );

    final armW = r.width * .085;
    for (final arm in [
      Rect.fromLTWH(r.left, r.top + r.height * .06, armW, r.height * .88),
      Rect.fromLTWH(r.right - armW, r.top + r.height * .06, armW, r.height * .88),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(arm, Radius.circular(arm.shortestSide * .3)),
        Paint()..color = const Color(0xFFC0B5A7),
      );
    }

    final seat = Rect.fromLTRB(
      r.left + armW + r.width * .025,
      r.top + r.height * .31,
      r.right - armW - r.width * .025,
      r.bottom - r.height * .08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * .06)),
      Paint()..color = _fabricLight,
    );
    for (var i = 1; i < seats; i++) {
      final x = seat.left + seat.width * i / seats;
      canvas.drawLine(Offset(x, seat.top), Offset(x, seat.bottom), _thin);
    }
  }

  static void _cornerSofa(Canvas canvas, Rect r) {
    final horizontal = RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * .55),
      Radius.circular(r.shortestSide * .08),
    );
    final chaise = RRect.fromRectAndRadius(
      Rect.fromLTRB(r.right - r.width * .38, r.top, r.right, r.bottom),
      Radius.circular(r.shortestSide * .08),
    );
    final paint = Paint()..color = _fabric;
    canvas.drawRRect(horizontal, paint);
    canvas.drawRRect(chaise, paint);
    canvas.drawRRect(horizontal, _stroke);
    canvas.drawRRect(chaise, _stroke);
    canvas.drawLine(
      Offset(r.right - r.width * .38, r.top + r.height * .12),
      Offset(r.right - r.width * .38, r.top + r.height * .52),
      _thin,
    );
  }

  static void _armchair(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .18));
    canvas.drawRRect(rr, Paint()..color = _fabric);
    canvas.drawRRect(rr, _stroke);
    final seat = Rect.fromLTRB(
      r.left + r.width * .18,
      r.top + r.height * .27,
      r.right - r.width * .18,
      r.bottom - r.height * .12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(seat, Radius.circular(seat.shortestSide * .15)),
      Paint()..color = _fabricLight,
    );
    canvas.drawLine(
      Offset(r.left + r.width * .15, r.top + r.height * .20),
      Offset(r.right - r.width * .15, r.top + r.height * .20),
      _thin,
    );
  }

  static void _ottoman(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .24));
    canvas.drawRRect(rr, Paint()..color = _fabric);
    canvas.drawRRect(rr, _stroke);
    canvas.drawLine(r.topLeft + Offset(r.width * .15, r.height * .15), r.bottomRight - Offset(r.width * .15, r.height * .15), _thin);
    canvas.drawLine(Offset(r.right - r.width * .15, r.top + r.height * .15), Offset(r.left + r.width * .15, r.bottom - r.height * .15), _thin);
  }

  static void _roundTable(Canvas canvas, Rect r) {
    canvas.drawOval(r, Paint()..color = _wood);
    canvas.drawOval(r, _stroke);
    final radius = r.shortestSide * .09;
    canvas.drawCircle(r.center, radius, Paint()..color = _woodDark);
    canvas.drawCircle(r.center, radius, _thin);
  }

  static void _table(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .04));
    canvas.drawRRect(rr, Paint()..color = _wood);
    canvas.drawRRect(rr, _stroke);
    final insetX = r.width * .09;
    final insetY = r.height * .11;
    for (final p in [
      Offset(r.left + insetX, r.top + insetY),
      Offset(r.right - insetX, r.top + insetY),
      Offset(r.left + insetX, r.bottom - insetY),
      Offset(r.right - insetX, r.bottom - insetY),
    ]) {
      canvas.drawCircle(p, math.max(1.2, r.shortestSide * .025), Paint()..color = _woodDark);
    }
  }

  static void _chair(Canvas canvas, Rect r, {required bool upholstered}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .08));
    canvas.drawRRect(rr, Paint()..color = upholstered ? _fabric : _wood);
    canvas.drawRRect(rr, _stroke);
    final backY = r.top + r.height * .18;
    canvas.drawLine(
      Offset(r.left + r.width * .12, backY),
      Offset(r.right - r.width * .12, backY),
      _stroke,
    );
    if (upholstered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            r.left + r.width * .14,
            r.top + r.height * .29,
            r.right - r.width * .14,
            r.bottom - r.height * .10,
          ),
          Radius.circular(r.shortestSide * .06),
        ),
        Paint()..color = _fabricLight,
      );
    }
  }

  static void _officeChair(Canvas canvas, Rect r) {
    final seat = Rect.fromCenter(
      center: Offset(0, r.height * .04),
      width: r.width * .64,
      height: r.height * .55,
    );
    canvas.drawOval(seat, Paint()..color = _fabric);
    canvas.drawOval(seat, _stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -r.height * .20),
        width: r.width * .70,
        height: r.height * .48,
      ),
      math.pi,
      math.pi,
      false,
      _stroke,
    );
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final p = Offset(math.cos(a) * r.width * .42, math.sin(a) * r.height * .42);
      canvas.drawLine(Offset.zero, p, _thin);
      canvas.drawCircle(p, 1.3, Paint()..color = _metal);
    }
  }

  static void _storage(Canvas canvas, Rect r, String id) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(math.max(1, r.shortestSide * .025)));
    canvas.drawRRect(rr, Paint()..color = _wood);
    canvas.drawRRect(rr, _stroke);
    var divisions = 2;
    if (id.contains('3')) divisions = 3;
    if (id.contains('sliding')) divisions = 4;
    if (id == 'nightstand') divisions = 1;
    for (var i = 1; i < divisions; i++) {
      final x = r.left + r.width * i / divisions;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), _thin);
    }
    if (id.contains('wardrobe') || id.contains('bookcase') || id == 'shelf') {
      canvas.drawLine(
        Offset(r.left + r.width * .08, r.top + r.height * .16),
        Offset(r.right - r.width * .08, r.top + r.height * .16),
        _thin,
      );
    } else {
      for (var i = 1; i < 3; i++) {
        final y = r.top + r.height * i / 3;
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), _thin);
      }
    }
  }

  static void _kitchen(Canvas canvas, Rect r, String id) {
    canvas.drawRect(r, Paint()..color = const Color(0xFFAF8B68));
    canvas.drawRect(r, _stroke);
    final counter = Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * .16);
    canvas.drawRect(counter, Paint()..color = const Color(0xFFD5D0C5));

    if (id.contains('sink')) {
      final basin = Rect.fromCenter(
        center: r.center + Offset(0, r.height * .07),
        width: r.width * .62,
        height: r.height * .48,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(basin, Radius.circular(basin.shortestSide * .16)),
        Paint()..color = const Color(0xFF88999F),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(basin, Radius.circular(basin.shortestSide * .16)),
        _stroke,
      );
      canvas.drawCircle(
        Offset(basin.center.dx, basin.top + basin.height * .22),
        math.max(1.0, basin.shortestSide * .05),
        Paint()..color = _dark,
      );
    } else if (id.contains('oven')) {
      for (final dx in [-.23, .23]) {
        for (final dy in [-.17, .22]) {
          canvas.drawCircle(
            Offset(r.center.dx + r.width * dx, r.center.dy + r.height * dy),
            r.shortestSide * .09,
            Paint()..color = _dark,
          );
          canvas.drawCircle(
            Offset(r.center.dx + r.width * dx, r.center.dy + r.height * dy),
            r.shortestSide * .09,
            _thin,
          );
        }
      }
    } else if (id.contains('island')) {
      canvas.drawLine(
        Offset(r.left + r.width * .12, r.center.dy),
        Offset(r.right - r.width * .12, r.center.dy),
        _thin,
      );
    } else if (id.contains('upper')) {
      canvas.drawLine(r.topLeft, r.bottomRight, _thin);
      canvas.drawLine(r.topRight, r.bottomLeft, _thin);
    }
  }

  static void _fridge(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .035));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFCCD1D1));
    canvas.drawRRect(rr, _stroke);
    canvas.drawLine(
      Offset(r.center.dx, r.top + r.height * .04),
      Offset(r.center.dx, r.bottom - r.height * .04),
      _thin,
    );
    canvas.drawLine(
      Offset(r.center.dx - r.width * .06, r.top + r.height * .18),
      Offset(r.center.dx - r.width * .06, r.bottom - r.height * .18),
      Paint()
        ..color = _metal
        ..strokeWidth = 1.1,
    );
  }

  static void _appliance(Canvas canvas, Rect r, String id) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .04)),
      Paint()..color = const Color(0xFFC9CFD0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .04)),
      _stroke,
    );
    if (id == 'dishwasher') {
      canvas.drawLine(
        Offset(r.left + r.width * .12, r.top + r.height * .18),
        Offset(r.right - r.width * .12, r.top + r.height * .18),
        _thin,
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(
          Offset(r.left + r.width * (.28 + i * .14), r.top + r.height * .10),
          1.1,
          Paint()..color = _dark,
        );
      }
    } else {
      final drum = Rect.fromCenter(
        center: r.center,
        width: r.width * .62,
        height: r.height * .62,
      );
      canvas.drawOval(drum, Paint()..color = const Color(0xFF829197));
      canvas.drawOval(drum, _stroke);
      canvas.drawOval(drum.deflate(drum.shortestSide * .10), _thin);
    }
  }

  static void _toilet(Canvas canvas, Rect r, {required bool bidet}) {
    final cistern = Rect.fromLTRB(
      r.left + r.width * .14,
      r.top,
      r.right - r.width * .14,
      r.top + r.height * .25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cistern, Radius.circular(cistern.shortestSide * .16)),
      Paint()..color = _ceramic,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cistern, Radius.circular(cistern.shortestSide * .16)),
      _stroke,
    );

    final bowl = Rect.fromLTRB(
      r.left + r.width * .08,
      r.top + r.height * .20,
      r.right - r.width * .08,
      r.bottom,
    );
    canvas.drawOval(bowl, Paint()..color = _ceramic);
    canvas.drawOval(bowl, _stroke);
    canvas.drawOval(bowl.deflate(bowl.shortestSide * .19), _thin);
    if (bidet) {
      canvas.drawCircle(
        Offset(bowl.center.dx, bowl.top + bowl.height * .22),
        math.max(1.0, bowl.shortestSide * .045),
        Paint()..color = _metal,
      );
    }
  }

  static void _sink(Canvas canvas, Rect r, {required bool vanity}) {
    if (vanity) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .03)),
        Paint()..color = _wood,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .03)),
        _stroke,
      );
    }
    final basin = Rect.fromCenter(
      center: r.center,
      width: r.width * (vanity ? .62 : .88),
      height: r.height * (vanity ? .60 : .80),
    );
    canvas.drawOval(basin, Paint()..color = _ceramic);
    canvas.drawOval(basin, _stroke);
    canvas.drawOval(basin.deflate(basin.shortestSide * .18), _thin);
    canvas.drawCircle(
      Offset(basin.center.dx, basin.top + basin.height * .20),
      math.max(1.0, basin.shortestSide * .045),
      Paint()..color = _metal,
    );
  }

  static void _bath(Canvas canvas, Rect r, {required bool freestanding}) {
    final rr = RRect.fromRectAndRadius(
      r,
      Radius.circular(r.shortestSide * (freestanding ? .42 : .10)),
    );
    canvas.drawRRect(rr, Paint()..color = _ceramic);
    canvas.drawRRect(rr, _stroke);
    final inner = r.deflate(r.shortestSide * .15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.shortestSide * .42)),
      Paint()..color = const Color(0xFFB9D4DF).withValues(alpha: .52),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.shortestSide * .42)),
      _thin,
    );
    canvas.drawCircle(
      Offset(inner.right - inner.width * .08, inner.center.dy),
      math.max(1.0, inner.shortestSide * .035),
      Paint()..color = _metal,
    );
  }

  static void _shower(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = _glass.withValues(alpha: .16));
    canvas.drawRect(r, _stroke);
    final glass = Paint()
      ..color = _glass.withValues(alpha: .88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(r.topLeft, r.topRight, glass);
    canvas.drawLine(r.topRight, r.bottomRight, glass);
    canvas.drawCircle(
      Offset(r.left + r.width * .22, r.top + r.height * .22),
      math.max(1.2, r.shortestSide * .055),
      _stroke,
    );
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * .38;
      final start = Offset(r.left + r.width * .22, r.top + r.height * .22);
      final end = start + Offset(math.cos(a), math.sin(a)) * r.shortestSide * .18;
      canvas.drawLine(start, end, _thin);
    }
  }

  static void _radiator(Canvas canvas, Rect r, {required bool towel}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .08)),
      Paint()..color = const Color(0xFFBFC7C8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .08)),
      _stroke,
    );
    if (towel) {
      for (var i = 1; i < 5; i++) {
        final y = r.top + r.height * i / 5;
        canvas.drawLine(
          Offset(r.left + r.width * .08, y),
          Offset(r.right - r.width * .08, y),
          _thin,
        );
      }
    } else {
      final count = math.max(3, (r.width / math.max(7, r.height * .25)).round());
      for (var i = 1; i < count; i++) {
        final x = r.left + r.width * i / count;
        canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), _thin);
      }
    }
  }

  static void _tv(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .05)),
      Paint()..color = const Color(0xFF111719),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .05)),
      _stroke,
    );
    canvas.drawLine(
      Offset(r.left + r.width * .06, r.bottom - 1.5),
      Offset(r.right - r.width * .06, r.bottom - 1.5),
      Paint()
        ..color = _glass.withValues(alpha: .75)
        ..strokeWidth = 1.0,
    );
  }

  static void _plant(Canvas canvas, Rect r) {
    final radius = r.shortestSide * .16;
    canvas.drawCircle(r.center, radius, Paint()..color = _woodDark);
    for (var i = 0; i < 9; i++) {
      final angle = i * math.pi * 2 / 9;
      final length = r.shortestSide * (.23 + (i % 3) * .045);
      final c = r.center + Offset(math.cos(angle), math.sin(angle)) * length * .56;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: length,
          height: r.shortestSide * .16,
        ),
        Paint()..color = i.isEven ? _green : const Color(0xFF7F965D),
      );
      canvas.restore();
    }
  }

  static void _lighting(Canvas canvas, Rect r, String id) {
    final glow = Paint()..color = const Color(0xFFFFD399).withValues(alpha: .22);
    canvas.drawOval(r.inflate(math.max(2, r.shortestSide * .12)), glow);
    if (id.contains('ring') || id.contains('orbit') || id.contains('dome')) {
      canvas.drawOval(r, _stroke);
      canvas.drawOval(r.deflate(r.shortestSide * .18), _thin);
    } else if (id.startsWith('track-') || id.contains('linear')) {
      canvas.drawLine(
        Offset(r.left, r.center.dy),
        Offset(r.right, r.center.dy),
        Paint()
          ..color = _outline
          ..strokeWidth = 1.4,
      );
      for (var i = 0; i < 3; i++) {
        final x = r.left + r.width * (i + 1) / 4;
        canvas.drawCircle(Offset(x, r.center.dy), math.max(1.6, r.height * .20), _stroke);
      }
    } else {
      canvas.drawOval(r, _stroke);
      canvas.drawCircle(r.center, math.max(1.2, r.shortestSide * .10), Paint()..color = _outline);
    }
  }

  static void _generic(Canvas canvas, Rect r, PlanObjectType type) {
    final fill = switch (type) {
      PlanObjectType.sanitary => _ceramic,
      PlanObjectType.radiator => const Color(0xFFC2C8C9),
      PlanObjectType.lighting => const Color(0xFFE5C28F),
      _ => const Color(0xFFA88A70),
    };
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * .05));
    canvas.drawRRect(rr, Paint()..color = fill);
    canvas.drawRRect(rr, _stroke);
  }
}
