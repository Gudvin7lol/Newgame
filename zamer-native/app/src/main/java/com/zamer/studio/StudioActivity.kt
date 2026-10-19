package com.zamer.studio

import android.app.Activity
import android.graphics.Color
import android.text.InputType
import android.widget.EditText
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.content.Intent
import android.os.Build
import android.view.WindowInsets
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.CheckBox
import android.widget.SeekBar
import android.widget.TextView
import java.io.File
import kotlin.math.hypot

/** Offline native modeling sandbox. No Godot, browser, Three.js or external runtime. */
class StudioActivity : Activity() {
    private enum class Tool { CAMERA, OBJECT, FACE, VERTEX, EDGE, MOVE, ROTATE, SCALE }
    private var tool = Tool.OBJECT
    private var axis = 0
    private var amountInput: EditText? = null
    private lateinit var surface: GLSurfaceView
    private lateinit var inspector: TextView
    private lateinit var graphicsStatus: TextView
    private var engine: Long = 0L
    private var glbForSave: ByteArray? = null
    private val glbExportRequest = 4129
    private var previousX = 0f
    private var previousY = 0f
    private var previousPinch = 0f
    private var previousMidX = 0f
    private var previousMidY = 0f
    private var firstRenderReport = true
    private var frames: Int = 0
    private var moved: Boolean = false
    private var startX = 0f
    private var startY = 0f
    private val bg = Color.rgb(11, 18, 29)
    private val panel = Color.rgb(20, 33, 48)
    private val accent = Color.rgb(59, 219, 196)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = bg
        window.navigationBarColor = bg
        engine = Native.create()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bg)
        }
        val brand = TextView(this).apply {
            text = "Z / ENGINE    •    CORE 1.1"
            setTextColor(Color.WHITE)
            textSize = 17f
            setPadding(18.dp(), 9.dp(), 12.dp(), 9.dp())
        }
        val toolbar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        toolbar.addView(brand, LinearLayout.LayoutParams(0, 42.dp(), 1f))
        fun historyButton(title: String, redo: Boolean): Button = Button(this).apply {
            text = title
            textSize = 13f
            setTextColor(accent)
            setPadding(0, 0, 0, 0)
            setBackgroundColor(panel)
            setOnClickListener {
                surface.queueEvent {
                    val ok = if (redo) Native.redo(engine) else Native.undo(engine)
                    val info = Native.sceneInfo(engine)
                    runOnUiThread { inspector.text = if (ok) info else "История пуста" }
                }
            }
        }
        toolbar.addView(historyButton("↶", false), LinearLayout.LayoutParams(48.dp(), 42.dp()))
        toolbar.addView(historyButton("↷", true), LinearLayout.LayoutParams(48.dp(), 42.dp()))
        root.addView(toolbar)

        surface = GLSurfaceView(this).apply {
            setEGLContextClientVersion(3)
            // Widely supported RGB888 / depth16 EGL config.
            setEGLConfigChooser(8, 8, 8, 0, 16, 0)
            preserveEGLContextOnPause = true
            setRenderer(object : GLSurfaceView.Renderer {
                override fun onSurfaceCreated(gl: javax.microedition.khronos.opengles.GL10?,
                                              config: javax.microedition.khronos.egl.EGLConfig?) {
                    firstRenderReport = true
                    Native.initGl(engine)
                    val status = Native.graphicsStatus(engine)
                    runOnUiThread { graphicsStatus.text = status }
                }
                override fun onSurfaceChanged(gl: javax.microedition.khronos.opengles.GL10?, width: Int, height: Int) {
                    Native.resize(engine, width, height)
                    val status = Native.graphicsStatus(engine)
                    runOnUiThread { graphicsStatus.text = status }
                }
                override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) {
                    Native.draw(engine)
                    if (firstRenderReport || (++frames % 45 == 0)) {
                        firstRenderReport = false
                        val report = Native.graphicsStatus(engine)
                        runOnUiThread { graphicsStatus.text = report }
                    }
                }
            })
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            setOnTouchListener { _: View, event: MotionEvent ->
                if (event.pointerCount >= 2) {
                    val d = hypot(event.getX(0)-event.getX(1), event.getY(0)-event.getY(1))
                    val midX = (event.getX(0)+event.getX(1))*0.5f
                    val midY = (event.getY(0)+event.getY(1))*0.5f
                    if (previousPinch > 0f && event.actionMasked == MotionEvent.ACTION_MOVE) {
                        val scale = (d / previousPinch).coerceIn(0.75f, 1.25f)
                        val dx = (midX-previousMidX).coerceIn(-80f,80f)
                        val dy = (midY-previousMidY).coerceIn(-80f,80f)
                        queueEvent { Native.zoom(engine,scale); Native.pan(engine,dx,dy) }
                    }
                    previousPinch=d
                    previousMidX=midX
                    previousMidY=midY
                    return@setOnTouchListener true
                }
                previousPinch=0f
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        previousX = event.x
                        previousY = event.y
                        startX = event.x
                        startY = event.y
                        moved = false
                        if (tool == Tool.MOVE || tool == Tool.SCALE) {
                            val px = event.x
                            val py = event.y
                            queueEvent { Native.beginGizmo(engine, px, py) }
                        } else {
                            queueEvent { Native.endGizmo(engine) }
                        }
                    }
                    MotionEvent.ACTION_UP -> {
                        queueEvent { Native.endGizmo(engine) }
                        if (!moved) {
                            val px = event.x
                            val py = event.y
                            queueEvent {
                                val selected = when (tool) {
                                    Tool.FACE -> Native.pickFace(engine, px, py)
                                    Tool.VERTEX -> Native.pickElement(engine, px, py, 1)
                                    Tool.EDGE -> Native.pickElement(engine, px, py, 2)
                                    else -> Native.pick(engine, px, py)
                                }
                                val info = Native.sceneInfo(engine)
                                runOnUiThread {
                                    inspector.text = if (selected >= 0) info else "Коснись объекта для выделения"
                                }
                            }
                        }
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = event.x - previousX
                        val dy = event.y - previousY
                        if (hypot(event.x - startX, event.y - startY) > 8.dp()) moved = true
                        previousX = event.x
                        previousY = event.y
                        val activeTool = tool
                        val lockedAxis = axis
                        queueEvent {
                            when (activeTool) {
                                Tool.MOVE -> Native.dragGizmo(engine, dx, dy)
                                Tool.ROTATE -> Native.dragRotate(engine, dx, dy)
                                Tool.SCALE -> Native.dragGizmo(engine, dx, dy)
                                else -> Native.orbit(engine, dx*0.008f, dy*0.008f)
                            }
                        }
                    }
                }
                true
            }
        }
        root.addView(surface, LinearLayout.LayoutParams(-1, 0, 1f))

        graphicsStatus = TextView(this).apply {
            text = "GPU: ожидание OpenGL ES 3.0"
            setTextColor(accent)
            textSize = 11f
            setPadding(12.dp(), 5.dp(), 12.dp(), 6.dp())
            setBackgroundColor(Color.rgb(18, 36, 52))
        }
        root.addView(graphicsStatus)

        inspector = TextView(this).apply {
            text = "3D-сцена • C++ геометрия • OpenGL ES 3"
            textSize = 12f
            setTextColor(accent)
            setPadding(18, 16, 16, 12)
            setBackgroundColor(panel)
        }
        root.addView(inspector)

        fun controls(parent: LinearLayout, vararg items: Pair<String, () -> Unit>) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setBackgroundColor(panel)
            }
            for ((title, action) in items) {
                val button = Button(this).apply {
                    text = title
                    textSize = 10f
                    setPadding(0,0,0,0)
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.rgb(34, 55, 72))
                    setOnClickListener { action() }
                }
                row.addView(button, LinearLayout.LayoutParams(0, 44.dp(), 1f).apply {
                    setMargins(2.dp(), 2.dp(), 2.dp(), 2.dp())
                })
            }
            parent.addView(row)
        }
        fun act(action: () -> Unit) {
            surface.queueEvent {
                action()
                val text = Native.sceneInfo(engine)
                runOnUiThread { inspector.text = text }
            }
        }
        val tabs = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val actions = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(tabs)
        root.addView(actions)

        fun activate(mode: Tool) {
            tool = mode
            val gizmoMode = when(mode) {
                Tool.MOVE -> 1
                Tool.ROTATE -> 2
                Tool.SCALE -> 3
                else -> 0
            }
            val elementMode = when(mode) {
                Tool.VERTEX -> 1
                Tool.EDGE -> 2
                else -> 0
            }
            surface.queueEvent {
                Native.setGizmoMode(engine, gizmoMode)
                Native.setElementMode(engine, elementMode)
            }
            inspector.text = when(mode) {
                Tool.CAMERA -> "Камера: вращение пальцем, приближение двумя."
                Tool.OBJECT -> "Выбери объект одним касанием."
                Tool.FACE -> "Выбери конкретную грань касанием."
                Tool.VERTEX -> "Вершины: выбери точку на модели. Для сдвига открой «Трансформ.»."
                Tool.EDGE -> "Рёбра: выбери линию сетки. Для сдвига открой «Трансформ.»."
                Tool.MOVE -> "Move: захвати цветную стрелку X / Y / Z и потяни."
                Tool.SCALE -> "Scale: захвати цветную ось на модели и потяни."
                Tool.ROTATE -> "Rotate: поворот только вокруг оси Y."
            }
        }

        fun exact(sign: Int) {
            val value = amountInput?.text?.toString()?.toFloatOrNull()
            if (value == null || !value.isFinite() || value < -10000f || value > 10000f) {
                inspector.text = "Нужен числовой шаг от −10000 до 10000."
                return
            }
            val mode = when(tool) {
                Tool.MOVE -> 0
                Tool.ROTATE -> 1
                Tool.SCALE -> 2
                else -> -1
            }
            if (tool == Tool.VERTEX || tool == Tool.EDGE) {
                val selectedAxis = axis
                act { Native.nudgeElement(engine, selectedAxis, value / 1000f * sign) }
                return
            }
            if(mode < 0) {
                inspector.text = "Выбери Move, Rotate Y, Scale, Вершину или Ребро."
                return
            }
            val targetAxis = if(mode==1) 1 else axis
            val amount = if(mode==1) Math.toRadians(value.toDouble()).toFloat()
                         else value/1000f
            act { Native.transform(engine, mode, targetAxis, amount*sign) }
        }

        fun page(index: Int) {
            actions.removeAllViews()
            when(index) {
                0 -> {
                    controls(actions,
                        "Блок" to { act { Native.add(engine, 0) } },
                        "Сфера" to { act { Native.add(engine, 1) } },
                        "Цилиндр" to { act { Native.add(engine, 2) } },
                        "След." to { act { Native.selectNext(engine) } }
                    )
                    controls(actions,
                        "Объект" to { activate(Tool.OBJECT) },
                        "Грань" to { activate(Tool.FACE) },
                        "Вершина" to { activate(Tool.VERTEX) },
                        "Ребро" to { activate(Tool.EDGE) },
                        "Камера" to { activate(Tool.CAMERA) }
                    )
                    controls(actions,
                        "Дублировать" to { surface.queueEvent {
                            val ok = Native.duplicate(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                inspector.text = if (ok) "Объект скопирован.\n$info"
                                    else "Не удалось дублировать объект (лимит: 64)."
                            }
                        } },
                        "Удалить" to { surface.queueEvent {
                            val ok = Native.deleteSelected(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                inspector.text = if (ok) "Объект удалён. ↶ для отмены.\n$info"
                                    else "Сначала выбери объект для удаления."
                            }
                        } }
                    )
                    controls(actions,
                        "В центре" to { surface.queueEvent {
                            val ok=Native.focusSelected(engine)
                            runOnUiThread { inspector.text=if(ok) "Камера наведена на объект. Два пальца: панорамирование и масштаб."
                                else "Выбери объект." }
                        } }
                    )
                }
                3 -> {
                    controls(actions,
                        "Грань" to { activate(Tool.FACE) },
                        "Ребро" to { activate(Tool.EDGE) },
                        "Вершина" to { activate(Tool.VERTEX) },
                        "Камера" to { activate(Tool.CAMERA) }
                    )
                    controls(actions,
                        "Extrude +" to { act { Native.extrude(engine, 0.05f) } },
                        "Extrude −" to { act { Native.extrude(engine, -0.05f) } },
                        "Inset" to { act { Native.inset(engine, 0.10f) } },
                        "Subdivide" to { act { Native.subdivide(engine) } }
                    )
                    controls(actions,
                        "Loop Cut" to { surface.queueEvent {
                            val ok = Native.loopCut(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                if (ok) tool = Tool.VERTEX
                                inspector.text = if (ok) "Loop Cut выполнен.\n" + info
                                else "Loop Cut: выбери ребро цепочки четырёхугольников."
                            }
                        } },
                        "Split Edge" to { surface.queueEvent {
                            val ok = Native.splitEdge(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                if (ok) tool = Tool.VERTEX
                                inspector.text = if (ok) "Ребро разделено.\n" + info
                                else "Split Edge: выбери ребро."
                            }
                        } },
                        "Mark A" to { surface.queueEvent {
                            val ok = Native.markBridgeFace(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                inspector.text = if (ok) "Грань A отмечена. Выбери противоположную грань B, затем Bridge.\n" + info
                                else "Для Mark A выбери четырёхугольную грань."
                            }
                        } },
                        "Bridge" to { surface.queueEvent {
                            val ok = Native.bridgeFaces(engine)
                            val info = Native.sceneInfo(engine)
                            runOnUiThread {
                                if (ok) tool = Tool.FACE
                                inspector.text = if (ok) "Bridge: внутренний канал создан.\n" + info
                                else "Bridge: нужны противоположные квад-граня одного объекта. Сначала Mark A."
                            }
                        } }
                    )
                    val bevelRow = LinearLayout(this).apply {
                        orientation = LinearLayout.HORIZONTAL
                        setBackgroundColor(panel)
                        setPadding(5.dp(), 0, 5.dp(), 0)
                    }
                    bevelRow.addView(TextView(this).apply {
                        text = "Радиус, мм"
                        textSize = 12f
                        setTextColor(accent)
                    }, LinearLayout.LayoutParams(85.dp(), 42.dp()))
                    val bevelInput = EditText(this).apply {
                        setText("20")
                        textSize = 13f
                        setTextColor(Color.WHITE)
                        setSingleLine(true)
                        inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    }
                    bevelRow.addView(bevelInput, LinearLayout.LayoutParams(0, 42.dp(), 1f))
                    bevelRow.addView(TextView(this).apply {
                        text = "Сегм."
                        textSize = 11f
                        setTextColor(accent)
                        gravity = android.view.Gravity.CENTER_VERTICAL
                    }, LinearLayout.LayoutParams(45.dp(), 42.dp()))
                    val bevelSegments = EditText(this).apply {
                        setText("4")
                        textSize = 13f
                        setTextColor(Color.WHITE)
                        setSingleLine(true)
                        setSelectAllOnFocus(true)
                        inputType = InputType.TYPE_CLASS_NUMBER
                    }
                    bevelRow.addView(bevelSegments, LinearLayout.LayoutParams(39.dp(), 42.dp()))
                    bevelRow.addView(Button(this).apply {
                        text = "Bevel"
                        isAllCaps = false
                        textSize = 12f
                        setOnClickListener {
                            val mm = bevelInput.text.toString().toFloatOrNull()
                            val segments = bevelSegments.text.toString().toIntOrNull()
                            if (mm == null || !mm.isFinite() || mm <= 0f || mm > 100f ||
                                segments == null || segments !in 1..8) {
                                inspector.text = "Bevel: ширина 0–100 мм, количество сегментов от 1 до 8."
                            } else {
                                surface.queueEvent {
                                    val ok = Native.bevelEdge(engine, mm / 1000f, segments)
                                    val info = Native.sceneInfo(engine)
                                    runOnUiThread {
                                        if (ok) tool = Tool.FACE
                                        inspector.text = if (ok) "Bevel $mm мм, сегментов $segments.\n$info"
                                            else "Bevel: поддерживается выпуклое внешнее ребро. Проверь ширину."
                                    }
                                }
                            }
                        }
                    }, LinearLayout.LayoutParams(105.dp(), 42.dp()))
                    actions.addView(bevelRow)
                }
                1 -> {
                    controls(actions,
                        "Move" to { activate(Tool.MOVE) },
                        "Rotate Y" to { axis = 1; activate(Tool.ROTATE) },
                        "Scale" to { activate(Tool.SCALE) },
                        "Вершина" to { activate(Tool.VERTEX) },
                        "Ребро" to { activate(Tool.EDGE) }
                    )
                    controls(actions,
                        "Ось X" to { axis = 0; inspector.text = "Выбрана ось X" },
                        "Ось Y" to { axis = 1; inspector.text = "Выбрана ось Y" },
                        "Ось Z" to { axis = 2; inspector.text = "Выбрана ось Z" }
                    )
                    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                    row.addView(TextView(this).apply {
                        text = "Шаг, мм/°"
                        setTextColor(accent)
                        textSize = 12f
                    }, LinearLayout.LayoutParams(94.dp(), 38.dp()))
                    val field = EditText(this).apply {
                        setText("10")
                        setTextColor(Color.WHITE)
                        textSize = 13f
                        setSingleLine(true)
                        inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL or InputType.TYPE_NUMBER_FLAG_SIGNED
                    }
                    amountInput = field
                    row.addView(field, LinearLayout.LayoutParams(0, 42.dp(), 1f))
                    row.addView(Button(this).apply {
                        text = "−"
                        setOnClickListener { exact(-1) }
                    }, LinearLayout.LayoutParams(55.dp(), 42.dp()))
                    row.addView(Button(this).apply {
                        text = "+"
                        setOnClickListener { exact(1) }
                    }, LinearLayout.LayoutParams(55.dp(), 42.dp()))
                    actions.addView(row)
                }
                4 -> {
                    val swatch=TextView(this).apply {
                        text="Цвет выбранного объекта"
                        textSize=12f
                        setTextColor(Color.WHITE)
                        setPadding(12.dp(),9.dp(),12.dp(),9.dp())
                        setBackgroundColor(Color.rgb(122,132,144))
                    }
                    actions.addView(swatch,LinearLayout.LayoutParams(-1,40.dp()))
                    val colorRow=LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL }
                    colorRow.addView(TextView(this).apply {
                        text="HEX #"
                        textSize=12f
                        setTextColor(accent)
                        gravity=android.view.Gravity.CENTER_VERTICAL
                    },LinearLayout.LayoutParams(65.dp(),40.dp()))
                    val hex=EditText(this).apply {
                        setText("9E8C75")
                        setSingleLine(true)
                        setTextColor(Color.WHITE)
                        textSize=13f
                        setSelectAllOnFocus(true)
                        inputType=InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
                    }
                    colorRow.addView(hex,LinearLayout.LayoutParams(0,40.dp(),1f))
                    fun sliderRow(name:String,value:Int):Pair<SeekBar,TextView>{
                        val row=LinearLayout(this).apply {
                            orientation=LinearLayout.HORIZONTAL
                            setBackgroundColor(panel)
                        }
                        val label=TextView(this).apply {
                            text=name + ": " + value + "%"
                            textSize=11f
                            setTextColor(accent)
                            gravity=android.view.Gravity.CENTER_VERTICAL
                        }
                        row.addView(label,LinearLayout.LayoutParams(122.dp(),42.dp()))
                        val seek=SeekBar(this).apply {
                            max=100
                            progress=value
                        }
                        row.addView(seek,LinearLayout.LayoutParams(0,42.dp(),1f))
                        actions.addView(row)
                        return seek to label
                    }
                    val metallicRow=sliderRow("Metallic",0)
                    val roughnessRow=sliderRow("Roughness",70)
                    val metallic=metallicRow.first
                    val roughness=roughnessRow.first
                    fun showValues(){
                        metallicRow.second.text="Metallic: " + metallic.progress + "%"
                        roughnessRow.second.text="Roughness: " + roughness.progress + "%"
                    }
                    fun setSwatch(rgb:Int){
                        swatch.setBackgroundColor(Color.rgb((rgb shr 16) and 255,(rgb shr 8) and 255,rgb and 255))
                    }
                    fun applyPbr(){
                        val value=hex.text.toString().trim().removePrefix("#")
                        if(!value.matches(Regex("[0-9a-fA-F]{6}"))){
                            inspector.text="HEX: требуется 6 цифр, например B89B80."
                            return
                        }
                        val rgb=value.toInt(16)
                        val metal=metallic.progress/100f
                        val rough=(roughness.progress.coerceAtLeast(4))/100f
                        surface.queueEvent {
                            Native.checkpoint(engine)
                            val ok=Native.setPbr(engine,rgb,metal,rough)
                            val info=Native.sceneInfo(engine)
                            runOnUiThread {
                                if(ok)setSwatch(rgb)
                                inspector.text=if(ok)"PBR обновлён.\n"+info else "Выбери объект."
                            }
                        }
                    }
                    colorRow.addView(Button(this).apply {
                        text="Применить"
                        isAllCaps=false
                        textSize=10f
                        setOnClickListener { applyPbr() }
                    },LinearLayout.LayoutParams(110.dp(),40.dp()))
                    // Keep editable controls compact, with actual viewport available above.
                    actions.addView(colorRow,0)
                    val sliderListener=object:SeekBar.OnSeekBarChangeListener{
                        override fun onProgressChanged(bar:SeekBar?,progress:Int,fromUser:Boolean){
                            if(fromUser&&bar===roughness&&progress<4)roughness.progress=4
                            showValues()
                        }
                        override fun onStartTrackingTouch(bar:SeekBar?){}
                        override fun onStopTrackingTouch(bar:SeekBar?){applyPbr()}
                    }
                    metallic.setOnSeekBarChangeListener(sliderListener)
                    roughness.setOnSeekBarChangeListener(sliderListener)
                    val smoothing=CheckBox(this).apply {
                        text="Smooth shading"
                        textSize=12f
                        setTextColor(Color.WHITE)
                        setBackgroundColor(panel)
                    }
                    actions.addView(smoothing,LinearLayout.LayoutParams(-1,40.dp()))
                    val presets=listOf("Ткань","Кожа","Дерево","Металл","Олива")
                    controls(actions,*presets.mapIndexed { id,name ->
                        name to {
                            surface.queueEvent {
                                Native.material(engine,id)
                                val state=Native.materialState(engine)
                                val info=Native.sceneInfo(engine)
                                runOnUiThread {
                                    val fields=state.split("|")
                                    if(fields.size>=5){
                                        hex.setText(fields[0])
                                        metallic.progress=((fields[1].toFloatOrNull()?:0f)*100).toInt()
                                        roughness.progress=((fields[2].toFloatOrNull()?:0.7f)*100).toInt()
                                        setSwatch(fields[0].toIntOrNull(16)?:0)
                                    }
                                    inspector.text=info
                                }
                            }
                        }
                    }.toTypedArray())
                    val uvRow=LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL }
                    uvRow.addView(TextView(this).apply {
                        text="UV масштаб"
                        textSize=12f
                        setTextColor(accent)
                        gravity=android.view.Gravity.CENTER_VERTICAL
                    },LinearLayout.LayoutParams(105.dp(),42.dp()))
                    val uvInput=EditText(this).apply {
                        setText("1.0")
                        setSingleLine(true)
                        setTextColor(Color.WHITE)
                        inputType=InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                        textSize=13f
                    }
                    uvRow.addView(uvInput,LinearLayout.LayoutParams(0,42.dp(),1f))
                    var pattern=0
                    fun applyPattern(selected:Int){
                        val scale=uvInput.text.toString().toFloatOrNull()
                        if(scale==null||!scale.isFinite()||scale !in 0.1f..10f){
                            inspector.text="UV масштаб должен быть от 0.1 до 10."
                            return
                        }
                        pattern=selected
                        surface.queueEvent {
                            Native.checkpoint(engine)
                            val ok=Native.setPattern(engine,selected,scale)
                            val info=Native.sceneInfo(engine)
                            runOnUiThread { inspector.text=if(ok)"UV-рисунок применён.\n$info" else "Выбери объект." }
                        }
                    }
                    uvRow.addView(Button(this).apply {
                        text="Применить"
                        textSize=10f
                        isAllCaps=false
                        setOnClickListener { applyPattern(pattern) }
                    },LinearLayout.LayoutParams(110.dp(),42.dp()))
                    actions.addView(uvRow)
                    controls(actions,
                        "Без" to { applyPattern(0) },
                        "Ткань" to { applyPattern(1) },
                        "Дерево" to { applyPattern(2) },
                        "Кожа" to { applyPattern(3) },
                        "Металл" to { applyPattern(4) }
                    )
                    surface.queueEvent {
                        val state=Native.materialState(engine)
                        runOnUiThread {
                            val fields=state.split("|")
                            if(fields.size>=5){
                                hex.setText(fields[0])
                                metallic.progress=((fields[1].toFloatOrNull()?:0f)*100).toInt().coerceIn(0,100)
                                roughness.progress=((fields[2].toFloatOrNull()?:0.7f)*100).toInt().coerceIn(4,100)
                                smoothing.isChecked=fields[3]=="1"
                                pattern=fields.getOrNull(5)?.toIntOrNull()?:0
                                uvInput.setText(fields.getOrNull(6)?:"1.0")
                                setSwatch(fields[0].toIntOrNull(16)?:0)
                            }
                        }
                    }
                    smoothing.setOnCheckedChangeListener { _,enabled ->
                        surface.queueEvent {
                            Native.checkpoint(engine)
                            Native.setSmooth(engine,enabled)
                            val info=Native.sceneInfo(engine)
                            runOnUiThread { inspector.text=info }
                        }
                    }
                }
                else -> {
                    controls(actions,
                        "Экспорт GLB" to { exportGlb() },
                        "Материал" to { act { Native.material(engine, -1) } },
                        "Сохранить" to {
                            surface.queueEvent {
                                val project = Native.serialize(engine)
                                runOnUiThread {
                                    try {
                                        File(filesDir, "project.zms").writeText(project)
                                        inspector.text = "Проект сохранён во внутренней памяти."
                                    } catch(error: Exception) {
                                        inspector.text = "Ошибка записи проекта."
                                    }
                                }
                            }
                        },
                        "Открыть" to {
                            val f = File(filesDir, "project.zms")
                            if(f.exists()) {
                                try {
                                    val project = f.readText()
                                    act { Native.restore(engine, project) }
                                } catch(error: Exception) {
                                    inspector.text = "Ошибка чтения проекта."
                                }
                            } else inspector.text = "Сохранённый проект не найден."
                        }
                    )
                }
            }
        }

        controls(tabs,
            "Модель" to { page(0) },
            "Топология" to { page(3) },
            "Трансф." to { page(1) },
            "Материал" to { page(4) },
            "Файлы" to { page(2) }
        )
        page(0)
        setContentView(root)
        // Android 15/16 enforce edge-to-edge. Reserve both system-bar insets.
        root.setOnApplyWindowInsetsListener { _, insets ->
            val top: Int
            val bottom: Int
            if (Build.VERSION.SDK_INT >= 30) {
                top = insets.getInsets(WindowInsets.Type.statusBars()).top
                bottom = insets.getInsets(WindowInsets.Type.navigationBars()).bottom
            } else {
                @Suppress("DEPRECATION")
                top = insets.systemWindowInsetTop
                @Suppress("DEPRECATION")
                bottom = insets.systemWindowInsetBottom
            }
            root.setPadding(0, top, 0, bottom)
            insets
        }
        root.requestApplyInsets()
        surface.queueEvent {
            val text = Native.sceneInfo(engine)
            runOnUiThread { inspector.text = text }
        }
    }
    private fun exportGlb() {
        surface.queueEvent {
            val bytes=Native.exportGlb(engine)
            runOnUiThread {
                if(bytes.isEmpty()){
                    inspector.text="GLB: нечего экспортировать или файл превышает 32 МБ."
                    return@runOnUiThread
                }
                glbForSave=bytes
                val intent=Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type="model/gltf-binary"
                    putExtra(Intent.EXTRA_TITLE,"ZAMER-model.glb")
                }
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent,glbExportRequest)
                }catch(error:Exception){
                    glbForSave=null
                    inspector.text="Не удалось открыть выбор места для GLB."
                }
            }
        }
    }

    @Deprecated("Android activity result compatibility")
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?){
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode!=glbExportRequest)return
        val bytes=glbForSave
        glbForSave=null
        if(resultCode!=RESULT_OK||data?.data==null||bytes==null)return
        try {
            val stream=contentResolver.openOutputStream(data.data!!,"w")
                ?:throw IllegalStateException("Нет доступа к файлу")
            stream.use { it.write(bytes) }
            inspector.text="GLB сохранён. " + (bytes.size/1024) + " КБ. Геометрия, UV, PBR."
        }catch(error:Exception){
            inspector.text="Ошибка записи GLB: " + error.message
        }
    }
    private fun Int.dp(): Int = (this * resources.displayMetrics.density).toInt()
    override fun onResume() { super.onResume(); if (::surface.isInitialized) surface.onResume() }
    override fun onPause() { if (::surface.isInitialized) surface.onPause(); super.onPause() }
    override fun onDestroy() {
        if (::surface.isInitialized) {
            surface.queueEvent { Native.destroy(engine) }
        }
        super.onDestroy()
    }
}
