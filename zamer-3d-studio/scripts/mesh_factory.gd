extends RefCounted

## Soft superellipse upholstery mesh: real subdivision geometry rather than a BoxMesh.
static func spow(v: float, p: float) -> float:
    return signf(v) * pow(absf(v), p)

static func cushion(w: float, h: float, d: float, softness: float, seed: float) -> ArrayMesh:
    var rings := 28
    var segments := 48
    var shape := lerpf(0.62, 0.40, clampf(softness, 0.0, 1.0))
    var verts: Array[Vector3] = []
    var uv: Array[Vector2] = []
    for r in range(rings + 1):
        var theta := PI * float(r) / rings
        for u in range(segments + 1):
            var phi := TAU * float(u) / segments
            var radial := spow(sin(theta), shape)
            var x := w * 0.5 * radial * spow(cos(phi), shape)
            var y := h * 0.5 * spow(cos(theta), shape)
            var z := d * 0.5 * radial * spow(sin(phi), shape)
            var wrinkle := 0.003 * sin(phi * 3.0 + seed) * sin(theta * 4.0)
            verts.append(Vector3(x + wrinkle * cos(phi), y, z + wrinkle * sin(phi)))
            uv.append(Vector2(float(u) / segments * maxf(w,d) * 6.0, float(r) / rings * (h + d) * 5.0))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for r in range(rings):
        for u in range(segments):
            var a := r * (segments + 1) + u
            var b := a + segments + 1
            for k in [a, a + 1, b, b, a + 1, b + 1]:
                st.set_uv(uv[k])
                st.add_vertex(verts[k])
    st.index()
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

static func piping(w: float, d: float, y: float, softness: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var p := lerpf(0.62, 0.40, clampf(softness,0.0,1.0))
    for i in range(64):
        var a := TAU * float(i) / 64.0
        var b := TAU * float(i+1) / 64.0
        var pa := Vector3(w*0.49*spow(cos(a),p),y,d*0.49*spow(sin(a),p))
        var pb := Vector3(w*0.49*spow(cos(b),p),y,d*0.49*spow(sin(b),p))
        for j in range(8):
            var t0 := TAU * float(j) / 8.0
            var t1 := TAU * float(j+1) / 8.0
            var q0 := Vector3(cos(t0)*0.003,sin(t0)*0.003,0)
            var q1 := Vector3(cos(t1)*0.003,sin(t1)*0.003,0)
            for point in [pa+q0, pa+q1, pb+q0, pb+q0, pa+q1, pb+q1]:
                st.add_vertex(point)
    st.index()
    st.generate_normals()
    return st.commit()
