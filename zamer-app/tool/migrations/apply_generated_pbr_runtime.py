#!/usr/bin/env python3
"""One-shot source migration that wires generated finish PBR maps into 3D."""

from __future__ import annotations

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
GPU = APP / "lib" / "renderer3d" / "zamer_gpu_viewport.dart"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f"Could not locate {label}")
    if text.count(old) != 1:
        raise RuntimeError(f"Expected exactly one {label}, found {text.count(old)}")
    return text.replace(old, new, 1)


def main() -> None:
    text = GPU.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "import '../services/material_catalog.dart';\n",
        "import '../services/generated_pbr_finish_catalog.dart';\n"
        "import '../services/material_catalog.dart';\n",
        "generated PBR import",
    )

    old_loader = """  Future<void> _loadFinishTextures() async {
    for (final preset in MaterialCatalog.presets) {
      final asset = preset.textureAsset;
      if (asset == null) continue;
      final candidates = <String>{
        asset,
        if (preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_half.png'),
        if (preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_third.png'),
      };
      for (final candidate in candidates) {
        if (_finishTextures.containsKey(candidate)) continue;
        try {
          _finishTextures[candidate] = await Texture2D.fromAsset(candidate);
        } catch (_) {
          // Decorative textures are optional; a single missing asset must not
          // make the complete 3D room fail to initialise.
        }
      }
    }
    _concreteTexture ??= await Texture2D.fromAsset(
      'assets/textures/concrete_soft.png',
    );
    _plasterTexture ??= await Texture2D.fromAsset(
      'assets/textures/plaster_warm.png',
    );
  }
"""
    new_loader = """  Future<void> _loadFinishTextures() async {
    for (final preset in MaterialCatalog.presets) {
      final asset = preset.textureAsset;
      final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
      final candidates = <String>{
        if (asset != null) asset,
        if (generatedPbr != null) generatedPbr.normalAsset,
        if (generatedPbr != null) generatedPbr.metallicRoughnessAsset,
        if (asset != null && preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_half.png'),
        if (asset != null && preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_third.png'),
      };
      for (final candidate in candidates) {
        if (_finishTextures.containsKey(candidate)) continue;
        try {
          _finishTextures[candidate] = await Texture2D.fromAsset(candidate);
        } catch (_) {
          // Decorative textures are optional; a single missing asset must not
          // make the complete 3D room fail to initialise.
        }
      }
    }
    _concreteTexture ??= await Texture2D.fromAsset(
      'assets/textures/concrete_soft.png',
    );
    _plasterTexture ??= await Texture2D.fromAsset(
      'assets/textures/plaster_warm.png',
    );
  }
"""
    text = replace_once(text, old_loader, new_loader, "finish texture loader")

    old_floor_tail = """    final material = _pbr(tint, roughness: roughness, texture: texture)
      ..doubleSided = false;
    return material;
  }

  TextureSource? _textureForFloorSurface(
"""
    new_floor_tail = """    final material = _pbr(tint, roughness: roughness, texture: texture)
      ..doubleSided = false;
    _applyGeneratedPbr(material, preset);
    return material;
  }

  TextureSource? _textureForFloorSurface(
"""
    text = replace_once(text, old_floor_tail, new_floor_tail, "floor PBR hook")

    old_uv_head = """  (double, double) _floorUvScaleMm(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
"""
    new_uv_head = """  (double, double) _floorUvScaleMm(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
"""
    text = replace_once(text, old_uv_head, new_uv_head, "floor UV PBR lookup")

    old_uv_mid = """    if (preset.pattern == 'concrete' || mode.contains('бетон')) {
      return const (1000.0, 1000.0);
    }
    if (surface.laminatePattern == 'herringbone') {
"""
    new_uv_mid = """    if (preset.pattern == 'concrete' || mode.contains('бетон')) {
      return const (1000.0, 1000.0);
    }
    if (preset.pattern != 'wood' && generatedPbr != null) {
      final repeatMm = math.max(50.0, generatedPbr.realWorldTileMm);
      return (repeatMm, repeatMm);
    }
    if (surface.laminatePattern == 'herringbone') {
"""
    text = replace_once(text, old_uv_mid, new_uv_mid, "physical floor UV scale")

    old_wall_tail = """    if (finish.tileEnabled && texture != null) {
      final sourceTileW = math.max(20.0, finish.tileWidthMm);
      final sourceTileH = math.max(20.0, finish.tileHeightMm);
      final tileW = finish.tileRotated ? sourceTileH : sourceTileW;
      final tileH = finish.tileRotated ? sourceTileW : sourceTileH;
      final repeatX = math.max(0.001, wall.lengthMm / tileW);
      final repeatY = math.max(0.001, wall.heightMm / tileH);
      final wallU = (wall.textureStartMm + finish.tileOffsetXMm) / tileW;
      final wallV = (wall.bottomMm - finish.tileOffsetYMm) / tileH;
      material.baseColorTextureTransform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) * repeatX,
          repeatY,
        ),
        offset: vm.Vector2(finish.tileMirrored ? 1.0 - wallU : wallU, wallV),
        rotation: finish.tileRotated ? math.pi / 2 : 0,
      );
    }
    return material;
  }

  TextureSource? _textureForPreset(
"""
    new_wall_tail = """    TextureTransform? textureTransform;
    if (finish.tileEnabled && texture != null) {
      final sourceTileW = math.max(20.0, finish.tileWidthMm);
      final sourceTileH = math.max(20.0, finish.tileHeightMm);
      final tileW = finish.tileRotated ? sourceTileH : sourceTileW;
      final tileH = finish.tileRotated ? sourceTileW : sourceTileH;
      final repeatX = math.max(0.001, wall.lengthMm / tileW);
      final repeatY = math.max(0.001, wall.heightMm / tileH);
      final wallU = (wall.textureStartMm + finish.tileOffsetXMm) / tileW;
      final wallV = (wall.bottomMm - finish.tileOffsetYMm) / tileH;
      textureTransform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) * repeatX,
          repeatY,
        ),
        offset: vm.Vector2(finish.tileMirrored ? 1.0 - wallU : wallU, wallV),
        rotation: finish.tileRotated ? math.pi / 2 : 0,
      );
    } else if (texture != null) {
      final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
      if (generatedPbr != null) {
        final repeatMm = math.max(50.0, generatedPbr.realWorldTileMm);
        textureTransform = TextureTransform(
          scale: vm.Vector2(
            math.max(0.001, wall.lengthMm / repeatMm),
            math.max(0.001, wall.heightMm / repeatMm),
          ),
          offset: vm.Vector2(
            wall.textureStartMm / repeatMm,
            wall.bottomMm / repeatMm,
          ),
        );
      }
    }
    _applyGeneratedPbr(material, preset, transform: textureTransform);
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

  TextureSource? _textureForPreset(
"""
    text = replace_once(text, old_wall_tail, new_wall_tail, "wall PBR runtime")

    GPU.write_text(text, encoding="utf-8")
    print(f"Patched {GPU}")


if __name__ == "__main__":
    main()
