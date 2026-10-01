from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWPORT = ROOT / "lib" / "renderer3d" / "zamer_gpu_viewport.dart"

text = VIEWPORT.read_text(encoding="utf-8")

import_line = "import 'camera_clip_policy.dart';\n"
if import_line not in text:
    anchor = "import 'floor_grout_geometry.dart';\n"
    if anchor not in text:
        raise SystemExit("camera clip migration: import anchor not found")
    text = text.replace(anchor, import_line + anchor, 1)

old_walk = """        fovNear: 0.035,\n        fovFar: 160,\n"""
new_walk = """        fovNear: ZamerCameraClipPolicy.near(walkMode: true),\n        fovFar: ZamerCameraClipPolicy.walkFarM,\n"""
if old_walk in text:
    text = text.replace(old_walk, new_walk, 1)
elif new_walk not in text:
    raise SystemExit("camera clip migration: walk camera anchor not found")

old_overview = "        fovNear: 0.045,\n"
new_overview = "        fovNear: ZamerCameraClipPolicy.near(walkMode: false),\n"
if old_overview in text:
    text = text.replace(old_overview, new_overview, 1)
elif new_overview not in text:
    raise SystemExit("camera clip migration: overview camera anchor not found")

VIEWPORT.write_text(text, encoding="utf-8")
print("walk camera near clip policy integrated")
