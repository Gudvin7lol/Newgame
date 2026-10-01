/// Camera clipping distances in metres.
///
/// Walk Mode needs a closer near plane than the orbit overview because the
/// camera can approach thin geometry such as door leaves, frames, switches
/// and furniture. Keeping this policy separate makes the trade-off explicit
/// and testable instead of scattering magic numbers through the renderer.
class ZamerCameraClipPolicy {
  const ZamerCameraClipPolicy._();

  static const double walkNearM = 0.018;
  static const double overviewNearM = 0.045;
  static const double walkFarM = 160.0;

  static double near({required bool walkMode}) =>
      walkMode ? walkNearM : overviewNearM;
}
