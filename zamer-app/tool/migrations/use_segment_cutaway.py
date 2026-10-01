from pathlib import Path

PATH = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
text = PATH.read_text(encoding='utf-8')

import_anchor = "import 'model_asset_catalog.dart';\n"
import_line = "import 'cutaway_geometry.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        raise SystemExit('model asset import anchor not found')
    text = text.replace(import_anchor, import_line + import_anchor, 1)

old_visual = '''      nextWallVisuals.add(\n        _WallVisual(\n          node: node,\n          x: _mx(wall.centerXMm, geometry.bounds),\n          z: _mz(wall.centerYMm, geometry.bounds),\n        ),\n      );\n'''
new_visual = '''      final centerX = _mx(wall.centerXMm, geometry.bounds);\n      final centerZ = _mz(wall.centerYMm, geometry.bounds);\n      final halfLengthM = wall.lengthMm / 2000;\n      final segmentDx = math.cos(wall.angleRad) * halfLengthM;\n      final segmentDz = math.sin(wall.angleRad) * halfLengthM;\n      nextWallVisuals.add(\n        _WallVisual(\n          node: node,\n          startX: centerX - segmentDx,\n          startZ: centerZ - segmentDz,\n          endX: centerX + segmentDx,\n          endZ: centerZ + segmentDz,\n          halfThickness: wall.thicknessMm / 2000,\n        ),\n      );\n'''
if old_visual in text:
    text = text.replace(old_visual, new_visual, 1)
elif 'startX: centerX - segmentDx' not in text:
    raise SystemExit('wall visual construction anchor not found')

old_dir = '''    final cameraDir = cameraFromTarget.normalized();\n    final cameraDistance = cameraFromTarget.length;\n'''
new_dir = '''    final cameraDistance = cameraFromTarget.length;\n'''
if old_dir in text:
    text = text.replace(old_dir, new_dir, 1)

loop_start = text.find('    for (final wall in _wallVisuals) {\n      final wallPos = vm.Vector2(wall.x, wall.z);')
loop_end_marker = '''    }\n  }\n\n  /// Creates an actual GPU scene render'''
loop_end = text.find(loop_end_marker, loop_start)
if loop_start < 0 or loop_end < 0:
    if 'zamerWallSegmentOccludesCutaway(' not in text:
        raise SystemExit('cutaway wall loop anchors not found')
else:
    replacement = '''    final targetPoint = math.Point<double>(target2.x, target2.y);\n    final cameraPoint = math.Point<double>(camera2.x, camera2.y);\n    for (final wall in _wallVisuals) {\n      final occludesTarget = zamerWallSegmentOccludesCutaway(\n        start: math.Point<double>(wall.startX, wall.startZ),\n        end: math.Point<double>(wall.endX, wall.endZ),\n        target: targetPoint,\n        camera: cameraPoint,\n        corridorHalfWidth: corridorHalfWidth,\n        wallHalfThickness: wall.halfThickness,\n      );\n      wall.node.visible = !occludesTarget;\n    }\n'''
    text = text[:loop_start] + replacement + text[loop_end:]

old_class = '''class _WallVisual {\n  const _WallVisual({required this.node, required this.x, required this.z});\n  final Node node;\n  final double x;\n  final double z;\n}\n'''
new_class = '''class _WallVisual {\n  const _WallVisual({\n    required this.node,\n    required this.startX,\n    required this.startZ,\n    required this.endX,\n    required this.endZ,\n    required this.halfThickness,\n  });\n\n  final Node node;\n  final double startX;\n  final double startZ;\n  final double endX;\n  final double endZ;\n  final double halfThickness;\n}\n'''
if old_class in text:
    text = text.replace(old_class, new_class, 1)
elif 'final double startX;' not in text:
    raise SystemExit('wall visual class anchor not found')

PATH.write_text(text, encoding='utf-8')
print('Segment-aware cutaway integrated.')
