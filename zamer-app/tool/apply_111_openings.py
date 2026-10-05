from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWPORT = ROOT / 'zamer-app/lib/renderer3d/zamer_gpu_viewport.dart'
PUBSPEC = ROOT / 'zamer-app/pubspec.yaml'

text = VIEWPORT.read_text()

old_import = "import 'model_lod_policy.dart';\n"
new_import = old_import + "import 'opening_render_policy.dart';\n"
if "import 'opening_render_policy.dart';" not in text:
    if old_import not in text:
        raise SystemExit('model_lod_policy import marker missing')
    text = text.replace(old_import, new_import, 1)

old_metrics = """    final depthM = math.max(0.055, (opening.wallThicknessMm + 14) / 1000);\n    final widthM = math.max(0.20, opening.widthMm / 1000);\n    final heightM = math.max(0.20, opening.heightMm / 1000);\n    const frameBarM = 0.045;\n"""
new_metrics = """    final metrics = ZamerOpeningRenderMetrics.fromMillimetres(\n      widthMm: opening.widthMm,\n      heightMm: opening.heightMm,\n      wallThicknessMm: opening.wallThicknessMm,\n    );\n    final depthM = metrics.frameDepthM;\n    final widthM = metrics.widthM;\n    final heightM = metrics.heightM;\n    final frameBarM = metrics.frameBarM;\n"""
if old_metrics not in text:
    raise SystemExit('opening metric marker missing')
text = text.replace(old_metrics, new_metrics, 1)

old_bar_args = """      double depth = 0,\n      PhysicallyBasedMaterial? material,\n"""
new_bar_args = """      double depth = 0,\n      double z = 0,\n      PhysicallyBasedMaterial? material,\n"""
if old_bar_args not in text:
    raise SystemExit('bar args marker missing')
text = text.replace(old_bar_args, new_bar_args, 1)

old_bar_pos = """            ..position = vm.Vector3(x, y, 0)\n"""
new_bar_pos = """            ..position = vm.Vector3(x, y, z)\n"""
if old_bar_pos not in text:
    raise SystemExit('bar position marker missing')
text = text.replace(old_bar_pos, new_bar_pos, 1)

casing_marker = """      );\n\n    if (opening.type == OpeningType.window) {\n"""
casing_block = """      );\n\n    // Proper casings on both wall faces make the opening read as a finished\n    // door/window instead of a frame floating inside a hole. The casing is\n    // kept just outside the frame depth so it cannot z-fight with wall finish.\n    void addCasing(double faceSign) {\n      final z = faceSign *\n          (depthM / 2 + metrics.casingDepthM / 2 + 0.0015);\n      final casingWidth = metrics.casingWidthM;\n      root\n        ..add(\n          bar(\n            name: faceSign > 0\n                ? 'opening-casing-left-front'\n                : 'opening-casing-left-back',\n            x: -widthM / 2 + casingWidth / 2,\n            y: bottomM + heightM / 2,\n            width: casingWidth,\n            height: heightM + casingWidth,\n            depth: metrics.casingDepthM,\n            z: z,\n          ),\n        )\n        ..add(\n          bar(\n            name: faceSign > 0\n                ? 'opening-casing-right-front'\n                : 'opening-casing-right-back',\n            x: widthM / 2 - casingWidth / 2,\n            y: bottomM + heightM / 2,\n            width: casingWidth,\n            height: heightM + casingWidth,\n            depth: metrics.casingDepthM,\n            z: z,\n          ),\n        )\n        ..add(\n          bar(\n            name: faceSign > 0\n                ? 'opening-casing-top-front'\n                : 'opening-casing-top-back',\n            x: 0,\n            y: topM - casingWidth / 2,\n            width: widthM,\n            height: casingWidth,\n            depth: metrics.casingDepthM,\n            z: z,\n          ),\n        );\n      if (opening.type == OpeningType.window) {\n        root.add(\n          bar(\n            name: faceSign > 0\n                ? 'opening-casing-bottom-front'\n                : 'opening-casing-bottom-back',\n            x: 0,\n            y: bottomM + casingWidth / 2,\n            width: widthM,\n            height: casingWidth,\n            depth: metrics.casingDepthM,\n            z: z,\n          ),\n        );\n      }\n    }\n\n    addCasing(-1);\n    addCasing(1);\n\n    if (opening.type == OpeningType.window) {\n"""
if casing_marker not in text:
    raise SystemExit('casing insertion marker missing')
text = text.replace(casing_marker, casing_block, 1)

mullion_old = """          width: 0.032,\n          height: math.max(0.05, heightM - frameBarM * 2),\n"""
mullion_new = """          width: metrics.mullionWidthM,\n          height: math.max(0.05, heightM - frameBarM * 2),\n"""
if mullion_old not in text:
    raise SystemExit('mullion marker missing')
text = text.replace(mullion_old, mullion_new, 1)

sill_marker = """      root.add(\n        bar(\n          name: 'window-mullion',\n"""
sill_block = """      root.add(\n        bar(\n          name: 'window-sill-board',\n          x: 0,\n          y: bottomM + metrics.sillBoardThicknessM / 2,\n          width: widthM + 0.10,\n          height: metrics.sillBoardThicknessM,\n          depth: metrics.sillBoardDepthM,\n          material: whiteFrameMaterial,\n        ),\n      );\n      root.add(\n        bar(\n          name: 'window-mullion',\n"""
if sill_marker not in text:
    raise SystemExit('window sill insertion marker missing')
text = text.replace(sill_marker, sill_block, 1)

text = text.replace(
    "width: math.max(0.08, widthM - frameBarM * 2.2),",
    "width: math.max(0.08, widthM - frameBarM * 2.4),",
    1,
)
text = text.replace(
    "height: math.max(0.08, heightM - frameBarM * 2.2),",
    "height: math.max(0.08, heightM - frameBarM * 2.4),",
    1,
)

leaf_old = """      final leafWidth = math.max(0.12, widthM - frameBarM * 1.5);\n      final leafHeight = math.max(0.18, heightM - frameBarM);\n"""
leaf_new = """      final leafWidth = metrics.leafWidthM;\n      final leafHeight = metrics.leafHeightM;\n"""
if leaf_old not in text:
    raise SystemExit('door leaf metric marker missing')
text = text.replace(leaf_old, leaf_new, 1)

text = text.replace(
    "swingSign * 32 * math.pi / 180,",
    "swingSign * 42 * math.pi / 180,",
    1,
)
text = text.replace(
    "CuboidGeometry(vm.Vector3(leafWidth, leafHeight, 0.042)),",
    "CuboidGeometry(vm.Vector3(leafWidth, leafHeight, metrics.leafThicknessM)),",
    1,
)

VIEWPORT.write_text(text)

pubspec = PUBSPEC.read_text()
if 'version: 1.5.6+110' not in pubspec:
    raise SystemExit('expected +110 pubspec version missing')
PUBSPEC.write_text(pubspec.replace('version: 1.5.6+110', 'version: 1.5.6+111', 1))
