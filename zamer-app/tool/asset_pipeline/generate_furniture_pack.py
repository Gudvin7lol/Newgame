from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "zamer_catalog"


def spow(v, e):
    return float(np.sign(v) * (abs(v) ** e))


def superellipsoid(center, size, eps1, eps2, lat_rings, lon_segments, transform=None):
    w, h, d = size
    a, b, c = w / 2, h / 2, d / 2
    vertices = [[0.0, -b, 0.0]]
    etas = np.linspace(-math.pi / 2, math.pi / 2, lat_rings + 2)[1:-1]
    omegas = np.linspace(-math.pi, math.pi, lon_segments, endpoint=False)
    for eta in etas:
        ce, se = math.cos(eta), math.sin(eta)
        for omega in omegas:
            cw, sw = math.cos(omega), math.sin(omega)
            vertices.append([
                a * spow(ce, eps1) * spow(cw, eps2),
                b * spow(se, eps1),
                c * spow(ce, eps1) * spow(sw, eps2),
            ])
    top = len(vertices)
    vertices.append([0.0, b, 0.0])
    faces = []
    for j in range(lon_segments):
        n = (j + 1) % lon_segments
        faces.append([0, 1 + j, 1 + n])
    for ring in range(lat_rings - 1):
        r0 = 1 + ring * lon_segments
        r1 = 1 + (ring + 1) * lon_segments
        for j in range(lon_segments):
            n = (j + 1) % lon_segments
            faces.extend(([r0 + j, r1 + n, r0 + n], [r0 + j, r1 + j, r1 + n]))
    last = 1 + (lat_rings - 1) * lon_segments
    for j in range(lon_segments):
        n = (j + 1) % lon_segments
        faces.append([last + j, last + n, top])
    mesh = trimesh.Trimesh(np.asarray(vertices), np.asarray(faces), process=True)
    if transform is not None:
        mesh.apply_transform(transform)
    mesh.apply_translation(center)
    mesh.fix_normals()
    return mesh


def mat(name, color, rough=0.7, metal=0.0):
    return PBRMaterial(
        name=name,
        baseColorFactor=[*color, 1.0],
        metallicFactor=metal,
        roughnessFactor=rough,
    )


def add(scene, mesh, material, name):
    mesh.fix_normals()
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    scene.add_geometry(mesh, geom_name=name, node_name=name)


def cyl(radius, height, sections, center, material, scene, name, axis="y"):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        mesh.apply_transform(trimesh.transformations.rotation_matrix(math.radians(90), [1, 0, 0]))
    elif axis == "x":
        mesh.apply_transform(trimesh.transformations.rotation_matrix(math.radians(90), [0, 1, 0]))
    mesh.apply_translation(center)
    add(scene, mesh, material, name)


def scale_floor_center(scene, target):
    target = np.asarray(target, float)
    scale = target / scene.extents
    matrix = np.eye(4)
    matrix[0, 0], matrix[1, 1], matrix[2, 2] = scale
    for mesh in scene.geometry.values():
        mesh.apply_transform(matrix)
        mesh.fix_normals()
    bounds = scene.bounds
    shift = np.array([
        -(bounds[0, 0] + bounds[1, 0]) / 2,
        -bounds[0, 1],
        -(bounds[0, 2] + bounds[1, 2]) / 2,
    ])
    for mesh in scene.geometry.values():
        mesh.apply_translation(shift)
    if not np.allclose(scene.extents, target, atol=1e-5):
        raise RuntimeError(f"dimensions mismatch: {scene.extents} != {target}")
    return scene


def build_armchair(q):
    lat, lon, leg_sections = q
    fabric = mat("fabric_warm_gray", [0.36, 0.34, 0.32], 0.92)
    accent = mat("fabric_cushion", [0.45, 0.42, 0.38], 0.94)
    wood = mat("wood_walnut", [0.19, 0.09, 0.045], 0.58)
    scene = trimesh.Scene()
    base = trimesh.creation.box(extents=[0.72, 0.16, 0.70])
    base.apply_translation([0, 0.30, 0.02])
    add(scene, base, fabric, "base")
    add(scene, superellipsoid([-0.39, 0.48, 0.02], [0.16, 0.52, 0.76], 0.28, 0.28, lat, lon), fabric, "arm_left")
    add(scene, superellipsoid([0.39, 0.48, 0.02], [0.16, 0.52, 0.76], 0.28, 0.28, lat, lon), fabric, "arm_right")
    add(scene, superellipsoid([0, 0.48, 0.05], [0.64, 0.17, 0.66], 0.38, 0.28, lat, lon), accent, "seat")
    tilt = trimesh.transformations.rotation_matrix(math.radians(-8), [1, 0, 0])
    add(scene, superellipsoid([0, 0, 0], [0.64, 0.46, 0.18], 0.34, 0.30, lat, lon, tilt), accent, "back")
    scene.geometry["back"].apply_translation([0, 0.68, -0.29])
    for i, (x, z) in enumerate([(-0.30, -0.25), (0.30, -0.25), (-0.30, 0.25), (0.30, 0.25)], 1):
        cyl(0.034, 0.17, leg_sections, [x, 0.085, z], wood, scene, f"leg_{i}")
    return scale_floor_center(scene, [0.90, 0.90, 0.90]), 3


def build_bed(q):
    lat, lon, leg_sections = q
    wood = mat("wood_oak", [0.34, 0.19, 0.09], 0.62)
    textile = mat("textile_headboard", [0.28, 0.30, 0.32], 0.90)
    bedding = mat("bedding", [0.78, 0.79, 0.77], 0.96)
    scene = trimesh.Scene()
    frame = trimesh.creation.box(extents=[1.78, 0.24, 2.05])
    frame.apply_translation([0, 0.23, 0.02])
    add(scene, frame, wood, "frame")
    add(scene, superellipsoid([0, 0.49, 0.02], [1.68, 0.28, 1.93], 0.32, 0.25, lat, lon), bedding, "mattress")
    add(scene, superellipsoid([0, 0.86, -0.94], [1.72, 0.72, 0.16], 0.30, 0.30, lat, lon), textile, "headboard")
    for i, x in enumerate([-0.43, 0.43], 1):
        add(scene, superellipsoid([x, 0.73, -0.64], [0.72, 0.18, 0.42], 0.42, 0.34, max(6, lat // 2), max(16, lon // 2)), bedding, f"pillow_{i}")
    for i, (x, z) in enumerate([(-0.75, -0.82), (0.75, -0.82), (-0.75, 0.82), (0.75, 0.82)], 1):
        cyl(0.035, 0.15, leg_sections, [x, 0.075, z], wood, scene, f"leg_{i}")
    return scale_floor_center(scene, [1.80, 1.05, 2.15]), 3


def build_dining_chair(q):
    lat, lon, leg_sections = q
    fabric = mat("fabric_taupe", [0.40, 0.34, 0.29], 0.91)
    metal = mat("metal_black", [0.035, 0.038, 0.042], 0.34, 0.72)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.49, 0.02], [0.50, 0.13, 0.50], 0.42, 0.30, lat, lon), fabric, "seat")
    tilt = trimesh.transformations.rotation_matrix(math.radians(-5), [1, 0, 0])
    add(scene, superellipsoid([0, 0, 0], [0.48, 0.43, 0.14], 0.34, 0.28, lat, lon, tilt), fabric, "back")
    scene.geometry["back"].apply_translation([0, 0.71, -0.18])
    for i, (x, z) in enumerate([(-0.19, -0.16), (0.19, -0.16), (-0.19, 0.16), (0.19, 0.16)], 1):
        cyl(0.018, 0.46, leg_sections, [x, 0.23, z], metal, scene, f"leg_{i}")
    return scale_floor_center(scene, [0.50, 0.86, 0.58]), 2


def build_table(q):
    lat, lon, leg_sections = q
    wood = mat("oak_top", [0.38, 0.22, 0.11], 0.60)
    metal = mat("steel_black", [0.035, 0.038, 0.042], 0.31, 0.78)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.72, 0], [1.80, 0.08, 0.90], 0.24, 0.22, lat, lon), wood, "top")
    apron = trimesh.creation.box(extents=[1.55, 0.10, 0.64])
    apron.apply_translation([0, 0.64, 0])
    add(scene, apron, metal, "apron")
    for i, (x, z) in enumerate([(-0.70, -0.30), (0.70, -0.30), (-0.70, 0.30), (0.70, 0.30)], 1):
        cyl(0.032, 0.64, leg_sections, [x, 0.32, z], metal, scene, f"leg_{i}")
    return scale_floor_center(scene, [1.80, 0.76, 0.90]), 2


def build_wardrobe(q):
    _, _, handle_sections = q
    wood = mat("wood_matte", [0.58, 0.54, 0.48], 0.82)
    panel = mat("door_panel", [0.78, 0.76, 0.72], 0.75)
    metal = mat("aluminium", [0.24, 0.26, 0.29], 0.28, 0.74)
    scene = trimesh.Scene()
    body = trimesh.creation.box(extents=[2.0, 2.4, 0.62])
    body.apply_translation([0, 1.2, 0])
    add(scene, body, wood, "body")
    for i, x in enumerate([-0.49, 0.49], 1):
        door = trimesh.creation.box(extents=[0.98, 2.30, 0.035])
        door.apply_translation([x, 1.2, 0.327])
        add(scene, door, panel, f"door_{i}")
        cyl(0.012, 1.28, handle_sections, [x + (0.40 if i == 1 else -0.40), 1.20, 0.355], metal, scene, f"handle_{i}")
    toprail = trimesh.creation.box(extents=[1.96, 0.035, 0.045])
    toprail.apply_translation([0, 2.32, 0.35])
    add(scene, toprail, metal, "top_track")
    bottomrail = trimesh.creation.box(extents=[1.96, 0.035, 0.045])
    bottomrail.apply_translation([0, 0.08, 0.35])
    add(scene, bottomrail, metal, "bottom_track")
    return scale_floor_center(scene, [2.0, 2.40, 0.65]), 3


BUILDERS = {
    "armchair": (build_armchair, [0.90, 0.90, 0.90], "soft_furniture", "Кресло"),
    "bed-160": (build_bed, [1.80, 2.15, 1.05], "beds", "Кровать 160"),
    "dining-chair-upholstered": (build_dining_chair, [0.50, 0.58, 0.86], "tables_chairs", "Стул обеденный мягкий"),
    "dining-table-1800": (build_table, [1.80, 0.90, 0.76], "tables_chairs", "Стол обеденный 1800"),
    "wardrobe-sliding-2000": (build_wardrobe, [2.0, 0.65, 2.40], "storage", "Шкаф-купе 2000"),
}

QUALITY = {
    "lod0": (20, 52, 24),
    "lod1": (12, 32, 16),
    "lod2": (7, 18, 10),
}


def export_asset(asset_id, builder, dims, category, display):
    results = {}
    material_count = None
    for suffix, quality in QUALITY.items():
        scene, material_count = builder(quality)
        filename = f"{asset_id}.glb" if suffix == "lod0" else f"{asset_id}_{suffix}.glb"
        path = OUT / filename
        path.write_bytes(scene.export(file_type="glb"))
        results[suffix] = (sum(len(mesh.faces) for mesh in scene.geometry.values()), filename, path.stat().st_size)
    if not (results["lod0"][0] > results["lod1"][0] > results["lod2"][0]):
        raise RuntimeError(f"LOD triangle ordering failed for {asset_id}: {results}")
    metadata = {
        "id": asset_id,
        "name": display,
        "category": category,
        "file": f"assets/models/zamer_catalog/{asset_id}.glb",
        "dimensions_m": {"width": dims[0], "depth": dims[1], "height": dims[2]},
        "placement": "floor",
        "pivot": "floor_center",
        "lod": {
            "lod0_triangles": results["lod0"][0],
            "lod1_file": f"assets/models/zamer_catalog/{asset_id}_lod1.glb",
            "lod1_triangles": results["lod1"][0],
            "lod2_file": f"assets/models/zamer_catalog/{asset_id}_lod2.glb",
            "lod2_triangles": results["lod2"][0],
        },
        "materials": {"pbr": True, "max_texture_size": 2048, "material_count": material_count},
        "collision": {"type": "box", "file": None},
        "source": {"generator": "zamer-procedural-furniture-v1", "license": "project-generated", "reference": "internal"},
        "version": 1,
    }
    (OUT / f"{asset_id}.asset.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return results


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for asset_id, (builder, dims, category, display) in BUILDERS.items():
        results = export_asset(asset_id, builder, dims, category, display)
        print(asset_id, {key: value[0] for key, value in results.items()})


if __name__ == "__main__":
    main()
