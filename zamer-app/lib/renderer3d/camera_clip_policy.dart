/// Camera clipping distances in metres.
///
/// Walk Mode needs a closer near plane than orbit overview because the camera
/// can approach door leaves, switches and furniture. Going too close, however,
/// destroys depth-buffer precision and brings z-fighting back. These values are
/// the tested compromise for interior-scale scenes.
class ZamerCameraClipPolicy {
  const ZamerCameraClipPolicy._();

  // 18 mm keeps close walk inspection usable while retaining a sane 160 m
  // far/near ratio on mobile depth buffers.
  static const double walkNearM = 0.018;

  // 30 mm is close enough for orbit inspection without sacrificing the depth
  // precision needed by wall finishes, floor layers and nearby furniture.
  static const double overviewNearM = 0.030;
  static const double walkFarM = 160.0;

  static double near({required bool walkMode}) =>
      walkMode ? walkNearM : overviewNearM;
}
