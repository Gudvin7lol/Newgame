"""Cloth Study 06: physically simulated loose cloth draped over a cushion core.
This is an actual Blender Cloth modifier simulation, not an AI image and
not a final sewn cushion. Exported mesh is evaluated after simulation.
"""
import bpy, os, math
from pathlib import Path
from mathutils import Vector
out=Path(os.environ.get("BLENDER_OUT","out/blender")).resolve()
out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)

def mat(name,rgba):
    m=bpy.data.materials.new(name)
    m.diffuse_color=rgba
    m.use_nodes=True
    b=m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value=rgba
    b.inputs["Roughness"].default_value=.85
    return m
clothmat=mat("Canvas cotton - clay",(0.54,.45,.34,1))
coremat=mat("Foam insert",(0.74,.70,.61,1))
groundmat=mat("Studio dark floor",(.07,.075,.081,1))
# Core has a genuine collision surface, not merely a visual reference.
bpy.ops.mesh.primitive_cube_add(size=1)
foam=bpy.context.object;foam.name="Foam / collision"
foam.dimensions=(.65,.57,.14);foam.location.z=.018
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bev=foam.modifiers.new("Rounded foam contour","BEVEL");bev.width=.068;bev.segments=11
bpy.context.view_layer.objects.active=foam;bpy.ops.object.modifier_apply(modifier=bev.name)
smooth=foam.modifiers.new("Smooth foam","SUBSURF");smooth.levels=1
bpy.ops.object.modifier_apply(modifier=smooth.name)
for f in foam.data.polygons:f.use_smooth=True
foam.data.materials.append(coremat)
coll=foam.modifiers.new("Foam collision","COLLISION")
foam.collision.thickness_outer=.003
foam.collision.cloth_friction=7.0

# Slack 85x77 cm rectangular cloth cut on a 65x57 cm foam body:
# drape has excess area, so natural folds appear near the corners.
nx,ny=86,78
verts=[];faces=[];uvs=[]
for j in range(ny+1):
    v=j/ny; yy=(v-.5)*.77
    for i in range(nx+1):
        u=i/nx;xx=(u-.5)*.85
        z=.195+0.008*math.sin(u*6.1)*math.sin(v*4.9)
        verts.append((xx,yy,z))
        uvs.append((u,v))
for j in range(ny):
    for i in range(nx):
        a=j*(nx+1)+i
        faces.append((a,a+1,a+nx+2,a+nx+1))
mesh=bpy.data.meshes.new("Cloth grid")
mesh.from_pydata(verts,[],faces);mesh.update()
cover=bpy.data.objects.new("Loose cut fabric | actual cloth simulation",mesh)
bpy.context.collection.objects.link(cover)
uv=mesh.uv_layers.new(name="UV")
for poly in mesh.polygons:
    poly.use_smooth=True
    for li in poly.loop_indices:
        uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
mesh.materials.append(clothmat)
bpy.context.view_layer.objects.active=cover
cover.select_set(True)
cloth=cover.modifiers.new("Real Blender Cloth simulation","CLOTH")
cloth.settings.quality=7
cloth.settings.mass=.27
cloth.settings.tension_stiffness=17.0
cloth.settings.compression_stiffness=15.0
cloth.settings.shear_stiffness=12.0
cloth.settings.bending_stiffness=.5
cloth.collision_settings.use_collision=True
cloth.collision_settings.distance_min=.003
cloth.collision_settings.use_self_collision=False

bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.11))
floor=bpy.context.object;floor.name="Ground"
floor.data.materials.append(groundmat)
floor.modifiers.new("Floor collision","COLLISION")

scene=bpy.context.scene
scene.frame_start=1;scene.frame_end=65
scene.render.fps=24
print("RUNNING_CLOTH_FRAMES")
for f in range(1,66):
    scene.frame_set(f)
    if f % 15==0:print("CLOTH_SIM_FRAME", f)
# Capture evaluated geometry after real simulation, then apply it as exportable mesh.
bpy.context.view_layer.objects.active=cover
bpy.ops.object.select_all(action="DESELECT");cover.select_set(True)
depsgraph=bpy.context.evaluated_depsgraph_get()
evaluated=cover.evaluated_get(depsgraph)
tmp=bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
assert tmp is not None and len(tmp.vertices)>6000
zs=[v.co.z for v in tmp.vertices]
spread=max(zs)-min(zs)
print("CLOTH_SIM_Z_RANGE", min(zs), max(zs), spread)
assert min(zs)<.16 and spread>.04, "Cloth failed to drape; physics requires inspection"
for m in list(cover.modifiers):cover.modifiers.remove(m)
old=cover.data;cover.data=tmp;bpy.data.meshes.remove(old)
# Keep simulated mesh on top of foam; export both with their own materials.

bpy.ops.object.camera_add(location=(1.04,-1.22,.61))
cam=bpy.context.object
look=Vector((0,0,.015))
cam.rotation_euler=(look-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO";cam.data.ortho_scale=1.19
scene.camera=cam
for name,loc,power,size in [
    ("Cloth key",(-.65,-.65,1.0),150,1.7),
    ("Cloth fill",(.65,.25,.95),85,1.4),
]:
    bpy.ops.object.light_add(type="AREA",location=loc)
    lamp=bpy.context.object;lamp.name=name;lamp.data.energy=power
    lamp.data.shape="DISK";lamp.data.size=size
    lamp.rotation_euler=(look-lamp.location).to_track_quat("-Z","Y").to_euler()
scene.render.engine="CYCLES"
scene.cycles.samples=20
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=1000;scene.render.resolution_y=730
scene.render.resolution_percentage=100
scene.view_settings.exposure=-.55
scene.world.color=(.08,.08,.08)
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(out/"cloth_sim06_cycles.png")
# Save physical simulation result in editable BLEND with evaluated mesh.
bpy.ops.wm.save_as_mainfile(filepath=str(out/"cloth_sim06.blend"))
bpy.ops.object.select_all(action="DESELECT")
cover.select_set(True);foam.select_set(True)
bpy.context.view_layer.objects.active=cover
bpy.ops.export_scene.gltf(filepath=str(out/"cloth_sim06.glb"),export_format="GLB",
    use_selection=True,export_texcoords=True,export_normals=True,export_materials="EXPORT")
bpy.ops.render.render(write_still=True)
for f in ("cloth_sim06.blend","cloth_sim06.glb","cloth_sim06_cycles.png"):
    p=out/f
    assert p.exists() and p.stat().st_size>10000, f
print("CLOTH_SIM06_OK",out)
