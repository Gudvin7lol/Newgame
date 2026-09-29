from __future__ import annotations

import json
import math

import trimesh

from generate_furniture_pack import OUT, QUALITY, add, cyl, mat, scale_floor_center, superellipsoid


def build_sofa2(q):
    lat, lon, leg = q
    fabric = mat("fabric_sand", [0.48, 0.43, 0.38], 0.93)
    accent = mat("fabric_cushion", [0.55, 0.50, 0.45], 0.95)
    wood = mat("wood_walnut", [0.18, 0.085, 0.04], 0.58)
    scene = trimesh.Scene()
    base = trimesh.creation.box(extents=[1.55, 0.18, 0.76])
    base.apply_translation([0, 0.30, 0])
    add(scene, base, fabric, "base")
    for x, name in [(-0.79, "arm_left"), (0.79, "arm_right")]:
        add(scene, superellipsoid([x, 0.49, 0.015], [0.17, 0.52, 0.82], 0.28, 0.28, lat, lon), fabric, name)
    for i, x in enumerate([-0.37, 0.37], 1):
        add(scene, superellipsoid([x, 0.49, 0.05], [0.68, 0.17, 0.69], 0.38, 0.28, lat, lon), accent, f"seat_{i}")
        tilt = trimesh.transformations.rotation_matrix(math.radians(-7), [1, 0, 0])
        back = superellipsoid([0, 0, 0], [0.68, 0.44, 0.17], 0.34, 0.30, lat, lon, tilt)
        back.apply_translation([x, 0.69, -0.31])
        add(scene, back, accent, f"back_{i}")
    for i, (x, z) in enumerate([(-0.66, -0.27), (0.66, -0.27), (-0.66, 0.27), (0.66, 0.27)], 1):
        cyl(0.034, 0.17, leg, [x, 0.085, z], wood, scene, f"leg_{i}")
    return scale_floor_center(scene, [1.75, 0.86, 0.90]), 3


def build_corner(q):
    lat, lon, leg = q
    fabric = mat("fabric_greige", [0.39, 0.38, 0.36], 0.93)
    cushion = mat("fabric_cushion", [0.46, 0.45, 0.43], 0.95)
    metal = mat("leg_black", [0.04, 0.04, 0.04], 0.40, 0.55)
    scene = trimesh.Scene()
    base_main = trimesh.creation.box(extents=[2.55, 0.18, 0.82])
    base_main.apply_translation([0, 0.28, 0])
    add(scene, base_main, fabric, "base_main")
    base_chaise = trimesh.creation.box(extents=[0.88, 0.18, 1.58])
    base_chaise.apply_translation([0.84, 0.28, 0.38])
    add(scene, base_chaise, fabric, "base_chaise")
    for i, x in enumerate([-0.83, 0, 0.83], 1):
        add(scene, superellipsoid([x, 0.48, 0.02], [0.76, 0.18, 0.72], 0.39, 0.28, lat, lon), cushion, f"seat_{i}")
        tilt = trimesh.transformations.rotation_matrix(math.radians(-7), [1, 0, 0])
        back = superellipsoid([0, 0, 0], [0.76, 0.43, 0.17], 0.35, 0.30, lat, lon, tilt)
        back.apply_translation([x, 0.69, -0.33])
        add(scene, back, cushion, f"back_{i}")
    add(scene, superellipsoid([0.84, 0.48, 0.72], [0.76, 0.18, 0.72], 0.39, 0.28, lat, lon), cushion, "chaise_seat")
    add(scene, superellipsoid([-1.30, 0.48, 0.02], [0.18, 0.54, 0.84], 0.28, 0.28, lat, lon), fabric, "arm_left")
    add(scene, superellipsoid([1.30, 0.48, 0.38], [0.18, 0.54, 1.60], 0.28, 0.28, lat, lon), fabric, "arm_right_chaise")
    for i, (x, z) in enumerate([(-1.1, -0.28), (1.1, -0.28), (-1.1, 0.28), (1.1, 0.90)], 1):
        cyl(0.03, 0.14, leg, [x, 0.07, z], metal, scene, f"leg_{i}")
    return scale_floor_center(scene, [2.80, 0.88, 1.90]), 3


def build_modular(q):
    lat, lon, _ = q
    fabric = mat("fabric_graphite", [0.20, 0.22, 0.23], 0.95)
    accent = mat("fabric_soft", [0.29, 0.31, 0.31], 0.97)
    metal = mat("base_dark", [0.035, 0.04, 0.045], 0.37, 0.65)
    scene = trimesh.Scene()
    for i, x in enumerate([-0.78, 0, 0.78], 1):
        base = trimesh.creation.box(extents=[0.74, 0.16, 0.92])
        base.apply_translation([x, 0.22, 0])
        add(scene, base, metal, f"base_{i}")
        add(scene, superellipsoid([x, 0.40, 0.04], [0.72, 0.20, 0.84], 0.42, 0.30, lat, lon), fabric, f"seat_{i}")
        tilt = trimesh.transformations.rotation_matrix(math.radians(-9), [1, 0, 0])
        back = superellipsoid([0, 0, 0], [0.70, 0.38, 0.16], 0.36, 0.30, lat, lon, tilt)
        back.apply_translation([x, 0.67, -0.39])
        add(scene, back, accent, f"back_{i}")
    return scale_floor_center(scene, [2.40, 0.78, 1.05]), 3


def build_bed180(q):
    lat, lon, leg = q
    wood = mat("wood_dark", [0.22, 0.12, 0.07], 0.65)
    textile = mat("headboard_beige", [0.53, 0.49, 0.45], 0.92)
    bedding = mat("bedding_warm_white", [0.83, 0.82, 0.78], 0.97)
    scene = trimesh.Scene()
    frame = trimesh.creation.box(extents=[1.96, 0.24, 2.08])
    frame.apply_translation([0, 0.23, 0.02])
    add(scene, frame, wood, "frame")
    add(scene, superellipsoid([0, 0.50, 0.02], [1.86, 0.28, 1.95], 0.32, 0.25, lat, lon), bedding, "mattress")
    add(scene, superellipsoid([0, 0.88, -0.96], [1.92, 0.74, 0.17], 0.30, 0.30, lat, lon), textile, "headboard")
    for i, x in enumerate([-0.50, 0.50], 1):
        add(scene, superellipsoid([x, 0.75, -0.64], [0.82, 0.18, 0.44], 0.42, 0.34, max(6, lat // 2), max(16, lon // 2)), bedding, f"pillow_{i}")
    for i, (x, z) in enumerate([(-0.82, -0.84), (0.82, -0.84), (-0.82, 0.84), (0.82, 0.84)], 1):
        cyl(0.035, 0.15, leg, [x, 0.075, z], wood, scene, f"leg_{i}")
    return scale_floor_center(scene, [2.00, 1.08, 2.18]), 3


def build_coffee(q):
    lat, lon, leg = q
    topmat = mat("stone_top", [0.50, 0.48, 0.45], 0.74)
    metal = mat("steel_black", [0.035, 0.038, 0.042], 0.32, 0.75)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.39, 0], [1.10, 0.08, 0.62], 0.25, 0.20, lat, lon), topmat, "top")
    for i, x in enumerate([-0.35, 0.35], 1):
        cyl(0.025, 0.36, leg, [x, 0.18, -0.22], metal, scene, f"leg_{i}_a")
        cyl(0.025, 0.36, leg, [x, 0.18, 0.22], metal, scene, f"leg_{i}_b")
        rail = trimesh.creation.box(extents=[0.05, 0.05, 0.46])
        rail.apply_translation([x, 0.04, 0])
        add(scene, rail, metal, f"rail_{i}")
    return scale_floor_center(scene, [1.10, 0.42, 0.62]), 2


def build_nightstand(q):
    lat, lon, leg = q
    wood = mat("wood_oak", [0.47, 0.30, 0.16], 0.70)
    front = mat("front_matte", [0.66, 0.59, 0.50], 0.80)
    metal = mat("handle_black", [0.04, 0.04, 0.04], 0.35, 0.70)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.30, 0], [0.52, 0.56, 0.42], 0.24, 0.20, max(6, lat // 2), max(16, lon // 2)), wood, "body")
    for i, y in enumerate([0.22, 0.39], 1):
        drawer = trimesh.creation.box(extents=[0.46, 0.14, 0.025])
        drawer.apply_translation([0, y, 0.222])
        add(scene, drawer, front, f"drawer_{i}")
        cyl(0.009, 0.16, leg, [0, y, 0.244], metal, scene, f"handle_{i}", axis="x")
    return scale_floor_center(scene, [0.55, 0.62, 0.45]), 3


def build_tvconsole(q):
    lat, lon, leg = q
    wood = mat("wood_smoked", [0.20, 0.14, 0.10], 0.70)
    front = mat("front_charcoal", [0.12, 0.13, 0.14], 0.82)
    metal = mat("metal_black", [0.035, 0.038, 0.042], 0.30, 0.75)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.33, 0], [1.60, 0.48, 0.42], 0.22, 0.18, max(6, lat // 2), max(16, lon // 2)), wood, "body")
    for i, x in enumerate([-0.52, 0, 0.52], 1):
        front_panel = trimesh.creation.box(extents=[0.50, 0.38, 0.025])
        front_panel.apply_translation([x, 0.34, 0.224])
        add(scene, front_panel, front, f"front_{i}")
    for i, x in enumerate([-0.66, 0.66], 1):
        cyl(0.018, 0.14, leg, [x, 0.07, -0.12], metal, scene, f"leg_{i}_a")
        cyl(0.018, 0.14, leg, [x, 0.07, 0.12], metal, scene, f"leg_{i}_b")
    return scale_floor_center(scene, [1.60, 0.55, 0.45]), 3


def build_dresser(q):
    lat, lon, leg = q
    wood = mat("wood_light", [0.56, 0.43, 0.28], 0.72)
    front = mat("front_cream", [0.72, 0.68, 0.60], 0.82)
    metal = mat("hardware_brass", [0.35, 0.24, 0.10], 0.28, 0.74)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.48, 0], [1.20, 0.88, 0.48], 0.22, 0.20, max(6, lat // 2), max(16, lon // 2)), wood, "body")
    for row, y in enumerate([0.24, 0.49, 0.74], 1):
        for col, x in enumerate([-0.29, 0.29], 1):
            drawer = trimesh.creation.box(extents=[0.55, 0.22, 0.025])
            drawer.apply_translation([x, y, 0.255])
            add(scene, drawer, front, f"drawer_{row}_{col}")
            cyl(0.008, 0.10, leg, [x, y, 0.278], metal, scene, f"handle_{row}_{col}", axis="x")
    return scale_floor_center(scene, [1.20, 0.95, 0.50]), 3


def build_officedesk(q):
    lat, lon, leg = q
    topmat = mat("desk_top", [0.28, 0.21, 0.15], 0.65)
    metal = mat("steel_black", [0.035, 0.038, 0.042], 0.31, 0.78)
    scene = trimesh.Scene()
    add(scene, superellipsoid([0, 0.73, 0], [1.40, 0.07, 0.70], 0.23, 0.20, lat, lon), topmat, "top")
    for i, (x, z) in enumerate([(-0.58, -0.25), (0.58, -0.25), (-0.58, 0.25), (0.58, 0.25)], 1):
        cyl(0.025, 0.66, leg, [x, 0.33, z], metal, scene, f"leg_{i}")
    beam = trimesh.creation.box(extents=[1.15, 0.05, 0.05])
    beam.apply_translation([0, 0.35, -0.22])
    add(scene, beam, metal, "crossbeam")
    return scale_floor_center(scene, [1.40, 0.76, 0.70]), 2


def build_roundtable(q):
    _, lon, leg = q
    wood = mat("oak_round", [0.43, 0.28, 0.15], 0.62)
    metal = mat("pedestal_black", [0.035, 0.038, 0.042], 0.30, 0.78)
    scene = trimesh.Scene()
    top = trimesh.creation.cylinder(radius=0.55, height=0.06, sections=max(24, lon))
    top.apply_transform(trimesh.transformations.rotation_matrix(math.radians(90), [1, 0, 0]))
    top.apply_translation([0, 0.73, 0])
    add(scene, top, wood, "top")
    cyl(0.10, 0.63, max(16, leg), [0, 0.36, 0], metal, scene, "pedestal")
    base = trimesh.creation.cylinder(radius=0.32, height=0.045, sections=max(24, lon))
    base.apply_transform(trimesh.transformations.rotation_matrix(math.radians(90), [1, 0, 0]))
    base.apply_translation([0, 0.022, 0])
    add(scene, base, metal, "base")
    return scale_floor_center(scene, [1.10, 0.76, 1.10]), 2


BUILDERS = {
    "sofa-2": (build_sofa2, [1.75, 0.90, 0.86], "soft_furniture", "Диван 2-местный"),
    "sofa-corner": (build_corner, [2.80, 1.90, 0.88], "soft_furniture", "Диван угловой"),
    "sofa-modular": (build_modular, [2.40, 1.05, 0.78], "soft_furniture", "Диван модульный"),
    "bed-180": (build_bed180, [2.00, 2.18, 1.08], "beds", "Кровать 180"),
    "coffee-table": (build_coffee, [1.10, 0.62, 0.42], "tables_chairs", "Журнальный стол"),
    "nightstand": (build_nightstand, [0.55, 0.45, 0.62], "storage", "Тумба прикроватная"),
    "tv-console-1600": (build_tvconsole, [1.60, 0.45, 0.55], "storage", "ТВ-тумба 1600"),
    "dresser-1200": (build_dresser, [1.20, 0.50, 0.95], "storage", "Комод 1200"),
    "office-desk-1400": (build_officedesk, [1.40, 0.70, 0.76], "office", "Стол офисный 1400"),
    "table-round": (build_roundtable, [1.10, 1.10, 0.76], "tables_chairs", "Стол круглый"),
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
        raise RuntimeError(f"LOD order failed {asset_id}: {results}")
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
        "source": {"generator": "zamer-procedural-furniture-v2", "license": "project-generated", "reference": "internal"},
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
