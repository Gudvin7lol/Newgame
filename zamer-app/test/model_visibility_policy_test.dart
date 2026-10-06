import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_visibility_policy.dart';

void main() {
  test('quality mode keeps normal interior scenes pinned', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: false,
        photoQuality: false,
        walkMode: false,
        visibleObjectCount: 240,
      ),
      isFalse,
    );
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: false,
        photoQuality: false,
        walkMode: false,
        visibleObjectCount: 241,
      ),
      isTrue,
    );
  });

  test('performance mode still protects ordinary scenes from blinking models', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: false,
        walkMode: false,
        visibleObjectCount: 80,
      ),
      isFalse,
    );
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: false,
        walkMode: false,
        visibleObjectCount: 81,
      ),
      isTrue,
    );
  });

  test('walk mode prioritizes stable furniture visibility', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: false,
        walkMode: true,
        visibleObjectCount: 200,
      ),
      isFalse,
    );
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: false,
        walkMode: true,
        visibleObjectCount: 241,
      ),
      isTrue,
    );
  });

  test('photo render never frustum-culls placed models', () {
    expect(
      ZamerModelVisibilityPolicy.frustumCulled(
        performanceMode: true,
        photoQuality: true,
        walkMode: false,
        visibleObjectCount: 1000,
      ),
      isFalse,
    );
  });
}
