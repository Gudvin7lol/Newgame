"""Real Cycles reference render + geometry/material diagnostics for Poly Haven chair."""
import bpy,math,json,os
from pathlib import Path
from mathutils import Vector

ROOT=Path(os.environ.get("CHAIR_OUT","out/reference_chair")).resolve()
SRC=ROOT/"source"/"modern_arm_chair_01_2k.gltf"
assert SRC.is_file()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SRC))
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert meshes,"No source 3D geometry"
for m in meshes:
    if len(m.data.polygons):
        for p in m.data.polygons:p.use_smooth=True
print("POLYHAVEN_IMPORT",[(m.name,len(m.data.vertices),len(m.data.polygons)) for m in meshes],flush=True)

def bounds(meshes):
    from mathutils import Vector
    positions=[o.matrix_world @ Vector(pt) for o in meshes for pt in o.bound_box]
    low=Vector(tuple(min(float(v[i]) for v in positions) for i in range(3)))
    high=Vector(tuple(max(float(v[i]) for v in positions) for i in range(3)))
    return low,high
low,high=bounds(meshes)
dims=high-low
centre=(low+high)*.5
max_axis=max(dims)
print("SOURCE_BOUNDS_M",list(map(float,dims)),flush=True)
assert .45<float(max_axis)<3.0,"Suspicious source units"
assert sum(len(m.data.polygons) for m in meshes)>1000
# No extra material added to imported geometry. Neutral studio only.
mat=bpy.data.materials.new("STUDIO ONLY | matte gray")
mat.use_nodes=True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.25,.26,.27,1)
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.91
bpy.ops.mesh.primitive_plane_add(size=100,location=(centre.x,centre.y,low.z-.013))
ground=bpy.context.object
ground.name="STUDIO ONLY | floor"
ground.data.materials.append(mat)
focus=Vector((centre.x,centre.y,low.z+dims.z*.53))
camera_pos=Vector((centre.x+dims.x*1.7,centre.y-dims.y*2.2,low.z+dims.z*1.38))
bpy.ops.object.camera_add(location=camera_pos)
cam=bpy.context.object
cam.rotation_euler=(focus-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type="ORTHO"
cam.data.ortho_scale=max_axis*1.75
scene=bpy.context.scene
scene.camera=cam
for name,direction,power,size in (
    ("STUDIO ONLY | key",(-1.,-1.2,2.4),360,2.0),
    ("STUDIO ONLY | fill",(1.0,.8,1.8),180,2.5),
    ("STUDIO ONLY | rim",(-.7,1.2,1.1),120,1.6)):
    loc=Vector((centre.x+direction[0]*max_axis,centre.y+direction[1]*max_axis,low.z+direction[2]*max_axis))
    bpy.ops.object.light_add(type="AREA",location=loc)
    lamp=bpy.context.object;lamp.name=name
    lamp.data.energy=power
    lamp.data.shape="DISK";lamp.data.size=size*max_axis
    lamp.rotation_euler=(focus-lamp.location).to_track_quat("-Z","Y").to_euler()
scene.render.engine="CYCLES"
scene.cycles.samples=24
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=1000
scene.render.resolution_y=840
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.exposure=-.60
scene.render.filepath=str(ROOT/"source_cycles.png")
bpy.ops.render.render(write_still=True)
# Same object, second angle for visible construction and silhouette.
cam.location=Vector((centre.x-dims.x*1.7,centre.y+dims.y*2.0,low.z+dims.z*1.2))
cam.rotation_euler=(focus-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=str(ROOT/"source_back.png")
bpy.ops.render.render(write_still=True)
scene.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"reference_chair_studio.blend"))
report={
    "source":"https://polyhaven.com/a/modern_arm_chair_01",
    "source_mesh_count":len(meshes),
    "source_faces":sum(len(m.data.polygons) for m in meshes),
    "source_vertices":sum(len(m.data.vertices) for m in meshes),
    "bounds_m":[round(float(x),4) for x in dims],
    "materials":sorted({m.name for o in meshes for m in o.data.materials if m}),
    "renderer":"Cycles 24spp / no denoising",
    "source_unchanged":True,
    "mobile_viewer_tested":False,
}
(ROOT/"reference_geometry_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print("REFERENCE_CYCLES_OK",report,flush=True)
