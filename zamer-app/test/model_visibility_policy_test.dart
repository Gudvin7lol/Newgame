import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_visibility_policy.dart';

void main() {
  test('quality mode keeps normal interior scenes immune to false culling', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: false,
        photoQuality: false,
        visibleObjectCount: 48,
      ),
      isFalse,
    );
  });

  test('performance mode still uses frustum culling', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: false,
        visibleObjectCount: 24,
      ),
      isTrue,
    );
  });

  test('very dense quality scenes keep culling for draw-call safety', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: false,
        photoQuality: false,
        visibleObjectCount:
            ZamerModelVisibilityPolicy.qualityAlwaysVisibleObjectLimit + 1,
      ),
      isTrue,
    );
  });

  test('photo render never drops a placed object through frustum culling', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: true,
        visibleObjectCount: 500,
      ),
      isFalse,
    );
  });
}
