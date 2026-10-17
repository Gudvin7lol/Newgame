extends SceneTree

func _initialize() -> void:
    var factory=load("res://scripts/mesh_factory.gd")
    if factory==null:
        push_error("Missing mesh factory")
        quit(1)
        return
    var m:ArrayMesh=factory.cushion(0.64,0.17,0.65,0.7,1.0)
    if m==null or m.get_surface_count()!=1:
        push_error("No mesh surface")
        quit(2)
        return
    var arrays:=m.surface_get_arrays(0)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
    if vertices.size()<6000 or normals.size()!=vertices.size() or uvs.size()!=vertices.size():
        push_error("Missing vertices, normals, or texture coordinates")
        quit(3)
        return
    var bounds:=m.get_aabb()
    if absf(bounds.size.x-0.64)>0.015 or absf(bounds.size.z-0.65)>0.015:
        push_error("Wrong cushion dimensions")
        quit(4)
        return
    for n in normals:
        if not is_finite(n.x) or not is_finite(n.y) or not is_finite(n.z) or absf(n.length()-1.0)>0.02:
            push_error("Broken vertex normals")
            quit(5)
            return
    print("MESH VALID: ",vertices.size()," verts; AABB=",bounds)
    quit(0)
