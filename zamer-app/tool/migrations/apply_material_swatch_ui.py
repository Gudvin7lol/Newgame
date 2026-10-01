#!/usr/bin/env python3
"""Upgrade finish pickers with textured PBR swatches and scale metadata."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SCREEN = APP / 'lib' / 'screens' / 'materials_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f'{label} anchor not found')
    if text.count(old) != 1:
        raise RuntimeError(f'expected one {label} anchor, found {text.count(old)}')
    return text.replace(old, new, 1)


def main() -> None:
    text = SCREEN.read_text(encoding='utf-8')

    import_anchor = "import '../services/material_catalog.dart';\n"
    swatch_import = "import '../widgets/material_finish_swatch.dart';\n"
    if swatch_import not in text:
        if import_anchor not in text:
            raise RuntimeError('material catalog import anchor not found')
        text = text.replace(import_anchor, import_anchor + swatch_import, 1)

    old = """Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: m.color,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: const Color(0x33000000),
                                      ),
                                    ),
                                  )"""
    new = """MaterialFinishSwatch(
                                    material: m,
                                    size: 20,
                                    borderRadius: 5,
                                  )"""

    count = text.count(old)
    if count == 0:
        if text.count(new) < 2:
            raise RuntimeError('flat material swatches not found')
    else:
        # Floor and wall dropdowns share this exact old chip. The larger tile
        # carousel already uses full texture images and remains unchanged.
        text = text.replace(old, new)

    floor_old = """                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: 'laminate',
"""
    floor_new = """                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                      child: MaterialPbrSummary(
                        material: MaterialCatalog.byId(s.floorMaterialId),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: 'laminate',
"""
    text = replace_once(text, floor_old, floor_new, 'floor PBR summary')

    wall_old = """                    ),
                    if (s.wallMaterialId.startsWith('paint-'))
                      ListTile(
"""
    wall_new = """                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                      child: MaterialPbrSummary(
                        material: MaterialCatalog.byId(s.wallMaterialId),
                      ),
                    ),
                    if (s.wallMaterialId.startsWith('paint-'))
                      ListTile(
"""
    text = replace_once(text, wall_old, wall_new, 'wall PBR summary')

    SCREEN.write_text(text, encoding='utf-8')
    print(f'Updated material picker swatches and PBR summaries in {SCREEN}')


if __name__ == '__main__':
    main()
