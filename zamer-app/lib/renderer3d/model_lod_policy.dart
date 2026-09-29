import 'model_asset_catalog.dart';

/// Central policy for choosing model detail without scattering magic numbers
/// through the viewport. LOD0 is always used for final photo renders. During
/// interaction we trade distant/large-scene detail for stability and frame time.
class ZamerModelLodPolicy {
  const ZamerModelLodPolicy._();

  static const overviewLod1ObjectCount = 10;
  static const overviewLod2ObjectCount = 28;
  static const walkLod2ObjectCount = 18;

  static ZamerModelLod select({
    required ZamerModelAsset asset,
    required int visibleObjectCount,
    required bool photoQuality,
    required bool walkMode,
  }) {
    if (!asset.hasCompleteLodChain || photoQuality) {
      return ZamerModelLod.lod0;
    }

    final count = visibleObjectCount < 0 ? 0 : visibleObjectCount;

    // Walk mode benefits most from stable frame pacing because camera motion
    // makes dropped frames much more noticeable than in the orbit overview.
    if (walkMode) {
      if (count >= walkLod2ObjectCount) return ZamerModelLod.lod2;
      return ZamerModelLod.lod1;
    }

    if (count >= overviewLod2ObjectCount) return ZamerModelLod.lod2;
    if (count >= overviewLod1ObjectCount) return ZamerModelLod.lod1;
    return ZamerModelLod.lod0;
  }

  static String pathFor({
    required ZamerModelAsset asset,
    required int visibleObjectCount,
    required bool photoQuality,
    required bool walkMode,
  }) {
    return asset.pathForLod(
      select(
        asset: asset,
        visibleObjectCount: visibleObjectCount,
        photoQuality: photoQuality,
        walkMode: walkMode,
      ),
    );
  }
}
