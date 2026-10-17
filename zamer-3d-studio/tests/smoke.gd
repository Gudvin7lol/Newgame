extends SceneTree

func _initialize() -> void:
    var g = load("res://scripts/mesh_factory.gd")
    if g == null:
        push_error("Missing geometry")
        quit(1)
        return
    var mesh: ArrayMesh = g.cushion(0.72, 0.18, 0.65, 0.65, 1.0)
    if mesh == null or mesh.get_surface_count() != 1:
        push_error("Invalid mesh")
        quit(2)
        return
    var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if v.size() < 1000:
        push_error("Mesh under-detailed")
        quit(3)
        return
    print("GEOMETRY OK ", v.size())
    quit(0)
