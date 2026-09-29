from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+49' in pubspec:
    print('1.5.6+49 floor winding patch already applied')
    raise SystemExit(0)
if 'version: 1.5.6+48' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +49 patch')

renderer_path = APP / 'lib/renderer3d/zamer_gpu_viewport.dart'
renderer = renderer_path.read_text()
renderer = replace_once(
    renderer,
    "import 'model_lod_policy.dart';\nimport 'zamer_scene_geometry.dart';",
    "import 'model_lod_policy.dart';\nimport 'scene_mesh_winding.dart';\nimport 'zamer_scene_geometry.dart';",
    'scene winding import',
)

floor_start = renderer.index('  Node? _buildFloorNode(')
floor_end = renderer.index('  PhysicallyBasedMaterial _floorMaterial(', floor_start)
floor_section = renderer[floor_start:floor_end]
floor_section = replace_once(
    floor_section,
    "    for (var i = 0; i < indices.length; i += 3) {\n      builder.addTriangle(indices[i], indices[i + 1], indices[i + 2]);\n    }",
    "    // Plan polygons are CCW in XY, but mapping plan Y to GPU +Z flips\n"
    "    // handedness. Reverse every triangle so the visible floor face has a\n"
    "    // +Y geometric normal, matching the authored +Y vertex normal.\n"
    "    final floorIndices = floorFacingTriangleIndices(indices);\n"
    "    for (var i = 0; i < floorIndices.length; i += 3) {\n"
    "      builder.addTriangle(\n"
    "        floorIndices[i],\n"
    "        floorIndices[i + 1],\n"
    "        floorIndices[i + 2],\n"
    "      );\n"
    "    }",
    'floor triangle winding',
)
renderer = renderer[:floor_start] + floor_section + renderer[floor_end:]

floor_material_start = renderer.index('  PhysicallyBasedMaterial _floorMaterial(')
floor_material_end = renderer.index('  TextureSource? _textureForFloorSurface(', floor_material_start)
floor_material = renderer[floor_material_start:floor_material_end]
floor_material = replace_once(
    floor_material,
    '      ..doubleSided = true;',
    '      ..doubleSided = false;',
    'floor single-sided PBR',
)
renderer = renderer[:floor_material_start] + floor_material + renderer[floor_material_end:]

ceiling_start = renderer.index('  Node? _buildCeilingNode(')
ceiling_end = renderer.index('  Node? _buildUnderWallFloorNode(', ceiling_start)
ceiling_section = renderer[ceiling_start:ceiling_end]
ceiling_section = replace_once(
    ceiling_section,
    "    for (var i = 0; i < indices.length; i += 3) {\n      builder.addTriangle(indices[i + 2], indices[i + 1], indices[i]);\n    }",
    "    // The original plan winding maps to -Y in XZ, which is exactly the\n"
    "    // visible underside of the ceiling in Walk Mode. Do not reverse it.\n"
    "    for (var i = 0; i < indices.length; i += 3) {\n"
    "      builder.addTriangle(indices[i], indices[i + 1], indices[i + 2]);\n"
    "    }",
    'ceiling triangle winding',
)
ceiling_section = replace_once(
    ceiling_section,
    '      ..doubleSided = true;',
    '      ..doubleSided = false;',
    'ceiling single-sided PBR',
)
renderer = renderer[:ceiling_start] + ceiling_section + renderer[ceiling_end:]
renderer_path.write_text(renderer)

winding_path = APP / 'lib/renderer3d/scene_mesh_winding.dart'
winding_path.write_text("""/// Converts triangle indices produced from a counter-clockwise plan polygon
/// in XY into front-facing floor triangles in the renderer's XZ plane.
///
/// Zamer maps plan X -> GPU X and plan Y -> GPU +Z. That mapping reverses the
/// handedness of a polygon: a CCW triangle in plan space has a -Y geometric
/// normal after it is laid on XZ. Reversing each triangle restores +Y, so PBR
/// lighting, culling, shadows and texture shading all agree on the floor face.
List<int> floorFacingTriangleIndices(List<int> planarCcwIndices) {
  if (planarCcwIndices.length % 3 != 0) {
    throw ArgumentError.value(
      planarCcwIndices.length,
      'planarCcwIndices.length',
      'Triangle index lists must contain a multiple of three entries',
    );
  }
  final result = <int>[];
  for (var i = 0; i < planarCcwIndices.length; i += 3) {
    result.addAll(<int>[
      planarCcwIndices[i + 2],
      planarCcwIndices[i + 1],
      planarCcwIndices[i],
    ]);
  }
  return result;
}
""")

test_path = APP / 'test/scene_mesh_winding_test.dart'
test_path.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/scene_mesh_winding.dart';

void main() {
  test('plan CCW triangles are reversed for an upward GPU floor face', () {
    const plan = <({double x, double y})>[
      (x: 0.0, y: 0.0),
      (x: 4.0, y: 0.0),
      (x: 4.0, y: 3.0),
    ];
    final indices = floorFacingTriangleIndices(const <int>[0, 1, 2]);
    expect(indices, const <int>[2, 1, 0]);

    final a = plan[indices[0]];
    final b = plan[indices[1]];
    final c = plan[indices[2]];
    // GPU mapping is (plan.x, 0, plan.y). For two XZ edges u and v,
    // cross(u, v).y = u.z * v.x - u.x * v.z.
    final ux = b.x - a.x;
    final uz = b.y - a.y;
    final vx = c.x - a.x;
    final vz = c.y - a.y;
    final normalY = uz * vx - ux * vz;
    expect(normalY, greaterThan(0));
  });

  test('winding helper preserves triangle groups and rejects broken lists', () {
    expect(
      floorFacingTriangleIndices(const <int>[0, 1, 2, 0, 2, 3]),
      const <int>[2, 1, 0, 3, 2, 0],
    );
    expect(
      () => floorFacingTriangleIndices(const <int>[0, 1]),
      throwsArgumentError,
    );
  });
}
""")

pubspec_path.write_text(pubspec.replace('version: 1.5.6+48', 'version: 1.5.6+49', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = """## 1.5.6+49

- Исправлена ориентация треугольников пола после перехода на `flutter_scene 0.23`: плановый CCW-контур при переносе XY → XZ менял handedness, поэтому видимая сторона пола фактически была back-face при нормали +Y. Из-за `doubleSided` геометрия не исчезала, но PBR освещал её некорректно и покрытие выглядело как ровная серая плоскость.
- Пол теперь разворачивает winding в +Y и рендерится односторонним PBR-материалом; текстура, освещение и геометрическая нормаль используют одну сторону поверхности.
- Потолок исправлен зеркально: его исходный winding уже даёт -Y после XY → XZ и теперь не переворачивается повторно. В Walk Mode видна корректная нижняя сторона потолка.
- Добавлен unit-тест handedness XY → XZ, чтобы этот класс ошибки не вернулся при следующем обновлении 3D-движка.

"""
changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+49 floor/ceiling winding fix')
