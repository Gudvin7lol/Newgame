/// Runtime frustum-culling policy for placed catalogue objects.
///
/// Imported GLBs are transformed from authored dimensions into measured plan
/// dimensions. On some mobile GPUs a stale or over-tight subtree bound can
/// make furniture disappear while the camera rotates. Quality mode therefore
/// favours stable visibility for normal-sized interior scenes, while
/// Performance mode and very dense projects keep frustum culling enabled.
class ZamerModelVisibilityPolicy {
  const ZamerModelVisibilityPolicy._();

  static const int qualityAlwaysVisibleObjectLimit = 120;

  static bool frustumCulled({
    required bool performanceMode,
    required bool photoQuality,
    required int visibleObjectCount,
  }) {
    if (photoQuality) return false;
    if (performanceMode) return true;
    return visibleObjectCount > qualityAlwaysVisibleObjectLimit;
  }
}
