extends RefCounted

## Editable polygonal mesh document. Uses shared vertices and ordered polygon faces.
## Triangles are only generated for GPU rendering/export.
static func cube() -> Dictionary:
    return {
        "vertices": [
            [-0.5,-0.5,-0.5],[0.5,-0.5,-0.5],[0.5,0.5,-0.5],[-0.5,0.5,-0.5],
            [-0.5,-0.5,0.5],[0.5,-0.5,0.5],[0.5,0.5,0.5],[-0.5,0.5,0.5]
        ],
        "faces": [
            [1,2,6,5], [0,4,7,3], [3,7,6,2],
            [0,1,5,4], [4,5,6,7], [0,3,2,1]
        ]
    }

static func point(doc: Dictionary, i: int) -> Vector3:
    var p: Array = doc["vertices"][i]
    return Vector3(float(p[0]),float(p[1]),float(p[2]))

static func array3(v: Vector3) -> Array:
    return [v.x,v.y,v.z]

static func face_center(doc: Dictionary, face_idx: int) -> Vector3:
    var indices: Array = doc["faces"][face_idx]
    var sum := Vector3.ZERO
    for index in indices: sum += point(doc,int(index))
    return sum/float(indices.size())

static func normal(doc: Dictionary, face_idx: int) -> Vector3:
    var indices: Array = doc["faces"][face_idx]
    if indices.size()<3: return Vector3.UP
    var p0 := point(doc,int(indices[0]))
    var aggregate := Vector3.ZERO
    for k in range(1,indices.size()-1):
        aggregate += (point(doc,int(indices[k]))-p0).cross(point(doc,int(indices[k+1]))-p0)
    return aggregate.normalized() if aggregate.length_squared()>0.00000001 else Vector3.UP

static func mesh(doc: Dictionary) -> ArrayMesh:
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertices: Array = doc.get("vertices",[])
    for face_index in range(doc["faces"].size()):
        var face: Array = doc["faces"][face_index]
        if face.size()<3: continue
        var n := normal(doc,face_index)
        for k in range(1,face.size()-1):
            for i in [int(face[0]),int(face[k]),int(face[k+1])]:
                var p := point(doc,i)
                builder.set_normal(n)
                builder.set_uv(Vector2(p.x*1.2+p.z*0.35,p.y*1.2+p.z*0.35))
                builder.add_vertex(p)
    return builder.commit()

## Extrude selected polygon in its own normal direction, preserving adjacent faces.
## Physical depth in metres supplied in scene units before nonuniform object scaling.
## inset_fraction=0 creates a straight extrusion; positive gives an inset border.
static func extrude(doc: Dictionary, face_idx: int, depth: float, inset_fraction: float = 0.0) -> int:
    var faces: Array = doc["faces"]
    if face_idx<0 or face_idx>=faces.size(): return -1
    var old_face: Array = faces[face_idx].duplicate()
    if old_face.size()<3: return -1
    var n := normal(doc,face_idx)
    var centroid := face_center(doc,face_idx)
    var inner: Array = []
    var end: Array = []
    var inset := clampf(inset_fraction,0.0,0.42)
    if inset>0.0001:
        for v in old_face:
            var p := point(doc,int(v)).lerp(centroid,inset)
            inner.append(doc["vertices"].size())
            doc["vertices"].append(array3(p))
    else:
        inner = old_face.duplicate()
    var base: Array = inner
    if inset>0.0001:
        for i in range(old_face.size()):
            var j := (i+1)%old_face.size()
            faces.append([old_face[i],old_face[j],inner[j],inner[i]])
    if absf(depth)>0.000001:
        for idx in inner:
            end.append(doc["vertices"].size())
            doc["vertices"].append(array3(point(doc,int(idx))+n*depth))
        for i in range(inner.size()):
            var j := (i+1)%inner.size()
            faces.append([inner[i],inner[j],end[j],end[i]])
    else:
        end=inner
    # Replace the original cap by a newly created face; the new cap is last.
    faces.remove_at(face_idx)
    faces.append(end)
    return faces.size()-1

## Shared-midpoint quad subdivision with consistent adjacent boundaries.
static func subdivide(doc: Dictionary) -> void:
    var existing: Array = doc["faces"]
    var midpoint: Dictionary = {}
    var new_faces: Array = []
    for face in existing:
        if face.size()<3: continue
        var centre := Vector3.ZERO
        for index in face: centre+=point(doc,int(index))
        centre/=float(face.size())
        var center_idx: int = doc["vertices"].size()
        doc["vertices"].append(array3(centre))
        var mids: Array = []
        for i in range(face.size()):
            var a: int=int(face[i])
            var b: int=int(face[(i+1)%face.size()])
            var key := "%d:%d" % [mini(a,b),maxi(a,b)]
            if not midpoint.has(key):
                midpoint[key]=doc["vertices"].size()
                doc["vertices"].append(array3((point(doc,a)+point(doc,b))*0.5))
            mids.append(midpoint[key])
        for i in range(face.size()):
            var previous: int = (i-1+face.size())%face.size()
            new_faces.append([mids[previous],face[i],mids[i],center_idx])
    doc["faces"]=new_faces

static func move_vertex(doc: Dictionary,index: int,delta: Vector3) -> bool:
    if index<0 or index>=doc["vertices"].size(): return false
    doc["vertices"][index]=array3(point(doc,index)+delta)
    return true

## Project a ray onto each triangle and return nearest polygon face id.
static func hit_face(doc:Dictionary,origin:Vector3,direction:Vector3) -> Dictionary:
    var nearest := INF
    var picked := -1
    var hit_point := Vector3.ZERO
    for fi in range(doc["faces"].size()):
        var face: Array = doc["faces"][fi]
        if face.size()<3: continue
        var a := point(doc,int(face[0]))
        for i in range(1,face.size()-1):
            var hit = Geometry3D.ray_intersects_triangle(origin,direction,a,
                point(doc,int(face[i])),point(doc,int(face[i+1])))
            if hit is Vector3:
                var distance := origin.distance_to(hit)
                if distance<nearest:
                    nearest=distance
                    picked=fi
                    hit_point=hit
    return {"face":picked,"distance":nearest,"point":hit_point}

static func is_closed(doc:Dictionary) -> bool:
    var edges: Dictionary = {}
    for face in doc["faces"]:
        for i in range(face.size()):
            var a: int=int(face[i])
            var b: int=int(face[(i+1)%face.size()])
            var key := "%d:%d" % [mini(a,b),maxi(a,b)]
            edges[key]=int(edges.get(key,0))+1
    for frequency in edges.values():
        if int(frequency)!=2: return false
    return edges.size()>0
