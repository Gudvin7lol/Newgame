from pathlib import Path

root = Path(__file__).resolve().parents[1]
viewport_path = root / 'lib/renderer3d/zamer_gpu_viewport.dart'
pubspec_path = root / 'pubspec.yaml'

source = viewport_path.read_text(encoding='utf-8')

import_anchor = "import 'cutaway_geometry.dart';\n"
if "import 'door_floor_bridge.dart';" not in source:
    if import_anchor not in source:
        raise SystemExit('door bridge import anchor not found')
    source = source.replace(
        import_anchor,
        import_anchor + "import 'door_floor_bridge.dart';\n",
        1,
    )

opening_anchor = """    for (final opening in geometry.openings) {\n      final node = _buildOpeningNode(opening, geometry.bounds);\n      nextNodes.add(node);\n"""
opening_replacement = """    for (final opening in geometry.openings) {\n      final threshold = _buildDoorFloorBridgeNode(\n        opening,\n        geometry,\n        floorMaterialCache,\n      );\n      if (threshold != null) nextNodes.add(threshold);\n      final node = _buildOpeningNode(opening, geometry.bounds);\n      nextNodes.add(node);\n"""
if opening_replacement not in source:
    if opening_anchor not in source:
        raise SystemExit('opening integration anchor not found')
    source = source.replace(opening_anchor, opening_replacement, 1)

start_marker = '  Node? _buildUnderWallFloorNode('
end_marker = '  Node _buildWallNode('
if start_marker not in source:
    raise SystemExit('legacy under-wall helper not found')
start = source.index(start_marker)
end = source.index(end_marker, start)

bridge_method = r'''  Node? _buildDoorFloorBridgeNode(
    ZamerOpeningPlacement opening,
    ZamerSceneGeometry geometry,
    Map<String, PhysicallyBasedMaterial> materialCache,
  ) {
    final segments = buildDoorFloorBridgeSegments(
      opening: opening,
      floors: geometry.floors,
    );
    if (segments.isEmpty) return null;

    final root = Node(name: 'door-floor-bridge:${opening.id}');

    void addOverlay({
      required List<FloorGroutQuad> quads,
      required String name,
      required PhysicallyBasedMaterial material,
    }) {
      if (quads.isEmpty) return;
      final builder = GeometryBuilder(deduplicate: false)
        ..normal(vm.Vector3(0, 1, 0));
      var vertex = 0;
      for (final quad in quads) {
        if (quad.pointsMm.length != 4) continue;
        for (final point in quad.pointsMm) {
          builder
            ..texCoord(vm.Vector2.zero())
            ..addVertex(
              vm.Vector3(
                _mx(point.x, geometry.bounds),
                zamerFloorGroutYM,
                _mz(point.y, geometry.bounds),
              ),
            );
        }
        builder
          ..addTriangle(vertex, vertex + 2, vertex + 1)
          ..addTriangle(vertex, vertex + 3, vertex + 2);
        vertex += 4;
      }
      if (vertex == 0) return;
      root.add(
        Node(name: name, mesh: Mesh(builder.build(), material))
          ..castsShadows = false
          ..shadowStatic = true,
      );
    }

    for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
      final segment = segments[segmentIndex];
      final surface = segment.surface;
      final uvScale = _floorUvScaleMm(surface);
      final preset = MaterialCatalog.byId(surface.materialId);
      final isTile =
          surface.materialMode.toLowerCase().contains('tile') ||
          preset.pattern == 'tile';
      final effectiveDirection = isTile
          ? surface.directionDeg + (surface.tilePattern == 'diagonal' ? 45 : 0)
          : surface.directionDeg;
      final angle = effectiveDirection * math.pi / 180;
      final ca = math.cos(angle), sa = math.sin(angle);
      final offX = isTile ? surface.tileOffsetXMm : surface.laminateOffsetXMm;
      final offY = isTile ? surface.tileOffsetYMm : surface.laminateOffsetYMm;

      final builder = GeometryBuilder(deduplicate: false)
        ..normal(vm.Vector3(0, 1, 0));
      for (final point in segment.pointsMm) {
        final dx = point.x - surface.anchorXMm;
        final dy = point.y - surface.anchorYMm;
        final rx = dx * ca + dy * sa - offX;
        final ry = -dx * sa + dy * ca - offY;
        builder
          ..texCoord(vm.Vector2(rx / uvScale.$1, ry / uvScale.$2))
          ..addVertex(
            vm.Vector3(
              _mx(point.x, geometry.bounds),
              zamerFloorSurfaceYM,
              _mz(point.y, geometry.bounds),
            ),
          );
      }
      builder
        ..addTriangle(0, 2, 1)
        ..addTriangle(0, 3, 2);

      final materialKey =
          '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}:${uvScale.$1}:${uvScale.$2}';
      final material = materialCache.putIfAbsent(
        materialKey,
        () => _floorMaterial(surface, uvScale),
      );
      root.add(
        Node(
            name: 'door-floor-bridge:${opening.id}:$segmentIndex',
            mesh: Mesh(builder.build(), material),
          )
          ..castsShadows = false
          ..shadowStatic = true,
      );

      if (surface.laminatePattern == 'herringbone') {
        final seams = buildFloorHerringboneSeamQuads(
          polygonMm: segment.pointsMm,
          anchorXMm: surface.anchorXMm,
          anchorYMm: surface.anchorYMm,
          directionDeg: surface.directionDeg,
          plankLengthMm: surface.plankLengthMm,
          plankWidthMm: surface.plankWidthMm,
          offsetXMm: surface.laminateOffsetXMm,
          offsetYMm: surface.laminateOffsetYMm,
        );
        addOverlay(
          quads: seams,
          name: 'door-floor-herringbone:${opening.id}:$segmentIndex',
          material: _pbr(
            vm.Vector4(0.23, 0.18, 0.13, 1),
            roughness: 0.82,
          )..doubleSided = false,
        );
      } else if (isTile && surface.groutMm > 0) {
        final grout = buildFloorTileGroutQuads(
          polygonMm: segment.pointsMm,
          anchorXMm: surface.anchorXMm,
          anchorYMm: surface.anchorYMm,
          directionDeg: effectiveDirection,
          tileWidthMm: surface.tileWidthMm,
          tileHeightMm: surface.tileHeightMm,
          offsetXMm: surface.tileOffsetXMm,
          offsetYMm: surface.tileOffsetYMm,
          groutMm: surface.groutMm,
          pattern: surface.tilePattern,
        );
        addOverlay(
          quads: grout,
          name: 'door-floor-grout:${opening.id}:$segmentIndex',
          material: _pbr(
            vm.Vector4(0.68, 0.69, 0.68, 1),
            roughness: 0.94,
          )..doubleSided = false,
        );
      }
    }

    return root;
  }

'''
source = source[:start] + bridge_method + source[end:]
viewport_path.write_text(source, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
old_version = 'version: 1.5.6+112'
new_version = 'version: 1.5.6+113'
if new_version not in pubspec:
    if old_version not in pubspec:
        raise SystemExit('expected +112 pubspec version not found')
    pubspec = pubspec.replace(old_version, new_version, 1)
    pubspec_path.write_text(pubspec, encoding='utf-8')

print('Applied Zamer 1.5.6+113 door threshold floor bridge integration.')
