import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class GlbInfo {
  const GlbInfo({
    required this.triangles,
    required this.materials,
    required this.meshes,
    required this.images,
    required this.baseColorTexturedMaterials,
    required this.normalMappedMaterials,
    required this.metallicRoughnessMappedMaterials,
    required this.boundsMin,
    required this.boundsMax,
  });

  final int triangles;
  final int materials;
  final int meshes;
  final int images;
  final int baseColorTexturedMaterials;
  final int normalMappedMaterials;
  final int metallicRoughnessMappedMaterials;
  final List<double>? boundsMin;
  final List<double>? boundsMax;

  List<double>? get boundsExtent {
    final min = boundsMin;
    final max = boundsMax;
    if (min == null || max == null) return null;
    return <double>[
      max[0] - min[0],
      max[1] - min[1],
      max[2] - min[2],
    ];
  }

  List<double>? get boundsCenter {
    final min = boundsMin;
    final max = boundsMax;
    if (min == null || max == null) return null;
    return <double>[
      (min[0] + max[0]) / 2,
      (min[1] + max[1]) / 2,
      (min[2] + max[2]) / 2,
    ];
  }
}

class _Bounds3 {
  final min = <double>[double.infinity, double.infinity, double.infinity];
  final max = <double>[-double.infinity, -double.infinity, -double.infinity];
  bool hasValue = false;

  void include(List<double> point) {
    hasValue = true;
    for (var i = 0; i < 3; i++) {
      if (point[i] < min[i]) min[i] = point[i];
      if (point[i] > max[i]) max[i] = point[i];
    }
  }
}

List<double> _identity4() => <double>[
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ];

List<double> _multiply4(List<double> a, List<double> b) {
  final out = List<double>.filled(16, 0);
  for (var col = 0; col < 4; col++) {
    for (var row = 0; row < 4; row++) {
      var value = 0.0;
      for (var k = 0; k < 4; k++) {
        value += a[k * 4 + row] * b[col * 4 + k];
      }
      out[col * 4 + row] = value;
    }
  }
  return out;
}

List<double> _transformPoint(List<double> m, double x, double y, double z) {
  final tx = m[0] * x + m[4] * y + m[8] * z + m[12];
  final ty = m[1] * x + m[5] * y + m[9] * z + m[13];
  final tz = m[2] * x + m[6] * y + m[10] * z + m[14];
  final tw = m[3] * x + m[7] * y + m[11] * z + m[15];
  if (tw.abs() > 1e-12 && (tw - 1).abs() > 1e-12) {
    return <double>[tx / tw, ty / tw, tz / tw];
  }
  return <double>[tx, ty, tz];
}

List<double>? _vec3(dynamic value) {
  if (value is! List || value.length < 3) return null;
  final result = <double>[];
  for (var i = 0; i < 3; i++) {
    final item = value[i];
    if (item is! num) return null;
    result.add(item.toDouble());
  }
  return result;
}

List<double> _nodeMatrix(Map<String, dynamic> node) {
  final explicit = node['matrix'];
  if (explicit is List && explicit.length == 16 && explicit.every((v) => v is num)) {
    return explicit.map((v) => (v as num).toDouble()).toList(growable: false);
  }

  final translation = _vec3(node['translation']) ?? const <double>[0, 0, 0];
  final scale = _vec3(node['scale']) ?? const <double>[1, 1, 1];
  final rotationRaw = node['rotation'];
  var qx = 0.0, qy = 0.0, qz = 0.0, qw = 1.0;
  if (rotationRaw is List &&
      rotationRaw.length >= 4 &&
      rotationRaw.take(4).every((v) => v is num)) {
    qx = (rotationRaw[0] as num).toDouble();
    qy = (rotationRaw[1] as num).toDouble();
    qz = (rotationRaw[2] as num).toDouble();
    qw = (rotationRaw[3] as num).toDouble();
    final length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
    if (length > 1e-12) {
      qx /= length;
      qy /= length;
      qz /= length;
      qw /= length;
    } else {
      qx = 0;
      qy = 0;
      qz = 0;
      qw = 1;
    }
  }

  final xx = qx * qx;
  final yy = qy * qy;
  final zz = qz * qz;
  final xy = qx * qy;
  final xz = qx * qz;
  final yz = qy * qz;
  final xw = qx * qw;
  final yw = qy * qw;
  final zw = qz * qw;
  final sx = scale[0], sy = scale[1], sz = scale[2];

  // glTF stores matrices column-major and defines local transforms as T * R * S.
  return <double>[
    (1 - 2 * (yy + zz)) * sx,
    (2 * (xy + zw)) * sx,
    (2 * (xz - yw)) * sx,
    0,
    (2 * (xy - zw)) * sy,
    (1 - 2 * (xx + zz)) * sy,
    (2 * (yz + xw)) * sy,
    0,
    (2 * (xz + yw)) * sz,
    (2 * (yz - xw)) * sz,
    (1 - 2 * (xx + yy)) * sz,
    0,
    translation[0],
    translation[1],
    translation[2],
    1,
  ];
}

void _includeAccessorBounds({
  required dynamic accessor,
  required List<double> world,
  required _Bounds3 bounds,
}) {
  if (accessor is! Map<String, dynamic>) return;
  final min = _vec3(accessor['min']);
  final max = _vec3(accessor['max']);
  if (min == null || max == null) return;
  for (final x in <double>[min[0], max[0]]) {
    for (final y in <double>[min[1], max[1]]) {
      for (final z in <double>[min[2], max[2]]) {
        bounds.include(_transformPoint(world, x, y, z));
      }
    }
  }
}

void _includeMeshBounds({
  required dynamic mesh,
  required List accessors,
  required List<double> world,
  required _Bounds3 bounds,
}) {
  if (mesh is! Map<String, dynamic>) return;
  final primitives = mesh['primitives'];
  if (primitives is! List) return;
  for (final primitive in primitives) {
    if (primitive is! Map<String, dynamic>) continue;
    final attributes = primitive['attributes'];
    if (attributes is! Map) continue;
    final positionIndex = attributes['POSITION'];
    if (positionIndex is! int || positionIndex < 0 || positionIndex >= accessors.length) {
      continue;
    }
    _includeAccessorBounds(
      accessor: accessors[positionIndex],
      world: world,
      bounds: bounds,
    );
  }
}

_Bounds3 _worldBounds(Map<String, dynamic> root, List accessors, List meshes) {
  final bounds = _Bounds3();
  final nodes = (root['nodes'] as List?) ?? const [];
  final childIndexes = <int>{};
  for (final rawNode in nodes) {
    if (rawNode is! Map<String, dynamic>) continue;
    final children = rawNode['children'];
    if (children is! List) continue;
    for (final child in children) {
      if (child is int && child >= 0 && child < nodes.length) childIndexes.add(child);
    }
  }

  final roots = <int>[];
  final scenes = root['scenes'];
  if (scenes is List && scenes.isNotEmpty) {
    final rawSceneIndex = root['scene'];
    final sceneIndex = rawSceneIndex is int && rawSceneIndex >= 0 && rawSceneIndex < scenes.length
        ? rawSceneIndex
        : 0;
    final scene = scenes[sceneIndex];
    if (scene is Map<String, dynamic> && scene['nodes'] is List) {
      for (final nodeIndex in scene['nodes'] as List) {
        if (nodeIndex is int && nodeIndex >= 0 && nodeIndex < nodes.length) roots.add(nodeIndex);
      }
    }
  }
  if (roots.isEmpty) {
    for (var i = 0; i < nodes.length; i++) {
      if (!childIndexes.contains(i)) roots.add(i);
    }
  }
  if (roots.isEmpty && nodes.isNotEmpty) {
    roots.addAll(List<int>.generate(nodes.length, (i) => i));
  }

  void walk(int nodeIndex, List<double> parent, Set<int> ancestry) {
    if (nodeIndex < 0 || nodeIndex >= nodes.length) return;
    if (!ancestry.add(nodeIndex)) {
      throw StateError('Cyclic node hierarchy at node $nodeIndex');
    }
    final rawNode = nodes[nodeIndex];
    if (rawNode is Map<String, dynamic>) {
      final world = _multiply4(parent, _nodeMatrix(rawNode));
      final meshIndex = rawNode['mesh'];
      if (meshIndex is int && meshIndex >= 0 && meshIndex < meshes.length) {
        _includeMeshBounds(
          mesh: meshes[meshIndex],
          accessors: accessors,
          world: world,
          bounds: bounds,
        );
      }
      final children = rawNode['children'];
      if (children is List) {
        for (final child in children) {
          if (child is int) walk(child, world, ancestry);
        }
      }
    }
    ancestry.remove(nodeIndex);
  }

  final identity = _identity4();
  for (final rootIndex in roots) {
    walk(rootIndex, identity, <int>{});
  }

  // A malformed-but-readable exporter may omit nodes. Fall back to raw mesh
  // accessor bounds so validation can still report a useful geometry result.
  if (!bounds.hasValue) {
    for (final mesh in meshes) {
      _includeMeshBounds(
        mesh: mesh,
        accessors: accessors,
        world: identity,
        bounds: bounds,
      );
    }
  }
  return bounds;
}

GlbInfo inspectGlb(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('GLB not found: $path');
  final bytes = file.readAsBytesSync();
  if (bytes.length < 20) throw StateError('GLB too small: $path');
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != 0x46546c67) {
    throw StateError('Invalid GLB magic: $path');
  }
  if (data.getUint32(4, Endian.little) != 2) {
    throw StateError('Only glTF 2.0 GLB is supported: $path');
  }
  final declaredLength = data.getUint32(8, Endian.little);
  if (declaredLength != bytes.length) {
    throw StateError('GLB length mismatch: header=$declaredLength actual=${bytes.length}');
  }

  final jsonLength = data.getUint32(12, Endian.little);
  final jsonType = data.getUint32(16, Endian.little);
  if (jsonType != 0x4e4f534a || 20 + jsonLength > bytes.length) {
    throw StateError('Missing/invalid GLB JSON chunk: $path');
  }
  final rawJson = utf8.decode(bytes.sublist(20, 20 + jsonLength)).trimRight();
  final root = jsonDecode(rawJson) as Map<String, dynamic>;
  final asset = root['asset'] as Map<String, dynamic>?;
  if (asset?['version'] != '2.0') {
    throw StateError('asset.version must be 2.0: $path');
  }

  void rejectExternalUris(dynamic list, String field) {
    if (list is! List) return;
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final uri = entry['uri'];
      if (uri is String && !uri.startsWith('data:')) {
        throw StateError('$field contains external URI "$uri": $path');
      }
    }
  }

  rejectExternalUris(root['buffers'], 'buffers');
  rejectExternalUris(root['images'], 'images');

  final accessors = (root['accessors'] as List?) ?? const [];
  int accessorCount(dynamic index) {
    if (index is! int || index < 0 || index >= accessors.length) return 0;
    final a = accessors[index];
    return a is Map<String, dynamic> && a['count'] is int
        ? a['count'] as int
        : 0;
  }

  var triangles = 0;
  final meshes = (root['meshes'] as List?) ?? const [];
  for (final mesh in meshes) {
    if (mesh is! Map<String, dynamic>) continue;
    final primitives = mesh['primitives'];
    if (primitives is! List) continue;
    for (final p in primitives) {
      if (p is! Map<String, dynamic>) continue;
      final mode = p['mode'] ?? 4;
      if (mode != 4) {
        throw StateError('Non-triangle primitive mode $mode is not allowed: $path');
      }
      final vertexIndex = p['indices'];
      var count = accessorCount(vertexIndex);
      if (count == 0) {
        final attrs = p['attributes'];
        if (attrs is Map<String, dynamic>) count = accessorCount(attrs['POSITION']);
      }
      if (count % 3 != 0) {
        throw StateError('Primitive count is not divisible by 3: $path');
      }
      triangles += count ~/ 3;
    }
  }

  final nodes = (root['nodes'] as List?) ?? const [];
  for (final node in nodes) {
    if (node is! Map<String, dynamic>) continue;
    final scale = node['scale'];
    if (scale is List && scale.any((v) => v is num && v < 0)) {
      throw StateError('Negative node scale is not allowed: $path');
    }
  }

  final materials = (root['materials'] as List?) ?? const [];
  var baseColorTexturedMaterials = 0;
  var normalMappedMaterials = 0;
  var metallicRoughnessMappedMaterials = 0;
  for (final material in materials) {
    if (material is! Map<String, dynamic>) continue;
    final pbr = material['pbrMetallicRoughness'];
    if (pbr is Map<String, dynamic>) {
      if (pbr['baseColorTexture'] is Map<String, dynamic>) {
        baseColorTexturedMaterials++;
      }
      if (pbr['metallicRoughnessTexture'] is Map<String, dynamic>) {
        metallicRoughnessMappedMaterials++;
      }
    }
    if (material['normalTexture'] is Map<String, dynamic>) {
      normalMappedMaterials++;
    }
  }

  final bounds = _worldBounds(root, accessors, meshes);
  return GlbInfo(
    triangles: triangles,
    materials: materials.length,
    meshes: meshes.length,
    images: ((root['images'] as List?) ?? const []).length,
    baseColorTexturedMaterials: baseColorTexturedMaterials,
    normalMappedMaterials: normalMappedMaterials,
    metallicRoughnessMappedMaterials: metallicRoughnessMappedMaterials,
    boundsMin: bounds.hasValue ? List<double>.unmodifiable(bounds.min) : null,
    boundsMax: bounds.hasValue ? List<double>.unmodifiable(bounds.max) : null,
  );
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/asset_pipeline/glb_inspector.dart <model.glb>');
    exit(64);
  }
  try {
    final info = inspectGlb(args.single);
    stdout.writeln(jsonEncode({
      'file': args.single,
      'triangles': info.triangles,
      'materials': info.materials,
      'meshes': info.meshes,
      'images': info.images,
      'baseColorTexturedMaterials': info.baseColorTexturedMaterials,
      'normalMappedMaterials': info.normalMappedMaterials,
      'metallicRoughnessMappedMaterials': info.metallicRoughnessMappedMaterials,
      'boundsMin': info.boundsMin,
      'boundsMax': info.boundsMax,
      'boundsExtent': info.boundsExtent,
      'boundsCenter': info.boundsCenter,
    }));
  } catch (e) {
    stderr.writeln('GLB VALIDATION FAILED: $e');
    exit(1);
  }
}
