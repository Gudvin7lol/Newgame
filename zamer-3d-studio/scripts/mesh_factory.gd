extends RefCounted

## Seam-safe upholstered rounded box. Analytic bevel normals avoid faceting,
## while the face bulge falls to zero at shared boundaries.
static func soft_box(w:float,h:float,d:float,round_radius:float,fullness:float,seed:float)->ArrayMesh:
    var half:=Vector3(maxf(w,0.025),maxf(h,0.025),maxf(d,0.025))*0.5
    var radius:=minf(maxf(round_radius,0.001),minf(half.x,minf(half.y,half.z))*0.92)
    var core:=half-Vector3.ONE*radius
    var faces:Array=[
        [Vector3.RIGHT,Vector3.FORWARD,Vector3.UP],
        [Vector3.LEFT,Vector3.BACK,Vector3.UP],
        [Vector3.UP,Vector3.RIGHT,Vector3.FORWARD],
        [Vector3.DOWN,Vector3.RIGHT,Vector3.BACK],
        [Vector3.BACK,Vector3.RIGHT,Vector3.UP],
        [Vector3.FORWARD,Vector3.LEFT,Vector3.UP]
    ]
    var res:=32
    var mesh_builder:=SurfaceTool.new()
    mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in faces:
        var axis_n:Vector3=face[0]
        var axis_u:Vector3=face[1]
        var axis_v:Vector3=face[2]
        var vtx:Array[Vector3]=[]
        var nrm:Array[Vector3]=[]
        var uv:Array[Vector2]=[]
        var center:=Vector3(axis_n.x*half.x,axis_n.y*half.y,axis_n.z*half.z)
        var eu:=Vector3(axis_u.x*half.x,axis_u.y*half.y,axis_u.z*half.z)
        var ev:=Vector3(axis_v.x*half.x,axis_v.y*half.y,axis_v.z*half.z)
        for iy in range(res+1):
            var v:=float(iy)/float(res)*2.0-1.0
            for ix in range(res+1):
                var u:=float(ix)/float(res)*2.0-1.0
                var raw:=center+eu*u+ev*v
                var near:=Vector3(clampf(raw.x,-core.x,core.x),clampf(raw.y,-core.y,core.y),clampf(raw.z,-core.z,core.z))
                var offset:=raw-near
                var outward:=offset.normalized() if offset.length_squared()>0.00000001 else axis_n
                var position:=near+outward*radius
                var falloff:=pow(maxf(0.0,1.0-u*u),2.0)*pow(maxf(0.0,1.0-v*v),2.0)
                if axis_n.y>0.5:
                    position.y+=(0.002+0.005*fullness)*falloff
                    position.y+=sin(8.0*u+seed)*sin(7.0*v+seed)*0.0009*falloff
                elif absf(axis_n.z)>0.5:
                    position.z+=axis_n.z*(0.001+0.003*fullness)*falloff
                elif absf(axis_n.x)>0.5:
                    position.x+=axis_n.x*0.003*fullness*falloff
                vtx.append(position)
                nrm.append(outward)
                uv.append(Vector2((u+1.0)*eu.length()*4.2,(v+1.0)*ev.length()*4.2))
        for iy in range(res):
            for ix in range(res):
                var a:=iy*(res+1)+ix
                var b:=a+1
                var c:=a+res+1
                var e:=c+1
                for k in [a,b,c,c,b,e]:
                    mesh_builder.set_normal(nrm[k])
                    mesh_builder.set_uv(uv[k])
                    mesh_builder.add_vertex(vtx[k])
    mesh_builder.index()
    mesh_builder.generate_tangents()
    return mesh_builder.commit()

static func cushion(w:float,h:float,d:float,softness:float,seed:float)->ArrayMesh:
    return soft_box(w,h,d,minf(0.07,h*0.32),softness,seed)
