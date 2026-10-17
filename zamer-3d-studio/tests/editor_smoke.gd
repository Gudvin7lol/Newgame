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
    print("EDITOR SMOKE OK: add, transform, vertex edit, undo, duplicate, delete, material, save, glb")
    quit(0)
