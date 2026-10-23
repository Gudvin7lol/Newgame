import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Lightweight 2.5D contact shading. The rectangles are derived from actual
/// CAD footprints, so shadows move with furniture and never become baked into
/// the catalogue raster. Rendered *before* either raster or vector artwork.
abstract final class CadContactShadowPainter {
  static void drawObject(
    Canvas canvas,
    PlanObject object, {
    required Offset center,
    required double mmToPx,
  }) {
    if (object.elevationMm > 2300 ||
        object.type == PlanObjectType.lighting ||
        object.type == PlanObjectType.ceilingZone ||
        object.type == PlanObjectType.waterPoint ||
        object.type == PlanObjectType.drainPoint) {
      return;
    }
    final width = object.widthMm * mmToPx;
    final depth = object.depthMm * mmToPx;
    if (width < 3 || depth < 3) return;

    // Rugs rest on the floor, while tall wardrobes cast a denser shadow.
    final isRug = object.catalogId.startsWith('rug-');
    final baseAlpha = isRug ? .08 : .25;
    final heightBoost = (object.heightMm / 2000).clamp(0.0, .35);
    final offset = isRug ? .35 :
        (2.1 + heightBoost * 4.5).clamp(2.1, 4.5);
    final shortest = math.min(width, depth);
    final blurRadius = isRug
        ? (shortest * .045).clamp(1.4, 4.5).toDouble()
        : (shortest * .11).clamp(2.2, 9.0).toDouble();

    // Shadow direction is fixed in world/screen space and must not rotate
    // with the furniture, though the contact silhouette itself does.
    canvas.save();
    canvas.translate(center.dx + offset, center.dy + offset * 1.25);
    canvas.rotate(object.rotationDeg * math.pi / 180);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: depth,
    );
    final rounded = RRect.fromRectAndRadius(
      rect, Radius.circular((shortest * .075).clamp(2.0, 16.0)),
    );
    canvas.drawRRect(rounded,
      Paint()
        ..color = Colors.black.withValues(alpha: baseAlpha * .55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius));
    canvas.restore();

    // Tight contact shadow beneath the footprint, for visible separation
    // without a fake elevated/disconnected look.
    canvas.save();
    canvas.translate(center.dx + .5, center.dy + .7);
    canvas.rotate(object.rotationDeg * math.pi / 180);
    canvas.drawRRect(rounded,
      Paint()
        ..color = Colors.black.withValues(alpha: baseAlpha * .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.restore();
  }

  static void drawWallUnion(Canvas canvas, Path wallBodies) {
    // Shadow is calculated once from the joined wall silhouette so inside
    // and T junctions do not generate doubled black seams.
    canvas.save();
    canvas.translate(2.4, 3.0);
    canvas.drawPath(wallBodies,
      Paint()
        ..color = Colors.black.withValues(alpha: .24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5));
    canvas.restore();

    canvas.save();
    canvas.translate(.8, 1.0);
    canvas.drawPath(wallBodies,
      Paint()
        ..color = Colors.black.withValues(alpha: .19)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
    canvas.restore();
  }
}
