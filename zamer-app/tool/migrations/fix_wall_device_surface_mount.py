from pathlib import Path

PATH = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
text = PATH.read_text(encoding='utf-8')

import_anchor = "import 'zamer_scene_geometry.dart';\n"
import_line = "import 'wall_device_mount.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        raise SystemExit('scene geometry import anchor not found')
    text = text.replace(import_anchor, import_anchor + import_line, 1)

old = '''    final nx = -math.sin(point.rotationRad);\n    final ny = math.cos(point.rotationRad);\n    final offsetMm = point.wallThicknessMm / 2 + 9;\n    final x = point.xMm + nx * offsetMm * point.wallSide;\n    final y = point.yMm + ny * offsetMm * point.wallSide;\n    final depthM = isPanel ? 0.055 : (isWallLight ? 0.075 : 0.018);\n'''
new = '''    final nx = -math.sin(point.rotationRad);\n    final ny = math.cos(point.rotationRad);\n    final depthM = isPanel ? 0.055 : (isWallLight ? 0.075 : 0.018);\n    final offsetMm = zamerWallDeviceCenterOffsetMm(\n      wallThicknessMm: point.wallThicknessMm,\n      deviceDepthM: depthM,\n    );\n    final x = point.xMm + nx * offsetMm * point.wallSide;\n    final y = point.yMm + ny * offsetMm * point.wallSide;\n'''
if old in text:
    text = text.replace(old, new, 1)
elif 'zamerWallDeviceCenterOffsetMm(' not in text:
    raise SystemExit('electrical mount block not found')

PATH.write_text(text, encoding='utf-8')
print('Wall device surface mount applied.')
