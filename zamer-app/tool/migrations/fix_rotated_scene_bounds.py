from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "lib" / "renderer3d" / "zamer_scene_geometry.dart"

text = SCENE.read_text(encoding="utf-8")

import_line = "import 'rotated_footprint_bounds.dart';\n"
if import_line not in text:
    anchor = "import '../services/layout_service.dart';\n"
    if anchor not in text:
        raise SystemExit("rotated bounds migration: import anchor not found")
    text = text.replace(anchor, anchor + import_line, 1)

old = """    for (final o in floor.planObjects) {
      minX = math.min(minX, o.xMm - o.widthMm / 2);
      maxX = math.max(maxX, o.xMm + o.widthMm / 2);
      minY = math.min(minY, o.yMm - o.depthMm / 2);
      maxY = math.max(maxY, o.yMm + o.depthMm / 2);
    }
"""
new = """    for (final o in floor.planObjects) {
      if (o.layer == ProjectLayer.demolition) continue;
      final footprint = zamerRotatedFootprintHalfExtentsMm(
        widthMm: o.widthMm,
        depthMm: o.depthMm,
        rotationDeg: o.rotationDeg,
      );
      minX = math.min(minX, o.xMm - footprint.halfX);
      maxX = math.max(maxX, o.xMm + footprint.halfX);
      minY = math.min(minY, o.yMm - footprint.halfY);
      maxY = math.max(maxY, o.yMm + footprint.halfY);
    }
"""
if old in text:
    text = text.replace(old, new, 1)
elif "zamerRotatedFootprintHalfExtentsMm(" not in text:
    raise SystemExit("rotated bounds migration: scene bounds block not found")

SCENE.write_text(text, encoding="utf-8")
print("rotated plan-object scene bounds integrated")
