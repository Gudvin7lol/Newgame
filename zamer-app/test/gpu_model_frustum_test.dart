import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:zamer_app/models/production_asset_catalog.dart';

Future<Node> _loadRebasedModel(String path) async {
  final bytes = await File(path).readAsBytes();
  final model = await Node.fromGlbBytes(bytes);
  final bounds = model.combinedLocalBounds;
  expect(bounds, isNotNull, reason: '$path must expose culling bounds');

  model.position = vm.Vector3(
    -bounds!.center.x,
    -bounds.min.y,
    -bounds.center.z,
  );

  final root = Node(name: 'test-object');
  root.add(model);
  return root;
}

PerspectiveCamera _camera(double orbitAngle) {
  const distance = 4.2;
  return PerspectiveCamera(
    fovRadiansY: 64 * math.pi / 180,
    position: vm.Vector3(
      math.cos(orbitAngle) * distance,
      1.65,
      math.sin(orbitAngle) * distance,
    ),
    target: vm.Vector3(0, 0.75, 0),
    up: vm.Vector3(0, 1, 0),
    fovNear: 0.045,
    fovFar: 120,
  );
}

Iterable<String> _runtimeVariants(String modelPath) sync* {
  yield modelPath;
  final stem = modelPath.endsWith('.glb')
      ? modelPath.substring(0, modelPath.length - 4)
      : modelPath;
  for (final suffix in const <String>['_lod1.glb', '_lod2.glb']) {
    final candidate = '$stem$suffix';
    if (File(candidate).existsSync()) yield candidate;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production GLBs keep valid GPU frustum bounds while rotating', () async {
    const viewport = Size(1080, 1920);
    const cameraAngles = <double>[-2.4, -1.2, 0.0, 1.1, 2.35];
    const objectAngles = <double>[0.0, 0.7, 1.57, 2.35];

    final modelPaths = <String>{
      for (final asset in ZamerProductionCatalog.linked2d3d)
        if (asset.model3d case final String path) ..._runtimeVariants(path),
    };

    expect(
      modelPaths.length,
      greaterThanOrEqualTo(ZamerProductionCatalog.linked2d3d.length),
      reason: 'Every linked production asset must contribute a runtime GLB.',
    );

    for (final path in modelPaths) {
      final root = await _loadRebasedModel(path);
      for (final objectAngle in objectAngles) {
        root.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          objectAngle,
        );
        final worldBounds = root.combinedWorldBounds;
        expect(
          worldBounds,
          isNotNull,
          reason: '$path must retain world bounds at rotation $objectAngle',
        );
        expect(
          worldBounds!.max.x - worldBounds.min.x,
          greaterThan(0.005),
          reason: '$path produced a collapsed X bound at $objectAngle',
        );
        expect(
          worldBounds.max.y - worldBounds.min.y,
          greaterThan(0.005),
          reason: '$path produced a collapsed Y bound at $objectAngle',
        );
        expect(
          worldBounds.max.z - worldBounds.min.z,
          greaterThan(0.005),
          reason: '$path produced a collapsed Z bound at $objectAngle',
        );

        for (final cameraAngle in cameraAngles) {
          expect(
            root.isVisibleTo(_camera(cameraAngle), viewport),
            isTrue,
            reason:
                '$path was incorrectly frustum-culled at object=$objectAngle camera=$cameraAngle',
          );
        }
      }
    }
  });
}
