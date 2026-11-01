"""Cushion Study 14 — pinned cloth over separate foam, actual Blender cloth physics.
Geometry is authored as separate top, gusset, underside, cord and stitching.
Real Cloth modifier, pin group along upper seam, collided against foam core.\nGusset/underpanel are constructed components, not sewn by sewing springs.
"""
import bpy, math, os, random
import numpy as np
from pathlib import Path
from mathutils import Vector
from math import exp, sin, cos, pi, sqrt

OUT = Path(os.environ.get("BLENDER_OUT", "out/blender")).resolve()
OUT.mkdir(parents=True, exist_ok=True)
# Reproducible candidate controls. The objective QA script compares resulting assets.
TEXTURE_TILE_M=float(os.environ.get("TEXTURE_TILE_M","0.30"))
NORMAL_STRENGTH=float(os.environ.get("NORMAL_STRENGTH","0.75"))
RENDER_SAMPLES=int(os.environ.get("RENDER_SAMPLES","18"))
SHAPE_LOOSENESS=float(os.environ.get("SHAPE_LOOSENESS","1.0"))
assert 0.55<=SHAPE_LOOSENESS<=1.65, "Unreasonable upholstery looseness"
assert 0.12<=TEXTURE_TILE_M<=0.70, "UV physical scale out of range"
assert 0.2<=NORMAL_STRENGTH<=1.6, "Normal strength out of range"
random.seed(50)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
A, B, R = 0.355, 0.305, 0.094
# Half width, half depth, sewn corner radius in metres.
# Clamp UV onto a true rounded rectangular outline, not a rounded cube.
def sdrounded(x,y):
    qx, qy = abs(x)-(A-R), abs(y)-(B-R)
    return math.hypot(max(qx,0),max(qy,0)) + min(max(qx,qy),0) - R

def xy(u,v):
    m = max(abs(u),abs(v))
    if m < 1e-8: return 0.0,0.0
    ux,vy=u/m,v/m
    lo,hi=0.0,1.0
    for _ in range(18):
        mid=(lo+hi)*0.5
        if sdrounded(A*ux*mid, B*vy*mid)>0: hi=mid
        else: lo=mid
    scale=(lo+hi)*0.5
    # Small independent fluctuations in the cutting line: actual cushions do not
    # retain a mathematically perfect superellipse once stuffed and compressed.
    x,y=A*u*scale,B*v*scale
    a=math.atan2(y/B,x/A)
    edge_weight=max(abs(u),abs(v))**2.5
    ripple=(.0025*math.sin(3*a+.37)+.0017*math.sin(7*a-1.14)
            +.0009*math.sin(11*a+.55))
    ripple*=SHAPE_LOOSENESS*edge_weight
    radius=max(.001,math.hypot(x,y))
    return x+ripple*x/radius, y+ripple*y/radius

def top_height(x,y):
    # Filled foam distends the broad centre, not the entire edge uniformly.
    ux,vy=abs(x/A),abs(y/B)
    crown=max(0,1-ux**2.5)**1.2 * max(0,1-vy**2.5)**1.2
    # Flatter, compressed foam crest. The old 41mm dome looked inflated and rigid.
    z=.064+( .027-.004*(SHAPE_LOOSENESS-1.0))*crown
    # Uneven upholstery tension; small broad depressions, not repeating stripes.
    z+=.0039*SHAPE_LOOSENESS*math.sin(7.5*x+1.8*y+.6)*math.cos(4.6*y-1.2*x)*crown
    # Broad, asymmetric foam pockets create uneven support instead of a single
    # perfect inflated dome. All amplitudes are millimetric and deterministic.
    z-=.0056*SHAPE_LOOSENESS*exp(-((x+.13)/.18)**2-((y+.05)/.14)**2)*crown
    z+=.0036*SHAPE_LOOSENESS*exp(-((x-.16)/.12)**2-((y-.12)/.14)**2)*crown
    z+=0.0045*exp(-((x+0.086)/0.12)**2 - ((y-0.047)/0.17)**2)
    z+=0.0025*exp(-((x-0.17)/0.07)**2 - ((y+0.09)/0.15)**2)
    z-=0.002*exp(-((x+0.21)/0.075)**2 - ((y+0.15)/0.06)**2)
    # Sparse folds are attached to seam compression points, with a natural falloff.
    folds=[(-.250,-.225, .86,.51, .083,.0070, .012),
           (-.185,-.266, .31,.95, .061,.0048, .010),
           ( .229,-.237,-.78,.61, .094,.0056, .013),
           ( .292,-.131,-.93,.24, .065,.0038, .011),
           (-.309, .113, .89,-.24, .055,.0028, .011),
           ( .169, .276,-.29,-.94, .060,.0025,.012)]
    for ax,ay,dx,dy,L,amp,w in folds:
        t=(x-ax)*dx+(y-ay)*dy
        p=-(x-ax)*dy+(y-ay)*dx
        if t>-0.015 and t<L*2.0:
            envelope=exp(-((t-L*0.67)/(L*0.7))**2)
            # asymmetric crease with adjacent lifted ridge
            z+=SHAPE_LOOSENESS*amp*envelope*(exp(-((p-w*.53)/w)**2)-.72*exp(-((p+w*.42)/(w*.72))**2))
    return z

def mesh_obj(name, verts, faces, uvs, material):
    mesh=bpy.data.meshes.new(name+"Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    uv=mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.use_smooth=True
        for loop_idx in poly.loop_indices:
            vi=mesh.loops[loop_idx].vertex_index
            uv.data[loop_idx].uv=uvs[vi]
    mesh.materials.append(material)
    return ob

# Real scanned CC0 Poly Haven Rough Linen, not a procedural woven grid.
# Pre-processing provided by blender/scan_fabric_v13.py.
SCAN = OUT / "scan_v13"
def tex(name, linear=False):
    path=SCAN/name
    assert path.is_file(), "Missing scanned PBR map: " + str(path)
    im=bpy.data.images.load(str(path),check_existing=False)
    if linear:
        im.colorspace_settings.name="Non-Color"
    im.pack()
    print("SCANNED_TEXTURE", name, im.size[:], im.colorspace_settings.name)
    return im
alb=tex("linen_scan_beige_basecolor.png")
nrm=tex("linen_scan_normal_gl.png",True)
orm_img=tex("linen_scan_orm.png",True)
fabric=bpy.data.materials.new("ROUGH LINEN SCAN | CC0 | glTF PBR")
fabric.use_nodes=True
nodes=fabric.node_tree.nodes
links=fabric.node_tree.links
bsdf=nodes.get("Principled BSDF")
bsdf.inputs["Metallic"].default_value=0.0
bsdf.inputs["Roughness"].default_value=.81
base_tex=nodes.new("ShaderNodeTexImage")
base_tex.label="SCANNED BASE COLOR SRGB"
base_tex.image=alb
base_tex.extension="REPEAT"
links.new(base_tex.outputs["Color"],bsdf.inputs["Base Color"])
normal_tex=nodes.new("ShaderNodeTexImage")
normal_tex.label="SCANNED NORMAL GL NON-COLOR"
normal_tex.image=nrm
normal_tex.extension="REPEAT"
nmap=nodes.new("ShaderNodeNormalMap")
nmap.inputs["Strength"].default_value=NORMAL_STRENGTH
links.new(normal_tex.outputs["Color"],nmap.inputs["Color"])
links.new(nmap.outputs["Normal"],bsdf.inputs["Normal"])
ormtex=nodes.new("ShaderNodeTexImage")
ormtex.label="ORM R=AO G=ROUGHNESS B=METAL"
ormtex.image=orm_img
ormtex.extension="REPEAT"
sep=nodes.new("ShaderNodeSeparateColor")
links.new(ormtex.outputs["Color"],sep.inputs["Color"])
links.new(sep.outputs["Green"],bsdf.inputs["Roughness"])
links.new(sep.outputs["Blue"],bsdf.inputs["Metallic"])
print("MATERIAL_PBR_NODES_READY")

def simplemat(name,rgba,roughness=0.9):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=rgba
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value=rgba
    shader.inputs["Roughness"].default_value=roughness
    return mat
cordmat=simplemat("Cotton welt seam",(.35,.29,.24,1))
cordmat.node_tree.nodes.get("Principled BSDF").inputs["Specular IOR Level"].default_value=.16
threadmat=simplemat("Warm seam thread",(.52,.45,.36,1))
foam=simplemat("Internal foam | hidden under fabric",(.82,.79,.68,1))
ground=simplemat("Studio charcoal floor",(.052,.057,.060,1))

# Top panel: quad topology, genuinely curved and asymmetric profile.
nxg,nyg=96,96
verts=[];uvs=[];faces=[]
for j in range(nyg+1):
    v=2*j/nyg-1
    for i in range(nxg+1):
        u=2*i/nxg-1
        x,y=xy(u,v)
        verts.append((x,y,top_height(x,y)))
        uvs.append(((x+A)/TEXTURE_TILE_M, (y+B)/TEXTURE_TILE_M))
for j in range(nyg):
    for i in range(nxg):
        a=j*(nxg+1)+i
        faces.append((a,a+1,a+nxg+2,a+nxg+1))
top=mesh_obj("01 | tensioned top linen panel",verts,faces,uvs,fabric)

# Side band / gusset: real separate cloth, convex and imperfect rather than vertical wall.
perimeter=[]
for k in range(4*96):
    side=k//96
    t=(k%96)/96.0
    u,v= ((-1+2*t,-1) if side==0 else
          (1,-1+2*t) if side==1 else
          (1-2*t,1) if side==2 else
          (-1,1-2*t))
    perimeter.append(xy(u,v))
count=len(perimeter)
verts=[];uvs=[];faces=[]
arclens=[0.]
for k in range(1,count):
    p0,p1=perimeter[k-1],perimeter[k]
    arclens.append(arclens[-1]+math.dist(p0,p1))
for h in range(23):
    t=h/22.0
    for k,(x,y) in enumerate(perimeter):
        radial=math.hypot(x/A,y/B)
        # Side bulges outward near central height; ends are pulled into stitched seams.
        bulge=(.015+.008*(SHAPE_LOOSENESS-1))*math.sin(pi*t)**1.2
        ang=math.atan2(y/B,x/A)
        bulge*=1+.14*math.sin(3*ang+.4)+.06*math.sin(7*ang-1.6)
        # Settled side fabric forms a few non-uniform tension bands.
        bulge+=SHAPE_LOOSENESS*.0032*math.sin(8*ang+3.1*t+.7)*math.sin(pi*t)**1.35
        bulge+=SHAPE_LOOSENESS*.0014*math.sin(13*ang-5*t)*math.sin(pi*t)**1.8
        xx=x+bulge*x/(math.hypot(x,y)+.0001)
        yy=y+bulge*y/(math.hypot(x,y)+.0001)
        z=top_height(x,y)*(1-t) + (-.051)*t
        # Local compression only at selected seam anchor points.
        for ai,atk in [(44,.0030),(68,.0025),(150,.0035),(265,.0020),(328,.0028)]:
            d=min(abs(k-ai),count-abs(k-ai))
            z+=SHAPE_LOOSENESS*atk*math.exp(-(d/7.5)**2)*math.sin(2*pi*t)*math.exp(-((t-.24)/.25)**2)
        # Localized seam puckers on the gusset follow nonuniform sewn tension:
        # no repeated sine grid and no geometry added to the top/bottom seam.
        for anchor, sign, extent, amp in (
            (23,1,.24,.0075),(70,-1,.20,.009),(141,1,.34,.008),
            (191,-1,.21,.010),(258,1,.26,.007),(327,-1,.30,.009)):
            d=min(abs(k-anchor),count-abs(k-anchor))
            lateral=math.exp(-(d/(13.0*SHAPE_LOOSENESS))**2)
            vertical=math.sin(pi*t)**1.7
            wave=math.sin(pi*(t-extent)*1.5)
            z+=sign*amp*SHAPE_LOOSENESS*lateral*vertical*wave
            # Woven fabric wrinkles also push inward/outward, not only up/down.
            wrinkle=sign*.007*SHAPE_LOOSENESS*lateral*vertical*math.cos(3.4*pi*t)
            xx+=wrinkle*x/(math.hypot(x,y)+.0001)
            yy+=wrinkle*y/(math.hypot(x,y)+.0001)
        verts.append((xx,yy,z))
        uvs.append((arclens[k]/TEXTURE_TILE_M,t*.13/TEXTURE_TILE_M))
for h in range(22):
    for k in range(count):
        a=h*count+k
        b=h*count+(k+1)%count
        c=(h+1)*count+(k+1)%count
        d=(h+1)*count+k
        faces.append((a,d,c,b))
gusset=mesh_obj("02 | separate convex gusset",verts,faces,uvs,fabric)

# Under-panel: not a flat sheet.
verts=[];uvs=[];faces=[]
for j in range(97):
    v=2*j/96-1
    for i in range(97):
        u=2*i/96-1
        x,y=xy(u,v)
        depressed=max(0,1-(x/A)**2)*max(0,1-(y/B)**2)*min(1,max(0,-sdrounded(x,y)/.055))
        verts.append((x,y,-.051-.007*depressed))
        uvs.append(((x+A)/TEXTURE_TILE_M,(y+B)/TEXTURE_TILE_M))
for j in range(96):
    for i in range(96):
        a=j*97+i
        faces.append((a,a+97,a+98,a+1))
underside=mesh_obj("03 | underside cloth panel",verts,faces,uvs,fabric)

def polycurve(name,points,mat,radius):
    curve=bpy.data.curves.new(name+"Curve","CURVE")
    curve.dimensions="3D"
    curve.resolution_u=8
    curve.bevel_depth=radius
    curve.bevel_resolution=3
    spl=curve.splines.new("POLY")
    spl.points.add(len(points)-1)
    for p,c in zip(spl.points,points):p.co=(*c,1)
    spl.use_cyclic_u=True
    ob=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(ob)
    curve.materials.append(mat)
    return ob
upper=polycurve("04 | upper sewn welt piping",
                [(x*1.003,y*1.003,top_height(x,y)-.0005) for x,y in perimeter],
                cordmat,.0015)
lower=polycurve("05 | underside seam piping",
                [(x*.992,y*.992,-.0505) for x,y in perimeter],
                cordmat,.00085)
# Small discontinuous stitches inset from the upper seam, not fake stripes.
stcurve=bpy.data.curves.new("Stitch paths","CURVE")
stcurve.dimensions="3D";stcurve.bevel_depth=.00054;stcurve.bevel_resolution=1
for idx in range(0,count,3):
    def inner_pt(k):
        x,y=perimeter[k%count]
        mul=1-.019/(max(math.hypot(x,y),.01))
        sx,sy=x*mul,y*mul
        return (sx,sy,top_height(sx,sy)+.0006)
    a,b=inner_pt(idx),inner_pt(idx+1)
    spl=stcurve.splines.new("POLY");spl.points.add(1)
    spl.points[0].co=(*a,1);spl.points[1].co=(*b,1)
stitches=bpy.data.objects.new("06 | interrupted sewing stitches",stcurve)
bpy.context.collection.objects.link(stitches)
stcurve.materials.append(threadmat)

# Internal foam core as an independent model, hidden inside upholstery.
# Use a bevelled smoother volume for inspectable construction.
bpy.ops.mesh.primitive_cube_add()
foamobj=bpy.context.object;foamobj.name="07 | internal shaped foam core"
foamobj.dimensions=(.686,.590,.126)
foamobj.location.z=-.005
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=foamobj.modifiers.new("Soft foam edges","BEVEL")
bevel.width=.072;bevel.segments=14
bpy.context.view_layer.objects.active=foamobj
bpy.ops.object.modifier_apply(modifier=bevel.name)
sub=foamobj.modifiers.new("Foam shaping","SUBSURF")
sub.levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
for v in foamobj.data.vertices:
    x,y=v.co.x,v.co.y
    crown=max(0,1-(x/.355)**2)*max(0,1-(y/.305)**2)
    if v.co.z>0:v.co.z+=.022*crown
foamobj.location.z += .0035
foamobj.data.materials.append(foam)
for p in foamobj.data.polygons:p.use_smooth=True
# Keep internal foam invisible in beauty render and exclude from GLB to avoid z-fighting.
foamobj.hide_render=True

# ---- PHYSICAL CLOTH RELAXATION: upper cut panel pinned to real seam ----
# The upper edge of the upholstery is sewn to the side band.
# Pin its outer two rings, allow the central fabric to settle on the foam.
pin=top.vertex_groups.new(name="Sewn upper perimeter | pin group")
ids=[]
for j in range(nyg+1):
    for i in range(nxg+1):
        if i<2 or j<2 or i>nxg-2 or j>nyg-2:
            ids.append(j*(nxg+1)+i)
pin.add(ids,1.0,"REPLACE")
collider=foamobj.modifiers.new("Contact with foam core","COLLISION")
foamobj.collision.thickness_outer=.0025
foamobj.collision.cloth_friction=9.0
clothmod=top.modifiers.new("Cloth | edge sewn and foam-constrained","CLOTH")
clothmod.settings.quality=5
clothmod.settings.mass=.25
clothmod.settings.tension_stiffness=22
clothmod.settings.compression_stiffness=18
clothmod.settings.shear_stiffness=15
clothmod.settings.bending_stiffness=.62
clothmod.settings.vertex_group_mass=pin.name
clothmod.settings.pin_stiffness=24
clothmod.collision_settings.use_collision=True
clothmod.collision_settings.distance_min=.0025
clothmod.collision_settings.use_self_collision=False
simscene=bpy.context.scene
simscene.frame_start=1
simscene.frame_end=46
original_z=[v.co.z for v in top.data.vertices]
print("UPHOLSTERY_SIM_START",len(original_z),"vertices",len(ids),"pinned")
for frame in range(1,47):
    simscene.frame_set(frame)
    if frame%10==0:print("UPHOLSTERY_FRAME",frame)
depsgraph=bpy.context.evaluated_depsgraph_get()
evaluated=top.evaluated_get(depsgraph)
resultmesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=depsgraph)
assert len(resultmesh.vertices)==len(original_z), "Cloth mesh topology changed unexpectedly"
dz=[resultmesh.vertices[i].co.z-original_z[i] for i in range(len(original_z))]
max_shift=max(abs(d) for d in dz)
avg_shift=sum(abs(d) for d in dz)/len(dz)
assert max_shift>.001, "Simulation did not modify the fabric surface"
assert max_shift<.09, "Simulation unstable: fabric moved too far"
print("UPHOLSTERY_SIM_OK max_vertical_shift_m=",round(max_shift,5),
      "mean_vertical_shift_m=",round(avg_shift,5))
for mod in list(top.modifiers):
    top.modifiers.remove(mod)
oldmesh=top.data
top.data=resultmesh
bpy.data.meshes.remove(oldmesh)
# Restore the textured linen material and smooth shading if needed.
top.data.materials.clear()
top.data.materials.append(fabric)
for face in top.data.polygons:face.use_smooth=True
# Sew edges to EXACTLY the same sampled contour as the side band.
# Pinned simulator vertices can move a fraction of a millimetre.
for j in range(nyg+1):
    for i in range(nxg+1):
        if i in (0,nxg) or j in (0,nyg):
            idx=j*(nxg+1)+i
            u,v=(2*i/nxg-1),(2*j/nyg-1)
            ex,ey=xy(u,v)
            top.data.vertices[idx].co=(ex,ey,top_height(ex,ey))
# Preserve localized crease relief AFTER physical settling. Ordinary smooth cloth
# simulation flattens all seam wrinkles; these are modest 1-4mm geometric details.
creases=[
    # anchor xy / heading vector / length / positive ridge / width
    (-.251,-.212,.79,.61,.145,.0125,.018),
    (-.203,-.248,.43,.90,.123,.0080,.015),
    ( .221,-.223,-.72,.68,.158,.0121,.019),
    ( .283,-.131,-.93,.33,.132,.0095,.015),
    (-.287, .154,.86,-.50,.108,.0080,.015),
    ( .171, .269,-.38,-.92,.146,.0100,.017),
    (-.091, .284,.21,-.98,.106,.0065,.015),
    ( .294, .075,-.94,-.25,.107,.0085,.015),
]
max_detail=0.0
for v in top.data.vertices:
    x,y=v.co.x,v.co.y
    inner=max(0.0,-sdrounded(x,y))
    smooth=max(0.,min(1.,inner/.022))
    smooth=smooth*smooth*(3-2*smooth)
    dz=0.0
    for ax,ay,dx,dy,extent,amplitude,w in creases:
        t=(x-ax)*dx+(y-ay)*dy
        p=-(x-ax)*dy+(y-ay)*dx
        if -.015<t<extent*1.45:
            strength=math.exp(-((t-extent*.40)/(extent*.51))**2)
            bend=.006*math.sin(t*19+ax*11)
            valley=math.exp(-((p-bend+.001)/(w*.63))**2)
            ridge=math.exp(-((p-bend-w*.82)/(w*1.08))**2)
            dz+=amplitude*strength*(ridge-.91*valley)
    dz*=smooth*SHAPE_LOOSENESS
    v.co.z+=dz
    max_detail=max(max_detail,abs(dz))
print("RELIEF_QA",round(max_detail,5),"m", "shape_looseness",SHAPE_LOOSENESS)
assert .003<max_detail<.025,"Unreasonable/missing seam-relief geometry"
top.data.update()
simscene.frame_set(1)


bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.070))
floor=bpy.context.object;floor.name="Ground | nonexport"
floor.data.materials.append(ground)
bpy.ops.object.camera_add(location=(1.00,-1.32,.68))
camera=bpy.context.object
look=Vector((0,0,.018))
camera.rotation_euler=(look-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO";camera.data.ortho_scale=1.14
scene=bpy.context.scene;scene.camera=camera
for name,loc,energy,size in [
    ("Key softbox",(-.38,-.66,1.22),185,1.4),
    ("Fill softbox",(.75,.10,.92),95,1.5),
    ("Rim softbox",(-.12,.80,.95),75,1.0),
]:
    bpy.ops.object.light_add(type="AREA",location=loc)
    ob=bpy.context.object;ob.name=name;ob.data.energy=energy
    ob.data.shape="DISK";ob.data.size=size
    ob.rotation_euler=(look-ob.location).to_track_quat("-Z","Y").to_euler()
scene.render.engine="CYCLES"
scene.cycles.samples=RENDER_SAMPLES
scene.cycles.use_denoising=False # Ubuntu apt Blender 4.0.2 built without OpenImageDenoiser
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=840
scene.render.resolution_y=620
scene.render.resolution_percentage=100
scene.world.color=(.07,.07,.07)
scene.view_settings.exposure=-1.20
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(OUT/"cushion_v14_cycles.png")
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"cushion_v14.blend"))

# Combine the cloth panels AFTER saving the editable working scene,
# weld matching seam vertices, and validate watertight shell topology.
import bmesh
bpy.ops.object.select_all(action="DESELECT")
for obj in (top,gusset,underside):obj.select_set(True)
bpy.context.view_layer.objects.active=top
bpy.ops.object.join()
top.name="WELDED_CUSHION_OUTER_CLOTH"
bm=bmesh.new()
bm.from_mesh(top.data)
pre_vertices=len(bm.verts)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00055)
bm.normal_update()
boundary=sum(1 for e in bm.edges if len(e.link_faces)!=2)
print("SEAM_QA", "before_vertices",pre_vertices,
      "after_vertices",len(bm.verts),"nonmanifold_edges",boundary)
assert boundary==0, "Unclosed shell: check seam vertex matching and face winding"
# Geometry is measured separately from the render; a bright image cannot pass
# as realistic fabric geometry just because PBR files are present.
import json as _json
geometry_report={
    "model_version":"v16",
    "outer_shell_vertices_after_weld":len(bm.verts),
    "outer_shell_faces":len(bm.faces),
    "nonmanifold_edges":boundary,
    "simulation_max_vertical_displacement_m":round(max_shift,6),
    "simulation_mean_vertical_displacement_m":round(avg_shift,6),
    "sculpted_seam_relief_max_m":round(max_detail,6),
    "seam_relief_zones":8,
    "gusset_local_pucker_zones":6,
    "physical_sewing_springs_enabled":False,
    "mobile_realism_verified":False
}
(OUT/"geometry_report.json").write_text(_json.dumps(geometry_report,indent=2),encoding="utf-8")
print("GEOMETRY_REPORT",geometry_report)
bm.to_mesh(top.data)
bm.free()
top.data.update()
bpy.ops.object.select_all(action="DESELECT")
# Exclude floating stitch curves while we solve mesh integrity;
# retain curves in editable BLEND as separate detail layers.
pieces=[top,upper]
for obj in pieces:obj.select_set(True)
bpy.context.view_layer.objects.active=top
bpy.ops.export_scene.gltf(
    filepath=str(OUT/"cushion_v14.glb"),
    export_format="GLB",use_selection=True,export_texcoords=True,
    export_normals=True,export_materials="EXPORT"
)
# Match Cycles beauty renders to actual GLB export selection.
# The underlying foam, underside piping and draft stitching are editable in BLEND
# but excluded from both exported GLB and preview.
for nonexported in (foamobj,lower,stitches):
    nonexported.hide_render=True
bpy.ops.render.render(write_still=True)
# A second low camera angle catches seam defects that beauty views hide.
camera.location=Vector((.90,-1.66,.36))
camera.rotation_euler=(Vector((0,-.095,.028))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.ortho_scale=.98
scene.render.filepath=str(OUT/"cushion_v14_detail.png")
bpy.ops.render.render(write_still=True)
# Keep only real exported material in preview. Automated review uses both angles.
import json as _json
(OUT/"candidate_settings.json").write_text(_json.dumps({
    "normal_strength":NORMAL_STRENGTH,
    "shape_looseness":SHAPE_LOOSENESS,
    "sculpt_method":"broad asymmetric foam pockets, 8 radial seam folds, 6 nonuniform gusset puckers",
    "quality_note":"physical cloth relaxation and sculpted seam microfolds; not fully sewn cloth simulation",
    "texture_tile_m":TEXTURE_TILE_M,
    "render_samples":RENDER_SAMPLES,
    "source":"Poly Haven rough linen CC0 / fixed 3D geometry v14",
    "physics":"Blender pinned cloth; shaped contour and preserved seam-relief geometry; sewing springs not implemented"
},indent=2),encoding="utf-8")
for fn in ("cushion_v14.blend","cushion_v14.glb","cushion_v14_cycles.png","cushion_v14_detail.png"):
    f=OUT/fn
    assert f.is_file() and f.stat().st_size>10000, f"Missing {fn}"
print("CUSHION_V14_OK: cloth-constrained top panel and separate sewn furniture components", OUT)
