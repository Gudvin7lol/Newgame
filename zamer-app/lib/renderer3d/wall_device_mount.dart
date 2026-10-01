import 'dart:math' as math;

/// Returns the wall-normal distance from the wall centreline to the centre of a
/// surface-mounted device.
///
/// Both inputs use the renderer's existing units: wall thickness in millimetres
/// and device depth in metres. The full device stays outside the structural wall
/// instead of penetrating it and becoming visible from the opposite room.
double zamerWallDeviceCenterOffsetMm({
  required double wallThicknessMm,
  required double deviceDepthM,
  double clearanceMm = 1.0,
}) {
  final safeWallThicknessMm = math.max(0.0, wallThicknessMm);
  final safeDeviceDepthM = math.max(0.0, deviceDepthM);
  final safeClearanceMm = math.max(0.0, clearanceMm);
  return safeWallThicknessMm / 2 + safeDeviceDepthM * 500 + safeClearanceMm;
}
