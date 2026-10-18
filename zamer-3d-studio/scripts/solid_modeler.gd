extends RefCounted

## Face-profile solid modeller. Base cuboid is [-0.5,+0.5]^3.
## Face 0..5: +X,-X,+Y,-Y,+Z,-Z
## A true inset face + extrusion or recessed cavity; no overlapping boxes.
static func build(face_id: int, depth: float, inset: float, chamfer: float) -> ArrayMesh:
    var f := clampi(face_id, 0, 5)
    var faces := [
        [Vector3.RIGHT, Vector3.BACK, Vector3.UP],
        [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
        [Vector3.UP, Vector3.RIGHT, Vector3.BACK],
        [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
        [Vector3.BACK, Vector3.RIGHT, Vector3.UP],
        [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(6):
        var n: Vector3 = faces[i][0]
        var u: Vector3 = faces[i][1]
        var v: Vector3 = faces[i][2]
        if i != f:
            var corners := _ring(n,u,v,0.5,0.0)
            _quad(st,corners[0],corners[1],corners[2],corners[3],n)
            continue
        var profile := _ring(n,u,v,0.5,0.0)
        var inner := _ring(n,u,v,0.5-clampf(inset,0.005,0.35),0.0)
        var sign_depth := signf(depth)
        if absf(depth) < 0.0001: sign_depth=1.0
        var bevel := minf(clampf(chamfer,0.0,0.14),absf(depth)*0.42)
        var end_flat := _ring(n,u,v,0.5-clampf(inset,0.005,0.35),depth-sign_depth*bevel)
        var cap := _ring(n,u,v,0.5-clampf(inset,0.005,0.35)-bevel,depth)
        for edge in range(4):
            var k := (edge+1)%4
            _quad(st,profile[edge],profile[k],inner[k],inner[edge],n)
        var side_sign := signf(depth)
        if absf(depth) < 0.0001: side_sign=1.0
        for edge in range(4):
            var k := (edge+1)%4
            var radial:Vector3 = ((inner[edge]+inner[k])*0.5 - n*0.5).normalized()
            _quad(st,inner[edge],inner[k],end_flat[k],end_flat[edge],radial*side_sign)
            if bevel>0.0001:
                _quad(st,end_flat[edge],end_flat[k],cap[k],cap[edge],radial*side_sign+n*0.5)
        _quad(st,cap[0],cap[1],cap[2],cap[3],n)
    st.index()
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

static func _ring(n:Vector3,u:Vector3,v:Vector3,half_width:float,offset:float)->Array[Vector3]:
    var c:=n*(0.5+offset)
    return [
        c-u*half_width-v*half_width,
        c+u*half_width-v*half_width,
        c+u*half_width+v*half_width,
        c-u*half_width+v*half_width
    ]

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,outward:Vector3)->void:
    _tri(st,a,b,c,outward)
    _tri(st,a,c,d,outward)

static func _tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,outward:Vector3)->void:
    if (b-a).cross(c-a).dot(outward)<0.0:
        var temp:=b
        b=c
        c=temp
    for p in [a,b,c]:
        st.set_uv(Vector2(p.x+p.z*0.7,p.y+p.z*0.3))
        st.add_vertex(p)
