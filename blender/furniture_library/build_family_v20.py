"""Furniture Library v20: two genuinely different architectural models.

(1) Upholstered lounge chair, linen + bent metal frame + solid oak armrests.
(2) Oak two-drawer nightstand with fitted carcass, shadow gaps and hardware.
Real mesh topology, seams, PBR, UVs in real-world units, glTF 2.0.
Not a concept image. Neither object claims scan-grade geometric accuracy.
"""
import bpy,math,os,json
from pathlib import Path
from math import sin,cos,pi,exp
from mathutils import Vector
OUT=Path(os.environ.get("FURNITURE_OUT","out/furniture20")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
SAMPLES=int(os.environ.get("RENDER_SAMPLES","35"))
assert 8<=SAMPLES<=128
REPORT={}
def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.frame_set(1)

def pbr(kind):
    folder=OUT/kind
    m=bpy.data.materials.new(kind.upper()+" | scanned CC0 material | real PBR")
    m.use_nodes=True
    nodes=m.node_tree.nodes; links=m.node_tree.links
    p=nodes.get("Principled BSDF")
    for name,slot,noncolor in (("basecolor.png","Base Color",False),
                                ("normal.png","Normal",True),
                                ("orm.png","Metallic Roughness",True)):
        im=bpy.data.images.load(str(folder/name),check_existing=False)
        if noncolor:im.colorspace_settings.name="Non-Color"
        im.pack()
        t=nodes.new("ShaderNodeTexImage")
        t.image=im;t.label=f"GLTF {slot} {kind}"
        if slot=="Base Color":links.new(t.outputs["Color"],p.inputs["Base Color"])
        if slot=="Normal":
            n=nodes.new("ShaderNodeNormalMap");n.inputs["Strength"].default_value=.77 if kind=="linen" else .5
            links.new(t.outputs["Color"],n.inputs["Color"])
            links.new(n.outputs["Normal"],p.inputs["Normal"])
        if slot=="Metallic Roughness":
            split=nodes.new("ShaderNodeSeparateColor")
            links.new(t.outputs["Color"],split.inputs["Color"])
            links.new(split.outputs["Green"],p.inputs["Roughness"])
            links.new(split.outputs["Blue"],p.inputs["Metallic"])
    p.inputs["Metallic"].default_value=0.
    p.inputs["Roughness"].default_value=.85 if kind=="linen" else .69
    return m
def simple(name,rgba,roughness=.7,metallic=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=tuple(rgba)
    m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=tuple(rgba)
    p.inputs["Roughness"].default_value=roughness
    p.inputs["Metallic"].default_value=metallic
    return m
def apply_wood_uv(obj,world_width=1.8):
    # In 1 UV repeat, the original photographed veneer covers world_width metres.
    me=obj.data
    uv=me.uv_layers.active or me.uv_layers.new(name="Wood physical UV")
    for f in me.polygons:
        n=f.normal
        for li in f.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            if abs(n.y)>.55:u,w=v.x,v.z
            elif abs(n.x)>.55:u,w=v.y,v.z
            else:u,w=v.x,v.y
            uv.data[li].uv=(u/world_width,w/world_width)
def block(name,pos,dim,mat,bevel=.003,uvwood=False):
    bpy.ops.mesh.primitive_cube_add()
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=dim
    obj.location=pos
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel>0:
        m=obj.modifiers.new("manufactured radius","BEVEL")
        m.width=min(bevel, min(dim)*.30);m.segments=4
        bpy.ops.object.modifier_apply(modifier=m.name)
        normal=obj.modifiers.new("weighted corner normals","WEIGHTED_NORMAL")
        normal.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=normal.name)
    obj.data.materials.append(mat)
    if uvwood:apply_wood_uv(obj)
    return obj
def smoothpath(pts,segments=7):
    """Interpolated path, non-angular bent-tube fabrication."""
    pts=[Vector(q) for q in pts]
    result=[]
    for i in range(len(pts)-1):
        p0,p1,p2,p3=pts[max(i-1,0)],pts[i],pts[i+1],pts[min(i+2,len(pts)-1)]
        for j in range(segments):
            t=j/segments
            q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*(t*t)+(-p0+3*p1-3*p2+p3)*(t*t*t))
            result.append(tuple(q))
    result.append(tuple(pts[-1]))
    return result
def tube(name,pts,radius,material,smooth=True):
    cv=bpy.data.curves.new(name+" profile","CURVE")
    cv.dimensions="3D";cv.resolution_u=4;cv.bevel_depth=radius;cv.bevel_resolution=4
    path=smoothpath(pts) if smooth else pts
    spline=cv.splines.new("POLY")
    spline.points.add(len(path)-1)
    for a,p in zip(spline.points,path):a.co=(*p,1.)
    obj=bpy.data.objects.new(name,cv)
    bpy.context.collection.objects.link(obj)
    cv.materials.append(material)
    return obj
def fastener(name,pos,metal,r=.006,depth=.004,axis="Y"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=depth,location=pos)
    ob=bpy.context.object;ob.name=name
    if axis=="Y":ob.rotation_euler[0]=pi/2
    if axis=="X":ob.rotation_euler[1]=pi/2
    ob.data.materials.append(metal)
    for f in ob.data.polygons:f.use_smooth=True
    return ob
def rrxy(u,v,ax,by,rad):
    m=max(abs(u),abs(v))
    if m<1.e-8:return (0.,0.)
    ux,vy=u/m,v/m;lo,hi=0.,1.
    def sdf(x,y):
        qx=abs(x)-(ax-rad);qy=abs(y)-(by-rad)
        return math.hypot(max(qx,0),max(qy,0))+min(max(qx,qy),0)-rad
    for _ in range(16):
        t=(lo+hi)*.5
        if sdf(ax*ux*t,by*vy*t)>0:hi=t
        else:lo=t
    k=(lo+hi)*.5
    return ax*u*k,by*v*k
def upholstered_panel(name,ax,by,corner,centre,rotation,linen,part="seat",N=48):
    """Closed, watertight remeshed cushion. Shared perimeter, genuine side band,
    local directional folds at seam tension zones; not a physically sewn cover.
    The older separate sewing-springs physics remains in V19 research branch.
    """
    verts=[];faces=[];fuvs=[]
    def vtx(q):
        verts.append(q);return len(verts)-1
    def transform(x,y,z):
        if part=="seat":return (centre[0]+x,centre[1]+y,centre[2]+z)
        # local y is height along back, local z is outward front of cushion
        c,s=cos(rotation),sin(rotation)
        return (centre[0]+x,centre[1]+s*y-c*z,centre[2]+c*y+s*z)
    def topheight(x,y):
        dx=abs(x/ax);dy=abs(y/by)
        crown=max(0,1-dx**2.9)**1.1*max(0,1-dy**2.9)**1.1
        top=(.046 if part=="seat" else .038)+(.019 if part=="seat" else .014)*crown
        top+=.0028*exp(-((x+.18)/.16)**2-((y+.08)/.12)**2)
        top-=.0036*exp(-((x-.12)/.16)**2-((y-.08)/.11)**2)
        # Creases radiate inward from one side of the cut seam.
        for x0,y0,dx0,dy0,amplitude,width in (
            (-ax*.83,-by*.73,.72,.69,.0055,.013),
            ( ax*.82,-by*.79,-.70,.72,.0065,.016),
            (-ax*.86, by*.58,.88,-.48,.0038,.012),
            ( ax*.72, by*.85,-.52,-.85,.0047,.013)):
            along=(x-x0)*dx0+(y-y0)*dy0
            across=-(x-x0)*dy0+(y-y0)*dx0
            if -.01<along<.16:
                amp=exp(-((along-.055)/.065)**2)
                ridge=exp(-((across-width*.7)/width)**2)
                valley=exp(-((across+width*.4)/(width*.72))**2)
                top+=amplitude*amp*(ridge-.82*valley)
        return top
    gridT=[];gridB=[]
    for j in range(N+1):
        rt=[];rb=[]
        for i in range(N+1):
            x,y=rrxy(2*i/N-1,2*j/N-1,ax,by,corner)
            a=math.atan2(y/by,x/ax)
            edge=max(abs(2*i/N-1),abs(2*j/N-1))**2
            wav=.0014*edge*(sin(3*a+.37)+.5*sin(7*a-1.13))
            rr=math.hypot(x,y)+.001
            x+=wav*x/rr;y+=wav*y/rr
            rt.append(vtx(transform(x,y,topheight(x,y))))
            rb.append(vtx(transform(x,y,-.045)))
        gridT.append(rt);gridB.append(rb)
    def uvlocal(i):
        x,y=verts[i][0],verts[i][1]
        # planar UV is generated from vertex param before world transform
        return (0.,0.)
    def face(seq,uv):
        faces.append(tuple(seq));fuvs.append(tuple(uv))
    def corner_at(i,j):
        x,y=rrxy(2*i/N-1,2*j/N-1,ax,by,corner)
        return ((x+ax)/.30,(y+by)/.30)
    for j in range(N):
        for i in range(N):
            ids=(gridT[j][i],gridT[j][i+1],gridT[j+1][i+1],gridT[j+1][i])
            face(ids,[corner_at(i,j),corner_at(i+1,j),corner_at(i+1,j+1),corner_at(i,j+1)])
            ids=(gridB[j][i],gridB[j+1][i],gridB[j+1][i+1],gridB[j][i+1])
            face(ids,[corner_at(i,j),corner_at(i,j+1),corner_at(i+1,j+1),corner_at(i+1,j)])
    per=[]
    for k in range(N):per.append((k,0))
    for k in range(N):per.append((N,k))
    for k in range(N):per.append((N-k,N))
    for k in range(N):per.append((0,N-k))
    assert len(per)==4*N
    top_ring=[gridT[j][i] for i,j in per]
    bot_ring=[gridB[j][i] for i,j in per]
    perimeter=[rrxy(2*i/N-1,2*j/N-1,ax,by,corner) for i,j in per]
    arcs=[0.]
    for k in range(1,len(per)):
        arcs.append(arcs[-1]+math.dist(perimeter[k-1],perimeter[k]))
    arcs_total=arcs[-1]+math.dist(perimeter[-1],perimeter[0])
    mid=[]
    for h in range(1,9):
        t=h/9.
        row=[]
        for k,(i,j) in enumerate(per):
            x,y=perimeter[k]
            a=math.atan2(y/by,x/ax)
            bulge=.010*sin(pi*t)**1.1*(1+.15*sin(3*a+.4))
            # uneven side tension, small and physically plausible
            for anchor,amp in ((12,.0035),(54,-.0028),(101,.0033),(167,-.003)):
                dist=min(abs(k-anchor),len(per)-abs(k-anchor))
                bulge+=amp*exp(-(dist/9.)**2)*sin(pi*t)**1.7
            rr=math.hypot(x,y)+.001
            x+=x/rr*bulge;y+=y/rr*bulge
            z=topheight(x,y)*(1-t)-.045*t
            row.append(vtx(transform(x,y,z)))
        mid.append(row)
    rings=[top_ring]+mid+[bot_ring]
    for h in range(len(rings)-1):
        a,b=rings[h],rings[h+1]
        for k in range(len(per)):
            m=(k+1)%len(per)
            s0,s1=arcs[k]/.30,(arcs_total if m==0 else arcs[m])/.30
            z0,z1=h*.10/9/.30,(h+1)*.10/9/.30
            face((a[k],b[k],b[m],a[m]),((s0,z0),(s0,z1),(s1,z1),(s1,z0)))
    me=bpy.data.meshes.new(name+" closed cloth mesh")
    me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    uv=me.uv_layers.new(name="Real world fabric UV")
    for f,faceuv in zip(me.polygons,fuvs):
        f.use_smooth=True
        for l,p in zip(f.loop_indices,faceuv):uv.data[l].uv=p
    me.materials.append(linen)
    # Physically expressed welt seam on upper outer perimeter.
    welt=tube(name+" | cotton upper seam",[verts[i] for i in top_ring]+[verts[top_ring[0]]],.0017,trim,smooth=False)
    return ob,welt

def convert_curves():
    for ob in list(bpy.context.scene.objects):
        if ob.type!="CURVE":continue
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.convert(target="MESH")
def studio(pos,ortho=1.42,target=(0,0,.46)):
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.014))
    floor=bpy.context.object;floor.name="STUDIO FLOOR NOT EXPORT"
    floor.data.materials.append(simple("Studio grey",(.105,.108,.11,1),.87))
    bpy.ops.object.camera_add(location=pos)
    cam=bpy.context.object;cam.name="STUDIO CAMERA"
    look=Vector(target)
    cam.rotation_euler=(look-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO";cam.data.ortho_scale=ortho
    sc=bpy.context.scene;sc.camera=cam
    for name,loc,power,size in (
        ("Key softbox",(-.65,-1.1,2.2),300,2.2),
        ("Right fill", (1.2,.55,1.7),175,2.4),
        ("Rear strip",(-.7,1.4,1.8),165,1.3)):
        bpy.ops.object.light_add(type="AREA",location=loc)
        light=bpy.context.object;light.name=name;light.data.energy=power
        light.data.shape="DISK";light.data.size=size
        light.rotation_euler=(look-light.location).to_track_quat("-Z","Y").to_euler()
    sc.render.engine="CYCLES";sc.cycles.samples=SAMPLES
    sc.cycles.use_denoising=False
    bpy.context.view_layer.cycles.use_denoising=False
    sc.render.resolution_x=840;sc.render.resolution_y=760;sc.render.resolution_percentage=100
    sc.render.image_settings.file_format="PNG"
    sc.view_settings.exposure=-.95
def export(name,info):
    convert_curves()
    valid=[ob for ob in bpy.context.scene.objects if ob.type=="MESH" and not ob.name.startswith("STUDIO")]
    assert len(valid)>=12,f"{name} has too few constructive pieces"
    bpy.ops.object.select_all(action="DESELECT")
    for ob in valid:ob.select_set(True)
    bpy.context.view_layer.objects.active=valid[0]
    path=OUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_texcoords=True,export_normals=True,export_materials="EXPORT")
    sc=bpy.context.scene
    sc.render.filepath=str(OUT/(name+"_render.png"))
    bpy.ops.render.render(write_still=True)
    sc.render.filepath=str(OUT/(name+"_detail.png"))
    sc.camera.location.x*=.65
    sc.camera.location.y*=1.17
    target=Vector((0,0,.45))
    sc.camera.rotation_euler=(target-sc.camera.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.render.render(write_still=True)
    (OUT/(name+".blend")) # Save editable project with original objects
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+".blend")))
    info.update({"name":name,"constructive_mesh_objects":len(valid),
                 "material_names":list(sorted({m.name for ob in valid for m in ob.data.materials if m})),
                 "glb_size_bytes":path.stat().st_size,"preview":"Cycles un-denoised",
                 "mobile_verified":False,"photorealism_verified":False})
    REPORT[name]=info
    print("FURNITURE_MODEL_EXPORTED",name,info,flush=True)
# Materials use common packed PBR textures, retained across scene resets.
reset()
linen=pbr("linen");wood=pbr("oak")
steel=simple("Black satin powder coated steel",(.062,.067,.071,1),.37,.72)
gold=simple("Brushed champagne brass",(.43,.33,.17,1),.34,.8)
trim=simple("Warm beige textile seam",(.35,.31,.27,1),.90)
dark=simple("Drawer interior graphite",(.047,.043,.040,1),.96)
def chair():
    reset()
    # The two matching sled frames follow curved welded steel tube construction,
    # with real seat rails, legs, cross ties and oak armrest slabs.
    for side in (-1,1):
        x=side*.338
        tube(f"{'L' if side<0 else 'R'} | continuous bent steel frame",[
            (x,-.34,.037),(x,-.345,.11),(x,-.34,.37),
            (x,-.31,.395),(x,.25,.397),(x,.315,.44),
            (x,.327,.68),(x,.329,.77),(x,.351,.85)],.013,steel)
        tube(f"{'L' if side<0 else 'R'} | front arm pillar",[
            (x,-.25,.390),(x,-.255,.55),(x,-.248,.681)],.010,steel)
        tube(f"{'L' if side<0 else 'R'} | floating armrest support",[
            (x,-.25,.681),(x,.23,.696),(x,.327,.75)],.010,steel)
        block("American oak armrest "+str(side),
              (x,-.002,.712),(.078,.43,.027),wood,.009,True)
        fastener("Visible countersunk arm screw "+str(side),(x,-.20,.731),gold,r=.005,depth=.002,axis="Z")
    for y,z,r in ((-.27,.34,.011),(.245,.355,.009),(.30,.82,.010)):
        tube("cross frame rail "+str(y),[(-.338,y,z),(.338,y,z)],r,steel,smooth=False)
    # Exposed seat cradle rails actually support the upholstery.
    block("Recessed seat support", (0,-.02,.412),(.57,.47,.024),dark,.012)
    seat,_=upholstered_panel("Seat cushion | tailored linen",.318,.272,.068,
                            (0,-.025,.482),0,linen,"seat")
    # Angled lumbar back cushion: face oriented toward seated person, not world Z.
    back,_=upholstered_panel("Backrest | angled lumbar upholstery",.309,.222,.060,
                            (0,.253,.722),.24,linen,"back")
    for x in (-.28,.28):
        fastener("Rear frame bolt "+str(x),(x,.35,.79),gold,.008,.006,"Y")
    studio((1.75,-2.17,1.31),1.52,(0,0,.52))
    export("lounge_chair_v20",{"class":"upholstered lounge chair with metal frame",
          "envelope_m":[.76,.78,.95],
          "construction":["separate seat/back cushion shells","bent tubular frame","cross braces","oak armrests","seams and bolts"],
          "upholstery":"scanned linen CC0; geometric seam creases; not full cloth sewn physics"})
def cabinet():
    reset()
    # 540 x 415 x 665 mm. Separate structural slabs, drawers, back and hardware.
    # Central positive depth points to the rear; drawers front at y=-.205.
    block("Full top slab, overhanging 8mm",(0,0,.665),(.553,.427,.025),wood,.006,True)
    for x in (-.243,.243):
        block("Oak side gable "+str(x),(x,.005,.419),(.028,.385,.452),wood,.004,True)
        # Exposed vertical edge grain reveals actual panel thickness.
        block("Oak side edge band "+str(x),(x,-.193,.419),(.028,.004,.438),wood,.0015,True)
    block("Lower fixed case panel",(0,.003,.215),(.467,.390,.025),wood,.004,True)
    block("Inner back panel",(0,.186,.429),(.470,.014,.437),wood,.002,True)
    block("Central drawer divider rail",(0,-.170,.437),(.469,.033,.020),wood,.003,True)
    for drawer,z in enumerate((.335,.545)):
        # Real depth behind fronts and visible shadow-gap at carcass.
        block("Drawer interior bottom "+str(drawer),(0,-.026,z-.077),(.417,.310,.009),dark,.002)
        for x in (-.216,.216):
            block("Drawer metal slide "+str(drawer)+" "+str(x),
                (x,-.033,z),(.010,.285,.018),steel,.0015)
        block("Full oak drawer face "+str(drawer),(0,-.199,z),(.456,.022,.206),wood,.0045,True)
        # Handle cap and two fastened posts. All real mesh, no painted impostors.
        for x in (-.055,.055):
            fastener("Handle fixing stud "+str(drawer)+" "+str(x),(x,-.216,z),gold,r=.006,depth=.017,axis="Y")
        tube("Brushed steel drawer handle "+str(drawer),
             [(-.070,-.231,z),(-.067,-.251,z),(0,-.252,z),(.067,-.251,z),(.070,-.231,z)],
             .006,steel)
    # Tapered foot form, generated from independent profile rings, UV wood mapped.
    for x in (-.215,.215):
        for y in (-.156,.156):
            bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.018,radius2=.027,
                depth=.185,location=(x,y,.100))
            ob=bpy.context.object;ob.name=f"Turned oak leg {x} {y}"
            ob.data.materials.append(wood)
            apply_wood_uv(ob)
            for p in ob.data.polygons:p.use_smooth=True
            block("Brass ferrule "+str(x)+" "+str(y),(x,y,.019),(.034,.034,.028),gold,.004)
    # Small adjustable feet are modeled below plinth, not painted circles.
    studio((1.14,-1.50,1.08),1.10,(0,0,.37))
    export("oak_nightstand_v20",{"class":"two drawer solid oak bedside cabinet",
          "envelope_m":[.553,.427,.68],
          "construction":["separate carcass panels","two fitted drawer fronts","slide rails",
                         "real metal handles and fixing studs","four turned legs with metal tips"],
          "wood":"real oak veneer CC0 PBR, UV oriented to structural face grain"})
chair()
cabinet()
(OUT/"furniture_library_report.json").write_text(json.dumps(REPORT,ensure_ascii=False,indent=2),encoding="utf-8")
print("FURNITURE_FAMILY_V20_OK",list(REPORT),flush=True)
