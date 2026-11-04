"""Render one real furniture variant in Blender, no AI concept art.

Uses Blender glTF importer so the renderer sees actual embedded PBR maps.
"""
import bpy,json,os
from mathutils import Vector
from pathlib import Path
root=Path(os.environ.get("FURNITURE22_OUT","out/furniture22")).resolve()
name=os.environ["VARIANT_NAME"]
slug="sofa_01" if name.startswith("sofa_01_") else "drawer_cabinet"
model=root/slug/(name+".glb")
assert model.exists(),model
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(model))
objects=[x for x in bpy.context.scene.objects if x.type=="MESH"]
assert objects
points=[ob.matrix_world @ Vector(q) for ob in objects for q in ob.bound_box]
minimum=Vector([min(q[i] for q in points) for i in range(3)])
maximum=Vector([max(q[i] for q in points) for i in range(3)])
size=maximum-minimum
focus=minimum+(size*.52)
maxdim=max(size)
assert .25<maxdim<5
# Studio objects never enter glTF; GLB was already built beforehand.
mat=bpy.data.materials.new("Studio grey")
mat.use_nodes=True
p=mat.node_tree.nodes.get("Principled BSDF")
p.inputs["Base Color"].default_value=(.25,.25,.27,1)
p.inputs["Roughness"].default_value=.94
bpy.ops.mesh.primitive_plane_add(size=50,location=(focus.x,focus.y,minimum.z-.012))
bpy.context.object.name="Studio Floor"
bpy.context.object.data.materials.append(mat)
camera_pos=Vector((focus.x+size.x*1.7,focus.y-size.y*2.2,minimum.z+size.z*1.4))
bpy.ops.object.camera_add(location=camera_pos)
camera=bpy.context.object
camera.rotation_euler=(focus-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"
camera.data.ortho_scale=maxdim*1.8
bpy.context.scene.camera=camera
for label,offset,power,radius in (
    ("Key",(-1.5,-1.5,2.5),350,2.1),
    ("Fill",(1.1,.8,1.7),180,2.3),
    ("Rim",(-1.2,1.6,1.7),200,1.9)):
    pos=Vector((focus.x+maxdim*offset[0],focus.y+maxdim*offset[1],minimum.z+maxdim*offset[2]))
    bpy.ops.object.light_add(type="AREA",location=pos)
    lamp=bpy.context.object
    lamp.name=label
    lamp.data.energy=power
    lamp.data.shape="DISK"
    lamp.data.size=maxdim*radius
    lamp.rotation_euler=(focus-lamp.location).to_track_quat("-Z","Y").to_euler()
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=20
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=860
scene.render.resolution_y=660
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.exposure=-.65
scene.render.filepath=str(root/(name+"_cycles.png"))
bpy.ops.render.render(write_still=True)
print("COLORWAY_CYCLES_RENDER_OK",name,scene.render.filepath,flush=True)
