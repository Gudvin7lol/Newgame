import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One world-space viewport for Plan / Floor / Furniture.
///
/// Values are in saved floor-plan millimetres and logical screen pixels.
/// Canvas origins, fixed canvas sizes, and per-screen fit transforms are
/// intentionally absent, so switching tabs does not jump the camera.
@immutable
class PlanViewportSnapshot {
  const PlanViewportSnapshot({
    required this.centerXMm,
    required this.centerYMm,
    required this.pixelsPerMm,
  });

  final double centerXMm;
  final double centerYMm;
  final double pixelsPerMm;

  bool get valid => centerXMm.isFinite && centerYMm.isFinite &&
      pixelsPerMm.isFinite && pixelsPerMm > 0;

  static PlanViewportSnapshot? capture({
    required Size viewport,
    required Offset origin,
    required double mmToPx,
    required Matrix4 transform,
  }) {
    if (viewport.width <= 0 || viewport.height <= 0 || mmToPx <= 0) {
      return null;
    }
    final scale = transform.getMaxScaleOnAxis();
    if (!scale.isFinite || scale <= 0) return null;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final worldPx = Offset(
      (center.dx - transform.storage[12]) / scale - origin.dx,
      (center.dy - transform.storage[13]) / scale - origin.dy,
    );
    final snapshot = PlanViewportSnapshot(
      centerXMm: worldPx.dx / mmToPx,
      centerYMm: worldPx.dy / mmToPx,
      pixelsPerMm: scale * mmToPx,
    );
    return snapshot.valid ? snapshot : null;
  }

  Matrix4? toCanvasTransform({
    required Size viewport,
    required Offset origin,
    required double mmToPx,
    double minScale = .22,
    double maxScale = 6,
  }) {
    if (!valid || viewport.width <= 0 || viewport.height <= 0 ||
        mmToPx <= 0) return null;
    final scale = (pixelsPerMm / mmToPx)
        .clamp(minScale, maxScale).toDouble();
    final worldCenter = origin +
        Offset(centerXMm * mmToPx, centerYMm * mmToPx);
    return Matrix4.identity()
      ..translate(viewport.width / 2 - worldCenter.dx * scale,
          viewport.height / 2 - worldCenter.dy * scale)
      ..scale(scale);
  }

  bool nearlyEquals(PlanViewportSnapshot other) =>
      (centerXMm - other.centerXMm).abs() < 1 &&
      (centerYMm - other.centerYMm).abs() < 1 &&
      (math.log(pixelsPerMm / other.pixelsPerMm)).abs() < .0001;
}
