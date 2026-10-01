from pathlib import Path

geometry_path = Path('zamer-app/lib/renderer3d/zamer_scene_geometry.dart')
viewport_path = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
test_path = Path('zamer-app/test/zamer_scene_geometry_test.dart')
contract_path = Path('zamer-app/test/hosted_lighting_renderer_contract_test.dart')

geometry = geometry_path.read_text(encoding='utf-8')
viewport = viewport_path.read_text(encoding='utf-8')
tests = test_path.read_text(encoding='utf-8')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'Missing expected source for {label}')
    return text.replace(old, new, 1)


objects_anchor = '''    final objects = floor.planObjects
        .where((o) => o.layer != ProjectLayer.demolition)
        .map(
          (o) => ZamerObjectPlacement(
'''
objects_replacement = '''    String? hostWallIdForLightingObject(PlanObject object) {
      if (object.type != PlanObjectType.lighting) return null;
      String? nearestWallId;
      var bestDistanceSquared = 260.0 * 260.0;
      for (final point in floor.electricalPoints) {
        if (point.type != ElectricalPointType.wallLight ||
            point.wallId == null ||
            point.wallId!.isEmpty) {
          continue;
        }
        final dx = object.xMm - point.xMm;
        final dy = object.yMm - point.yMm;
        final distanceSquared = dx * dx + dy * dy;
        if (distanceSquared <= bestDistanceSquared) {
          bestDistanceSquared = distanceSquared;
          nearestWallId = point.wallId;
        }
      }
      return nearestWallId;
    }

    final objects = floor.planObjects
        .where((o) => o.layer != ProjectLayer.demolition)
        .map(
          (o) => ZamerObjectPlacement(
'''
geometry = replace_once(
    geometry,
    objects_anchor,
    objects_replacement,
    'lighting host wall resolver',
)

geometry = replace_once(
    geometry,
    '''            rotationRad: o.rotationDeg * math.pi / 180,
          ),
''',
    '''            rotationRad: o.rotationDeg * math.pi / 180,
            hostWallId: hostWallIdForLightingObject(o),
          ),
''',
    'object host wall assignment',
)

geometry = replace_once(
    geometry,
    '''    required this.rotationRad,
  });
  final String id, catalogId;
  final PlanObjectType type;
''',
    '''    required this.rotationRad,
    this.hostWallId,
  });
  final String id, catalogId;
  final PlanObjectType type;
  final String? hostWallId;
''',
    'object placement host wall field',
)

viewport = replace_once(
    viewport,
    '''      if (generation != _buildGeneration) return;
      nextNodes.add(node);
    }

    if (!mounted || generation != _buildGeneration) return;
''',
    '''      if (generation != _buildGeneration) return;
      nextNodes.add(node);
      if (object.hostWallId != null) {
        nextHostedWallVisuals.add(
          _HostedWallVisual(
            node: node,
            wallId: object.hostWallId,
            x: _mx(object.xMm, geometry.bounds),
            z: _mz(object.yMm, geometry.bounds),
          ),
        );
      }
    }

    if (!mounted || generation != _buildGeneration) return;
''',
    'renderer hosted catalog object registration',
)

test_marker = "  test('curved wall pieces preserve one continuous texture phase', () {\n"
new_test = '''  test(
    'catalog wall light keeps host wall after electrical marker deduplication',
    () {
      final floor = FloorPlan(id: 'hosted-light', name: 'Hosted light')
        ..nodes.addAll(<PlanNode>[
          PlanNode(id: 'a', xMm: 0, yMm: 1200),
          PlanNode(id: 'b', xMm: 3000, yMm: 1200),
        ])
        ..walls.add(
          PlanWall(id: 'w', startNodeId: 'a', endNodeId: 'b'),
        )
        ..planObjects.add(
          PlanObject(
            id: 'sconce',
            type: PlanObjectType.lighting,
            xMm: 1500,
            yMm: 1200,
            widthMm: 420,
            depthMm: 180,
            heightMm: 220,
            elevationMm: 1800,
            catalogId: 'wall-sconce-round',
          ),
        )
        ..electricalPoints.add(
          ElectricalPoint(
            id: 'wall-light-point',
            type: ElectricalPointType.wallLight,
            xMm: 1510,
            yMm: 1200,
            heightMm: 1900,
            wallId: 'w',
            wallSide: 1,
          ),
        );

      final scene = ZamerSceneGeometry.fromFloor(floor);
      final light = scene.objects.singleWhere((o) => o.id == 'sconce');
      expect(light.hostWallId, 'w');
      expect(
        scene.electrical.where((e) => e.type == ElectricalPointType.wallLight),
        isEmpty,
      );
    },
  );

'''
if new_test not in tests:
    if test_marker not in tests:
        raise SystemExit('Missing curved wall test anchor')
    tests = tests.replace(test_marker, new_test + test_marker, 1)

contract = '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog wall lights participate in host-wall cutaway visibility', () {
    final viewport = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(viewport.contains('if (object.hostWallId != null)'), isTrue);
    expect(viewport.contains('wallId: object.hostWallId'), isTrue);
    expect(
      viewport.contains('x: _mx(object.xMm, geometry.bounds)'),
      isTrue,
    );
    expect(
      viewport.contains('z: _mz(object.yMm, geometry.bounds)'),
      isTrue,
    );
  });
}
'''

geometry_path.write_text(geometry, encoding='utf-8')
viewport_path.write_text(viewport, encoding='utf-8')
test_path.write_text(tests, encoding='utf-8')
contract_path.write_text(contract, encoding='utf-8')
