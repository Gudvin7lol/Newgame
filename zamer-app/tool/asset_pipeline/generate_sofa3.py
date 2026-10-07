from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "zamer_catalog"
TARGET = np.array([2.2, 0.85, 0.9], dtype=float)  # X width, Y height, Z depth


def spow(value: float, exponent: float) -> float:
    return float(np.sign(value) * (abs(value) ** exponent))


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


def materials():
    fabric = PBRMaterial(
        name="fabric_charcoal",
        baseColorFactor=[0.20, 0.25, 0.31, 1.0],
        metallicFactor=0.0,
        roughnessFactor=0.88,
    )
    cushion = PBRMaterial(
        name="fabric_cushion",
        baseColorFactor=[0.24, 0.30, 0.37, 1.0],
        metallicFactor=0.0,
        roughnessFactor=0.92,
    )
    wood = PBRMaterial(
        name="wood_legs",
        baseColorFactor=[0.20, 0.12, 0.075, 1.0],
        metallicFactor=0.0,
        roughnessFactor=0.58,
    )
    return fabric, cushion, wood


def build_sofa(lat, lon, rail_lat, rail_lon, leg_sections):
    fabric, cushion, wood = materials()
    scene = trimesh.Scene()

    def add(mesh, material, name):
        mesh.fix_normals()
        mesh.visual = trimesh.visual.TextureVisuals(material=material)
        scene.add_geometry(mesh, geom_name=name, node_name=name)

    base = trimesh.creation.box(extents=[2.02, 0.18, 0.76])
    base.apply_translation([0, 0.31, 0])
    add(base, fabric, "frame_base")

    for x, name in [(-1.01, "arm_left"), (1.01, "arm_right")]:
        add(superellipsoid([x, 0.49, 0.015], [0.18, 0.52, 0.82], 0.27, 0.27, lat, lon), fabric, name)

    xs = [-0.68, 0.0, 0.68]
    for i, x in enumerate(xs, 1):
        add(superellipsoid([x, 0.48, 0.055], [0.64, 0.16, 0.72], 0.38, 0.27, lat, lon), cushion, f"seat_{i}")

    tilt = trimesh.transformations.rotation_matrix(math.radians(-7), [1, 0, 0])
    for i, x in enumerate(xs, 1):
        back = superellipsoid([0, 0, 0], [0.64, 0.43, 0.17], 0.34, 0.30, lat, lon, tilt)
        back.apply_translation([x, 0.68, -0.315])
        add(back, cushion, f"back_{i}")

    add(
        superellipsoid([0, 0.53, -0.36], [1.96, 0.28, 0.16], 0.26, 0.26, rail_lat, rail_lon),
        fabric,
        "back_rail",
    )

    for i, (x, z) in enumerate([(-0.88, -0.28), (0.88, -0.28), (-0.88, 0.28), (0.88, 0.28)], 1):
        leg = trimesh.creation.cylinder(radius=0.035, height=0.17, sections=leg_sections)
        leg.apply_transform(trimesh.transformations.rotation_matrix(math.radians(90), [1, 0, 0]))
        leg.apply_translation([x, 0.085, z])
        add(leg, wood, f"leg_{i}")

    scale = TARGET / scene.extents
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

    if not np.allclose(scene.extents, TARGET, atol=1e-6):
        raise RuntimeError(f"Unexpected dimensions: {scene.extents}")
    return scene


def export(name, params):
    scene = build_sofa(*params)
    path = OUT / name
    path.write_bytes(scene.export(file_type="glb"))
    triangles = sum(len(mesh.faces) for mesh in scene.geometry.values())
    return triangles, path.stat().st_size


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    specs = {
        "sofa-3.glb": (24, 64, 18, 48, 24),
        "sofa-3_lod1.glb": (16, 40, 12, 32, 16),
        "sofa-3_lod2.glb": (8, 24, 6, 16, 12),
    }
    result = {name: export(name, params) for name, params in specs.items()}

    metadata = {
        "id": "sofa-3",
        "name": "Диван 3-местный",
        "category": "soft_furniture",
        "file": "assets/models/zamer_catalog/sofa-3.glb",
        "dimensions_m": {"width": 2.2, "depth": 0.9, "height": 0.85},
        "placement": "floor",
        "pivot": "floor_center",
        "lod": {
            "lod0_triangles": result["sofa-3.glb"][0],
            "lod1_file": "assets/models/zamer_catalog/sofa-3_lod1.glb",
            "lod1_triangles": result["sofa-3_lod1.glb"][0],
            "lod2_file": "assets/models/zamer_catalog/sofa-3_lod2.glb",
            "lod2_triangles": result["sofa-3_lod2.glb"][0],
        },
        "materials": {"pbr": True, "max_texture_size": 2048, "material_count": 3},
        "collision": {"type": "box", "file": None},
        "source": {
            "generator": "zamer-procedural-superellipsoid-v1",
            "license": "project-generated",
            "reference": "internal",
        },
        "version": 1,
    }
    (OUT / "sofa-3.asset.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for name, (triangles, size) in result.items():
        print(f"{name}: {triangles} triangles, {size} bytes")


if __name__ == "__main__":
    main()
