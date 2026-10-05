import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/material_pbr_uv_policy.dart';

void main() {
  test('plank layout keeps PBR microdetail at physical scale', () {
    final transform = ZamerMaterialPbrUvPolicy.forFloor(
      geometryUvWidthMm: 1380,
      geometryUvHeightMm: 193,
      realWorldTileMm: 1200,
    );

    expect(transform.scaleX, closeTo(1.15, 1e-9));
    expect(transform.scaleY, closeTo(193 / 1200, 1e-9));
  });

  test('rectangular tile does not squash square PBR channels', () {
    final transform = ZamerMaterialPbrUvPolicy.forFloor(
      geometryUvWidthMm: 600,
      geometryUvHeightMm: 300,
      realWorldTileMm: 600,
    );

    expect(transform.scaleX, closeTo(1, 1e-9));
    expect(transform.scaleY, closeTo(.5, 1e-9));
  });

  test('wall PBR keeps physical repeat and phase across wall pieces', () {
    final transform = ZamerMaterialPbrUvPolicy.forWall(
      wallLengthMm: 3000,
      wallHeightMm: 2700,
      textureStartMm: 1200,
      bottomMm: 600,
      realWorldTileMm: 900,
    );

    expect(transform.scaleX, closeTo(3000 / 900, 1e-9));
    expect(transform.scaleY, closeTo(3, 1e-9));
    expect(transform.offsetX, closeTo(1200 / 900, 1e-9));
    expect(transform.offsetY, closeTo(600 / 900, 1e-9));
  });

  test('invalid legacy scale falls back to a safe physical repeat', () {
    final transform = ZamerMaterialPbrUvPolicy.forFloor(
      geometryUvWidthMm: 1000,
      geometryUvHeightMm: 1000,
      realWorldTileMm: 0,
    );

    expect(transform.scaleX, closeTo(1, 1e-9));
    expect(transform.scaleY, closeTo(1, 1e-9));
  });
}
