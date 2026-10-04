/// Camera clipping distances in metres.
///
/// Walk Mode needs a very close near plane because the camera can approach thin
/// geometry such as door leaves, frames, switches and furniture. Orbit mode also
/// needs a close plane when the user zooms into a room. Keeping the policy here
/// makes the precision trade-off explicit and testable.
class ZamerCameraClipPolicy {
  const ZamerCameraClipPolicy._();

  // 18 mm was still enough to cut handles, wall lights and thin furniture when
  // walking very close to them. 8 mm keeps those details visible without making
  // the 160 m far plane unusable on mobile depth buffers.
  static const double walkNearM = 0.008;

  // The previous 30 mm overview plane made object edges disappear while orbiting
  // close to furniture. 12 mm is a better compromise for interior-scale scenes.
  static const double overviewNearM = 0.012;
  static const double walkFarM = 160.0;

  static double near({required bool walkMode}) =>
      walkMode ? walkNearM : overviewNearM;
}
