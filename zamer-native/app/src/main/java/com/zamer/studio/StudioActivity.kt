package com.zamer.studio

import android.app.Activity
import android.graphics.Color
import android.text.InputType
import android.widget.EditText
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.os.Build
import android.view.WindowInsets
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
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
    private var previousX = 0f
    private var previousY = 0f
    private var previousPinch = 0f
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
            text = "Z / ENGINE    •    CORE 0.7"
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
                    if (previousPinch > 0f && event.actionMasked == MotionEvent.ACTION_MOVE) {
                        val scale = (d / previousPinch).coerceIn(0.75f, 1.25f)
                        queueEvent { Native.zoom(engine, scale) }
                    }
                    previousPinch = d
                    return@setOnTouchListener true
                }
                previousPinch = 0f
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
                        "Extrude +" to { act { Native.extrude(engine, 0.05f) } },
                        "Extrude −" to { act { Native.extrude(engine, -0.05f) } },
                        "Inset" to { act { Native.inset(engine, 0.10f) } },
                        "Subdivide" to { act { Native.subdivide(engine) } }
                    )
                    controls(actions,
                        "Loop Cut" to {
                            surface.queueEvent {
                                val success = Native.loopCut(engine)
                                val state = Native.sceneInfo(engine)
                                runOnUiThread {
                                    if (success) tool = Tool.VERTEX
                                    inspector.text = if (success) "Loop Cut выполнен. Выбрана новая вершина.\n$state"
                                        else "Loop Cut: выбери ребро замкнутой цепочки четырёхугольников."
                                }
                            }
                        },
                        "Split Edge" to {
                            surface.queueEvent {
                                val success = Native.splitEdge(engine)
                                val state = Native.sceneInfo(engine)
                                runOnUiThread {
                                    if (success) tool = Tool.VERTEX
                                    inspector.text = if (success) "Ребро разделено на два.\n$state"
                                        else "Split Edge: сначала выбери ребро замкнутой сетки."
                                }
                            }
                        }
                    )
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
                else -> {
                    controls(actions,
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
            "Трансформ." to { page(1) },
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
