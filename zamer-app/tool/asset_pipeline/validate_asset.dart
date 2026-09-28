import 'dart:convert';
import 'dart:io';

import 'glb_inspector.dart';

const allowedCategories = <String>{
  'soft_furniture', 'tables_chairs', 'storage', 'beds', 'kitchen',
  'plumbing', 'office', 'kids', 'outdoor', 'lighting', 'doors_windows',
  'stairs', 'decor_plants', 'appliances', 'sport_hobby', 'construction', 'misc',
};
const allowedPlacements = <String>{'floor', 'wall', 'ceiling', 'opening', 'free'};
const allowedPivots = <String>{
  'floor_center', 'wall_center', 'ceiling_center', 'opening_center', 'custom',
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

GlbInfo validateGlbReference(String path, int expectedTriangles, String label) {
  if (!File(path).existsSync()) fail('$label file does not exist: $path');
  try {
    final info = inspectGlb(path);
    if (info.triangles != expectedTriangles) {
      fail('$label triangle mismatch: metadata=$expectedTriangles actual=${info.triangles} ($path)');
    }
    return info;
  } catch (e) {
    fail('$label GLB invalid: $e');
  }
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
  if (lod0 > 150000) fail('LOD0 exceeds mobile hard cap of 150k triangles');

  if (lod1 != null) {
    final v = positiveInt(lod1, 'lod.lod1_triangles');
    if (v >= lod0) fail('LOD1 must have fewer triangles than LOD0');
    if (lod['lod1_file'] is! String) fail('lod1_file is required when lod1_triangles is set');
  }
  if (lod2 != null) {
    final v = positiveInt(lod2, 'lod.lod2_triangles');
    if (lod1 is! int) fail('LOD2 requires LOD1');
    if (v >= lod1) fail('LOD2 must have fewer triangles than LOD1');
    if (lod['lod2_file'] is! String) fail('lod2_file is required when lod2_triangles is set');
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

  final lod0Info = validateGlbReference(modelPath, lod0, 'LOD0');
  if (lod1 is int) validateGlbReference(lod['lod1_file'] as String, lod1, 'LOD1');
  if (lod2 is int) validateGlbReference(lod['lod2_file'] as String, lod2, 'LOD2');

  final expectedMaterials = materials['material_count'];
  if (expectedMaterials is int && expectedMaterials != lod0Info.materials) {
    fail('material_count mismatch: metadata=$expectedMaterials actual=${lod0Info.materials}');
  }
  if (materials['pbr'] != true) fail('production assets must use PBR materials');

  stdout.writeln('ASSET VALID: $id | ${lod0Info.triangles} tris | ${lod0Info.materials} materials | ${lod0Info.meshes} meshes');
}
