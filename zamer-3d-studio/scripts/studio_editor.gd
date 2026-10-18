extends Control

# ZAMER 3D Studio: native modeling workspace, not the furniture demo.
# Scene document stores editable objects, modifiers and per-vertex operations.
const Factory = preload("res://scripts/mesh_factory.gd")
const Solid = preload("res://scripts/solid_modeler.gd")
const BG = Color("#0a111b")
const SURFACE = Color("#111e2b")
const PANEL = Color("#182737")
const INK = Color("#eaf4f5")
const SUBTLE = Color("#92aabd")
const TEAL = Color("#47dec3")
const BORDER = Color("#2a3b4d")

var stage: SubViewportContainer
var view: SubViewport
var world: Node3D
var model_root: Node3D
var view_camera: Camera3D
var camera_pivot: Node3D
var status: Label
var selected_info: Label
var inspector: VBoxContainer
var names_panel: VBoxContainer
var overlay_label: Label
var data: Array[Dictionary] = []
var instances: Dictionary = {}
var selection_id: int = -1
var vertex_index: int = -1
var next_id: int = 1
var undo_stack: Array[String] = []
var redo_stack: Array[String] = []
var active_tab: String = "objects"
var tool_mode: String = "select"
var selected_material: int = 0
var orbit_y: float = 0.42
var orbit_x: float = -0.23
var orbit_distance: float = 4.8
var focus: Vector3 = Vector3(0, 0.85, 0)
var pointers: Dictionary = {}
var touch_origin: Vector2 = Vector2.ZERO
var dragged: bool = false
var materials: Array[StandardMaterial3D] = []
var selection_overlay: MeshInstance3D
var selected_face: int = 2

func _ready() -> void:
    _make_materials()
    _build_interface()
    _build_world()
    _open_autosave()
    _sync_scene()
    _refresh_panel()
    _camera_update()
    _note("Новый редактор: добавь объект, выдели его и выбери инструмент.")

func _style(color: Color, radius: int = 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(9)
    return s

func _text(value: String, font_size: int = 14, color: Color = INK) -> Label:
    var lab := Label.new()
    lab.text = value
    lab.add_theme_color_override("font_color", color)
    lab.add_theme_font_size_override("font_size", font_size)
    return lab

func _btn(parent: Node, label: String, cb: Callable, accent: bool = false) -> Button:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 42
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", INK)
    button.add_theme_stylebox_override("normal", _style(Color("#146a65") if accent else PANEL, 10))
    button.add_theme_stylebox_override("hover", _style(Color("#247879") if accent else Color("#263d50"), 10))
    button.add_theme_stylebox_override("pressed", _style(Color("#138e80"), 10))
    button.pressed.connect(cb)
    parent.add_child(button)
    return button

func _build_interface() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    add_child(root)
    var header := PanelContainer.new()
    header.add_theme_stylebox_override("panel", _style(BG, 0))
    root.add_child(header)
    var header_row := HBoxContainer.new()
    header_row.custom_minimum_size.y = 43
    header.add_child(header_row)
    var brand := _text("Z / STUDIO", 19)
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_row.add_child(brand)
    header_row.add_child(_text("MESH LAB  0.7", 11, TEAL))
    _btn(header_row, "↶", _undo)
    _btn(header_row, "↷", _redo)

    var stage_box := Control.new()
    stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stage_box.custom_minimum_size.y = 270
    root.add_child(stage_box)
    stage = SubViewportContainer.new()
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stage.stretch = true
    stage.mouse_filter = Control.MOUSE_FILTER_STOP
    stage.gui_input.connect(_on_view_event)
    stage_box.add_child(stage)
    view = SubViewport.new()
    view.size = Vector2i(480, 670)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    stage.add_child(view)

    var overlay := PanelContainer.new()
    overlay.position = Vector2(12, 12)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_theme_stylebox_override("panel", _style(Color(0.06, 0.11, 0.16, 0.82), 8))
    stage_box.add_child(overlay)
    overlay_label = _text("СЦЕНА  /  ОБЪЕКТЫ: 0", 11, TEAL)
    overlay.add_child(overlay_label)

    var controls := PanelContainer.new()
    controls.add_theme_stylebox_override("panel", _style(SURFACE, 12))
    root.add_child(controls)
    var below := VBoxContainer.new()
    below.add_theme_constant_override("separation", 6)
    controls.add_child(below)
    selected_info = _text("Нет выделения", 13, TEAL)
    selected_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    below.add_child(selected_info)

    var nav := HBoxContainer.new()
    below.add_child(nav)
    _btn(nav, "Объекты", _set_tab.bind("objects"), true)
    _btn(nav, "Правка", _set_tab.bind("transform"))
    _btn(nav, "Сетка", _set_tab.bind("mesh"))
    _btn(nav, "Материал", _set_tab.bind("materials"))
    _btn(nav, "Файлы", _set_tab.bind("files"))

    inspector = VBoxContainer.new()
    inspector.custom_minimum_size.y = 163
    inspector.add_theme_constant_override("separation", 6)
    below.add_child(inspector)

    var footer := HBoxContainer.new()
    below.add_child(footer)
    status = _text("Рабочая сцена", 11, SUBTLE)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(status)
    _btn(footer, "Сохранить", _save)

func _build_world() -> void:
    world = Node3D.new()
    view.add_child(world)
    var env_node := WorldEnvironment.new()
    world.add_child(env_node)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#1b2836")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b5c5d3")
    environment.ambient_light_energy = 0.7
    env_node.environment = environment

    model_root = Node3D.new()
    model_root.name = "EditableModel"
    world.add_child(model_root)
    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(200, 200)
    floor.mesh = plane
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#222f3c")
    floor_mat.roughness = 0.96
    floor.material_override = floor_mat
    floor.position.y = -0.018
    world.add_child(floor)
    _add_grid()

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-46, 32, 0)
    key.light_energy = 1.2
    key.shadow_enabled = true
    key.shadow_bias = 0.12
    world.add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-4, 5, 4)
    fill.omni_range = 13
    fill.light_energy = 0.75
    world.add_child(fill)
    camera_pivot = Node3D.new()
    world.add_child(camera_pivot)
    view_camera = Camera3D.new()
    view_camera.fov = 42
    view_camera.current = true
    camera_pivot.add_child(view_camera)

func _add_grid() -> void:
    var lines := ImmediateMesh.new()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color("#506477")
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = 0.28
    lines.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for i in range(-12, 13):
        var f := float(i) * 0.5
        lines.surface_add_vertex(Vector3(f, 0.003, -6))
        lines.surface_add_vertex(Vector3(f, 0.003, 6))
        lines.surface_add_vertex(Vector3(-6, 0.003, f))
        lines.surface_add_vertex(Vector3(6, 0.003, f))
    lines.surface_end()
    var instance := MeshInstance3D.new()
    instance.mesh = lines
    world.add_child(instance)

func _make_materials() -> void:
    materials.clear()
    var hues := [
        Color("#a69c90"), Color("#495661"), Color("#738675"),
        Color("#885c42"), Color("#514d49"), Color("#bdc7c8"),
        Color("#bcb9ab"), Color("#494f58")
    ]
    for index in range(hues.size()):
        var m := StandardMaterial3D.new()
        m.albedo_color = hues[index]
        m.roughness = [0.90, 0.76, 0.93, 0.66, 0.47, 0.28, 0.88, 0.32][index]
        if index == 5 or index == 7: m.metallic = 0.86
        if index == 3: m.clearcoat_enabled = true
        materials.append(m)

func _mesh_for(item: Dictionary) -> Mesh:
    var type_name := str(item.get("shape", "box"))
    match type_name:
        "box":
            var extrude_depth := float(item.get("extrude_depth",0.0))
            var bevel := float(item.get("bevel",0.0))
            if absf(extrude_depth)>0.0001:
                return Solid.build(int(item.get("extrude_face",2)),extrude_depth,float(item.get("inset",0.10)),bevel)
            if bevel>0.0001:
                return Factory.soft_box(1.0,1.0,1.0,bevel,0.0,0.0)
            var base := BoxMesh.new()
            base.size=Vector3.ONE
            return base
        "sphere":
            var sphere := SphereMesh.new()
            sphere.radial_segments = 48
            sphere.rings = 24
            return sphere
        "cylinder":
            var cylinder := CylinderMesh.new()
            cylinder.top_radius = 0.5
            cylinder.bottom_radius = 0.5
            cylinder.height = 1.0
            cylinder.radial_segments = 48
            return cylinder
        "soft":
            return Factory.soft_box(1.0, 1.0, 1.0, 0.13, 0.45, 1.0)
        _:
            var cube := BoxMesh.new()
            cube.size = Vector3.ONE
            return cube

func _build_one(item: Dictionary) -> void:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = str(item["name"])
    mesh_node.mesh = _mesh_for(item)
    mesh_node.position = _v(item["pos"])
    mesh_node.rotation = _v(item["rot"])
    mesh_node.scale = _v(item["size"])
    mesh_node.material_override = materials[clampi(int(item["mat"]), 0, materials.size() - 1)]
    model_root.add_child(mesh_node)
    instances[int(item["id"])] = mesh_node
    for op in item.get("vertex_ops", []):
        _apply_vertex_delta(mesh_node, _v(op["at"]), _v(op["delta"]))

func _sync_scene() -> void:
    for child in model_root.get_children():
        model_root.remove_child(child)
        child.queue_free()
    instances.clear()
    for item in data:
        _build_one(item)
    _show_outline()
    if overlay_label != null:
        overlay_label.text = "МОДЕЛИРОВАНИЕ  /  ОБЪЕКТЫ: %d" % data.size()
    _update_selection_text()

func _v(vals: Array) -> Vector3:
    return Vector3(float(vals[0]), float(vals[1]), float(vals[2]))

func _arr(vec: Vector3) -> Array:
    return [vec.x, vec.y, vec.z]

func _selected_item() -> Dictionary:
    for item in data:
        if int(item["id"]) == selection_id:
            return item
    return {}

func _history() -> void:
    undo_stack.append(JSON.stringify({"objects": data, "id": next_id, "selected": selection_id}))
    if undo_stack.size() > 25: undo_stack.pop_front()
    redo_stack.clear()

func _restore(serialized: String) -> void:
    var root = JSON.parse_string(serialized)
    if not (root is Dictionary): return
    data.clear()
    for obj in root.get("objects", []):
        data.append(obj)
    next_id = int(root.get("id", 1))
    selection_id = int(root.get("selected", -1))
    vertex_index = -1
    _sync_scene()
    _refresh_panel()

func _undo() -> void:
    if undo_stack.is_empty(): return
    redo_stack.append(JSON.stringify({"objects": data, "id": next_id, "selected": selection_id}))
    _restore(undo_stack.pop_back())
    _note("Изменение отменено")

func _redo() -> void:
    if redo_stack.is_empty(): return
    undo_stack.append(JSON.stringify({"objects": data, "id": next_id, "selected": selection_id}))
    _restore(redo_stack.pop_back())
    _note("Изменение возвращено")

func _add_item(shape: String) -> void:
    _history()
    var item := {"id": next_id, "name": _shape_title(shape) + " %d" % next_id,
        "shape": shape, "pos": [0.0, 0.68, 0.0], "rot": [0.0, 0.0, 0.0],
        "size": [1.2, 0.6, 0.7], "mat": 0, "vertex_ops": [],
        "extrude_depth": 0.0, "extrude_face": 2, "inset": 0.10, "bevel": 0.0}
    next_id += 1
    data.append(item)
    selection_id = int(item["id"])
    vertex_index = -1
    _sync_scene()
    _refresh_panel()
    _note("Создан новый объект. Теперь изменяй геометрию.")

func _shape_title(shape: String) -> String:
    match shape:
        "sphere": return "Сфера"
        "cylinder": return "Цилиндр"
        "soft": return "Мягкая форма"
        _: return "Блок"

func _duplicate() -> void:
    var selected := _selected_item()
    if selected.is_empty(): return
    _history()
    var copy: Dictionary = selected.duplicate(true)
    copy["id"] = next_id
    copy["name"] = str(selected["name"]) + " / копия"
    var p := _v(copy["pos"])
    p.x += 0.18
    copy["pos"] = _arr(p)
    next_id += 1
    data.append(copy)
    selection_id = int(copy["id"])
    vertex_index = -1
    _sync_scene()
    _refresh_panel()

func _delete_selected() -> void:
    if selection_id == -1: return
    _history()
    for idx in range(data.size() - 1, -1, -1):
        if int(data[idx]["id"]) == selection_id:
            data.remove_at(idx)
    selection_id = -1
    vertex_index = -1
    _sync_scene()
    _refresh_panel()

func _choose(id: int) -> void:
    selection_id = id
    vertex_index = -1
    _show_outline()
    _update_selection_text()
    _refresh_panel()

func _update_selection_text() -> void:
    if selected_info == null: return
    var item := _selected_item()
    selected_info.text = "Нет выделения" if item.is_empty() else "● %s" % item["name"]

func _set_tab(tab: String) -> void:
    active_tab = tab
    _refresh_panel()

func _refresh_panel() -> void:
    if inspector == null: return
    for old in inspector.get_children():
        inspector.remove_child(old)
        old.queue_free()
    match active_tab:
        "objects": _objects_ui()
        "transform": _transform_ui()
        "mesh": _mesh_ui()
        "materials": _material_ui()
        "files": _file_ui()

func _objects_ui() -> void:
    var label := _text("ДОБАВИТЬ ГЕОМЕТРИЮ", 11, SUBTLE)
    inspector.add_child(label)
    var row := HBoxContainer.new()
    inspector.add_child(row)
    _btn(row, "Блок", _add_item.bind("box"))
    _btn(row, "Сфера", _add_item.bind("sphere"))
    _btn(row, "Цилиндр", _add_item.bind("cylinder"))
    _btn(row, "Мягкая", _add_item.bind("soft"))
    var list := HBoxContainer.new()
    inspector.add_child(list)
    var n := 0
    for item in data:
        if n >= 3: break
        _btn(list, str(item["name"]), _choose.bind(int(item["id"])))
        n += 1
    if data.is_empty():
        inspector.add_child(_text("Пустая сцена. Добавь элемент и начни моделировать.", 12, SUBTLE))
    var actions := HBoxContainer.new()
    inspector.add_child(actions)
    _btn(actions, "Копировать", _duplicate)
    _btn(actions, "Удалить", _delete_selected)

func _transform_ui() -> void:
    var item := _selected_item()
    if item.is_empty():
        inspector.add_child(_text("Выбери модель касанием в 3D-сцене.", 13, SUBTLE))
        return
    for mode in ["pos", "rot", "size"]:
        var row := HBoxContainer.new()
        inspector.add_child(row)
        var title: String = {"pos":"Позиция", "rot":"Поворот", "size":"Размер"}[mode]
        var label := _text(str(title), 12, SUBTLE)
        label.custom_minimum_size.x = 72
        row.add_child(label)
        for axis in range(3):
            var axis_name: String = ["X", "Y", "Z"][axis]
            _btn(row, "%s −" % axis_name, _nudge.bind(mode, axis, -1))
            _btn(row, "%s +" % axis_name, _nudge.bind(mode, axis, 1))
    inspector.add_child(_text("Шаг: 10 мм для позиции/размера, 5° для поворота.", 11, SUBTLE))

func _nudge(field: String, axis: int, direction: int) -> void:
    var item := _selected_item()
    if item.is_empty(): return
    _history()
    var values: Array = item[field].duplicate()
    var step := deg_to_rad(5.0) if field == "rot" else 0.01
    values[axis] = float(values[axis]) + float(direction) * step
    if field == "size": values[axis] = maxf(0.05, float(values[axis]))
    item[field] = values
    _sync_scene()
    _refresh_panel()

func _mesh_ui() -> void:
    var item := _selected_item()
    if item.is_empty():
        inspector.add_child(_text("Выбери объект. Затем открой сетку для редактирования.", 12, SUBTLE))
        return
    if str(item.get("shape","")) == "box":
        inspector.add_child(_text("FACE EDITOR  /  ГРАНИ И ФАСКИ", 11, TEAL))
        var face_row := HBoxContainer.new()
        inspector.add_child(face_row)
        var face_names := ["X+", "X−", "Y+", "Y−", "Z+", "Z−"]
        for i in range(6):
            _btn(face_row, face_names[i], _set_face.bind(i), int(item.get("extrude_face",2))==i)
        var values := HBoxContainer.new()
        inspector.add_child(values)
        _btn(values, "Выдавить +", _edit_profile.bind("extrude_depth",0.05))
        _btn(values, "Вдавить −", _edit_profile.bind("extrude_depth",-0.05))
        _btn(values, "Сброс", _reset_profile)
        var details := HBoxContainer.new()
        inspector.add_child(details)
        _btn(details,"Inset +",_edit_profile.bind("inset",0.02))
        _btn(details,"Inset −",_edit_profile.bind("inset",-0.02))
        _btn(details,"Фаска +",_edit_profile.bind("bevel",0.01))
        _btn(details,"Фаска −",_edit_profile.bind("bevel",-0.01))
        inspector.add_child(_text(
            "Грань %s  •  глубина %.0f мм  •  inset %.0f мм  •  фаска %.0f мм" %
            [face_names[clampi(int(item.get("extrude_face",2)),0,5)],
            float(item.get("extrude_depth",0.0))*1000.0,
            float(item.get("inset",0.10))*1000.0,
            float(item.get("bevel",0.0))*1000.0],11,SUBTLE))
    inspector.add_child(_text("ВЕРШИНЫ / РУЧНАЯ ПРАВКА", 11, SUBTLE))
    var row := HBoxContainer.new()
    inspector.add_child(row)
    _btn(row,"Выбрать вершину",_vertex_mode)
    _btn(row,"Объект",_object_mode)
    if vertex_index >= 0:
        var controls := HBoxContainer.new()
        inspector.add_child(controls)
        for axis in range(3):
            _btn(controls, ["X−","Y−","Z−"][axis], _move_vertex.bind(axis,-1))
            _btn(controls, ["X+","Y+","Z+"][axis], _move_vertex.bind(axis,1))
    else:
        inspector.add_child(_text("Чтобы двигать отдельную вершину, включи выбор и коснись её.",11,SUBTLE))

func _set_face(face: int) -> void:
    var item := _selected_item()
    if item.is_empty(): return
    _history()
    item["extrude_face"] = clampi(face,0,5)
    selected_face = face
    _sync_scene()
    _refresh_panel()

func _edit_profile(property: String, delta: float) -> void:
    var item := _selected_item()
    if item.is_empty() or str(item.get("shape",""))!="box": return
    _history()
    var previous := float(item.get(property,0.0))
    match property:
        "extrude_depth":
            item[property] = clampf(previous+delta,-0.40,0.75)
            if absf(float(item[property]))<0.001: item[property]=0.0
        "inset": item[property]=clampf(previous+delta,0.01,0.38)
        "bevel": item[property]=clampf(previous+delta,0.0,0.13)
    _sync_scene()
    _refresh_panel()
    _note("Изменена реальная геометрия выбранной грани.")

func _reset_profile() -> void:
    var item := _selected_item()
    if item.is_empty(): return
    _history()
    item["extrude_depth"]=0.0
    item["inset"]=0.10
    item["bevel"]=0.0
    _sync_scene()
    _refresh_panel()

func _vertex_mode() -> void:
    tool_mode = "vertex"
    _note("Режим вершин: коснись вершины выделенной модели.")

func _object_mode() -> void:
    tool_mode = "select"
    vertex_index = -1
    _note("Режим выделения объектов.")
    _refresh_panel()

func _material_ui() -> void:
    if selection_id == -1:
        inspector.add_child(_text("Выбери деталь, которой хочешь назначить материал.", 12, SUBTLE))
        return
    inspector.add_child(_text("МАТЕРИАЛ ВЫДЕЛЕННОГО ОБЪЕКТА", 11, SUBTLE))
    var a := HBoxContainer.new()
    inspector.add_child(a)
    var b := HBoxContainer.new()
    inspector.add_child(b)
    var names := ["Лён", "Графит", "Олива", "Кожа", "Орех", "Сталь", "Керамика", "Титан"]
    for i in range(8):
        _btn(a if i < 4 else b, names[i], _assign_material.bind(i))

func _assign_material(id: int) -> void:
    var item := _selected_item()
    if item.is_empty(): return
    _history()
    item["mat"] = id
    _sync_scene()
    _refresh_panel()

func _file_ui() -> void:
    inspector.add_child(_text("ФАЙЛЫ ПРОЕКТА / ЛОКАЛЬНОЕ ХРАНИЛИЩЕ", 11, SUBTLE))
    var a := HBoxContainer.new()
    inspector.add_child(a)
    _btn(a, "Сохранить проект", _save, true)
    _btn(a, "Загрузить", _load_file)
    var b := HBoxContainer.new()
    inspector.add_child(b)
    _btn(b, "Экспорт GLB", _export_glb)
    _btn(b, "Снимок PNG", _export_png)
    inspector.add_child(_text("Экспорт пока сохраняет файлы во внутреннее хранилище Android. Отправку в Downloads добавим отдельно.", 11, SUBTLE))

func _camera_update() -> void:
    if camera_pivot == null: return
    camera_pivot.position = focus
    camera_pivot.rotation = Vector3(orbit_x, orbit_y, 0)
    view_camera.position = Vector3(0, 0, orbit_distance)
    view_camera.look_at(Vector3.ZERO)

func _process(_delta: float) -> void:
    if stage != null and view != null:
        var size := Vector2i(maxi(1, int(stage.size.x)), maxi(1, int(stage.size.y)))
        if size != view.size: view.size = size

func _on_view_event(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            pointers[event.index] = event.position
            touch_origin = event.position
            dragged = false
        else:
            if not dragged and pointers.size() <= 1:
                _tap(event.position)
            pointers.erase(event.index)
    elif event is InputEventScreenDrag:
        if event.position.distance_to(touch_origin) > 8.0: dragged = true
        if pointers.size() > 1:
            orbit_distance = clampf(orbit_distance - event.relative.y * 0.02, 1.25, 12.0)
        else:
            orbit_y -= event.relative.x * 0.008
            orbit_x = clampf(orbit_x - event.relative.y * 0.008, -1.3, 0.25)
        pointers[event.index] = event.position
        _camera_update()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT: _tap(event.position)
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            orbit_distance = maxf(1.25, orbit_distance - 0.3)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            orbit_distance = minf(12, orbit_distance + 0.3)
        _camera_update()
    elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
        orbit_y -= event.relative.x * 0.007
        orbit_x = clampf(orbit_x - event.relative.y * 0.007, -1.3, 0.25)
        _camera_update()

func _tap(point: Vector2) -> void:
    var ray_origin := view_camera.project_ray_origin(point)
    var ray_dir := view_camera.project_ray_normal(point)
    var nearest := INF
    var found: int = -1
    for id in instances.keys():
        var node: MeshInstance3D = instances[id]
        var local_origin := node.to_local(ray_origin)
        var local_dir := (node.to_local(ray_origin + ray_dir * 100) - local_origin).normalized()
        var hit = node.mesh.get_aabb().intersects_ray(local_origin, local_dir)
        if hit is Vector3:
            var world_hit: Vector3 = node.to_global(hit)
            var distance := world_hit.distance_to(ray_origin)
            if distance < nearest:
                nearest = distance
                found = int(id)
    if tool_mode == "vertex" and selection_id >= 0:
        if _pick_vertex(point): return
    if found >= 0:
        _choose(found)
    else:
        _choose(-1)

func _pick_vertex(point: Vector2) -> bool:
    if not instances.has(selection_id): return false
    var node: MeshInstance3D = instances[selection_id]
    var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var closest := 26.0
    var found := -1
    for i in range(vertices.size()):
        var world_pos := node.to_global(vertices[i])
        if view_camera.is_position_behind(world_pos): continue
        var screen := view_camera.unproject_position(world_pos)
        var delta := point.distance_to(screen)
        if delta < closest:
            closest = delta
            found = i
    if found < 0: return false
    vertex_index = found
    _refresh_panel()
    _note("Выделена вершина #%d. Используй X/Y/Z." % found)
    return true

func _move_vertex(axis: int, direction: int) -> void:
    var item := _selected_item()
    if item.is_empty() or vertex_index < 0: return
    var node: MeshInstance3D = instances[selection_id]
    var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if vertex_index >= verts.size(): return
    _history()
    var offset := Vector3.ZERO
    offset[axis] = 0.005 * direction
    var ops: Array = item.get("vertex_ops", [])
    ops.append({"at": _arr(verts[vertex_index]), "delta": _arr(offset)})
    item["vertex_ops"] = ops
    _sync_scene()
    _refresh_panel()
    _note("Вершина перемещена на 5 мм.")

func _apply_vertex_delta(node: MeshInstance3D, original: Vector3, delta: Vector3) -> void:
    var array: Array = node.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = array[Mesh.ARRAY_VERTEX]
    for i in range(vertices.size()):
        if vertices[i].distance_to(original) < 0.0001:
            vertices[i] = vertices[i] + delta
    array[Mesh.ARRAY_VERTEX] = vertices
    var changed := ArrayMesh.new()
    changed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
    node.mesh = changed

func _show_outline() -> void:
    if selection_overlay != null and is_instance_valid(selection_overlay):
        selection_overlay.queue_free()
        selection_overlay = null
    if not instances.has(selection_id): return
    var node: MeshInstance3D = instances[selection_id]
    var bounds := node.mesh.get_aabb()
    var lo := bounds.position
    var hi := bounds.position + bounds.size
    var points := [
        Vector3(lo.x,lo.y,lo.z), Vector3(hi.x,lo.y,lo.z), Vector3(hi.x,lo.y,hi.z), Vector3(lo.x,lo.y,hi.z),
        Vector3(lo.x,hi.y,lo.z), Vector3(hi.x,hi.y,lo.z), Vector3(hi.x,hi.y,hi.z), Vector3(lo.x,hi.y,hi.z)
    ]
    var edges := [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
    var line_mesh := ImmediateMesh.new()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = TEAL
    line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for edge in edges:
        line_mesh.surface_add_vertex(points[edge[0]])
        line_mesh.surface_add_vertex(points[edge[1]])
    line_mesh.surface_end()
    selection_overlay = MeshInstance3D.new()
    selection_overlay.name = "SELECTION_GUIDES_NOT_EXPORTED"
    selection_overlay.mesh = line_mesh
    node.add_child(selection_overlay)

func _save() -> void:
    var f := FileAccess.open("user://zamer_studio_project.json", FileAccess.WRITE)
    if f == null:
        _note("Ошибка записи проекта")
        return
    f.store_string(JSON.stringify({"schema":2, "objects":data, "next_id": next_id}))
    f.close()
    _note("Проект сохранён локально")

func _open_autosave() -> void:
    if not FileAccess.file_exists("user://zamer_studio_project.json"): return
    var file := FileAccess.open("user://zamer_studio_project.json", FileAccess.READ)
    if file == null: return
    var root = JSON.parse_string(file.get_as_text())
    if not (root is Dictionary): return
    data.clear()
    for item in root.get("objects", []): data.append(item)
    next_id = int(root.get("next_id", 1))
    selection_id = -1

func _load_file() -> void:
    _history()
    _open_autosave()
    _sync_scene()
    _refresh_panel()
    _note("Сохранённая сцена открыта")

func _export_glb() -> void:
    DirAccess.make_dir_recursive_absolute("user://exports")
    # Selection guides are editor-only. Remove them from the exported scene.
    var parent: Node = null
    if selection_overlay != null and is_instance_valid(selection_overlay):
        parent = selection_overlay.get_parent()
        parent.remove_child(selection_overlay)
    var exporter := GLTFDocument.new()
    var state := GLTFState.new()
    var err := exporter.append_from_scene(model_root, state)
    if err == OK: err = exporter.write_to_filesystem(state, "user://exports/studio_mesh.glb")
    if parent != null and is_instance_valid(parent) and is_instance_valid(selection_overlay):
        parent.add_child(selection_overlay)
    _note("GLB сохранён во внутреннюю память" if err == OK else "GLB: ошибка %d" % err)

func _export_png() -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("user://renders")
    var err := view.get_texture().get_image().save_png("user://renders/studio_preview.png")
    _note("PNG сохранён во внутреннюю память" if err == OK else "PNG: ошибка %d" % err)

func _note(message: String) -> void:
    if status != null: status.text = message
