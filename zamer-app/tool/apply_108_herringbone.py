from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'Expected patch anchor not found in {path}: {old[:80]!r}')
    path.write_text(text.replace(old, new, 1))


# 1) GPU herringbone seam geometry. The compatibility renderer already draws
# real board geometry; this ports the same layout math to a lightweight GPU
# overlay without turning every plank into a separate scene node.
geometry_path = ROOT / 'lib/renderer3d/floor_grout_geometry.dart'
geometry = geometry_path.read_text()
if 'buildFloorHerringboneSeamQuads' not in geometry:
    geometry += r'''

/// Builds narrow seam strips for a 45-degree herringbone laminate layout.
///
/// The board grid intentionally mirrors Floor3DPainter's herringbone math, but
/// only emits the visible seams. Keeping the base floor as one textured mesh
/// avoids hundreds of scene nodes while the seam geometry makes the real plank
/// length, width, direction and offsets readable in GPU 3D and Photo Render.
List<FloorGroutQuad> buildFloorHerringboneSeamQuads({
  required List<math.Point<double>> polygonMm,
  required double anchorXMm,
  required double anchorYMm,
  required double directionDeg,
  required double plankLengthMm,
  required double plankWidthMm,
  required double offsetXMm,
  required double offsetYMm,
  double seamMm = 1.8,
}) {
  if (polygonMm.length < 3 || plankLengthMm < 100 || plankWidthMm < 40) {
    return const <FloorGroutQuad>[];
  }

  final angle = directionDeg * math.pi / 180;
  final ca = math.cos(angle);
  final sa = math.sin(angle);
  math.Point<double> toLocal(math.Point<double> p) {
    final dx = p.x - anchorXMm;
    final dy = p.y - anchorYMm;
    return math.Point<double>(dx * ca + dy * sa, -dx * sa + dy * ca);
  }

  math.Point<double> toWorld(math.Point<double> p) => math.Point<double>(
    anchorXMm + p.x * ca - p.y * sa,
    anchorYMm + p.x * sa + p.y * ca,
  );

  final polygon = polygonMm.map(toLocal).toList(growable: false);
  final minX = polygon.map((p) => p.x).reduce(math.min);
  final maxX = polygon.map((p) => p.x).reduce(math.max);
  final minY = polygon.map((p) => p.y).reduce(math.min);
  final maxY = polygon.map((p) => p.y).reduce(math.max);

  bool pointInside(math.Point<double> p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses = (a.y > p.y) != (b.y > p.y);
      if (!crosses) continue;
      final hitX = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
      if (p.x < hitX) inside = !inside;
    }
    return inside;
  }

  List<(math.Point<double>, math.Point<double>)> clipSegment(
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final rx = b.x - a.x;
    final ry = b.y - a.y;
    final ts = <double>[0, 1];
    for (var i = 0; i < polygon.length; i++) {
      final c = polygon[i];
      final d = polygon[(i + 1) % polygon.length];
      final sx = d.x - c.x;
      final sy = d.y - c.y;
      final den = rx * sy - ry * sx;
      if (den.abs() < 1e-9) continue;
      final qx = c.x - a.x;
      final qy = c.y - a.y;
      final t = (qx * sy - qy * sx) / den;
      final u = (qx * ry - qy * rx) / den;
      if (t > 1e-7 && t < 1 - 1e-7 && u >= -1e-7 && u <= 1 + 1e-7) {
        ts.add(t);
      }
    }
    ts.sort();
    final unique = <double>[];
    for (final t in ts) {
      if (unique.isEmpty || (t - unique.last).abs() > 1e-7) unique.add(t);
    }
    final visible = <(math.Point<double>, math.Point<double>)>[];
    for (var i = 0; i + 1 < unique.length; i++) {
      final t0 = unique[i];
      final t1 = unique[i + 1];
      final tm = (t0 + t1) / 2;
      final mid = math.Point<double>(a.x + rx * tm, a.y + ry * tm);
      if (!pointInside(mid)) continue;
      visible.add((
        math.Point<double>(a.x + rx * t0, a.y + ry * t0),
        math.Point<double>(a.x + rx * t1, a.y + ry * t1),
      ));
    }
    return visible;
  }

  final half = seamMm.clamp(0.6, plankWidthMm * .12).toDouble() / 2;
  final result = <FloorGroutQuad>[];
  final seen = <String>{};

  String pointKey(math.Point<double> p) =>
      '${(p.x * 10).round()}:${(p.y * 10).round()}';

  void addSegment(math.Point<double> a, math.Point<double> b) {
    for (final clipped in clipSegment(a, b)) {
      final p0 = clipped.$1;
      final p1 = clipped.$2;
      final k0 = pointKey(p0);
      final k1 = pointKey(p1);
      final key = k0.compareTo(k1) <= 0 ? '$k0|$k1' : '$k1|$k0';
      if (!seen.add(key)) continue;
      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 0.5) continue;
      final nx = -dy / length * half;
      final ny = dx / length * half;
      result.add(
        FloorGroutQuad([
          toWorld(math.Point<double>(p0.x + nx, p0.y + ny)),
          toWorld(math.Point<double>(p1.x + nx, p1.y + ny)),
          toWorld(math.Point<double>(p1.x - nx, p1.y - ny)),
          toWorld(math.Point<double>(p0.x - nx, p0.y - ny)),
        ]),
      );
    }
  }

  final run = plankLengthMm / math.sqrt2;
  final pitch = plankWidthMm * math.sqrt2;
  final ox = offsetXMm % plankLengthMm;
  final oy = offsetYMm % plankWidthMm;
  final firstRow = ((minY - run - oy) / pitch).floor();
  final lastRow = ((maxY + run - oy) / pitch).ceil();
  final firstCol = ((minX - run - ox) / run).floor();
  final lastCol = ((maxX + run - ox) / run).ceil();

  var boardCount = 0;
  for (var row = firstRow; row <= lastRow && boardCount < 30000; row++) {
    final y = row * pitch + oy;
    for (var col = firstCol; col <= lastCol && boardCount < 30000; col++) {
      final x = col * run + ox;
      final y0 = y + (col.isOdd ? run : 0);
      final y1 = y + (col.isOdd ? 0 : run);
      final p0 = math.Point<double>(x, y0);
      final p1 = math.Point<double>(x + run, y1);
      final p2 = math.Point<double>(x + run, y1 + pitch);
      final p3 = math.Point<double>(x, y0 + pitch);
      addSegment(p0, p1);
      addSegment(p1, p2);
      addSegment(p2, p3);
      addSegment(p3, p0);
      boardCount++;
    }
  }
  return result;
}
'''
    geometry_path.write_text(geometry)

viewport_path = ROOT / 'lib/renderer3d/zamer_gpu_viewport.dart'
replace_once(
    viewport_path,
    "import 'photo_render_quality_policy.dart';\nimport 'photo_export_policy.dart';\nimport 'photo_render_quality_policy.dart';",
    "import 'photo_render_quality_policy.dart';\nimport 'photo_export_policy.dart';",
)
replace_once(
    viewport_path,
    """    if (isTile && surface.groutMm > 0) {
      final grout = _buildFloorGroutNode(surface, bounds, effectiveDirection);
      if (grout != null) root.add(grout);
    }
    return root;
""",
    """    if (surface.laminatePattern == 'herringbone') {
      final seams = _buildFloorHerringboneSeamNode(surface, bounds);
      if (seams != null) root.add(seams);
    }
    if (isTile && surface.groutMm > 0) {
      final grout = _buildFloorGroutNode(surface, bounds, effectiveDirection);
      if (grout != null) root.add(grout);
    }
    return root;
""",
)
replace_once(
    viewport_path,
    """  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {
""",
    r'''  Node? _buildFloorHerringboneSeamNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
  ) {
    final quads = buildFloorHerringboneSeamQuads(
      polygonMm: surface.polygonMm,
      anchorXMm: surface.anchorXMm,
      anchorYMm: surface.anchorYMm,
      directionDeg: surface.directionDeg,
      plankLengthMm: surface.plankLengthMm,
      plankWidthMm: surface.plankWidthMm,
      offsetXMm: surface.laminateOffsetXMm,
      offsetYMm: surface.laminateOffsetYMm,
    );
    if (quads.isEmpty) return null;

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
              _mx(point.x, bounds),
              zamerFloorGroutYM,
              _mz(point.y, bounds),
            ),
          );
      }
      builder
        ..addTriangle(vertex, vertex + 2, vertex + 1)
        ..addTriangle(vertex, vertex + 3, vertex + 2);
      vertex += 4;
    }
    if (vertex == 0) return null;
    final material = _pbr(
      vm.Vector4(0.23, 0.18, 0.13, 1),
      roughness: 0.82,
    )..doubleSided = false;
    return Node(
        name: 'floor-herringbone-seams:${surface.roomKey}',
        mesh: Mesh(builder.build(), material),
      )
      ..castsShadows = false
      ..shadowStatic = true;
  }

  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {
''',
)
replace_once(
    viewport_path,
    """    if (surface.laminatePattern == 'herringbone') {
      return (
        math.max(240.0, surface.plankLengthMm),
        math.max(80.0, surface.plankWidthMm),
      );
    }
""",
    """    if (surface.laminatePattern == 'herringbone') {
      final repeatMm = math.max(
        600.0,
        generatedPbr?.realWorldTileMm ?? surface.plankLengthMm,
      );
      return (repeatMm, repeatMm);
    }
""",
)

# 2) Regression coverage for geometry and integration contract.
test_path = ROOT / 'test/floor_grout_geometry_test.dart'
test_text = test_path.read_text()
if "herringbone seam geometry follows real plank dimensions" not in test_text:
    marker = '\n}\n'
    at = test_text.rfind(marker)
    if at < 0:
        raise SystemExit('Could not find floor grout test closing brace')
    addition = r'''

  test('herringbone seam geometry follows real plank dimensions', () {
    final quads = buildFloorHerringboneSeamQuads(
      polygonMm: const [
        math.Point(0, 0),
        math.Point(3600, 0),
        math.Point(3600, 2800),
        math.Point(0, 2800),
      ],
      anchorXMm: 1800,
      anchorYMm: 1400,
      directionDeg: 17,
      plankLengthMm: 1200,
      plankWidthMm: 180,
      offsetXMm: 125,
      offsetYMm: -70,
      seamMm: 2,
    );

    expect(quads, isNotEmpty);
    expect(quads.length, lessThan(5000));
    final hasDiagonal = quads.any((quad) {
      final a = quad.pointsMm[0];
      final b = quad.pointsMm[1];
      return (a.x - b.x).abs() > 20 && (a.y - b.y).abs() > 20;
    });
    expect(hasDiagonal, isTrue);
    final hasTwoMillimetreSeam = quads.any((quad) {
      final a = quad.pointsMm[0];
      final d = quad.pointsMm[3];
      final width = math.sqrt(
        math.pow(a.x - d.x, 2) + math.pow(a.y - d.y, 2),
      );
      return (width - 2).abs() < 0.001;
    });
    expect(hasTwoMillimetreSeam, isTrue);
  });
'''
    test_path.write_text(test_text[:at] + addition + test_text[at:])

contract_path = ROOT / 'test/render_quality_contract_test.dart'
contract = contract_path.read_text()
if "floor-herringbone-seams" not in contract:
    marker = '\n}\n'
    at = contract.rfind(marker)
    if at < 0:
        raise SystemExit('Could not find render contract closing brace')
    addition = r'''

  test('GPU renderer uses real herringbone seam geometry', () {
    final renderer = File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();
    expect(renderer, contains('buildFloorHerringboneSeamQuads'));
    expect(renderer, contains('floor-herringbone-seams:'));
    expect(renderer, contains("surface.laminatePattern == 'herringbone'"));
  });
'''
    contract_path.write_text(contract[:at] + addition + contract[at:])

# render_quality_contract_test already imports dart:io on the +107 branch.

pubspec = ROOT / 'pubspec.yaml'
replace_once(pubspec, 'version: 1.5.6+107', 'version: 1.5.6+108')

print('Applied Zamer 1.5.6+108 GPU herringbone patch')
