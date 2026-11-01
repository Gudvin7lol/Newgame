"""Experimental actual pattern-to-pattern cloth sewing (Blender 4.x).

Unlike earlier upholstery studies, top, gusset and underside begin as three
*disconnected* fabric panels. Bare edges (not part of any face) explicitly
connect corresponding seam vertices; Blender Cloth sewing springs pull panels
together during simulation. A separate foam collision body supports the cloth.
We close remaining sub-mm seams only AFTER physics, for a watertight GLB.
This is a controlled experimental prototype, NOT a production sewing solver.
"""
import bpy, math, os, json, bmesh
from pathlib import Path
from math import sin,cos,pi,exp
from mathutils import Vector
OUT=Path(os.environ.get("BLENDER_OUT","out/sewn")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
SCAN=OUT/"scan_v13"
SHAPE=float(os.environ.get("SEW_SLACK","1.0"))
FRAMES=int(os.environ.get("SEW_FRAMES","40"))
assert .7<=SHAPE<=1.45
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
N=48
A,B,R=.355,.305,.092
def sdrounded(x,y):
    qx,qy=abs(x)-(A-R),abs(y)-(B-R)
    return math.hypot(max(qx,0),max(qy,0))+min(max(qx,qy),0)-R
def xy(u,v):
    m=max(abs(u),abs(v))
    if m<1e-7: return 0.,0.
    ux,vy=u/m,v/m
    lo,hi=0.,1.
    for _ in range(17):
        mid=(lo+hi)*.5
        if sdrounded(A*ux*mid,B*vy*mid)>0:hi=mid
        else:lo=mid
    radial=(lo+hi)*.5
    x,y=A*u*radial,B*v*radial
    a=math.atan2(y/B,x/A)
    offset=.0022*(sin(3*a+.3)+.4*sin(7*a+.15))
    return x+offset*x/(math.hypot(x,y)+.001),y+offset*y/(math.hypot(x,y)+.001)
def topz(x,y):
    crown=(max(0,1-(abs(x)/A)**2.8)*max(0,1-(abs(y)/B)**2.8))**1.15
    # The top is pre-shaped and then physically settled over the foam core.
    return .055+.038*crown + .004*exp(-((x+.15)/.14)**2-((y-.05)/.18)**2)

texfiles=(("linen_scan_beige_basecolor.png",False),("linen_scan_normal_gl.png",True),("linen_scan_orm.png",True))
imgs=[]
for name,ncol in texfiles:
    f=SCAN/name
    assert f.is_file(),f"Missing downloaded scan {f}"
    im=bpy.data.images.load(str(f),check_existing=False)
    if ncol:im.colorspace_settings.name="Non-Color"
    im.pack()
    imgs.append(im)
mat=bpy.data.materials.new("Scanned linen | real sewn pattern PBR")
mat.use_nodes=True
nd=mat.node_tree.nodes;ln=mat.node_tree.links;p=nd.get("Principled BSDF")
p.inputs["Metallic"].default_value=0
p.inputs["Roughness"].default_value=.82
alb=nd.new("ShaderNodeTexImage");alb.image=imgs[0];ln.new(alb.outputs["Color"],p.inputs["Base Color"])
norm=nd.new("ShaderNodeTexImage");norm.image=imgs[1]
nm=nd.new("ShaderNodeNormalMap");nm.inputs["Strength"].default_value=.80
ln.new(norm.outputs["Color"],nm.inputs["Color"]);ln.new(nm.outputs["Normal"],p.inputs["Normal"])
orm=nd.new("ShaderNodeTexImage");orm.image=imgs[2]
sep=nd.new("ShaderNodeSeparateColor");ln.new(orm.outputs["Color"],sep.inputs["Color"])
ln.new(sep.outputs["Green"],p.inputs["Roughness"]);ln.new(sep.outputs["Blue"],p.inputs["Metallic"])

V=[]; UV=[]; F=[]; E=[];groups={}
def addv(co,uv):
    idx=len(V);V.append(co);UV.append(uv);return idx
top=[]
for j in range(N+1):
    row=[]
    for i in range(N+1):
        x,y=xy(2*i/N-1,2*j/N-1)
        row.append(addv((x,y,topz(x,y)),((x+A)/.23,(y+B)/.23)))
    top.append(row)
for j in range(N):
    for i in range(N):
        F.append((top[j][i],top[j][i+1],top[j+1][i+1],top[j+1][i]))
ringidx=[];ringxy=[]
# CCW path from bottom-left along bottom, then right, top, left.
for k in range(N):ringidx.append(top[0][k]);ringxy.append((2*k/N-1,-1))
for k in range(N):ringidx.append(top[k][N]);ringxy.append((1,2*k/N-1))
for k in range(N):ringidx.append(top[N][N-k]);ringxy.append((1-2*k/N,1))
for k in range(N):ringidx.append(top[N-k][0]);ringxy.append((-1,1-2*k/N))
assert len(ringidx)==4*N and len(set(ringidx))==4*N
count=len(ringidx);arc=[0.]
for k in range(1,count):
    q0=V[ringidx[k-1]];q1=V[ringidx[k]]
    arc.append(arc[-1]+math.dist(q0[:2],q1[:2]))
siderows=[]
for h in range(17):
    t=h/16
    row=[]
    for k,(u,v) in enumerate(ringxy):
        x,y=xy(u,v)
        a=math.atan2(y/B,x/A)
        # 3D fabric allowance: slightly overcut side perimeter and bunched folds.
        rad=(.0024*(1-t)+.0010*t)+.010*SHAPE*sin(pi*t)**1.15
        rad+=.0026*SHAPE*sin(5*a+1.7*t)*sin(pi*t)**1.6
        # Irregular gathers from asymmetric sewing tension.
        for anchor,amp in ((19,.010),(57,-.008),(110,.012),(166,-.009)):
            distance=min(abs(k-anchor),count-abs(k-anchor))
            rad+=amp*SHAPE*exp(-(distance/9)**2)*sin(pi*t)**2
        rr=math.hypot(x,y)+1.e-5
        xx=x+x/rr*rad; yy=y+y/rr*rad
        z=topz(x,y)*(1-t)-.052*t
        z+=SHAPE*.006*sin(3.7*a+5.2*t)*sin(pi*t)**2
        row.append(addv((xx,yy,z),(arc[k]/.23,.118*t/.23)))
    siderows.append(row)
for h in range(16):
    for k in range(count):
        m=(k+1)%count
        F.append((siderows[h][k],siderows[h+1][k],siderows[h+1][m],siderows[h][m]))
bottom=[]
for j in range(N+1):
    row=[]
    for i in range(N+1):
        x,y=xy(2*i/N-1,2*j/N-1)
        z=-.052-.006*max(0,1-(x/A)**2)*max(0,1-(y/B)**2)
        row.append(addv((x,y,z),((x+A)/.23,(y+B)/.23)))
    bottom.append(row)
for j in range(N):
    for i in range(N):
        F.append((bottom[j][i],bottom[j+1][i],bottom[j+1][i+1],bottom[j][i+1]))
bottomring=[]
for k in range(N):bottomring.append(bottom[0][k])
for k in range(N):bottomring.append(bottom[k][N])
for k in range(N):bottomring.append(bottom[N][N-k])
for k in range(N):bottomring.append(bottom[N-k][0])
assert len(bottomring)==count
# Each unattached edge is an explicit SEWING SPRING, not a manually pinned weld.
for k in range(count):
    E.append((ringidx[k],siderows[0][k]))
    E.append((bottomring[k],siderows[-1][k]))
print("SEWING_PATTERNS",len(V),"vertices",len(F),"faces",len(E),"loose sewing edges")
mesh=bpy.data.meshes.new("Three disjoint pattern panels with loose seam springs")
mesh.from_pydata(V,E,F);mesh.update()
cloth=bpy.data.objects.new("Sewn cushion | cloth physics",mesh)
bpy.context.collection.objects.link(cloth)
uvmap=mesh.uv_layers.new(name="Physical panel UV")
for poly in mesh.polygons:
    for loop in poly.loop_indices:
        uvmap.data[loop].uv=UV[mesh.loops[loop].vertex_index]
mesh.materials.append(mat)
for pol in mesh.polygons:pol.use_smooth=True
pinned=cloth.vertex_groups.new(name="Stationary underside")
bottom_vertices=[index for row in bottom for index in row]
pinned.add(bottom_vertices,1.0,"REPLACE")
# Sofa-sized 3D foam collision shape, independent from the fabric.
bpy.ops.mesh.primitive_cube_add(location=(0,0,-.004))
foam=bpy.context.object;foam.name="Core foam | support collision"
foam.dimensions=(.662,.556,.105)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bev=foam.modifiers.new("soft","BEVEL");bev.width=.063;bev.segments=7
bpy.context.view_layer.objects.active=foam;bpy.ops.object.modifier_apply(modifier=bev.name)
coll=foam.modifiers.new("foam collision","COLLISION")
foam.collision.thickness_outer=.002
foam.collision.cloth_friction=10
foam.hide_render=True
bpy.context.view_layer.objects.active=cloth
cm=cloth.modifiers.new("REAL CLOTH SEWING SPRINGS","CLOTH")
cm.settings.quality=5;cm.settings.mass=.25
cm.settings.tension_stiffness=14;cm.settings.compression_stiffness=10
cm.settings.shear_stiffness=9;cm.settings.bending_stiffness=.35
cm.settings.vertex_group_mass=pinned.name
cm.settings.pin_stiffness=20
assert hasattr(cm.settings,"use_sewing_springs")
cm.settings.use_sewing_springs=True
if hasattr(cm.settings,"sewing_force_max"):
    cm.settings.sewing_force_max=12.0
cm.collision_settings.use_collision=True
cm.collision_settings.distance_min=.002
cm.collision_settings.use_self_collision=False
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=FRAMES
initial=[v.co.copy() for v in cloth.data.vertices]
for frame in range(1,FRAMES+1):
    scene.frame_set(frame)
    if frame%10==0:print("SEWING_FRAME",frame,flush=True)
deps=bpy.context.evaluated_depsgraph_get()
ev=cloth.evaluated_get(deps)
newmesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps)
assert len(newmesh.vertices)==len(initial)
max_shift=max((newmesh.vertices[i].co-initial[i]).length for i in range(len(initial)))
print("SIM_DISPLACEMENT",round(max_shift,5),flush=True)
assert .0001<max_shift<.14,"Sewing physics did not converge"
# Measure seam gap from actual simulated vertices before making the exported GLB.
gaps=[]
for k in range(count):
    gaps.append((newmesh.vertices[ringidx[k]].co-newmesh.vertices[siderows[0][k]].co).length)
    gaps.append((newmesh.vertices[bottomring[k]].co-newmesh.vertices[siderows[-1][k]].co).length)
mean_gap=sum(gaps)/len(gaps)
max_gap=max(gaps)
print("ACTUAL_SEWING_GAP_M",mean_gap,max_gap,flush=True)
# Model data is saved prior to geometric cleanup so seams can be examined.
cloth.modifiers.clear()
old=cloth.data;cloth.data=newmesh;bpy.data.meshes.remove(old)
cloth.data.materials.clear();cloth.data.materials.append(mat)
for f in cloth.data.polygons:f.use_smooth=True
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"real_sewn_cloth.blend"))
# Snap corresponding seam pairs only after physics to form a renderable closed shell.
for k in range(count):
    for a,b in ((ringidx[k],siderows[0][k]),(bottomring[k],siderows[-1][k])):
        p=(cloth.data.vertices[a].co+cloth.data.vertices[b].co)*.5
        cloth.data.vertices[a].co=p
        cloth.data.vertices[b].co=p
bm=bmesh.new();bm.from_mesh(cloth.data)
# Remove loose spring edges (they exist for physics only, not final GLB).
loose=[e for e in bm.edges if len(e.link_faces)==0]
bmesh.ops.delete(bm,geom=loose,context="EDGES")
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00035)
bm.normal_update()
nonmanifold=sum(1 for e in bm.edges if len(e.link_faces)!=2)
print("SEWN_SHELL_QA",len(bm.verts),len(bm.faces),nonmanifold,flush=True)
assert nonmanifold==0,"Sewn export is not closed"
bm.to_mesh(cloth.data);bm.free();cloth.data.update()
for face in cloth.data.polygons:face.use_smooth=True
# Add fabric-colored piping at the new physically simulated upper seam.
seammat=bpy.data.materials.new("Matching cotton piping")
seammat.diffuse_color=(.43,.37,.31,1)
seammat.use_nodes=True
p=seammat.node_tree.nodes.get("Principled BSDF")
p.inputs["Base Color"].default_value=(.43,.37,.31,1)
p.inputs["Roughness"].default_value=.92
curve=bpy.data.curves.new("Sewn edge welt","CURVE")
curve.dimensions="3D";curve.bevel_depth=.0011;curve.bevel_resolution=3
spline=curve.splines.new("POLY");spline.points.add(count-1)
for k,index in enumerate(ringidx):
    v=newmesh.vertices[index].co
    spline.points[k].co=(v.x*1.003,v.y*1.003,v.z+.0004,1)
spline.use_cyclic_u=True
welt=bpy.data.objects.new("Cloth wrapped piping","CURVE" if False else curve)
bpy.context.collection.objects.link(welt)
curve.materials.append(seammat)
# Studio lighting: strong lateral grazing light exposes the textile silhouette.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.071))
ground=bpy.context.object
gmat=bpy.data.materials.new("Neutral gray floor")
gmat.diffuse_color=(.12,.12,.12,1);ground.data.materials.append(gmat)
bpy.ops.object.camera_add(location=(1.00,-1.40,.75))
camera=bpy.context.object
look=Vector((0,0,.012))
camera.rotation_euler=(look-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO";camera.data.ortho_scale=1.18
scene.camera=camera
for name,loc,energy,size in (
    ("Lateral weave light",(-.3,-.70,.96),120,1.0),
    ("soft ambient",(.9,.1,1.5),65,1.6),
    ("back rim",(-.7,.7,.55),75,.95)):
    bpy.ops.object.light_add(type="AREA",location=loc)
    light=bpy.context.object;light.name=name;light.data.energy=energy
    light.data.shape="DISK";light.data.size=size
    light.rotation_euler=(look-light.location).to_track_quat("-Z","Y").to_euler()
scene.render.engine="CYCLES";scene.cycles.samples=48
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=980;scene.render.resolution_y=690
scene.view_settings.exposure=-1.6
scene.render.image_settings.file_format="PNG"
# Export BEFORE rendering; only sewn shell + real piping.
bpy.ops.object.select_all(action="DESELECT")
cloth.select_set(True);welt.select_set(True)
bpy.context.view_layer.objects.active=cloth
bpy.ops.export_scene.gltf(filepath=str(OUT/"real_sewn_cloth.glb"),
    export_format="GLB",use_selection=True,export_texcoords=True,
    export_normals=True,export_materials="EXPORT")
scene.render.filepath=str(OUT/"real_sewn_cloth.png")
bpy.ops.render.render(write_still=True)
report={
    "simulation":"Cloth with use_sewing_springs True: disconnected pattern pieces",
    "sewing_force_max":getattr(cm.settings,"sewing_force_max",None),
    "simulated_displacement_m":round(max_shift,6),
    "seam_gap_before_snap_mean_m":round(mean_gap,6),
    "seam_gap_before_snap_max_m":round(max_gap,6),
    "seam_snap_postprocess_used":True,
    "seam_loose_edges":len(E),
    "final_nonmanifold_edges":nonmanifold,
    "mobile_visual_tested":False
}
(OUT/"sewing_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("REAL_SEWING_COMPLETE",report,flush=True)
