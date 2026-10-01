#!/usr/bin/env python3
"""Replace flat finish picker chips with the actual textured PBR swatch."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SCREEN = APP / 'lib' / 'screens' / 'materials_screen.dart'


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
        # Floor and wall dropdowns share this exact old chip. Tile has a slightly
        # different indent and keeps its large dedicated texture carousel below.
        text = text.replace(old, new)

    SCREEN.write_text(text, encoding='utf-8')
    print(f'Updated material picker swatches in {SCREEN}')


if __name__ == '__main__':
    main()
