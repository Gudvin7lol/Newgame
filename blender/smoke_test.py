import math
import os
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

OUT = Path(os.environ.get("BLENDER_OUT", "out/blender")).resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# Small image-based linen material: this tests GLB texture embedding.
n = 256
y, x = np.mgrid[0:n, 0:n].astype(np.float32)
weave = 0.5 * np.sin(x * 2 * np.pi / 7.0) + 0.5 * np.sin(y * 2 * np.pi / 7.0)
height = 0.15 * weave + 0.08 * np.sin(x * 0.21 + np.sin(y * 0.08))
color = np.empty((n, n, 4), dtype=np.float32)
for k, base in enumerate((0.60, 0.52, 0.42)):
    color[:, :, k] = np.clip(base + weave * 0.025, 0, 1)
color[:, :, 3] = 1.0
gy, gx = np.gradient(height)
normal = np.stack((-gx * 2, -gy * 2, np.ones_like(gx)), axis=2)
normal /= np.linalg.norm(normal, axis=2, keepdims=True)
normal = np.concatenate(((normal + 1) / 2, np.ones((n, n, 1), dtype=np.float32)), axis=2)

def save_image(name, pixels, is_data=False):
    image = bpy.data.images.new(name, width=n, height=n, alpha=True)
    image.pixels.foreach_set(pixels.ravel().tolist())
    image.filepath_raw = str(OUT / (name + ".png"))
    image.file_format = "PNG"
    if is_data:
        image.colorspace_settings.name = "Non-Color"
    image.save()
    return image

albedo = save_image("linen_basecolor", color)
normal_img = save_image("linen_normal", normal, is_data=True)
material = bpy.data.materials.new("Linen | test")
material.use_nodes = True
nodes, links = material.node_tree.nodes, material.node_tree.links
bsdf = nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.84
tex = nodes.new("ShaderNodeTexImage")
tex.image = albedo
links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
ntex = nodes.new("ShaderNodeTexImage")
ntex.image = normal_img
nmap = nodes.new("ShaderNodeNormalMap")
nmap.inputs["Strength"].default_value = 0.35
links.new(ntex.outputs["Color"], nmap.inputs["Color"])
links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

# Smoke-test geometry, not a physical cloth simulation.
bpy.ops.mesh.primitive_cube_add()
pillow = bpy.context.object
pillow.name = "Pillow | test shape"
pillow.dimensions = (0.63, 0.56, 0.13)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bevel = pillow.modifiers.new("Rounded construction", "BEVEL")
bevel.width, bevel.segments = 0.045, 10
bpy.context.view_layer.objects.active = pillow
bpy.ops.object.modifier_apply(modifier=bevel.name)
subdiv = pillow.modifiers.new("Surface quality", "SUBSURF")
subdiv.levels = 2
bpy.ops.object.modifier_apply(modifier=subdiv.name)
for vertex in pillow.data.vertices:
    u, v = vertex.co.x / 0.315, vertex.co.y / 0.28
    dome = max(0, 1 - u * u) * max(0, 1 - v * v)
    if vertex.co.z > 0.035:
        vertex.co.z += 0.014 * dome
    elif vertex.co.z < -0.035:
        vertex.co.z -= 0.005 * dome
for polygon in pillow.data.polygons:
    polygon.use_smooth = True
pillow.data.materials.append(material)

piping_mat = bpy.data.materials.new("Welt | beige")
piping_mat.diffuse_color = (0.57, 0.48, 0.38, 1)
piping = bpy.data.curves.new("Piping path", type="CURVE")
piping.dimensions = "3D"
piping.resolution_u = 16
piping.bevel_depth, piping.bevel_resolution = 0.0025, 3
spline = piping.splines.new("POLY")
points = []
for cx, cy, start in [(0.265, 0.23, 0), (-0.265, 0.23, 90),
                      (-0.265, -0.23, 180), (0.265, -0.23, 270)]:
    for j in range(13):
        angle = math.radians(start + j * 90 / 12)
        points.append((cx + 0.05 * math.cos(angle),
                       cy + 0.05 * math.sin(angle), 0.026))
spline.points.add(len(points) - 1)
for point, coords in zip(spline.points, points):
    point.co = (*coords, 1)
spline.use_cyclic_u = True
piping_obj = bpy.data.objects.new("Piping | perimeter", piping)
bpy.context.collection.objects.link(piping_obj)
piping_obj.data.materials.append(piping_mat)

floor_mat = bpy.data.materials.new("Floor")
floor_mat.diffuse_color = (0.26, 0.28, 0.30, 1)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.071))
bpy.context.object.data.materials.append(floor_mat)
bpy.ops.object.camera_add(location=(1.0, -1.3, 0.82))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 1.12
bpy.context.scene.camera = camera
for name, loc, power, size in [
    ("Key", (0.2, -0.8, 1.5), 320, 1.6),
    ("Fill", (-1.0, 0.3, 1.0), 180, 1.3),
]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    lamp = bpy.context.object
    lamp.name = name
    lamp.data.energy = power
    lamp.data.shape = "DISK"
    lamp.data.size = size
    lamp.rotation_euler = (Vector((0, 0, 0)) - lamp.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 20
scene.render.resolution_x, scene.render.resolution_y = 900, 650
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "pillow_render.png")
scene.world.color = (0.35, 0.35, 0.35)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "pillow_study.blend"))
bpy.ops.object.select_all(action="DESELECT")
pillow.select_set(True)
piping_obj.select_set(True)
bpy.context.view_layer.objects.active = pillow
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "pillow_study.glb"),
    export_format="GLB", use_selection=True, export_texcoords=True,
    export_normals=True, export_materials="EXPORT"
)
bpy.ops.render.render(write_still=True)
for name in ("pillow_study.blend", "pillow_study.glb", "pillow_render.png"):
    path = OUT / name
    assert path.exists() and path.stat().st_size > 1000, f"Missing artifact: {path}"
print("BLENDER_SMOKE_OK", OUT)
