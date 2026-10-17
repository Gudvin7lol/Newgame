extends RefCounted

## Continuous closed rounded box with cushion-friendly face inflation.
## Designed for mobile: mesh stays valid at parametric extremes.
static func soft_box(w: float, h: float, d: float, round_radius: float, fullness: float, seed: float) -> ArrayMesh:
    var size := Vector3(maxf(0.015,w), maxf(0.015,h), maxf(0.015,d))
    var half := size * 0.5
    var radius := minf(round_radius, minf(half.x,minf(half.y,half.z))*0.9)
    var core := half - Vector3(radius,radius,radius)
    var axes := [
        [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
        [Vector3.LEFT, Vector3.BACK, Vector3.UP],
        [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
        [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
        [Vector3.BACK, Vector3.RIGHT, Vector3.UP],
        [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var grid_size := 16
    for face in axes:
        var normal: Vector3 = face[0]
        var ux: Vector3 = face[1]
        var vy: Vector3 = face[2]
        var points: Array[Vector3] = []
        var uv: Array[Vector2] = []
        var n_coord := Vector3(normal.x*half.x,normal.y*half.y,normal.z*half.z)
        var ux_extent := Vector3(ux.x*half.x,ux.y*half.y,ux.z*half.z)
        var vy_extent := Vector3(vy.x*half.x,vy.y*half.y,vy.z*half.z)
        for row in range(grid_size+1):
            var v := float(row)/float(grid_size)*2.0-1.0
            for col in range(grid_size+1):
                var u := float(col)/float(grid_size)*2.0-1.0
                var raw := n_coord + ux_extent*u + vy_extent*v
                var clamped := Vector3(clampf(raw.x,-core.x,core.x),clampf(raw.y,-core.y,core.y),clampf(raw.z,-core.z,core.z))
                var offset := raw-clamped
                var point := clamped + offset.normalized()*radius if offset.length_squared()>0.0000001 else raw
                var inside := maxf(0.0,1.0-u*u)*maxf(0.0,1.0-v*v)
                if normal.y > 0.5:
                    point.y += (0.006 + 0.018*fullness)*inside
                    point.y += 0.0016 * sin(u*17.0+seed) * sin(v*12.0+seed*0.8)*inside
                elif absf(normal.z) > 0.5:
                    point.z += normal.z*(0.005+0.012*fullness)*inside
                    point.z += normal.z*0.0018*sin(u*13.0+seed)*inside
                elif absf(normal.x)>0.5:
                    point.x += normal.x*0.006*fullness*inside
                points.append(point)
                uv.append(Vector2((u+1.0)*0.5*(ux_extent.length()*2.0)*7.0,(v+1.0)*0.5*(vy_extent.length()*2.0)*7.0))
        for row in range(grid_size):
            for col in range(grid_size):
                var a := row*(grid_size+1)+col
                var b := a+1
                var c := a+grid_size+1
                var e := c+1
                for index in [a,b,c,c,b,e]:
                    st.set_uv(uv[index])
                    st.add_vertex(points[index])
    st.index()
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

## Geometry smoke compatibility.
static func cushion(w: float,h: float,d: float,softness: float,seed: float) -> ArrayMesh:
    return soft_box(w,h,d,0.055,softness,seed)

## True 3D seams along the cushion's front, not a broken elliptical ring.
static func welt(length: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sections := 32
    for x in range(sections):
        var x1 := (float(x)/sections-0.5)*length
        var x2 := (float(x+1)/sections-0.5)*length
        for j in range(8):
            var phi1 := TAU*float(j)/8.0
            var phi2 := TAU*float(j+1)/8.0
            var a := Vector3(x1,cos(phi1)*0.0023,sin(phi1)*0.0023)
            var b := Vector3(x1,cos(phi2)*0.0023,sin(phi2)*0.0023)
            var c := Vector3(x2,cos(phi1)*0.0023,sin(phi1)*0.0023)
            var d := Vector3(x2,cos(phi2)*0.0023,sin(phi2)*0.0023)
            for p in [a,c,b,b,c,d]:
                st.add_vertex(p)
    st.index()
    st.generate_normals()
    return st.commit()
