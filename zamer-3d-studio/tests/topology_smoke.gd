extends SceneTree

const MeshDoc=preload("res://scripts/topology_mesh.gd")
func _initialize() -> void:
    var doc:Dictionary=MeshDoc.cube()
    if doc["vertices"].size()!=8 or doc["faces"].size()!=6 or not MeshDoc.is_closed(doc):
        push_error("Invalid base polygon topology")
        quit(1)
        return
    var first_face:int=MeshDoc.extrude(doc,2,0.12,0.12)
    if first_face<0 or not MeshDoc.is_closed(doc):
        push_error("Inset+extrude broke mesh manifold")
        quit(2)
        return
    var second_face:int=MeshDoc.extrude(doc,first_face,0.08)
    if second_face<0 or not MeshDoc.is_closed(doc):
        push_error("Repeated extrusion broke mesh topology")
        quit(3)
        return
    var before:int=doc["faces"].size()
    MeshDoc.subdivide(doc)
    if doc["faces"].size()<=before or not MeshDoc.is_closed(doc):
        push_error("Subdivision broke shared polygon edges")
        quit(4)
        return
    var old:Vector3=MeshDoc.point(doc,0)
    if not MeshDoc.move_vertex(doc,0,Vector3(0.01,0,0)):
        push_error("Vertex edit failed")
        quit(5)
        return
    var new_pos:Vector3=MeshDoc.point(doc,0)
    if absf(new_pos.x-old.x-0.01)>0.00001:
        push_error("Vertex coordinate not updated")
        quit(6)
        return
    var built:ArrayMesh=MeshDoc.mesh(doc)
    if built.get_surface_count()!=1 or built.get_faces().size()<72:
        push_error("GPU mesh did not triangulate")
        quit(7)
        return
    var hit:Dictionary=MeshDoc.hit_face(doc,Vector3(0,3,0),Vector3.DOWN)
    if int(hit["face"])<0:
        push_error("Face ray selection failed")
        quit(8)
        return
    print("POLYGON TOPOLOGY OK: faces=",doc["faces"].size()," vertices=",doc["vertices"].size())
    quit(0)
