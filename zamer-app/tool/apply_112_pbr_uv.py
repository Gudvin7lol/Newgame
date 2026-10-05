from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWPORT = ROOT / 'zamer-app/lib/renderer3d/zamer_gpu_viewport.dart'
PUBSPEC = ROOT / 'zamer-app/pubspec.yaml'

text = VIEWPORT.read_text()

# Import the physical PBR UV policy.
marker = "import 'model_lod_policy.dart';\n"
if "import 'material_pbr_uv_policy.dart';" not in text:
    if marker not in text:
        raise SystemExit('import marker missing')
    text = text.replace(marker, "import 'material_pbr_uv_policy.dart';\n" + marker, 1)

# Floor material cache must include the UV module because PBR channel transforms
# are now material state rather than geometry-only state.
old_key = """    final key =
        '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface),
    );
"""
new_key = """    final key =
        '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}:${uvScale.$1}:${uvScale.$2}';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface, uvScale),
    );
"""
if old_key not in text:
    raise SystemExit('floor material cache marker missing')
text = text.replace(old_key, new_key, 1)

old_floor_sig = """  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {
"""
new_floor_sig = """  PhysicallyBasedMaterial _floorMaterial(
    ZamerFloorSurface surface,
    (double, double) uvScale,
  ) {
"""
if old_floor_sig not in text:
    raise SystemExit('floor material signature marker missing')
text = text.replace(old_floor_sig, new_floor_sig, 1)

old_floor_apply = """    final material = _pbr(tint, roughness: roughness, texture: texture)
      ..doubleSided = false;
    _applyGeneratedPbr(material, preset);
    return material;
"""
new_floor_apply = """    final material = _pbr(tint, roughness: roughness, texture: texture)
      ..doubleSided = false;
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    TextureTransform? pbrTransform;
    if (generatedPbr != null) {
      final physical = ZamerMaterialPbrUvPolicy.forFloor(
        geometryUvWidthMm: uvScale.$1,
        geometryUvHeightMm: uvScale.$2,
        realWorldTileMm: generatedPbr.realWorldTileMm,
      );
      pbrTransform = TextureTransform(
        scale: vm.Vector2(physical.scaleX, physical.scaleY),
      );
    }
    _applyGeneratedPbr(material, preset, pbrTransform: pbrTransform);
    return material;
"""
if old_floor_apply not in text:
    raise SystemExit('floor PBR apply marker missing')
text = text.replace(old_floor_apply, new_floor_apply, 1)

# Under-wall helper uses the same floor material and therefore needs the same UV
# module even though it is currently only a compatibility fill path.
old_under = """    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(nearest),
    );
"""
new_under = """    final nearestUvScale = _floorUvScaleMm(nearest);
    final material = materialCache.putIfAbsent(
      '$key:${nearestUvScale.$1}:${nearestUvScale.$2}',
      () => _floorMaterial(nearest, nearestUvScale),
    );
"""
if old_under not in text:
    raise SystemExit('under-wall floor material marker missing')
text = text.replace(old_under, new_under, 1)

# Split base-color transform from physical PBR transform on walls.
old_decl = """    TextureTransform? textureTransform;
"""
new_decl = """    TextureTransform? baseTextureTransform;
"""
if old_decl not in text:
    raise SystemExit('wall texture transform declaration missing')
text = text.replace(old_decl, new_decl, 1)

# Only replace the two assignments inside _wallFinishMaterial.
text = text.replace("      textureTransform = TextureTransform(\n", "      baseTextureTransform = TextureTransform(\n", 2)

old_wall_apply = """    _applyGeneratedPbr(material, preset, transform: textureTransform);
    return material;
  }

  void _applyGeneratedPbr(
    PhysicallyBasedMaterial material,
    VisualMaterialPreset preset, {
    TextureTransform? transform,
  }) {
    if (transform != null) {
      material.baseColorTextureTransform = transform;
    }
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    if (generatedPbr == null) return;

    final normal = _finishTextures[generatedPbr.normalAsset];
    if (normal != null) {
      material
        ..normalTexture = normal
        ..normalScale = generatedPbr.normalScale;
      if (transform != null) material.normalTextureTransform = transform;
    }

    final metallicRoughness =
        _finishTextures[generatedPbr.metallicRoughnessAsset];
    if (metallicRoughness != null) {
      material.metallicRoughnessTexture = metallicRoughness;
      if (transform != null) {
        material.metallicRoughnessTextureTransform = transform;
      }
    }
  }
"""
new_wall_apply = """    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    TextureTransform? pbrTextureTransform;
    if (generatedPbr != null) {
      final physical = ZamerMaterialPbrUvPolicy.forWall(
        wallLengthMm: wall.lengthMm,
        wallHeightMm: wall.heightMm,
        textureStartMm: wall.textureStartMm,
        bottomMm: wall.bottomMm,
        realWorldTileMm: generatedPbr.realWorldTileMm,
      );
      final mirrored = finish.tileEnabled && finish.tileMirrored;
      pbrTextureTransform = TextureTransform(
        scale: vm.Vector2(
          (mirrored ? -1.0 : 1.0) * physical.scaleX,
          physical.scaleY,
        ),
        offset: vm.Vector2(
          mirrored ? 1.0 - physical.offsetX : physical.offsetX,
          physical.offsetY,
        ),
        rotation: finish.tileEnabled && finish.tileRotated ? math.pi / 2 : 0,
      );
    }
    _applyGeneratedPbr(
      material,
      preset,
      baseTransform: baseTextureTransform,
      pbrTransform: pbrTextureTransform,
    );
    return material;
  }

  void _applyGeneratedPbr(
    PhysicallyBasedMaterial material,
    VisualMaterialPreset preset, {
    TextureTransform? baseTransform,
    TextureTransform? pbrTransform,
  }) {
    if (baseTransform != null) {
      material.baseColorTextureTransform = baseTransform;
    }
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    if (generatedPbr == null) return;
    final physicalTransform = pbrTransform ?? baseTransform;

    final normal = _finishTextures[generatedPbr.normalAsset];
    if (normal != null) {
      material
        ..normalTexture = normal
        ..normalScale = generatedPbr.normalScale;
      if (physicalTransform != null) {
        material.normalTextureTransform = physicalTransform;
      }
    }

    final metallicRoughness =
        _finishTextures[generatedPbr.metallicRoughnessAsset];
    if (metallicRoughness != null) {
      material.metallicRoughnessTexture = metallicRoughness;
      if (physicalTransform != null) {
        material.metallicRoughnessTextureTransform = physicalTransform;
      }
    }
  }
"""
if old_wall_apply not in text:
    raise SystemExit('wall/apply PBR marker missing')
text = text.replace(old_wall_apply, new_wall_apply, 1)

VIEWPORT.write_text(text)

pubspec = PUBSPEC.read_text()
if 'version: 1.5.6+111' not in pubspec:
    raise SystemExit('expected +111 pubspec version missing')
PUBSPEC.write_text(pubspec.replace('version: 1.5.6+111', 'version: 1.5.6+112', 1))
