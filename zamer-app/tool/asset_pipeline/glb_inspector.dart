import 'dart:convert';
import 'dart:io';
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
  });

  final int triangles;
  final int materials;
  final int meshes;
  final int images;
  final int baseColorTexturedMaterials;
  final int normalMappedMaterials;
  final int metallicRoughnessMappedMaterials;
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

  return GlbInfo(
    triangles: triangles,
    materials: materials.length,
    meshes: meshes.length,
    images: ((root['images'] as List?) ?? const []).length,
    baseColorTexturedMaterials: baseColorTexturedMaterials,
    normalMappedMaterials: normalMappedMaterials,
    metallicRoughnessMappedMaterials: metallicRoughnessMappedMaterials,
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
    }));
  } catch (e) {
    stderr.writeln('GLB VALIDATION FAILED: $e');
    exit(1);
  }
}
