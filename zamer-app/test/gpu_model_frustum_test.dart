import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';

const _glbMagic = 0x46546C67;
const _glbJsonChunk = 0x4E4F534A;

class _Bounds3 {
  vm.Vector3? min;
  vm.Vector3? max;

  bool get isValid => min != null && max != null;

  vm.Vector3 get size {
    final lo = min!;
    final hi = max!;
    return vm.Vector3(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z);
  }

  vm.Vector3 get center {
    final lo = min!;
    final hi = max!;
    return vm.Vector3(
      (lo.x + hi.x) / 2,
      (lo.y + hi.y) / 2,
      (lo.z + hi.z) / 2,
    );
  }

  void include(vm.Vector3 point) {
    final lo = min;
    final hi = max;
    if (lo == null || hi == null) {
      min = point.clone();
      max = point.clone();
      return;
    }
    lo
      ..x = math.min(lo.x, point.x)
      ..y = math.min(lo.y, point.y)
      ..z = math.min(lo.z, point.z);
    hi
      ..x = math.max(hi.x, point.x)
      ..y = math.max(hi.y, point.y)
      ..z = math.max(hi.z, point.z);
  }
}

Map<String, dynamic> _readGlbJson(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(20), reason: '$path is too small');
  final data = ByteData.sublistView(bytes);
  expect(data.getUint32(0, Endian.little), _glbMagic, reason: '$path is not GLB');
  expect(data.getUint32(4, Endian.little), 2, reason: '$path must be glTF 2');

  final declaredLength = data.getUint32(8, Endian.little);
  expect(declaredLength, lessThanOrEqualTo(bytes.length), reason: '$path is truncated');

  var offset = 12;
  while (offset + 8 <= declaredLength) {
    final chunkLength = data.getUint32(offset, Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + chunkLength;
    expect(end, lessThanOrEqualTo(declaredLength), reason: '$path has a broken chunk');
    if (chunkType == _glbJsonChunk) {
      final text = utf8.decode(bytes.sublist(start, end)).trimRight();
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    }
    offset = end;
  }
  throw StateError('$path has no JSON glTF chunk');
}

vm.Matrix4 _nodeMatrix(Map<String, dynamic> node) {
  final matrix = node['matrix'];
  if (matrix is List && matrix.length == 16) {
    return vm.Matrix4.fromList(
      matrix.map((value) => (value as num).toDouble()).toList(growable: false),
    );
  }

  final translation = node['translation'] is List
      ? node['translation'] as List
      : const <num>[0, 0, 0];
  final rotation = node['rotation'] is List
      ? node['rotation'] as List
      : const <num>[0, 0, 0, 1];
  final scale = node['scale'] is List
      ? node['scale'] as List
      : const <num>[1, 1, 1];

  return vm.Matrix4.compose(
    vm.Vector3(
      (translation[0] as num).toDouble(),
      (translation[1] as num).toDouble(),
      (translation[2] as num).toDouble(),
    ),
    vm.Quaternion(
      (rotation[0] as num).toDouble(),
      (rotation[1] as num).toDouble(),
      (rotation[2] as num).toDouble(),
      (rotation[3] as num).toDouble(),
    ),
    vm.Vector3(
      (scale[0] as num).toDouble(),
      (scale[1] as num).toDouble(),
      (scale[2] as num).toDouble(),
    ),
  );
}

void _includeAccessorBounds({
  required Map<String, dynamic> gltf,
  required int accessorIndex,
  required vm.Matrix4 world,
  required _Bounds3 bounds,
  required String path,
}) {
  final accessors = gltf['accessors'] as List? ?? const [];
  expect(accessorIndex, lessThan(accessors.length), reason: '$path has invalid POSITION accessor');
  final accessor = (accessors[accessorIndex] as Map).cast<String, dynamic>();
  final minValues = accessor['min'] as List?;
  final maxValues = accessor['max'] as List?;
  expect(minValues, isNotNull, reason: '$path POSITION accessor has no min bounds');
  expect(maxValues, isNotNull, reason: '$path POSITION accessor has no max bounds');
  expect(minValues!.length, greaterThanOrEqualTo(3));
  expect(maxValues!.length, greaterThanOrEqualTo(3));

  final lo = vm.Vector3(
    (minValues[0] as num).toDouble(),
    (minValues[1] as num).toDouble(),
    (minValues[2] as num).toDouble(),
  );
  final hi = vm.Vector3(
    (maxValues[0] as num).toDouble(),
    (maxValues[1] as num).toDouble(),
    (maxValues[2] as num).toDouble(),
  );

  for (final x in <double>[lo.x, hi.x]) {
    for (final y in <double>[lo.y, hi.y]) {
      for (final z in <double>[lo.z, hi.z]) {
        final point = vm.Vector3(x, y, z);
        world.transform3(point);
        bounds.include(point);
      }
    }
  }
}

_Bounds3 _glbBounds(String path) {
  final gltf = _readGlbJson(path);
  final nodes = gltf['nodes'] as List? ?? const [];
  final meshes = gltf['meshes'] as List? ?? const [];
  final bounds = _Bounds3();

  void visitNode(int index, vm.Matrix4 parent) {
    expect(index, lessThan(nodes.length), reason: '$path has invalid node index');
    final node = (nodes[index] as Map).cast<String, dynamic>();
    final world = parent.clone()..multiply(_nodeMatrix(node));
    final meshIndex = node['mesh'];
    if (meshIndex is int) {
      expect(meshIndex, lessThan(meshes.length), reason: '$path has invalid mesh index');
      final mesh = (meshes[meshIndex] as Map).cast<String, dynamic>();
      for (final rawPrimitive in mesh['primitives'] as List? ?? const []) {
        final primitive = (rawPrimitive as Map).cast<String, dynamic>();
        final attributes = (primitive['attributes'] as Map?)?.cast<String, dynamic>();
        final positionAccessor = attributes?['POSITION'];
        if (positionAccessor is int) {
          _includeAccessorBounds(
            gltf: gltf,
            accessorIndex: positionAccessor,
            world: world,
            bounds: bounds,
            path: path,
          );
        }
      }
    }
    for (final child in node['children'] as List? ?? const []) {
      visitNode(child as int, world);
    }
  }

  final scenes = gltf['scenes'] as List? ?? const [];
  if (scenes.isNotEmpty) {
    final activeScene = (gltf['scene'] as int?) ?? 0;
    expect(activeScene, lessThan(scenes.length), reason: '$path has invalid scene index');
    final scene = (scenes[activeScene] as Map).cast<String, dynamic>();
    for (final nodeIndex in scene['nodes'] as List? ?? const []) {
      visitNode(nodeIndex as int, vm.Matrix4.identity());
    }
  } else {
    final childIndices = <int>{
      for (final rawNode in nodes)
        for (final child in ((rawNode as Map)['children'] as List? ?? const []))
          child as int,
    };
    for (var index = 0; index < nodes.length; index++) {
      if (!childIndices.contains(index)) {
        visitNode(index, vm.Matrix4.identity());
      }
    }
  }

  expect(bounds.isValid, isTrue, reason: '$path exposes no POSITION bounds');
  return bounds;
}

_Bounds3 _runtimeRotatedBounds(_Bounds3 source, double angle) {
  final sourceCenter = source.center;
  final floorY = source.min!.y;
  final rotation = vm.Matrix4.compose(
    vm.Vector3.zero(),
    vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), angle),
    vm.Vector3.all(1),
  );
  final result = _Bounds3();
  final lo = source.min!;
  final hi = source.max!;

  for (final x in <double>[lo.x, hi.x]) {
    for (final y in <double>[lo.y, hi.y]) {
      for (final z in <double>[lo.z, hi.z]) {
        final point = vm.Vector3(
          x - sourceCenter.x,
          y - floorY,
          z - sourceCenter.z,
        );
        rotation.transform3(point);
        result.include(point);
      }
    }
  }
  return result;
}

void _expectDimensionClose({
  required double actual,
  required double expected,
  required String label,
  double relativeTolerance = 0.04,
  double absoluteTolerance = 0.025,
}) {
  final tolerance = math.max(absoluteTolerance, expected.abs() * relativeTolerance);
  expect(
    (actual - expected).abs(),
    lessThanOrEqualTo(tolerance),
    reason: '$label differs by ${(actual - expected).abs().toStringAsFixed(4)} m (allowed ${tolerance.toStringAsFixed(4)} m)',
  );
}

void main() {
  test('all production LOD GLBs keep stable transformed culling bounds headlessly', () {
    const objectAngles = <double>[0.0, 0.7, 1.57, 2.35];

    for (final id in ZamerModelAssetCatalog.productionLodIds) {
      final asset = ZamerModelAssetCatalog.byId(id);
      expect(asset, isNotNull, reason: '$id must resolve to a production model asset');
      final resolved = asset!;
      final paths = <String>[
        resolved.assetPath,
        resolved.lod1AssetPath!,
        resolved.lod2AssetPath!,
      ];
      final boundsByPath = <String, _Bounds3>{};

      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing from the runtime bundle');
        final bounds = _glbBounds(path);
        final size = bounds.size;
        expect(size.x, greaterThan(0.005), reason: '$path has collapsed X bounds');
        expect(size.y, greaterThan(0.005), reason: '$path has collapsed Y bounds');
        expect(size.z, greaterThan(0.005), reason: '$path has collapsed Z bounds');
        expect(
          size.x.isFinite && size.y.isFinite && size.z.isFinite,
          isTrue,
          reason: '$path has non-finite bounds',
        );
        boundsByPath[path] = bounds;

        for (final angle in objectAngles) {
          final rotated = _runtimeRotatedBounds(bounds, angle);
          final rotatedSize = rotated.size;
          expect(rotatedSize.x, greaterThan(0.005), reason: '$path collapsed X after rotation $angle');
          expect(rotatedSize.y, greaterThan(0.005), reason: '$path collapsed Y after rotation $angle');
          expect(rotatedSize.z, greaterThan(0.005), reason: '$path collapsed Z after rotation $angle');
          expect(
            rotatedSize.x.isFinite && rotatedSize.y.isFinite && rotatedSize.z.isFinite,
            isTrue,
            reason: '$path produced non-finite rotated bounds at $angle',
          );
        }
      }

      final baseSize = boundsByPath[resolved.assetPath]!.size;
      final nativeSize = vm.Vector3(
        resolved.nativeWidthMm / 1000,
        resolved.nativeHeightMm / 1000,
        resolved.nativeDepthMm / 1000,
      );
      _expectDimensionClose(actual: baseSize.x, expected: nativeSize.x, label: '$id LOD0 width vs catalog');
      _expectDimensionClose(actual: baseSize.y, expected: nativeSize.y, label: '$id LOD0 height vs catalog');
      _expectDimensionClose(actual: baseSize.z, expected: nativeSize.z, label: '$id LOD0 depth vs catalog');

      for (final path in paths.skip(1)) {
        final lodSize = boundsByPath[path]!.size;
        _expectDimensionClose(
          actual: lodSize.x,
          expected: baseSize.x,
          label: '$path width vs LOD0',
          relativeTolerance: 0.025,
          absoluteTolerance: 0.015,
        );
        _expectDimensionClose(
          actual: lodSize.y,
          expected: baseSize.y,
          label: '$path height vs LOD0',
          relativeTolerance: 0.025,
          absoluteTolerance: 0.015,
        );
        _expectDimensionClose(
          actual: lodSize.z,
          expected: baseSize.z,
          label: '$path depth vs LOD0',
          relativeTolerance: 0.025,
          absoluteTolerance: 0.015,
        );
      }
    }
  });
}
