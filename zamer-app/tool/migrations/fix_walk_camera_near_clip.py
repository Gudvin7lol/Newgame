from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
VIEWPORT = ROOT / "lib" / "renderer3d" / "zamer_gpu_viewport.dart"

text = VIEWPORT.read_text(encoding="utf-8")

import_line = "import 'camera_clip_policy.dart';\n"
if import_line not in text:
    anchor = "import 'floor_grout_geometry.dart';\n"
    if anchor not in text:
        raise SystemExit("camera clip migration: import anchor not found")
    text = text.replace(anchor, import_line + anchor, 1)

walk_near = "fovNear: ZamerCameraClipPolicy.near(walkMode: true)"
if walk_near not in text:
    text, count = re.subn(
        r"fovNear:\s*0\.035\s*,\s*\n\s*fovFar:\s*160(?:\.0)?\s*,",
        "fovNear: ZamerCameraClipPolicy.near(walkMode: true),\n        fovFar: ZamerCameraClipPolicy.walkFarM,",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("camera clip migration: walk camera anchor not found")

walk_far = "fovFar: ZamerCameraClipPolicy.walkFarM"
if walk_far not in text:
    raise SystemExit("camera clip migration: walk far plane was not integrated")

overview_near = "fovNear: ZamerCameraClipPolicy.near(walkMode: false)"
if overview_near not in text:
    text, count = re.subn(
        r"fovNear:\s*0\.045\s*,",
        "fovNear: ZamerCameraClipPolicy.near(walkMode: false),",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("camera clip migration: overview camera anchor not found")

VIEWPORT.write_text(text, encoding="utf-8")
print("walk camera near clip policy integrated")
