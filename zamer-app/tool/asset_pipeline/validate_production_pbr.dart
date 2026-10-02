import 'dart:io';

import 'glb_inspector.dart';

const productionIds = <String>[
  'armchair',
  'bed-160',
  'bed-180',
  'coffee-table',
  'dining-chair-upholstered',
  'dining-table-1800',
  'dresser-1200',
  'nightstand',
  'office-desk-1400',
  'sofa-2',
  'sofa-3',
  'sofa-corner',
  'sofa-modular',
  'table-round',
  'tv-console-1600',
  'wardrobe-sliding-2000',
];

Never fail(String message) {
  stderr.writeln('PRODUCTION PBR VALIDATION FAILED: $message');
  exit(1);
}

void validateProfile(String path, {required bool fullDetail}) {
  final info = inspectGlb(path);
  if (info.materials <= 0) fail('$path has no materials');
  if (info.images <= 0) fail('$path has no embedded images');
  if (info.baseColorTexturedMaterials != info.materials) {
    fail(
      '$path BaseColor coverage ${info.baseColorTexturedMaterials}/${info.materials}',
    );
  }

  if (fullDetail) {
    if (info.normalMappedMaterials != info.materials) {
      fail('$path Normal coverage ${info.normalMappedMaterials}/${info.materials}');
    }
    if (info.metallicRoughnessMappedMaterials != info.materials) {
      fail(
        '$path Metallic/Roughness coverage '
        '${info.metallicRoughnessMappedMaterials}/${info.materials}',
      );
    }
  } else {
    if (info.normalMappedMaterials != 0) {
      fail('$path LOD2 must not embed Normal maps');
    }
    if (info.metallicRoughnessMappedMaterials != 0) {
      fail('$path LOD2 must not embed Metallic/Roughness maps');
    }
  }
}

void main() {
  var checked = 0;
  for (final id in productionIds) {
    final base = 'assets/models/zamer_catalog/$id';
    validateProfile('$base.glb', fullDetail: true);
    validateProfile('${base}_lod1.glb', fullDetail: true);
    validateProfile('${base}_lod2.glb', fullDetail: false);
    checked += 3;
  }
  stdout.writeln('PRODUCTION PBR VALID: $checked GLBs');
}
