from pathlib import Path

root = Path(__file__).resolve().parents[1]
viewport_path = root / 'lib/renderer3d/zamer_gpu_viewport.dart'
pubspec_path = root / 'pubspec.yaml'

source = viewport_path.read_text(encoding='utf-8')

import_anchor = "import 'cutaway_geometry.dart';\n"
policy_import = "import 'cutaway_corridor_policy.dart';\n"
if policy_import not in source:
    if import_anchor not in source:
        raise SystemExit('cutaway import anchor not found')
    source = source.replace(import_anchor, policy_import + import_anchor, 1)

old_block = """    final cameraDistance = cameraFromTarget.length;\n    final halfFov =\n        widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble() * math.pi / 360;\n    final corridorHalfWidth = math.max(\n      0.75,\n      math.tan(halfFov) * cameraDistance * 1.15,\n    );\n"""
new_block = """    final cameraDistance = cameraFromTarget.length;\n    final corridorHalfWidth = ZamerCutawayCorridorPolicy.halfWidth(\n      cameraDistanceM: cameraDistance,\n      fovDegrees: widget.cameraFovDegrees,\n    );\n"""
if new_block not in source:
    if old_block not in source:
        raise SystemExit('cutaway corridor block not found')
    source = source.replace(old_block, new_block, 1)

viewport_path.write_text(source, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
old_version = 'version: 1.5.6+114'
new_version = 'version: 1.5.6+115'
if new_version not in pubspec:
    if old_version not in pubspec:
        raise SystemExit('expected +114 pubspec version not found')
    pubspec = pubspec.replace(old_version, new_version, 1)
    pubspec_path.write_text(pubspec, encoding='utf-8')

print('Applied Zamer 1.5.6+115 focused cutaway corridor integration.')
