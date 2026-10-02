from __future__ import annotations

import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
APP = REPO / 'zamer-app'

MATERIALS = [
    ('imported-oak-natural-1200', 'Дуб натуральный · 1200', 'Пол', 'FFD0AE83', 'wood', 'oak_natural_1200mm', .43, 1200, 1.7),
    ('imported-plaster-warm-white', 'Штукатурка тёплая белая', 'Стены', 'FFE9E4DC', 'concrete', 'plaster_warm_white_1000mm', .82, 1000, 1.15),
    ('imported-porcelain-limestone', 'Керамогранит · известняк', 'Плитка', 'FFD6CCBF', 'tile', 'porcelain_limestone_600mm', .38, 600, .8),
    ('imported-laminate-classic-oak', 'Ламинат · классический дуб', 'Пол', 'FFB48E64', 'wood', 'laminate_classic_oak', .48, 1200, 1.55),
    ('imported-parquet-herringbone', 'Паркет · натуральная ёлочка', 'Пол', 'FF8E613C', 'wood', 'parquet_natural_herringbone', .42, 600, 1.8),
    ('imported-tile-light-porcelain', 'Керамогранит · светлый', 'Плитка', 'FFCECBC0', 'tile', 'tile_light_porcelain', .28, 600, .55),
    ('imported-porcelain-gray-stone', 'Керамогранит · серый камень', 'Плитка', 'FF989B99', 'tile', 'porcelain_gray_stone', .34, 600, 1.0),
    ('imported-stone-natural-beige', 'Камень · натуральный бежевый', 'Плитка', 'FFBCB2A3', 'tile', 'stone_natural_beige', .48, 600, 1.25),
    ('imported-self-leveling-concrete', 'Наливной бетон · серый', 'Пол', 'FF989B99', 'concrete', 'self_leveling_concrete_gray', .58, 3000, 1.05),
    ('imported-plaster-warm', 'Штукатурка · тёплая', 'Стены', 'FFE1D6C4', 'concrete', 'plaster_warm', .84, 1000, 1.3),
    ('imported-microcement-grey', 'Микроцемент · серый', 'Стены', 'FFB6B5B3', 'concrete', 'microcement_grey', .70, 1000, 1.55),
    ('imported-concrete-wall', 'Бетон · стена', 'Стены', 'FF9A9793', 'concrete', 'concrete_wall', .88, 1000, 1.9),
    ('imported-paint-ivory', 'Краска · слоновая кость', 'Стены', 'FFEDE2D0', 'solid', 'paint_ivory', .78, 1000, .45),
    ('imported-brick-terracotta', 'Кирпич · терракота', 'Стены', 'FF935438', 'brick', 'brick_terracotta', .88, 1000, 3.0),
]

KITCHEN_OBJECTS = '''
    ObjectCatalogItem(
      id: 'kitchen-drawers-600',
      name: 'Кухня · тумба с ящиками 600',
      group: 'Кухня',
      type: PlanObjectType.furniture,
      widthMm: 600,
      depthMm: 624,
      heightMm: 903,
    ),
    ObjectCatalogItem(
      id: 'kitchen-sink-600-pro',
      name: 'Кухня · мойка 600 Pro',
      group: 'Кухня',
      type: PlanObjectType.furniture,
      widthMm: 600,
      depthMm: 620,
      heightMm: 1202,
    ),
    ObjectCatalogItem(
      id: 'kitchen-cooktop-600',
      name: 'Кухня · варочная панель 600',
      group: 'Кухня',
      type: PlanObjectType.furniture,
      widthMm: 600,
      depthMm: 624,
      heightMm: 908,
    ),
    ObjectCatalogItem(
      id: 'kitchen-corner-900',
      name: 'Кухня · угловой модуль 900',
      group: 'Кухня',
      type: PlanObjectType.furniture,
      widthMm: 900,
      depthMm: 995,
      heightMm: 903,
    ),
    ObjectCatalogItem(
      id: 'kitchen-pantry-600',
      name: 'Кухня · пенал 600 Pro',
      group: 'Кухня',
      type: PlanObjectType.furniture,
      widthMm: 600,
      depthMm: 624,
      heightMm: 2200,
    ),
    ObjectCatalogItem(
      id: 'fridge-built-in-610',
      name: 'Холодильник встроенный 610',
      group: 'Бытовая техника',
      type: PlanObjectType.furniture,
      widthMm: 610,
      depthMm: 624,
      heightMm: 2200,
    ),
'''.strip('\n')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'marker not found: {label}')
    return text.replace(old, new, 1)


def extract_pack(zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f'corrupt import entry: {bad}')
        root = APP.resolve()
        for member in archive.infolist():
            target = (APP / member.filename).resolve()
            if not str(target).startswith(str(root)):
                raise RuntimeError(f'unsafe zip path: {member.filename}')
        archive.extractall(APP)


def patch_material_catalog() -> None:
    path = APP / 'lib/services/material_catalog.dart'
    text = path.read_text()
    if 'static const imported20261002' in text:
        return
    rows = []
    for mid, name, category, argb, pattern, stem, rough, _, _ in MATERIALS:
        rows.append(f'''    VisualMaterialPreset(
      id: '{mid}',
      name: '{name}',
      category: '{category}',
      color: Color(0x{argb}),
      pattern: '{pattern}',
      textureAsset: 'assets/textures/imported_2026_10_02/{stem}_basecolor.webp',
      roughness: {rough:.2f},
    ),''')
    marker = '  static const presets = <VisualMaterialPreset>[\n    ...generatedV1,\n'
    replacement = (
        '  static const imported20261002 = <VisualMaterialPreset>[\n'
        + '\n'.join(rows)
        + '\n  ];\n\n'
        + '  static const presets = <VisualMaterialPreset>[\n'
        + '    ...generatedV1,\n'
        + '    ...imported20261002,\n'
    )
    path.write_text(replace_once(text, marker, replacement, 'material catalog'))


def patch_pbr_catalog() -> None:
    path = APP / 'lib/services/generated_pbr_finish_catalog.dart'
    text = path.read_text()
    if "static const _importRoot" not in text:
        text = replace_once(
            text,
            "  static const _root = 'assets/textures/generated_v1';\n",
            "  static const _root = 'assets/textures/generated_v1';\n"
            "  static const _importRoot = 'assets/textures/imported_2026_10_02';\n",
            'pbr root',
        )
    if 'static const importedByMaterialId' not in text:
        rows = []
        for mid, _, _, _, _, stem, _, scale, normal_scale in MATERIALS:
            rows.append(f'''    '{mid}': GeneratedPbrFinish(
      baseColorAsset: '$_importRoot/{stem}_basecolor.webp',
      normalAsset: '$_importRoot/{stem}_normal.webp',
      heightAsset: '$_importRoot/{stem}_normal.webp',
      metallicRoughnessAsset: '$_importRoot/{stem}_orm.webp',
      realWorldTileMm: {scale},
      normalScale: {normal_scale},
    ),''')
        marker = '  };\n\n  /// Older projects store the original material IDs.'
        replacement = (
            '  };\n\n'
            '  static const importedByMaterialId = <String, GeneratedPbrFinish>{\n'
            + '\n'.join(rows)
            + '\n  };\n\n'
            '  /// Older projects store the original material IDs.'
        )
        text = replace_once(text, marker, replacement, 'pbr map')
    resolver = '    final direct = byMaterialId[materialId];\n'
    if resolver in text:
        text = text.replace(
            resolver,
            '    final direct = byMaterialId[materialId] ?? importedByMaterialId[materialId];\n',
            1,
        )
    path.write_text(text)


def patch_object_catalog() -> None:
    path = APP / 'lib/services/object_catalog.dart'
    text = path.read_text()
    if "id: 'kitchen-drawers-600'" in text:
        return
    marker = '  ];\n\n  static ObjectCatalogItem byId(String id) =>'
    replacement = KITCHEN_OBJECTS + '\n  ];\n\n  static ObjectCatalogItem byId(String id) =>'
    path.write_text(replace_once(text, marker, replacement, 'object catalog'))


def patch_pubspec() -> None:
    path = APP / 'pubspec.yaml'
    text = path.read_text()
    if 'assets/topview/imported_2026_10_02/' in text:
        return
    marker = '    - assets/textures/generated_v1/\n'
    replacement = (
        marker
        + '    - assets/textures/imported_2026_10_02/\n'
        + '    - assets/topview/imported_2026_10_02/\n'
    )
    path.write_text(replace_once(text, marker, replacement, 'pubspec assets'))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit('usage: apply_import.py <visual-pack.zip>')
    extract_pack(Path(sys.argv[1]).resolve())
    patch_material_catalog()
    patch_pbr_catalog()
    patch_object_catalog()
    patch_pubspec()
    print('Imported 14 PBR materials, 14 top-view assets and 6 kitchen object IDs.')


if __name__ == '__main__':
    main()
