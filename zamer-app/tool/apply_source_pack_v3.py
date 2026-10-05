from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Expected marker not found in {path}: {old[:80]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


ids_path = ROOT / 'lib/services/source_pack_v3_material_ids.dart'
ids_path.write_text("""/// Stable IDs for the user supplied ZAMER New Materials SourcePack v3.\n///\n/// These IDs remain separate from GeneratedMaterialIds because the uploaded\n/// package contains source-reference sheets, while runtime rendering reuses\n/// validated production PBR profiles already bundled with the app.\nabstract final class SourcePackV3MaterialIds {\n  static const laminateOakLight = 'zamer-v3-laminate-oak-light';\n  static const laminateWalnutWarm = 'zamer-v3-laminate-walnut-warm';\n  static const laminateOakSmoked = 'zamer-v3-laminate-oak-smoked';\n  static const tileConcreteLight = 'zamer-v3-tile-concrete-light';\n  static const tileMarbleLight = 'zamer-v3-tile-marble-light';\n  static const tileTerrazzoLight = 'zamer-v3-tile-terrazzo-light';\n  static const wallBrickRed = 'zamer-v3-wall-brick-red';\n  static const wallGypsumPlasterWhite = 'zamer-v3-wall-gypsum-plaster-white';\n  static const wallPaintMatteWhite = 'zamer-v3-wall-paint-matte-white';\n\n  static const all = <String>{\n    laminateOakLight,\n    laminateWalnutWarm,\n    laminateOakSmoked,\n    tileConcreteLight,\n    tileMarbleLight,\n    tileTerrazzoLight,\n    wallBrickRed,\n    wallGypsumPlasterWhite,\n    wallPaintMatteWhite,\n  };\n}\n""", encoding='utf-8')

catalog = ROOT / 'lib/services/material_catalog.dart'
replace_once(
    catalog,
    "import 'generated_material_ids.dart';\n",
    "import 'generated_material_ids.dart';\nimport 'source_pack_v3_material_ids.dart';\n",
)
source_pack = """  static const sourcePackV3 = <VisualMaterialPreset>[\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.laminateOakLight,\n      name: 'Светлый дуб · v3',\n      category: 'Пол',\n      color: Color(0xFFD6C5A8),\n      pattern: 'wood',\n      textureAsset: 'assets/textures/floor_oak_light.png',\n      roughness: .56,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.laminateWalnutWarm,\n      name: 'Тёплый орех · v3',\n      category: 'Пол',\n      color: Color(0xFF8B6245),\n      pattern: 'wood',\n      textureAsset: 'assets/textures/floor_walnut.png',\n      roughness: .50,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.laminateOakSmoked,\n      name: 'Дымчатый дуб · v3',\n      category: 'Пол',\n      color: Color(0xFF978A79),\n      pattern: 'wood',\n      textureAsset: 'assets/textures/floor_oak_smoked.png',\n      roughness: .56,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.tileConcreteLight,\n      name: 'Бетон светлый · v3',\n      category: 'Плитка',\n      color: Color(0xFFC9C8C4),\n      pattern: 'tile',\n      textureAsset: 'assets/textures/tile_concrete.png',\n      roughness: .55,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.tileMarbleLight,\n      name: 'Мрамор светлый · v3',\n      category: 'Плитка',\n      color: Color(0xFFE9E6E0),\n      pattern: 'tile',\n      textureAsset: 'assets/textures/tile_marble.png',\n      roughness: .28,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.tileTerrazzoLight,\n      name: 'Терраццо светлый · v3',\n      category: 'Плитка',\n      color: Color(0xFFD7D4CB),\n      pattern: 'tile',\n      textureAsset: 'assets/textures/tile_terrazzo.png',\n      roughness: .48,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.wallBrickRed,\n      name: 'Красный кирпич · v3',\n      category: 'Стены',\n      color: Color(0xFFA65F49),\n      pattern: 'brick',\n      textureAsset: 'assets/textures/brick_red.png',\n      roughness: .90,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.wallGypsumPlasterWhite,\n      name: 'Гипсовая штукатурка · v3',\n      category: 'Стены',\n      color: Color(0xFFE4E0D8),\n      pattern: 'concrete',\n      textureAsset: 'assets/textures/plaster_warm.png',\n      roughness: .88,\n    ),\n    VisualMaterialPreset(\n      id: SourcePackV3MaterialIds.wallPaintMatteWhite,\n      name: 'Матовая краска · v3',\n      category: 'Стены',\n      color: Color(0xFFF0EEE9),\n      textureAsset: 'assets/textures/generated_v1/wall_paint.jpg',\n      roughness: .86,\n    ),\n  ];\n\n"""
replace_once(
    catalog,
    'class MaterialCatalog {\n  static const generatedV1 = <VisualMaterialPreset>[\n',
    'class MaterialCatalog {\n' + source_pack + '  static const generatedV1 = <VisualMaterialPreset>[\n',
)
replace_once(
    catalog,
    '  static const presets = <VisualMaterialPreset>[\n    ...generatedV1,\n',
    '  static const presets = <VisualMaterialPreset>[\n    ...sourcePackV3,\n    ...generatedV1,\n',
)

pbr = ROOT / 'lib/services/generated_pbr_finish_catalog.dart'
replace_once(
    pbr,
    "import 'generated_material_ids.dart';\n",
    "import 'generated_material_ids.dart';\nimport 'source_pack_v3_material_ids.dart';\n",
)
aliases = """    SourcePackV3MaterialIds.laminateOakLight: GeneratedMaterialIds.whiteOak,\n    SourcePackV3MaterialIds.laminateWalnutWarm: GeneratedMaterialIds.walnutPbr,\n    SourcePackV3MaterialIds.laminateOakSmoked: GeneratedMaterialIds.darkOak,\n    SourcePackV3MaterialIds.tileConcreteLight:\n        GeneratedMaterialIds.runtimeTileConcreteLight,\n    SourcePackV3MaterialIds.tileMarbleLight: GeneratedMaterialIds.marbleBiancoPbr,\n    SourcePackV3MaterialIds.tileTerrazzoLight: GeneratedMaterialIds.terrazzo,\n    SourcePackV3MaterialIds.wallBrickRed: GeneratedMaterialIds.wallRedClay,\n    SourcePackV3MaterialIds.wallGypsumPlasterWhite:\n        GeneratedMaterialIds.plasterMineralPbr,\n    SourcePackV3MaterialIds.wallPaintMatteWhite: GeneratedMaterialIds.wallPaint,\n"""
replace_once(
    pbr,
    '  static const legacyAliases = <String, String>{\n',
    '  static const legacyAliases = <String, String>{\n' + aliases,
)

source_dir = ROOT / 'tool/material_source_pack_v3'
source_dir.mkdir(parents=True, exist_ok=True)
source_dir.joinpath('README.md').write_text("""# ZAMER New Materials SourcePack v3\n\nUser-supplied source-reference package integrated in 1.5.7+118.\n\nIncluded families:\n- Walls: red brick, gypsum plaster, matte white paint.\n- Tiles: light concrete, light marble, light terrazzo.\n- Laminate: light oak, warm walnut, smoked oak.\n- Each laminate source describes 16 plank variants.\n\n## Production rule\n\nThe uploaded `source_sheet.png` files are photorealistic reference sheets, not\nstandalone 2048x2048 runtime maps. They must not be cropped and upscaled as if\nthey were production BaseColor/Normal/Roughness textures. That would reintroduce\nblurred, plastic-looking surfaces.\n\nFor this integration the nine stable material IDs are exposed in the catalog,\nwhile 3D rendering maps them onto the closest already validated `runtime_v2` PBR\nprofiles. Tile joints and physical dimensions remain procedural. Laminate plank\nlength, width, bevel, direction and layout remain procedural.\n\nFuture replacement with dedicated 2K exports can keep the same stable material\nIDs without breaking saved projects.\n""", encoding='utf-8')
manifest = {
  'package': 'Zamer New Materials SourcePack',
  'version': '3.0',
  'material_count': 9,
  'status': 'source_reference',
  'runtime_strategy': 'stable ids + validated runtime_v2 PBR aliases',
  'materials': [
    {'source_id': 'Wall_Brick_Red_01', 'id': 'zamer-v3-wall-brick-red', 'name': 'Красный кирпич', 'category': 'walls', 'runtime_alias': 'zamer-wall-red-clay'},
    {'source_id': 'Wall_GypsumPlaster_White_01', 'id': 'zamer-v3-wall-gypsum-plaster-white', 'name': 'Гипсовая штукатурка', 'category': 'walls', 'runtime_alias': 'zamer-plaster-mineral-pbr'},
    {'source_id': 'Wall_Paint_MatteWhite_01', 'id': 'zamer-v3-wall-paint-matte-white', 'name': 'Матовая краска', 'category': 'walls', 'runtime_alias': 'zamer-wall-paint'},
    {'source_id': 'Tile_ConcreteLight_01', 'id': 'zamer-v3-tile-concrete-light', 'name': 'Бетон светлый', 'category': 'tiles', 'runtime_alias': 'zamer-runtime-tile-concrete-light'},
    {'source_id': 'Tile_MarbleLight_01', 'id': 'zamer-v3-tile-marble-light', 'name': 'Мрамор светлый', 'category': 'tiles', 'runtime_alias': 'zamer-marble-bianco-pbr'},
    {'source_id': 'Tile_TerrazzoLight_01', 'id': 'zamer-v3-tile-terrazzo-light', 'name': 'Терраццо светлый', 'category': 'tiles', 'runtime_alias': 'zamer-terrazzo'},
    {'source_id': 'Laminate_OakLight_01', 'id': 'zamer-v3-laminate-oak-light', 'name': 'Светлый дуб', 'category': 'laminate', 'runtime_alias': 'zamer-white-oak', 'plank_variants': 16},
    {'source_id': 'Laminate_WalnutWarm_01', 'id': 'zamer-v3-laminate-walnut-warm', 'name': 'Тёплый орех', 'category': 'laminate', 'runtime_alias': 'zamer-walnut-pbr', 'plank_variants': 16},
    {'source_id': 'Laminate_OakSmoked_01', 'id': 'zamer-v3-laminate-oak-smoked', 'name': 'Дымчатый дуб', 'category': 'laminate', 'runtime_alias': 'zamer-dark-oak', 'plank_variants': 16},
  ],
  'runtime_target': {
    'resolution': '2048x2048',
    'maps': ['BaseColor', 'Normal', 'Roughness', 'Height', 'AO'],
    'metallic': 0,
    'tile_geometry': 'procedural',
    'laminate_geometry': 'procedural, separate planks',
  },
}
source_dir.joinpath('manifest.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

test = ROOT / 'test/source_pack_v3_materials_test.dart'
test.write_text("""import 'package:flutter_test/flutter_test.dart';\nimport 'package:zamer_app/services/generated_pbr_finish_catalog.dart';\nimport 'package:zamer_app/services/material_catalog.dart';\nimport 'package:zamer_app/services/source_pack_v3_material_ids.dart';\n\nvoid main() {\n  test('source pack v3 exposes all nine stable material ids', () {\n    expect(MaterialCatalog.sourcePackV3, hasLength(9));\n    expect(\n      MaterialCatalog.sourcePackV3.map((material) => material.id).toSet(),\n      SourcePackV3MaterialIds.all,\n    );\n  });\n\n  test('source pack v3 keeps three floors, tiles and walls', () {\n    final categories = <String, int>{};\n    for (final material in MaterialCatalog.sourcePackV3) {\n      categories.update(material.category, (value) => value + 1, ifAbsent: () => 1);\n    }\n    expect(categories['Пол'], 3);\n    expect(categories['Плитка'], 3);\n    expect(categories['Стены'], 3);\n  });\n\n  test('every source pack v3 finish resolves to production PBR', () {\n    for (final material in MaterialCatalog.sourcePackV3) {\n      expect(material.textureAsset, isNotNull, reason: material.id);\n      final pbr = GeneratedPbrFinishCatalog.byId(material.id);\n      expect(pbr, isNotNull, reason: '${material.id} must resolve to runtime PBR');\n      expect(pbr!.realWorldTileMm, greaterThan(0));\n      expect(pbr.normalScale, greaterThan(0));\n    }\n  });\n\n  test('laminate v3 stays procedural rather than baking room seams', () {\n    for (final material in MaterialCatalog.sourcePackV3\n        .where((material) => material.category == 'Пол')) {\n      expect(material.pattern, 'wood');\n      expect(material.id, contains('laminate'));\n    }\n  });\n}\n""", encoding='utf-8')

pubspec = ROOT / 'pubspec.yaml'
text = pubspec.read_text(encoding='utf-8')
if 'version: 1.5.7+118' not in text:
    if 'version: 1.5.7+117' not in text:
        raise SystemExit('Expected version 1.5.7+117')
    pubspec.write_text(text.replace('version: 1.5.7+117', 'version: 1.5.7+118', 1), encoding='utf-8')

print('SourcePack v3 integrated as Zamer 1.5.7+118')
