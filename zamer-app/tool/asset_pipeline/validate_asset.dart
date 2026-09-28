import 'dart:convert';
import 'dart:io';

const allowedCategories = <String>{
  'soft_furniture',
  'tables_chairs',
  'storage',
  'beds',
  'kitchen',
  'plumbing',
  'office',
  'kids',
  'outdoor',
  'lighting',
  'doors_windows',
  'stairs',
  'decor_plants',
  'appliances',
  'sport_hobby',
  'construction',
  'misc',
};

const allowedPlacements = <String>{'floor', 'wall', 'ceiling', 'opening', 'free'};
const allowedPivots = <String>{
  'floor_center',
  'wall_center',
  'ceiling_center',
  'opening_center',
  'custom',
};
const allowedCollisionTypes = <String>{'box', 'convex', 'mesh', 'compound', 'none'};

Never fail(String message) {
  stderr.writeln('ASSET VALIDATION FAILED: $message');
  exit(1);
}

Map<String, dynamic> asMap(dynamic value, String field) {
  if (value is! Map<String, dynamic>) fail('$field must be an object');
  return value;
}

num positiveNum(dynamic value, String field) {
  if (value is! num || value <= 0) fail('$field must be > 0');
  return value;
}

int positiveInt(dynamic value, String field) {
  if (value is! int || value <= 0) fail('$field must be a positive integer');
  return value;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/asset_pipeline/validate_asset.dart <asset.json>');
    exit(64);
  }

  final metadataFile = File(args.single);
  if (!metadataFile.existsSync()) fail('metadata file not found: ${args.single}');

  dynamic decoded;
  try {
    decoded = jsonDecode(metadataFile.readAsStringSync());
  } catch (e) {
    fail('invalid JSON: $e');
  }

  final data = asMap(decoded, 'root');

  final id = data['id'];
  if (id is! String || !RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id)) {
    fail('id must use lowercase letters, digits, _ or -');
  }

  final name = data['name'];
  if (name is! String || name.trim().isEmpty) fail('name is required');

  final category = data['category'];
  if (category is! String || !allowedCategories.contains(category)) {
    fail('unsupported category: $category');
  }

  final modelPath = data['file'];
  if (modelPath is! String || !modelPath.toLowerCase().endsWith('.glb')) {
    fail('file must point to a .glb asset');
  }

  final dimensions = asMap(data['dimensions_m'], 'dimensions_m');
  positiveNum(dimensions['width'], 'dimensions_m.width');
  positiveNum(dimensions['depth'], 'dimensions_m.depth');
  positiveNum(dimensions['height'], 'dimensions_m.height');

  final placement = data['placement'];
  if (placement is! String || !allowedPlacements.contains(placement)) {
    fail('unsupported placement: $placement');
  }

  final pivot = data['pivot'];
  if (pivot is! String || !allowedPivots.contains(pivot)) {
    fail('unsupported pivot: $pivot');
  }

  final lod = asMap(data['lod'], 'lod');
  final lod0 = positiveInt(lod['lod0_triangles'], 'lod.lod0_triangles');
  final lod1 = lod['lod1_triangles'];
  final lod2 = lod['lod2_triangles'];

  if (lod1 != null) {
    final v = positiveInt(lod1, 'lod.lod1_triangles');
    if (v >= lod0) fail('LOD1 must have fewer triangles than LOD0');
  }
  if (lod2 != null) {
    final v = positiveInt(lod2, 'lod.lod2_triangles');
    if (lod1 is int && v >= lod1) fail('LOD2 must have fewer triangles than LOD1');
  }

  final materials = asMap(data['materials'], 'materials');
  if (materials['pbr'] is! bool) fail('materials.pbr must be boolean');
  final textureSize = materials['max_texture_size'];
  if (textureSize is! int || !{512, 1024, 2048, 4096}.contains(textureSize)) {
    fail('materials.max_texture_size must be 512, 1024, 2048 or 4096');
  }

  final collision = asMap(data['collision'], 'collision');
  final collisionType = collision['type'];
  if (collisionType is! String || !allowedCollisionTypes.contains(collisionType)) {
    fail('unsupported collision type: $collisionType');
  }

  final version = data['version'];
  if (version != null && (version is! int || version < 1)) fail('version must be >= 1');

  stdout.writeln('ASSET VALID: $id');
}
