import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/material_catalog.dart';

void main() {
  test('v125 Materials catalog exposes curated wall and floor grids', () {
    final ids = MaterialCatalog.masterUiPresets.map((e) => e.id).toList();

    expect(MaterialCatalog.masterWallFinishes.length, 8);
    expect(MaterialCatalog.masterFloorFinishes.length, 8);
    expect(ids.length, greaterThanOrEqualTo(12));
    expect(ids.toSet().length, ids.length);
    expect(MaterialCatalog.masterWallFinishes, isNotEmpty);
    expect(MaterialCatalog.masterFloorFinishes, isNotEmpty);
  });

  test('ceiling finish survives project serialization', () {
    final settings = RoomMaterialSettings(
      floorTintArgb: 0xFF7A583F,
      ceilingMaterialId: 'Wall_GypsumPlaster_White_01',
      ceilingPaintColorArgb: 0xFFE8E0D4,
    );

    final restored = RoomMaterialSettings.fromJson(settings.toJson());

    expect(restored.floorTintArgb, 0xFF7A583F);
    expect(restored.ceilingMaterialId, 'Wall_GypsumPlaster_White_01');
    expect(restored.ceilingPaintColorArgb, 0xFFE8E0D4);
  });

  test('Measure uses embedded equipment and approved Materials screen', () {
    final source = File(
      'lib/screens/measure_unified_workspace_screen.dart',
    ).readAsStringSync();

    expect(source, contains('MaterialsMasterScreen('));
    expect(source, contains('embedded: true'));
    expect(source, contains('if (_layer == 5)'));
  });

  test('3D phone camera uses wider view and can look down', () {
    final screen = File('lib/screens/floor_3d_screen.dart').readAsStringSync();
    final renderer =
        File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    expect(screen, contains('cameraFovDegrees: 58'));
    expect(screen, contains('_walkMode ? -1.25'));
    expect(renderer, contains('fovRadiansY: 72 * math.pi / 180'));
    expect(renderer, contains('widget.tilt.clamp(-1.25, 0.90)'));
  });

  test('approved Materials layout keeps phone side-by-side composition', () {
    final source = File('lib/screens/materials_master_screen.dart').readAsStringSync();

    expect(source, contains("Text('Материалы'"));
    expect(source, contains('crossAxisCount: 4'));
    expect(source, contains('flex: 50'));
    expect(source, contains('Предпросмотр материала'));
    expect(source, isNot(contains('constraints.maxWidth >= 400')));
  });
}
