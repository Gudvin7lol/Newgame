extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var editor = scene.instantiate()
    root.add_child(editor)
    await process_frame
    if editor.data.size() != 0:
        push_error("New editor must start with empty scene")
        quit(1)
        return
    editor._add_item("soft")
    if editor.data.size() != 1 or editor.instances.size() != 1:
        push_error("Adding object failed")
        quit(2)
        return
    var original: float = float(editor.data[0]["size"][0])
    editor._nudge("size", 0, 1)
    if not is_equal_approx(float(editor.data[0]["size"][0]), original + 0.01):
        push_error("Parametric editing failed")
        quit(3)
        return
    editor.vertex_index = 0
    editor._move_vertex(1, 1)
    if editor.data[0]["vertex_ops"].size() != 1:
        push_error("Actual vertex modification was not recorded")
        quit(4)
        return
    editor._undo()
    if editor.data[0]["vertex_ops"].size() != 0:
        push_error("Undo did not restore vertex geometry")
        quit(5)
        return
    editor._duplicate()
    if editor.data.size() != 2:
        push_error("Duplicate failed")
        quit(6)
        return
    editor._delete_selected()
    if editor.data.size() != 1:
        push_error("Delete failed")
        quit(7)
        return
    editor._choose(int(editor.data[0]["id"]))
    editor._assign_material(3)
    if int(editor.data[0]["mat"]) != 3:
        push_error("Material assignment failed")
        quit(8)
        return
    editor._save()
    if not FileAccess.file_exists("user://zamer_studio_project.json"):
        push_error("Project file not written")
        quit(9)
        return
    editor._export_glb()
    if not FileAccess.file_exists("user://exports/studio_mesh.glb"):
        push_error("GLB not exported")
        quit(10)
        return
    var glb_file := FileAccess.open("user://exports/studio_mesh.glb", FileAccess.READ)
    if glb_file == null or glb_file.get_length() < 1024:
        push_error("GLB file empty")
        quit(11)
        return
    # Real topology change: selected face extrusion must create more geometry.
    editor._choose(int(editor.data[0]["id"]))
    # The remaining item is a soft object; add an editable cuboid.
    editor._add_item("box")
    var box_id: int = editor.selection_id
    var base_mesh: Mesh = editor.instances[box_id].mesh
    var base_faces: int = base_mesh.get_faces().size()
    editor._set_face(2)
    editor._edit_profile("extrude_depth",0.15)
    var extruded_mesh: Mesh = editor.instances[box_id].mesh
    var extrusion_faces: int = extruded_mesh.get_faces().size()
    if extrusion_faces <= base_faces:
        push_error("Extrude did not add real mesh geometry")
        quit(12)
        return
    if extruded_mesh.get_aabb().size.y <= base_mesh.get_aabb().size.y:
        push_error("Extrude did not change solid dimensions")
        quit(13)
        return
    editor._edit_profile("bevel",0.035)
    if float(editor.data[-1]["bevel"]) < 0.03:
        push_error("Chamfer parameter not updated")
        quit(14)
        return
    editor._undo()
    if float(editor.data[-1]["bevel"]) > 0.0001:
        push_error("Undo did not restore face profile")
        quit(15)
        return
    editor._redo()
    if float(editor.data[-1]["bevel"]) < 0.03:
        push_error("Redo did not restore bevel")
        quit(16)
        return
    editor._reset_profile()
    editor._edit_profile("extrude_depth",0.05)
    var physical_height: float = float(editor.data[-1]["extrude_depth"])*float(editor.data[-1]["size"][1])
    if absf(physical_height-0.05)>0.0005:
        push_error("Physical extrusion is not 50 mm")
        quit(20)
        return
    editor._export_glb()
    var gltf := GLTFDocument.new()
    var state := GLTFState.new()
    var load_err := gltf.append_from_file("user://exports/studio_mesh.glb",state)
    if load_err != OK or state.get_meshes().size() < 2:
        push_error("Round trip GLB contains invalid geometry")
        quit(17)
        return
    editor._set_exact(1450.0,"size",0)
    if absf(float(editor.data[-1]["size"][0])-1.45)>0.0001:
        push_error("Millimetre input did not convert to metres")
        quit(18)
        return
    editor._camera_preset("top")
    if absf(editor.orbit_x + PI*0.499)>0.002:
        push_error("Top camera preset failed")
        quit(19)
        return
    editor._add_item("editable")
    var editable_id:int=editor.selection_id
    var polygon_before:int=editor.data[-1]["mesh_data"]["faces"].size()
    editor.polygon_face=2
    editor._topology_extrude(0.05,0.10)
    if editor.data[-1]["mesh_data"]["faces"].size()<=polygon_before:
        push_error("Editable face extrusion failed")
        quit(21)
        return
    var face_after:int=editor.polygon_face
    editor._topology_extrude(0.04,0.0)
    if editor.polygon_face==face_after:
        push_error("Repeated face extrusion did not continue to cap")
        quit(22)
        return
    editor._topology_subdivide()
    if editor.data[-1]["mesh_data"]["faces"].size()<20:
        push_error("Topology subdivide did not change the mesh")
        quit(23)
        return
    editor._save()
    editor._load_file()
    if not editor.instances.has(editable_id) or not editor.data[-1].has("mesh_data"):
        push_error("Editable polygon document lost on save/load")
        quit(24)
        return
    editor._export_glb()
    var gltf_new:=GLTFDocument.new()
    var gltf_new_state:=GLTFState.new()
    if gltf_new.append_from_file("user://exports/studio_mesh.glb",gltf_new_state)!=OK:
        push_error("Edited topology failed GLB round-trip")
        quit(25)
        return
    editor._choose(editable_id)
    editor._set_transform_tool("translate")
    editor._lock_axis(0)
    var origin_x:float=float(editor.data[-1]["pos"][0])
    editor._apply_drag_transform(Vector2(65,0))
    if absf(float(editor.data[-1]["pos"][0])-origin_x)<0.0005:
        push_error("Touch MOVE tool did not change the selected object")
        quit(26)
        return
    editor._set_transform_tool("rotate")
    var old_rot:float=float(editor.data[-1]["rot"][0])
    editor._apply_drag_transform(Vector2(20,0))
    if absf(float(editor.data[-1]["rot"][0])-old_rot)<0.02:
        push_error("Touch ROTATE tool did not update rotation")
        quit(27)
        return
    print("EDITOR SMOKE OK: vertex edit, undo/redo, extrude, inset, bevel, GLB roundtrip")
    quit(0)
