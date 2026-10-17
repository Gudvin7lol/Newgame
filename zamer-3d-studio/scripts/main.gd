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
var inspector: VBoxContainer
var active_tab := "model"
var light_style := 0

func _ready() -> void:
    _create_materials()
    _create_ui()
    _create_scene()
    _load()
    _rebuild()
    _camera_move()
    _set_light(0)

func _create_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 0)
    add_child(root)

    var top := PanelContainer.new()
    top.add_theme_stylebox_override("panel",_panel_style(Color("#0b1320"),0))
    root.add_child(top)
    var header := HBoxContainer.new()
    header.custom_minimum_size.y=48
    top.add_child(header)
    var heading := Label.new()
    heading.text = "Z / 3D STUDIO"
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    heading.add_theme_font_size_override("font_size",21)
    heading.add_theme_color_override("font_color",WHITE)
    header.add_child(heading)
    var version := Label.new()
    version.text="WORKSHOP  0.4"
    version.add_theme_font_size_override("font_size",11)
    version.add_theme_color_override("font_color",MINT)
    header.add_child(version)

    var stage := SubViewportContainer.new()
    stage.stretch=true
    stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
    stage.custom_minimum_size.y=220
    stage.mouse_filter=Control.MOUSE_FILTER_STOP
    stage.gui_input.connect(_on_view_input)
    root.add_child(stage)
    view=SubViewport.new()
    view.size=Vector2i(620,820)
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    stage.add_child(view)

    var bar := PanelContainer.new()
    bar.add_theme_stylebox_override("panel",_panel_style(Color("#111d2b"),6))
    root.add_child(bar)
    var bottom := VBoxContainer.new()
    bottom.add_theme_constant_override("separation",5)
    bar.add_child(bottom)

    var tabs := HBoxContainer.new()
    bottom.add_child(tabs)
    _tab_button(tabs,"Геометрия","model")
    _tab_button(tabs,"Материалы","materials")
    _tab_button(tabs,"Освещение","lights")

    inspector=VBoxContainer.new()
    inspector.custom_minimum_size.y=165
    inspector.add_theme_constant_override("separation",5)
    bottom.add_child(inspector)

    var line := HBoxContainer.new()
    bottom.add_child(line)
    _button(line,"Сохранить",_save)
    _button(line,"Открыть",_open_project)
    _button(line,"PNG",_export_png)
    _button(line,"GLB",_export_glb)

    status=Label.new()
    status.add_theme_color_override("font_color",MUTED)
    status.add_theme_font_size_override("font_size",10)
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    status.text="Проведи пальцем по модели, чтобы повернуть"
    bottom.add_child(status)
    _switch_tab("model")

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color=color
    box.set_corner_radius_all(radius)
    box.set_content_margin_all(10)
    return box

func _button(parent: HBoxContainer, title: String, cb: Callable) -> void:
    var b := Button.new()
    b.text=title
    b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    b.custom_minimum_size.y=40
    b.add_theme_font_size_override("font_size",13)
    b.add_theme_color_override("font_color",WHITE)
    b.add_theme_stylebox_override("normal",_panel_style(Color("#243346"),8))
    b.add_theme_stylebox_override("hover",_panel_style(Color("#314a5d"),8))
    b.add_theme_stylebox_override("pressed",_panel_style(Color("#175e5e"),8))
    b.pressed.connect(cb)
    parent.add_child(b)

func _tab_button(row: HBoxContainer,title: String,tab: String) -> void:
    _button(row,title,_switch_tab.bind(tab))

func _switch_tab(tab: String) -> void:
    active_tab=tab
    sw=null
    sd=null
    sh=null
    softness_slider=null
    dims=null
    for child in inspector.get_children():
        inspector.remove_child(child)
        child.queue_free()
    match tab:
        "model": _geometry_controls()
        "materials": _material_controls()
        "lights": _light_controls()
    _sync()

func _geometry_controls() -> void:
    var choices := HBoxContainer.new()
    inspector.add_child(choices)
    _button(choices,"Диван",_select.bind("sofa"))
    _button(choices,"Тумба",_select.bind("cabinet"))
    _button(choices,"Стол",_select.bind("table"))
    dims=Label.new()
    dims.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    dims.add_theme_color_override("font_color",MINT)
    dims.add_theme_font_size_override("font_size",13)
    inspector.add_child(dims)
    sw=_slider(inspector,"Ширина",800.0,3200.0)
    sw.value_changed.connect(func(v: float):
        w=v/1000.0
        _rebuild()
    )
    sd=_slider(inspector,"Глубина",400.0,1600.0)
    sd.value_changed.connect(func(v: float):
        d=v/1000.0
        _rebuild()
    )
    sh=_slider(inspector,"Высота",350.0,2200.0)
    sh.value_changed.connect(func(v: float):
        h=v/1000.0
        _rebuild()
    )
    softness_slider=_slider(inspector,"Мягкость",0.0,100.0)
    softness_slider.value_changed.connect(func(v: float):
        softness=v/100.0
        _rebuild()
    )

func _slider(parent: VBoxContainer,title: String,minimum: float,maximum: float) -> HSlider:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var name := Label.new()
    name.text=title
    name.custom_minimum_size.x=86
    name.add_theme_color_override("font_color",MUTED)
    name.add_theme_font_size_override("font_size",12)
    row.add_child(name)
    var s := HSlider.new()
    s.min_value=minimum
    s.max_value=maximum
    s.step=1.0 if maximum<=100.0 else 10.0
    s.custom_minimum_size.y=23
    s.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    row.add_child(s)
    return s

func _material_controls() -> void:
    var intro := Label.new()
    intro.text="Обивка и отделка • PBR preview"
    intro.add_theme_color_override("font_color",MUTED)
    inspector.add_child(intro)
    var grid := GridContainer.new()
    grid.columns=2
    inspector.add_child(grid)
    var names := ["01  Песочный лён","02  Графит","03  Шалфей букле","04  Коньячная кожа"]
    for i in range(4):
        var b := Button.new()
        b.text=names[i]
        b.custom_minimum_size.y=45
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",13)
        b.add_theme_stylebox_override("normal",_panel_style(Color("#17545a") if i==fabric_id else Color("#273545"),8))
        b.pressed.connect(_set_fabric.bind(i))
        grid.add_child(b)
    var info := Label.new()
    info.text="Изменяй обивку, затем поворачивай модель для проверки фактуры."
    info.add_theme_color_override("font_color",MUTED)
    info.add_theme_font_size_override("font_size",11)
    inspector.add_child(info)

func _light_controls() -> void:
    var intro := Label.new()
    intro.text="Предметная студия • свет и отражения"
    intro.add_theme_color_override("font_color",MUTED)
    inspector.add_child(intro)
    var row := HBoxContainer.new()
    inspector.add_child(row)
    _button(row,"Мягкий свет",_set_light.bind(0))
    _button(row,"Каталог",_set_light.bind(1))
    _button(row,"Контраст",_set_light.bind(2))
    var msg := Label.new()
    msg.text="Освещение не экспортируется в GLB вместе с мебелью."
    msg.add_theme_color_override("font_color",MUTED)
    inspector.add_child(msg)

func _set_fabric(id: int) -> void:
    fabric_id=id
    _create_materials()
    _rebuild()
    _switch_tab("materials")
    _notify("Материал обновлён")

func _set_light(id: int) -> void:
    light_style=id
    if lights.size()<3: return
    var levels: Array = [[1.15,0.8,1.0],[1.6,1.0,1.5],[2.0,0.35,1.85]]
    for i in range(3):
        lights[i].light_energy=levels[id][i]
    _notify("Настройки света применены")

func _open_project() -> void:
    _load()
    _rebuild()
    _notify("Проект загружен")


func _create_scene() -> void:
    var world := Node3D.new()
    view.add_child(world)
    var sky := WorldEnvironment.new()
    world.add_child(sky)
    var ambience := Environment.new()
    ambience.background_mode = Environment.BG_COLOR
    ambience.background_color = Color("#182433")
    ambience.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    ambience.ambient_light_color = Color("#b8c9df")
    ambience.ambient_light_energy = 0.45
    sky.environment = ambience

    model = Node3D.new()
    model.name = "ExportableFurniture"
    world.add_child(model)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#171e29")
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
    var img := Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in range(256):
        for x in range(256):
            var fx:=float(x)
            var fy:=float(y)
            var weave:=sin(fx*1.13)*sin(fy*1.13)
            var n:=float((x*37+y*19+x*y*11)%97)/97.0-0.5
            var softness_weave:=0.92 + 0.048*weave + 0.035*n
            if style==2:
                softness_weave+=0.045*sin(fx*0.16)*sin(fy*0.15)
            if style==3:
                softness_weave=0.91+0.05*n+0.023*sin(fx*0.24+fy*0.31)
            img.set_pixel(x,y,Color(clampf(tone.r*softness_weave,0,1),clampf(tone.g*softness_weave,0,1),clampf(tone.b*softness_weave,0,1),1))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _fabric_normal() -> Texture2D:
    var img:=Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in range(256):
        for x in range(256):
            var gx:=cos(float(x)*1.13)*sin(float(y)*1.13)*0.24
            var gy:=sin(float(x)*1.13)*cos(float(y)*1.13)*0.24
            var normal:=Vector3(-gx,-gy,1.0).normalized()
            img.set_pixel(x,y,Color((normal.x+1.0)*0.5,(normal.y+1.0)*0.5,(normal.z+1.0)*0.5,1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _wood_texture() -> Texture2D:
    var img:=Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in range(256):
        for x in range(256):
            var fx:=float(x)
            var fy:=float(y)
            var grain:=sin(fx*0.21+sin(fy*0.035)*3.0)*0.065+sin(fx*0.53+fy*0.034)*0.026
            var n:=float((x*7+y*17)%53)/53.0*0.04
            var t:=0.88+grain+n
            img.set_pixel(x,y,Color(0.51*t,0.35*t,0.25*t,1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _create_materials() -> void:
    var colors := [Color("#958879"),Color("#454d56"),Color("#63725f"),Color("#935a3a")]
    upholstery=StandardMaterial3D.new()
    upholstery.albedo_texture=_fabric_texture(colors[fabric_id],fabric_id)
    upholstery.roughness=0.9 if fabric_id!=3 else 0.68
    upholstery.normal_enabled=true
    upholstery.normal_scale=0.28 if fabric_id!=3 else 0.17
    upholstery.normal_texture=_fabric_normal()
    upholstery.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

    timber=StandardMaterial3D.new()
    timber.albedo_texture=_wood_texture()
    timber.roughness=0.69
    metallic=StandardMaterial3D.new()
    metallic.albedo_color=Color("#565d64")
    metallic.metallic=0.82
    metallic.roughness=0.3
    edge_mat=StandardMaterial3D.new()
    edge_mat.albedo_color=colors[fabric_id].darkened(0.24)
    edge_mat.roughness=0.95


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

func _round(title: String, size: Vector3, pos: Vector3, radius: float, puff: float, seed: float, mat: Material) -> void:
    var mesh := Factory.soft_box(size.x,size.y,size.z,radius,puff,seed)
    _part(model,title,mesh,pos,mat)

func _sofa() -> void:
    var arm:=clampf(w*0.103,0.13,0.24)
    var inside:=w-2.0*arm-0.028
    var main_seat_y:=0.443
    var seat_height:=0.165
    var seat_depth:=d*0.70
    var seat_z:=d*0.11
    _round("Upholstered foundation",Vector3(w-0.07,0.255,d-0.065),Vector3(0,0.265,0),0.052,0.07,3.0,upholstery)
    _round("Continuous back shell",Vector3(w-0.055,0.48,0.19),Vector3(0,0.59,-d*0.39),0.057,0.35,2.0,upholstery)
    for side in [-1.0,1.0]:
        _round("Upholstered arm",Vector3(arm,0.46,d*0.92),Vector3(side*(w*0.5-arm*0.5),0.54,0),0.057,0.58,4.0+side,upholstery)
    var sections:=3
    var gap:=0.016
    var pad_w:=(inside-gap*float(sections-1))/float(sections)
    var back_h:=maxf(0.29,h-0.46)
    for i in range(sections):
        var xx:=-inside*0.5+(float(i)+0.5)*pad_w+float(i)*gap
        _round("Seat cushion %d" % (i+1),Vector3(pad_w*0.985,seat_height,seat_depth),Vector3(xx,main_seat_y,seat_z),0.052,softness,float(i)+2.0,upholstery)
        _round("Back cushion %d" % (i+1),Vector3(pad_w*0.99,back_h,0.22),Vector3(xx,h-back_h*0.5-0.018,-d*0.295),0.055,softness,float(i)+9.0,upholstery)
        _part(model,"Front seam %d" % (i+1),Factory.welt(pad_w*0.80),Vector3(xx,main_seat_y+0.020,seat_z+seat_depth*0.5-0.006),edge_mat)
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            var leg:=CylinderMesh.new()
            leg.top_radius=0.022
            leg.bottom_radius=0.018
            leg.height=0.14
            _part(model,"Brushed steel leg",leg,Vector3(sx*(w*0.5-0.15),0.07,sz*(d*0.5-0.14)),metallic)

func _cabinet() -> void:
    var ht:=maxf(0.48,h)
    _round("Timber cabinet shell",Vector3(w,ht-0.14,d),Vector3(0,ht*0.5+0.07,0),0.014,0.0,0.0,timber)
    for i in range(3):
        var section:=w/3.0
        var xx:=-w*0.5+section*(float(i)+0.5)
        _round("Solid wood door %d" % (i+1),Vector3(section-0.007,ht-0.195,0.024),Vector3(xx,ht*0.5+0.073,d*0.5+0.013),0.008,0,1.0,timber)
        _round("Recessed handle %d" % (i+1),Vector3(0.012,0.13,0.025),Vector3(xx+section*0.32,ht*0.57,d*0.5+0.041),0.006,0,2,metallic)
    _round("Overhanging top",Vector3(w+0.018,0.03,d+0.018),Vector3(0,ht-0.012,0),0.011,0,1.0,timber)
    _box("Recessed plinth",Vector3(w-0.13,0.10,d-0.12),Vector3(0,0.05,0),metallic)

func _table() -> void:
    var ht:=maxf(0.50,h)
    _round("Solid wood tabletop",Vector3(w,0.05,d),Vector3(0,ht-0.025,0),0.019,0,0,timber)
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            _round("Metal support",Vector3(0.052,ht-0.055,0.052),Vector3(sx*(w*0.5-0.10),(ht-0.055)*0.5,sz*(d*0.5-0.10)),0.011,0,0,metallic)


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
    if sw != null and is_instance_valid(sw): sw.set_value_no_signal(w*1000.0)
    if sd != null and is_instance_valid(sd): sd.set_value_no_signal(d*1000.0)
    if sh != null and is_instance_valid(sh): sh.set_value_no_signal(h*1000.0)
    if softness_slider != null and is_instance_valid(softness_slider): softness_slider.set_value_no_signal(softness*100.0)

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
    camera.look_at(Vector3(0,0.55,0))

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
    if active_tab=="materials": _switch_tab("materials")
    _create_materials()
    _sync()
    _notify("Проект открыт")

func _notify(message: String) -> void:
    if status != null: status.text=message
