import 'dart:math' as math;

import '../models/models.dart';

/// Shared math for direct manipulation in the main plan editor.
///
/// Keeping object and floor-layout movement outside the widget prevents a UI
/// refresh from silently dropping the actual editing behaviour again.
class PlanDirectInteraction {
  const PlanDirectInteraction._();

  static void moveObjectByMm(
    PlanObject object, {
    required double dxMm,
    required double dyMm,
    double snapMm = 10,
  }) {
    final x = object.xMm + dxMm;
    final y = object.yMm + dyMm;
    if (snapMm > 0) {
      object.xMm = (x / snapMm).round() * snapMm;
      object.yMm = (y / snapMm).round() * snapMm;
    } else {
      object.xMm = x;
      object.yMm = y;
    }
  }

  static void shiftFloorLayout(
    RoomMaterialSettings settings, {
    required double worldDxMm,
    required double worldDyMm,
  }) {
    final isTile = settings.floorMode == 'tile' || settings.floorTile;
    final extra = isTile && settings.tilePattern == 'diagonal' ? 45.0 : 0.0;
    final angle = (settings.floorDirectionDeg + extra) * math.pi / 180;
    final dx = worldDxMm * math.cos(angle) + worldDyMm * math.sin(angle);
    final dy = -worldDxMm * math.sin(angle) + worldDyMm * math.cos(angle);

    if (isTile) {
      settings.tileOffsetXMm = _wrapped(
        settings.tileOffsetXMm + dx,
        settings.tileWidthMm,
      );
      settings.tileOffsetYMm = _wrapped(
        settings.tileOffsetYMm + dy,
        settings.tileHeightMm,
      );
    } else {
      settings.laminateOffsetXMm = _wrapped(
        settings.laminateOffsetXMm + dx,
        settings.laminatePlankLengthMm,
      );
      settings.laminateOffsetYMm = _wrapped(
        settings.laminateOffsetYMm + dy,
        settings.laminatePlankWidthMm,
      );
    }
  }

  static double _wrapped(double value, double module) {
    if (!module.isFinite || module <= 0) return value;
    final wrapped = value % module;
    return wrapped < 0 ? wrapped + module : wrapped;
  }
}
