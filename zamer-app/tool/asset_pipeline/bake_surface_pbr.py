#!/usr/bin/env python3
"""Bake tangent-space normal, height and metallic/roughness maps for ZAMER finishes.

The generated_v1 base-color textures are the visual source of truth. This tool
keeps every derived map aligned with the same UVs, adds only tileable micro
variation, and writes standard maps that flutter_scene can sample directly.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "assets" / "textures" / "generated_v1"

# roughness, normal strength, physical repeat in mm
SPECS: dict[str, tuple[float, float, int]] = {
    "dark_oak": (0.54, 2.5, 1200),
    "white_oak": (0.56, 2.4, 1200),
    "travertine": (0.62, 3.2, 600),
    "terrazzo": (0.43, 2.2, 600),
    "slate": (0.72, 4.0, 600),
    "terracotta": (0.68, 3.4, 300),
    "wall_paint": (0.86, 0.75, 900),
    "wall_lime": (0.88, 2.7, 900),
    "wall_microcement": (0.82, 2.2, 1000),
    "wall_red_clay": (0.78, 4.4, 1000),
    "wall_white_clay": (0.82, 4.1, 1000),
    "wall_linen": (0.92, 3.2, 700),
}


def _periodic_noise(height: int, width: int, seed: int) -> np.ndarray:
    """Small deterministic Fourier field whose opposite edges match exactly."""
    rng = np.random.default_rng(seed)
    y = np.arange(height, dtype=np.float32)[:, None] / max(1, height)
    x = np.arange(width, dtype=np.float32)[None, :] / max(1, width)
    field = np.zeros((height, width), dtype=np.float32)
    for octave, weight in ((2, 0.55), (5, 0.28), (11, 0.12), (23, 0.05)):
        angle = rng.uniform(0.0, math.tau)
        phase = rng.uniform(0.0, math.tau)
        kx = max(1, int(round(octave * math.cos(angle))))
        ky = max(1, int(round(octave * math.sin(angle))))
        field += weight * np.sin(math.tau * (kx * x + ky * y) + phase)
    peak = float(np.max(np.abs(field)))
    return field / peak if peak > 1e-6 else field


def _normalized_detail(rgb: np.ndarray, seed: int) -> np.ndarray:
    luminance = (
        rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    )
    fine = luminance - gaussian_filter(luminance, sigma=1.2, mode="wrap")
    medium = luminance - gaussian_filter(luminance, sigma=7.0, mode="wrap")
    broad = luminance - gaussian_filter(luminance, sigma=20.0, mode="wrap")
    periodic = _periodic_noise(luminance.shape[0], luminance.shape[1], seed)
    detail = fine * 0.28 + medium * 0.42 + broad * 0.24 + periodic * 0.06
    lo, hi = np.percentile(detail, (2.0, 98.0))
    if hi - lo < 1e-6:
        return np.full_like(detail, 0.5, dtype=np.float32)
    return np.clip((detail - lo) / (hi - lo), 0.0, 1.0).astype(np.float32)


def _normal_map(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    return np.clip((normal * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)


def _metallic_roughness(height: np.ndarray, base_roughness: float) -> np.ndarray:
    micro = np.abs(height - gaussian_filter(height, sigma=2.0, mode="wrap"))
    micro /= max(1e-6, float(micro.max()))
    rough = np.clip(base_roughness + (micro - 0.34) * 0.12, 0.18, 0.98)
    packed = np.empty((*height.shape, 3), dtype=np.uint8)
    packed[..., 0] = 255  # unused by metallic-roughness sampling
    packed[..., 1] = np.rint(rough * 255).astype(np.uint8)  # G = roughness
    packed[..., 2] = 0  # B = metallic, all architectural finishes are dielectric
    return packed


def bake_one(name: str, base_roughness: float, normal_strength: float) -> None:
    source = TEXTURES / f"{name}.jpg"
    if not source.exists():
        raise FileNotFoundError(source)

    image = Image.open(source).convert("RGB")
    # Derived maps are at least 512 px so grazing-angle highlights do not reveal
    # the tiny source grid. Bicubic keeps the maps aligned to the original UVs.
    width, height = image.size
    scale = max(1.0, 512.0 / max(1, min(width, height)))
    if scale > 1.0:
        image = image.resize(
            (max(1, round(width * scale)), max(1, round(height * scale))),
            Image.Resampling.BICUBIC,
        )

    rgb = np.asarray(image, dtype=np.float32) / 255.0
    seed = sum((index + 1) * ord(char) for index, char in enumerate(name))
    height_field = _normalized_detail(rgb, seed)

    Image.fromarray(np.rint(height_field * 255).astype(np.uint8), mode="L").save(
        TEXTURES / f"{name}_height.png", optimize=True
    )
    Image.fromarray(_normal_map(height_field, normal_strength), mode="RGB").save(
        TEXTURES / f"{name}_normal.png", optimize=True
    )
    Image.fromarray(
        _metallic_roughness(height_field, base_roughness), mode="RGB"
    ).save(TEXTURES / f"{name}_metallic_roughness.png", optimize=True)


def main() -> None:
    TEXTURES.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict[str, object]] = {}
    for name, (roughness, normal_strength, tile_mm) in SPECS.items():
        bake_one(name, roughness, normal_strength)
        manifest[name] = {
            "baseColor": f"{name}.jpg",
            "normal": f"{name}_normal.png",
            "height": f"{name}_height.png",
            "metallicRoughness": f"{name}_metallic_roughness.png",
            "roughness": roughness,
            "normalScale": normal_strength,
            "realWorldTileMm": tile_mm,
        }

    (TEXTURES / "pbr_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Baked {len(SPECS)} finish PBR sets into {TEXTURES}")


if __name__ == "__main__":
    main()
