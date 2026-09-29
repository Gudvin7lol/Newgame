from __future__ import annotations

import hashlib
import math
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image
from trimesh.visual.material import PBRMaterial

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "zamer_catalog"

PRODUCTION_IDS = (
    "armchair",
    "bed-160",
    "bed-180",
    "coffee-table",
    "dining-chair-upholstered",
    "dining-table-1800",
    "dresser-1200",
    "nightstand",
    "office-desk-1400",
    "sofa-2",
    "sofa-3",
    "sofa-corner",
    "sofa-modular",
    "table-round",
    "tv-console-1600",
    "wardrobe-sliding-2000",
)

LODS = ("", "_lod1", "_lod2")


def _seed(text: str) -> int:
    return int.from_bytes(hashlib.sha256(text.encode("utf-8")).digest()[:8], "little")


def _base_color(material) -> np.ndarray:
    factor = getattr(material, "baseColorFactor", None)
    if factor is None:
        return np.array([0.45, 0.45, 0.45], dtype=float)
    color = np.asarray(factor, dtype=float).reshape(-1)[:3]
    if color.size != 3 or not np.all(np.isfinite(color)):
        return np.array([0.45, 0.45, 0.45], dtype=float)
    if np.max(color) > 1.5:
        color = color / 255.0
    return np.clip(color, 0.025, 0.98)


def _style(name: str) -> str:
    key = name.lower()
    if any(token in key for token in ("fabric", "textile", "bedding", "cushion", "headboard")):
        return "fabric"
    if any(token in key for token in ("wood", "oak", "walnut", "smoked", "desk_top")):
        return "wood"
    if any(token in key for token in ("stone", "concrete", "marble")):
        return "stone"
    if any(token in key for token in ("metal", "steel", "aluminium", "aluminum", "brass", "hardware", "leg_black", "base_dark")):
        return "metal"
    if any(token in key for token in ("front", "panel", "door")):
        return "painted"
    return "matte"


def _height_to_normal(height: np.ndarray, strength: float) -> Image.Image:
    gy, gx = np.gradient(height.astype(np.float32))
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    normal = np.stack((nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5), axis=-1)
    return Image.fromarray(np.uint8(np.clip(normal, 0, 1) * 255), mode="RGB")


def _textures(style: str, base: np.ndarray, name: str, size: int):
    rng = np.random.default_rng(_seed(f"{style}:{name}:{size}"))
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    x /= size
    y /= size
    noise = rng.normal(0.0, 1.0, (size, size)).astype(np.float32)

    if style == "fabric":
        warp = np.sin(2 * math.pi * x * 54.0)
        weft = np.sin(2 * math.pi * y * 58.0)
        weave = 0.52 * warp + 0.48 * weft + 0.22 * warp * weft
        height = weave * 0.28 + noise * 0.045
        shade = np.clip(1.0 + weave * 0.055 + noise * 0.022, 0.82, 1.18)
        roughness = np.clip(0.90 + noise * 0.025, 0.80, 0.98)
        metallic = 0.0
        normal_strength = 4.2
    elif style == "wood":
        bend = 0.18 * np.sin(2 * math.pi * y * 1.7) + 0.05 * np.sin(2 * math.pi * y * 7.0)
        grain = np.sin(2 * math.pi * (x * 9.0 + bend + noise * 0.025))
        fine = np.sin(2 * math.pi * (x * 41.0 + noise * 0.015))
        height = grain * 0.23 + fine * 0.07 + noise * 0.025
        shade = np.clip(0.96 + grain * 0.095 + fine * 0.025 + noise * 0.018, 0.72, 1.22)
        roughness = np.clip(0.59 + grain * 0.045 + noise * 0.018, 0.46, 0.72)
        metallic = 0.0
        normal_strength = 3.0
    elif style == "stone":
        broad = (
            np.sin(2 * math.pi * (x * 2.1 + y * 1.3))
            + 0.55 * np.sin(2 * math.pi * (x * 5.7 - y * 3.2))
            + 0.25 * np.sin(2 * math.pi * (x * 13.0 + y * 8.0))
        )
        height = broad * 0.14 + noise * 0.065
        shade = np.clip(0.98 + broad * 0.045 + noise * 0.028, 0.78, 1.18)
        roughness = np.clip(0.70 + broad * 0.025 + noise * 0.03, 0.58, 0.84)
        metallic = 0.0
        normal_strength = 3.5
    elif style == "metal":
        brushed = np.sin(2 * math.pi * y * 110.0) * 0.35 + noise * 0.16
        height = brushed * 0.06
        shade = np.clip(1.0 + brushed * 0.025, 0.90, 1.10)
        roughness = np.clip(0.34 + noise * 0.02, 0.25, 0.46)
        metallic = 0.82
        normal_strength = 1.8
    elif style == "painted":
        height = noise * 0.035
        shade = np.clip(1.0 + noise * 0.012, 0.95, 1.05)
        roughness = np.clip(0.75 + noise * 0.015, 0.68, 0.84)
        metallic = 0.0
        normal_strength = 1.8
    else:
        height = noise * 0.035
        shade = np.clip(1.0 + noise * 0.016, 0.94, 1.06)
        roughness = np.clip(0.78 + noise * 0.018, 0.68, 0.88)
        metallic = 0.0
        normal_strength = 1.8

    rgb = np.clip(base[None, None, :] * shade[:, :, None], 0, 1)
    base_image = Image.fromarray(np.uint8(rgb * 255), mode="RGB")
    normal_image = _height_to_normal(height, normal_strength)

    mr = np.zeros((size, size, 3), dtype=np.uint8)
    mr[:, :, 0] = 255
    mr[:, :, 1] = np.uint8(np.clip(roughness, 0, 1) * 255)
    mr[:, :, 2] = np.uint8(np.clip(metallic, 0, 1) * 255)
    metallic_roughness = Image.fromarray(mr, mode="RGB")
    return base_image, normal_image, metallic_roughness, float(np.mean(roughness)), metallic


def _uv(mesh: trimesh.Trimesh, style: str) -> np.ndarray:
    vertices = np.asarray(mesh.vertices, dtype=np.float64)
    if len(vertices) == 0:
        return np.zeros((0, 2), dtype=np.float64)
    minimum = vertices.min(axis=0)
    maximum = vertices.max(axis=0)
    extents = np.maximum(maximum - minimum, 1e-9)

    if style == "fabric":
        center = (minimum + maximum) * 0.5
        rel = vertices - center
        u = np.arctan2(rel[:, 2], rel[:, 0]) / (2 * math.pi) + 0.5
        v = (vertices[:, 1] - minimum[1]) / extents[1]
        return np.column_stack((u * 4.0, v * 4.0))

    axes = np.argsort(extents)[-2:]
    repeat = 3.0 if style == "wood" else 2.0
    u = (vertices[:, axes[1]] - minimum[axes[1]]) / extents[axes[1]]
    v = (vertices[:, axes[0]] - minimum[axes[0]]) / extents[axes[0]]
    return np.column_stack((u * repeat, v * repeat))


def _triangle_count(scene: trimesh.Scene) -> int:
    return sum(len(mesh.faces) for mesh in scene.geometry.values())


def _bake(path: Path, texture_size: int) -> tuple[int, int]:
    scene = trimesh.load(path, force="scene", process=False)
    before_triangles = _triangle_count(scene)
    before_extents = scene.extents.copy()

    for geom_name, mesh in scene.geometry.items():
        old_material = getattr(mesh.visual, "material", None)
        material_name = getattr(old_material, "name", None) or geom_name
        style = _style(material_name)
        base = _base_color(old_material)
        base_tex, normal_tex, mr_tex, roughness, metallic = _textures(
            style, base, material_name, texture_size
        )
        material = PBRMaterial(
            name=material_name,
            baseColorFactor=[1.0, 1.0, 1.0, 1.0],
            baseColorTexture=base_tex,
            normalTexture=normal_tex,
            metallicRoughnessTexture=mr_tex,
            metallicFactor=metallic,
            roughnessFactor=roughness,
        )
        mesh.visual = trimesh.visual.TextureVisuals(
            uv=_uv(mesh, style),
            material=material,
        )

    data = scene.export(file_type="glb")
    path.write_bytes(data)

    check = trimesh.load(path, force="scene", process=False)
    after_triangles = _triangle_count(check)
    if after_triangles != before_triangles:
        raise RuntimeError(
            f"triangle count changed for {path.name}: {before_triangles} -> {after_triangles}"
        )
    if not np.allclose(check.extents, before_extents, atol=1e-5):
        raise RuntimeError(
            f"bounds changed for {path.name}: {before_extents} -> {check.extents}"
        )
    textured = 0
    for mesh in check.geometry.values():
        material = getattr(mesh.visual, "material", None)
        if getattr(material, "baseColorTexture", None) is not None:
            textured += 1
    if textured == 0:
        raise RuntimeError(f"no embedded base color textures in {path.name}")
    return before_triangles, path.stat().st_size


def main() -> None:
    for asset_id in PRODUCTION_IDS:
        for suffix in LODS:
            path = OUT / f"{asset_id}{suffix}.glb"
            if not path.exists():
                raise FileNotFoundError(path)
            size = 512 if suffix == "" else 256
            triangles, bytes_size = _bake(path, size)
            print(
                f"{path.name}: {triangles} triangles, embedded {size}px PBR maps, {bytes_size} bytes"
            )


if __name__ == "__main__":
    main()
