import 'model_asset_catalog.dart';

/// Central policy for choosing model detail without scattering magic numbers
/// through the viewport. LOD0 is always used for final photo renders. During
/// interaction we trade large-scene detail for stability and frame time.
///
/// [walkMode] is intentionally not part of the quality decision. The same
/// project must keep the same realtime geometry when switching between orbit
/// and Walk Mode, and after Photo Render restores the interactive scene.
class ZamerModelLodPolicy {
  const ZamerModelLodPolicy._();

  // Quality mode should stay visibly high-detail for a normal furnished room.
  // Ten objects was too aggressive: a sofa, bed, table, chairs and a few
  // fixtures were enough to drop the entire scene to LOD1. Keep LOD0 through
  // typical room counts and reserve LOD2 for genuinely dense projects.
  static const qualityLod1ObjectCount = 16;
  static const qualityLod2ObjectCount = 40;

  static ZamerModelLod select({
    required ZamerModelAsset asset,
    required int visibleObjectCount,
    required bool photoQuality,
    required bool walkMode,
    bool performanceMode = false,
  }) {
    if (!asset.hasCompleteLodChain || photoQuality) {
      return ZamerModelLod.lod0;
    }

    // Performance is an explicit user request for stable frame pacing. If the
    // authored model has a complete LOD chain, always use the lightest realtime
    // representation rather than waiting for the scene to become crowded.
    if (performanceMode) return ZamerModelLod.lod2;

    final count = visibleObjectCount < 0 ? 0 : visibleObjectCount;

    // Do not make Walk Mode a hidden LOD switch. Apart from visible popping,
    // Photo Render rebuild/restore could otherwise return the same project with
    // different geometry merely because the user happened to be walking.
    if (count >= qualityLod2ObjectCount) return ZamerModelLod.lod2;
    if (count >= qualityLod1ObjectCount) return ZamerModelLod.lod1;
    return ZamerModelLod.lod0;
  }

  static String pathFor({
    required ZamerModelAsset asset,
    required int visibleObjectCount,
    required bool photoQuality,
    required bool walkMode,
    bool performanceMode = false,
  }) {
    return asset.pathForLod(
      select(
        asset: asset,
        visibleObjectCount: visibleObjectCount,
        photoQuality: photoQuality,
        walkMode: walkMode,
        performanceMode: performanceMode,
      ),
    );
  }
}
