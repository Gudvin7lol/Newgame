/// Runtime frustum-culling policy for placed catalogue objects.
///
/// Imported GLBs are transformed from authored dimensions into measured plan
/// dimensions. On some mobile GPUs a stale or over-tight subtree bound can
/// make furniture disappear while the camera rotates. Quality mode therefore
/// favours stable visibility for normal-sized interior scenes, while
/// Performance mode and very dense projects keep frustum culling enabled.
class ZamerModelVisibilityPolicy {
  const ZamerModelVisibilityPolicy._();

  static const int qualityAlwaysVisibleObjectLimit = 240;
  static const int performanceAlwaysVisibleObjectLimit = 80;

  static bool frustumCulled({
    required bool performanceMode,
    required bool photoQuality,
    required bool walkMode,
    required int visibleObjectCount,
  }) {
    if (photoQuality) return false;

    // Walk Mode is where stale imported-model bounds are most noticeable:
    // furniture can appear to blink out while the camera turns. Keep normal
    // interior scenes pinned there, even on Performance, and only re-enable
    // culling once the scene is genuinely dense.
    if (walkMode && visibleObjectCount <= qualityAlwaysVisibleObjectLimit) {
      return false;
    }

    if (performanceMode) {
      return visibleObjectCount > performanceAlwaysVisibleObjectLimit;
    }
    return visibleObjectCount > qualityAlwaysVisibleObjectLimit;
  }
}
