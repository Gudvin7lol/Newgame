import 'package:flutter/material.dart';

/// Only a deliberate movement perpendicular to the wall starts a CAD move.
/// This prevents tiny one-finger tremors from shifting a measured wall.
class WallDragTouchPolicy {
  const WallDragTouchPolicy._();

  static const double perpendicularSlopPx = 9;

  static double perpendicularDisplacement(
    Offset touchStart,
    Offset touchNow, {
    required bool verticalWall,
  }) => verticalWall
      ? touchNow.dx - touchStart.dx
      : touchNow.dy - touchStart.dy;

  static bool shouldStart(
    Offset touchStart,
    Offset touchNow, {
    required bool verticalWall,
    double thresholdPx = perpendicularSlopPx,
  }) => perpendicularDisplacement(
    touchStart, touchNow, verticalWall: verticalWall,
  ).abs() >= thresholdPx;
}
