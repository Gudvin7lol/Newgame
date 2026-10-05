import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/new_material_alias_catalog.dart';

void main() {
  test('SourcePack v3 exposes all nine runtime material aliases', () {
    expect(NewMaterialAliasCatalog.runtimeBySourceId.length, 9);
    for (final id in <String>[
      'Wall_Brick_Red_01',
      'Wall_GypsumPlaster_White_01',
      'Wall_Paint_MatteWhite_01',
      'Tile_ConcreteLight_01',
      'Tile_MarbleLight_01',
      'Tile_TerrazzoLight_01',
      'Laminate_OakLight_01',
      'Laminate_WalnutWarm_01',
      'Laminate_OakSmoked_01',
    ]) {
      expect(NewMaterialAliasCatalog.runtimeIdFor(id), isNotNull, reason: id);
    }
  });
}
