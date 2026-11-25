"""Cycles review render of original 3D geometry, no cosmetic replacement."""
from pathlib import Path
from mathutils import Vector
import bpy,json,os
ROOT=Path(os.environ.get("FURNITURE21_OUT","out/furniture21")).resolve()
NAME=os.environ["ASSET_NAME"]
root=ROOT/NAME
provenance=json.loads((root/"provenance.json").read_text(encoding="utf-8"))
source=root/"source"/provenance["file_name"]
assert source.is_file(), source
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[m for m in bpy.context.scene.objects if m.type=="MESH"]
assert meshes,"Source has no 3D meshes"
verts=[m.matrix_world @ Vector(p) for m in meshes for p in m.bound_box]
low=Vector(tuple(min(float(v[i]) for v in verts) for i in range(3)))
high=Vector(tuple(max(float(v[i]) for v in verts) for i in range(3)))
size=high-low
assert 0.28 < max(size) < 5.0,(NAME,list(size))
center=(low+high)*.5
print("REFERENCE_GEOMETRY",NAME,"size",list(size),
      "polygons",sum(len(m.data.polygons) for m in meshes),flush=True)
# Keep all original mesh normals, UVs and PBR materials as provided.
floor_mat=bpy.data.materials.new("Review studio - not exported")
floor_mat.use_nodes=True
p=floor_mat.node_tree.nodes.get("Principled BSDF")
p.inputs["Base Color"].default_value=(.26,.27,.29,1)
p.inputs["Roughness"].default_value=.91
bpy.ops.mesh.primitive_plane_add(size=50,location=(center.x,center.y,low.z-.013))
floor=bpy.context.object;floor.name="STUDIO REVIEW FLOOR"
floor.data.materials.append(floor_mat)
target=Vector((center.x,center.y,low.z+size.z*.51))
s=max(size.x,size.y,size.z)
cam_pos=Vector((center.x+size.x*1.85,center.y-size.y*2.3,low.z+size.z*1.45))
bpy.ops.object.camera_add(location=cam_pos)
cam=bpy.context.object
cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO"
cam.data.ortho_scale=s*1.80
scene=bpy.context.scene
scene.camera=cam
for label,off,power,radius in (
    ("STUDIO KEY",(-1.4,-1.7,2.6),530,2.1),
    ("STUDIO FILL",(1.8,.4,1.9),220,2.4),
    ("STUDIO RIM",(-1.6,1.4,2.2),310,1.8)):
    pos=Vector((center.x+s*off[0],center.y+s*off[1],low.z+s*off[2]))
    bpy.ops.object.light_add(type="AREA",location=pos)
    light=bpy.context.object;light.name=label
    light.data.energy=power
    light.data.shape="DISK"
    light.data.size=s*radius
    light.rotation_euler=(target-light.location).to_track_quat("-Z","Y").to_euler()
scene.render.engine="CYCLES"
scene.cycles.samples=18
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=940
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.exposure=-.6
scene.render.filepath=str(root/"cycles_review.png")
bpy.ops.render.render(write_still=True)
# Second angle emphasizes hidden construction, unlike single product shot.
cam.location=Vector((center.x-size.x*1.5,center.y+size.y*1.9,low.z+size.z*1.30))
cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.resolution_percentage=65
scene.cycles.samples=12
scene.render.filepath=str(root/"cycles_back.png")
bpy.ops.render.render(write_still=True)
# Keep linked textures embedded in source .blend.
for img in bpy.data.images:
    if img.source=="FILE" and img.filepath and not img.packed_file:
        try:img.pack()
        except Exception as e:print("PACK_WARN",img.name,str(e))
bpy.ops.wm.save_as_mainfile(filepath=str(root/"reference_scene.blend"))
report={
    "name":NAME,
    "source":provenance["source"],
    "bounds_m":[round(float(x),4) for x in size],
    "blender_mesh_objects":len(meshes),
    "polygons":sum(len(m.data.polygons) for m in meshes),
    "materials":sorted({ma.name for obj in meshes for ma in obj.data.materials if ma}),
    "cycles_samples":[18,12],
    "studio_only_scene":True,
    "photorealism_human_verified":False,
    "mobile_viewer_verified":False
}
(root/"blender_review.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print("CYCLES_REFERENCE_QA_OK",json.dumps(report),flush=True)
