extends Control

const Factory = preload("res://scripts/mesh_factory.gd")
const INK := Color("#0c1622")
const PANEL := Color("#172637")
const MUTED := Color("#9db2c0")
const MINT := Color("#44dec2")
const WHITE := Color("#eaf7f9")

var view: SubViewport
var camera: Camera3D
var rig: Node3D
var model: Node3D
var status: Label
var dims: Label
var sw: HSlider
var sd: HSlider
var sh: HSlider
var softness_slider: HSlider
var fabric_select: OptionButton
var lights: Array[Light3D] = []
var kind := "sofa"
var w := 2.32
var d := 0.98
var h := 0.85
var softness := 0.7
var fabric_id := 0
var orbit_y := 0.5
var orbit_x := -0.20
var zoom := 4.4
var pointers: Dictionary = {}
var upholstery: StandardMaterial3D
var timber: StandardMaterial3D
var metallic: StandardMaterial3D
var edge_mat: StandardMaterial3D

func _ready() -> void:
    _create_materials()
    _create_ui()
    _create_scene()
    _load()
    _rebuild()
    _camera_move()

func _create_ui() -> void:
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("separation", 4)
    add_child(outer)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 64
    outer.add_child(header)
    var heading := Label.new()
    heading.text = "  ZAMER  /  3D STUDIO"
    heading.add_theme_color_override("font_color", WHITE)
    heading.add_theme_font_size_override("font_size", 19)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(heading)
    var vers := Label.new()
    vers.text = "NATIVE 0.3  "
    vers.add_theme_color_override("font_color", MINT)
    header.add_child(vers)

    var surface := SubViewportContainer.new()
    surface.stretch = true
    surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
    surface.custom_minimum_size.y = 290
    surface.mouse_filter = Control.MOUSE_FILTER_STOP
    surface.gui_input.connect(_on_view_input)
    outer.add_child(surface)
    view = SubViewport.new()
    view.size = Vector2i(540, 620)
    view.usage = SubViewport.USAGE_3D
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    surface.add_child(view)

    var controls := VBoxContainer.new()
    controls.add_theme_constant_override("separation", 5)
    outer.add_child(controls)
    var choose := HBoxContainer.new()
    controls.add_child(choose)
    _button(choose, "Диван", func(): _select("sofa"))
    _button(choose, "Тумба", func(): _select("cabinet"))
    _button(choose, "Стол", func(): _select("table"))

    dims = Label.new()
    dims.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dims.add_theme_color_override("font_color", MINT)
    controls.add_child(dims)

    sw = _slider(controls, "Ширина", 800.0, 3200.0)
    sw.value_changed.connect(func(v: float):
        w = v / 1000.0
        _rebuild()
    )
    sd = _slider(controls, "Глубина", 400.0, 1600.0)
    sd.value_changed.connect(func(v: float):
        d = v / 1000.0
        _rebuild()
    )
    sh = _slider(controls, "Высота", 350.0, 2200.0)
    sh.value_changed.connect(func(v: float):
        h = v / 1000.0
        _rebuild()
    )
    softness_slider = _slider(controls, "Мягкость", 0.0, 100.0)
    softness_slider.value_changed.connect(func(v: float):
        softness = v / 100.0
        _rebuild()
    )

    var fabrics := HBoxContainer.new()
    controls.add_child(fabrics)
    var title := Label.new()
    title.text = "Материал"
    title.add_theme_color_override("font_color", MUTED)
    fabrics.add_child(title)
    fabric_select = OptionButton.new()
    for name in ["Светлый лен", "Графит", "Букле", "Кожа"]:
        fabric_select.add_item(name)
    fabric_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fabric_select.item_selected.connect(func(id: int):
        fabric_id = id
        _create_materials()
        _rebuild()
    )
    fabrics.add_child(fabric_select)

    var tools := HBoxContainer.new()
    controls.add_child(tools)
    _button(tools, "Свет", _lighting)
    _button(tools, "PNG", _export_png)
    _button(tools, "GLB", _export_glb)
    _button(tools, "Сохранить", _save)
    var load_button := Button.new()
    load_button.text = "Открыть"
    load_button.pressed.connect(func():
        _load()
        _rebuild()
    )
    controls.add_child(load_button)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 11)
    status.add_theme_color_override("font_color", MUTED)
    controls.add_child(status)
    _sync()

func _button(parent: HBoxContainer, label: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = label
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size.y = 42
    b.pressed.connect(cb)
    parent.add_child(b)

func _slider(parent: VBoxContainer, name: String, lower: float, upper: float) -> HSlider:
    var line := HBoxContainer.new()
    parent.add_child(line)
    var label := Label.new()
    label.text = name
    label.custom_minimum_size.x = 86.0
    label.add_theme_color_override("font_color", MUTED)
    line.add_child(label)
    var s := HSlider.new()
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.custom_minimum_size.y = 30.0
    s.min_value = lower
    s.max_value = upper
    s.step = 1.0 if upper == 100.0 else 10.0
    line.add_child(s)
    return s

func _create_scene() -> void:
    var world := Node3D.new()
    view.add_child(world)
    var sky := WorldEnvironment.new()
    world.add_child(sky)
    var ambience := Environment.new()
    ambience.background_mode = Environment.BG_COLOR
    ambience.background_color = Color("#263447")
    ambience.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    ambience.ambient_light_color = Color("#b8c9df")
    ambience.ambient_light_energy = 0.75
    sky.environment = ambience

    model = Node3D.new()
    model.name = "ExportableFurniture"
    world.add_child(model)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#273241")
    floor_material.roughness = 0.92
    var plane := PlaneMesh.new()
    plane.size = Vector2(15,15)
    _part(world, "Studio backdrop", plane, Vector3(0,-0.03,0), floor_material)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,32,0)
    sun.light_energy = 1.6
    sun.shadow_enabled = true
    world.add_child(sun)
    lights.append(sun)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-2.6,3.8,2.7)
    fill.light_energy = 1.2
    fill.omni_range = 10.0
    world.add_child(fill)
    lights.append(fill)
    var rim := OmniLight3D.new()
    rim.position = Vector3(3.5,3.0,-2.5)
    rim.light_energy = 1.5
    rim.omni_range = 12.0
    world.add_child(rim)
    lights.append(rim)

    rig = Node3D.new()
    rig.position = Vector3(0,0.65,0)
    world.add_child(rig)
    camera = Camera3D.new()
    camera.fov = 45.0
    camera.current = true
    rig.add_child(camera)

func _fabric_texture(tone: Color, style: int) -> Texture2D:
    var tex := Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in range(256):
        for x in range(256):
            var weave := sin(float(x)*1.16)*sin(float(y)*1.16)
            var grain := float((x*31 + y*17 + x*y*7)%97)/97.0-0.5
            var variation := 0.95 + 0.06*weave + 0.06*grain
            if style == 2: variation += 0.08*sin(float(x)*0.16)*sin(float(y)*0.18)
            if style == 3: variation = 0.97 + 0.08*grain
            tex.set_pixel(x,y,Color(clampf(tone.r*variation,0,1),clampf(tone.g*variation,0,1),clampf(tone.b*variation,0,1),1))
    tex.generate_mipmaps()
    return ImageTexture.create_from_image(tex)

func _create_materials() -> void:
    var tones := [Color("#b8af9d"), Color("#465064"), Color("#858e79"), Color("#9f6643")]
    upholstery = StandardMaterial3D.new()
    upholstery.albedo_texture = _fabric_texture(tones[fabric_id],fabric_id)
    upholstery.roughness = 0.94 if fabric_id != 3 else 0.63
    timber = StandardMaterial3D.new()
    timber.albedo_color = Color("#775846")
    timber.roughness = 0.55
    metallic = StandardMaterial3D.new()
    metallic.albedo_color = Color("#777e88")
    metallic.metallic = 0.78
    metallic.roughness = 0.36
    edge_mat = StandardMaterial3D.new()
    edge_mat.albedo_color = tones[fabric_id].darkened(0.23)
    edge_mat.roughness = 0.98

func _part(parent: Node3D, title: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = mesh
    node.position = pos
    node.material_override = mat
    parent.add_child(node)
    return node

func _box(title: String, size: Vector3, pos: Vector3, mat: Material) -> void:
    var cube := BoxMesh.new()
    cube.size = size
    _part(model,title,cube,pos,mat)

func _soft(title: String, size: Vector3, pos: Vector3, seed: float) -> void:
    _part(model,title,Factory.cushion(size.x,size.y,size.z,softness,seed),pos,upholstery)

func _sofa() -> void:
    var arm := minf(0.23,w*0.12)
    var usable := w - arm*2.0 - 0.05
    _box("Frame",Vector3(w-0.06,0.19,d-0.06),Vector3(0,0.29,0),timber)
    _soft("Left upholstered arm",Vector3(arm,0.48,d*0.94),Vector3(-w*0.5+arm*0.5,0.55,0),0.2)
    _soft("Right upholstered arm",Vector3(arm,0.48,d*0.94),Vector3(w*0.5-arm*0.5,0.55,0),1.2)
    for i in range(3):
        var pad_w := (usable-0.028)/3.0
        var xx := -usable*0.5 + (float(i)+0.5)*pad_w + float(i)*0.014
        var sz := Vector3(pad_w*0.975,0.18,d*0.64)
        var pos := Vector3(xx,0.47,d*0.13)
        _soft("Seat cushion %d" % i,sz,pos,float(i)*0.7)
        _part(model,"Piping %d" % i,Factory.piping(sz.x,sz.z,-0.01,softness),pos,edge_mat)
        var back_h := maxf(0.24,h-0.39)
        var back := _part(model,"Back cushion %d" % i,Factory.cushion(pad_w*0.975,back_h,d*0.30,softness,7.0+float(i)),Vector3(xx,h-back_h*0.5,-d*0.33),upholstery)
        back.rotation.x = -0.06
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            var leg := CylinderMesh.new()
            leg.top_radius = 0.025
            leg.bottom_radius = 0.018
            leg.height = 0.13
            _part(model,"Metal leg",leg,Vector3(sx*(w*0.5-0.12),0.065,sz*(d*0.5-0.12)),metallic)

func _cabinet() -> void:
    var ht := maxf(h,0.5)
    _box("Body",Vector3(w,ht-0.14,d),Vector3(0,ht*0.5+0.06,0),timber)
    for i in range(3):
        var section := w/3.0
        var x := -w*0.5 + section*(float(i)+0.5)
        _box("Door",Vector3(section-0.008,ht-0.19,0.019),Vector3(x,ht*0.5+0.06,d*0.5+0.01),upholstery)
        _box("Handle",Vector3(0.014,0.12,0.022),Vector3(x+section*0.31,ht*0.52,d*0.5+0.032),metallic)
    _box("Plinth",Vector3(w-0.1,0.11,d-0.06),Vector3(0,0.055,0),metallic)

func _table() -> void:
    var ht := maxf(h,0.5)
    _box("Table top",Vector3(w,0.055,d),Vector3(0,ht-0.027,0),timber)
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            _box("Steel support",Vector3(0.05,ht-0.055,0.05),Vector3(sx*(w*0.5-0.10),(ht-0.055)*0.5,sz*(d*0.5-0.10)),metallic)

func _rebuild() -> void:
    if model == null: return
    for child in model.get_children():
        model.remove_child(child)
        child.queue_free()
    match kind:
        "sofa": _sofa()
        "cabinet": _cabinet()
        "table": _table()
    _sync()

func _sync() -> void:
    if dims != null:
        dims.text = "%.0f × %.0f × %.0f мм" % [w*1000.0,d*1000.0,h*1000.0]
    if sw != null: sw.set_value_no_signal(w*1000.0)
    if sd != null: sd.set_value_no_signal(d*1000.0)
    if sh != null: sh.set_value_no_signal(h*1000.0)
    if softness_slider != null: softness_slider.set_value_no_signal(softness*100.0)

func _select(which: String) -> void:
    kind = which
    match kind:
        "sofa":
            w=2.32
            d=0.98
            h=0.85
        "cabinet":
            w=1.7
            d=0.46
            h=0.75
        "table":
            w=1.55
            d=0.84
            h=0.75
    _rebuild()
    _notify("Выбрано: " + which)

func _on_view_input(ev: InputEvent) -> void:
    if ev is InputEventScreenTouch:
        if ev.pressed: pointers[ev.index]=ev.position
        else: pointers.erase(ev.index)
    elif ev is InputEventScreenDrag:
        if pointers.size()>1:
            zoom=clampf(zoom-ev.relative.y*0.013,1.7,9.0)
        else:
            orbit_y -= ev.relative.x*0.007
            orbit_x=clampf(orbit_x-ev.relative.y*0.007,-1.2,0.35)
        pointers[ev.index]=ev.position
        _camera_move()
    elif ev is InputEventMouseMotion:
        if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0:
            orbit_y -= ev.relative.x*0.007
            orbit_x=clampf(orbit_x-ev.relative.y*0.007,-1.2,0.35)
            _camera_move()
    elif ev is InputEventMouseButton and ev.pressed:
        if ev.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=maxf(1.7,zoom-0.3)
        if ev.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=minf(9.0,zoom+0.3)
        _camera_move()

func _camera_move() -> void:
    if rig == null: return
    rig.rotation=Vector3(orbit_x,orbit_y,0)
    camera.position=Vector3(0,0,zoom)
    camera.look_at(Vector3.ZERO)

func _lighting() -> void:
    if lights.size()<3: return
    var bright := lights[0].light_energy<2.0
    lights[0].light_energy=2.5 if bright else 1.6
    lights[1].light_energy=1.8 if bright else 1.2
    _notify("Студийный свет изменён")

func _export_png() -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("user://renders")
    var p := "user://renders/model.png"
    var err := view.get_texture().get_image().save_png(p)
    _notify("PNG сохранён во внутренней памяти" if err==OK else "Ошибка PNG: %d" % err)

func _export_glb() -> void:
    DirAccess.make_dir_recursive_absolute("user://exports")
    var gltf := GLTFDocument.new()
    var state := GLTFState.new()
    var err := gltf.append_from_scene(model,state)
    if err==OK:
        err=gltf.write_to_filesystem(state,"user://exports/model.glb")
    _notify("GLB сохранён во внутренней памяти" if err==OK else "Ошибка GLB: %d" % err)

func _save() -> void:
    var data := {"kind":kind,"w":w,"d":d,"h":h,"softness":softness,"fabric":fabric_id,"schema":1}
    var f := FileAccess.open("user://project.json",FileAccess.WRITE)
    if f==null:
        _notify("Не удалось сохранить проект")
        return
    f.store_string(JSON.stringify(data))
    f.close()
    _notify("Проект сохранён")

func _load() -> void:
    if not FileAccess.file_exists("user://project.json"): return
    var f := FileAccess.open("user://project.json",FileAccess.READ)
    if f==null: return
    var data = JSON.parse_string(f.get_as_text())
    if not (data is Dictionary): return
    kind = str(data.get("kind","sofa"))
    w = float(data.get("w",2.32))
    d = float(data.get("d",0.98))
    h = float(data.get("h",0.85))
    softness = float(data.get("softness",0.7))
    fabric_id = int(data.get("fabric",0))
    fabric_select.select(fabric_id)
    _create_materials()
    _sync()
    _notify("Проект открыт")

func _notify(message: String) -> void:
    if status != null: status.text=message
