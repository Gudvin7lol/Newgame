from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE_GEOMETRY = ROOT / "lib" / "renderer3d" / "zamer_scene_geometry.dart"
VIEWPORT = ROOT / "lib" / "renderer3d" / "zamer_gpu_viewport.dart"
SCENE_TEST = ROOT / "test" / "zamer_scene_geometry_test.dart"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"host-wall migration: {label} anchor not found")


scene = SCENE_GEOMETRY.read_text(encoding="utf-8")
scene = replace_once(
    scene,
    """          return ZamerElectricalPlacement(\n            id: point.id,\n            type: point.type,""",
    """          return ZamerElectricalPlacement(\n            id: point.id,\n            wallId: point.wallId,\n            type: point.type,""",
    "electrical placement wall id",
)
scene = replace_once(
    scene,
    """  const ZamerElectricalPlacement({\n    required this.id,\n    required this.type,""",
    """  const ZamerElectricalPlacement({\n    required this.id,\n    required this.wallId,\n    required this.type,""",
    "electrical constructor wall id",
)
scene = replace_once(
    scene,
    """  final String id;\n  final ElectricalPointType type;""",
    """  final String id;\n  final String? wallId;\n  final ElectricalPointType type;""",
    "electrical field wall id",
)
SCENE_GEOMETRY.write_text(scene, encoding="utf-8")

scene_test = SCENE_TEST.read_text(encoding="utf-8")
scene_test = replace_once(
    scene_test,
    """    final scene = ZamerSceneGeometry.fromFloor(floor);\n    final point = scene.electrical.single;\n    expect(point.heightMm, 300);""",
    """    final scene = ZamerSceneGeometry.fromFloor(floor);\n    final point = scene.electrical.single;\n    expect(point.wallId, 'w');\n    expect(point.heightMm, 300);""",
    "scene geometry wall id test",
)
SCENE_TEST.write_text(scene_test, encoding="utf-8")

viewport = VIEWPORT.read_text(encoding="utf-8")
viewport = replace_once(
    viewport,
    """import 'floor_grout_geometry.dart';\nimport 'cutaway_geometry.dart';""",
    """import 'floor_grout_geometry.dart';\nimport 'cutaway_geometry.dart';\nimport 'host_wall_visibility.dart';""",
    "viewport host visibility import",
)
viewport = replace_once(
    viewport,
    """  final List<_WallVisual> _wallVisuals = <_WallVisual>[];\n  final List<Node> _ceilingNodes = <Node>[];""",
    """  final List<_WallVisual> _wallVisuals = <_WallVisual>[];\n  final List<_HostedWallVisual> _hostedWallVisuals = <_HostedWallVisual>[];\n  final List<Node> _ceilingNodes = <Node>[];""",
    "hosted visual state",
)
viewport = replace_once(
    viewport,
    """    final nextWallVisuals = <_WallVisual>[];\n    final nextCeilingNodes = <Node>[];""",
    """    final nextWallVisuals = <_WallVisual>[];\n    final nextHostedWallVisuals = <_HostedWallVisual>[];\n    final nextCeilingNodes = <Node>[];""",
    "staged hosted visuals",
)
viewport = replace_once(
    viewport,
    """        _WallVisual(\n          node: node,\n          startX: centerX - segmentDx,""",
    """        _WallVisual(\n          node: node,\n          wallId: wall.wallId,\n          startX: centerX - segmentDx,""",
    "wall visual wall id",
)
viewport = replace_once(
    viewport,
    """    for (final opening in geometry.openings) {\n      nextNodes.add(_buildOpeningNode(opening, geometry.bounds));\n    }\n    for (final point in geometry.electrical) {\n      nextNodes.add(_buildElectricalNode(point, geometry.bounds));\n    }""",
    """    for (final opening in geometry.openings) {\n      final node = _buildOpeningNode(opening, geometry.bounds);\n      nextNodes.add(node);\n      nextHostedWallVisuals.add(\n        _HostedWallVisual(\n          node: node,\n          wallId: opening.wallId,\n          x: _mx(opening.xMm, geometry.bounds),\n          z: _mz(opening.yMm, geometry.bounds),\n        ),\n      );\n    }\n    for (final point in geometry.electrical) {\n      final node = _buildElectricalNode(point, geometry.bounds);\n      nextNodes.add(node);\n      nextHostedWallVisuals.add(\n        _HostedWallVisual(\n          node: node,\n          wallId: point.wallId,\n          x: _mx(point.xMm, geometry.bounds),\n          z: _mz(point.yMm, geometry.bounds),\n        ),\n      );\n    }""",
    "hosted opening and electrical nodes",
)
viewport = replace_once(
    viewport,
    """    _wallVisuals\n      ..clear()\n      ..addAll(nextWallVisuals);\n    _ceilingNodes""",
    """    _wallVisuals\n      ..clear()\n      ..addAll(nextWallVisuals);\n    _hostedWallVisuals\n      ..clear()\n      ..addAll(nextHostedWallVisuals);\n    _ceilingNodes""",
    "hosted visual staged swap",
)
viewport = replace_once(
    viewport,
    """    if (!widget.cutaway || widget.walkMode || widget.tilt >= 1.32) {\n      for (final wall in _wallVisuals) {\n        wall.node.visible = true;\n      }\n      return;\n    }""",
    """    if (!widget.cutaway || widget.walkMode || widget.tilt >= 1.32) {\n      for (final wall in _wallVisuals) {\n        wall.node.visible = true;\n      }\n      for (final hosted in _hostedWallVisuals) {\n        hosted.node.visible = true;\n      }\n      return;\n    }""",
    "reset hosted visibility",
)
viewport = replace_once(
    viewport,
    """      wall.node.visible = !occludesTarget;\n    }\n  }\n\n  /// Creates an actual GPU scene render""",
    """      wall.node.visible = !occludesTarget;\n    }\n\n    final hostSegments = _wallVisuals\n        .map(\n          (wall) => ZamerHostWallSegment(\n            wallId: wall.wallId,\n            startX: wall.startX,\n            startZ: wall.startZ,\n            endX: wall.endX,\n            endZ: wall.endZ,\n            visible: wall.node.visible,\n          ),\n        )\n        .toList(growable: false);\n    for (final hosted in _hostedWallVisuals) {\n      hosted.node.visible = zamerHostedWallVisualVisible(\n        wallId: hosted.wallId,\n        x: hosted.x,\n        z: hosted.z,\n        segments: hostSegments,\n      );\n    }\n  }\n\n  /// Creates an actual GPU scene render""",
    "apply hosted visibility",
)
viewport = replace_once(
    viewport,
    """    _modelTemplates.clear();\n    _wallVisuals.clear();\n    _ceilingNodes.clear();""",
    """    _modelTemplates.clear();\n    _wallVisuals.clear();\n    _hostedWallVisuals.clear();\n    _ceilingNodes.clear();""",
    "dispose hosted visuals",
)
viewport = replace_once(
    viewport,
    """class _WallVisual {\n  const _WallVisual({\n    required this.node,\n    required this.startX,""",
    """class _WallVisual {\n  const _WallVisual({\n    required this.node,\n    required this.wallId,\n    required this.startX,""",
    "wall visual constructor wall id",
)
viewport = replace_once(
    viewport,
    """  final Node node;\n  final double startX;""",
    """  final Node node;\n  final String wallId;\n  final double startX;""",
    "wall visual field wall id",
)
viewport = replace_once(
    viewport,
    """  final double halfThickness;\n}\n\n/// Ear-clipping triangulation""",
    """  final double halfThickness;\n}\n\nclass _HostedWallVisual {\n  const _HostedWallVisual({\n    required this.node,\n    required this.wallId,\n    required this.x,\n    required this.z,\n  });\n\n  final Node node;\n  final String? wallId;\n  final double x;\n  final double z;\n}\n\n/// Ear-clipping triangulation""",
    "hosted wall visual class",
)
VIEWPORT.write_text(viewport, encoding="utf-8")

print("host-wall cutaway linkage integrated")
