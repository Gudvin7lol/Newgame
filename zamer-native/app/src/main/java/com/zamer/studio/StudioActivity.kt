package com.zamer.studio

import android.app.Activity
import android.graphics.Color
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
    private lateinit var surface: GLSurfaceView
    private lateinit var inspector: TextView
    private lateinit var graphicsStatus: TextView
    private var engine: Long = 0L
    private var previousX = 0f
    private var previousY = 0f
    private var previousPinch = 0f
    private var translation = false
    private var firstRenderReport = true
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
            text = "Z / ENGINE    •    CORE 0.2"
            setTextColor(Color.WHITE)
            textSize = 17f
            setPadding(18.dp(), 9.dp(), 12.dp(), 9.dp())
        }
        root.addView(brand)

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
                    if (firstRenderReport) {
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
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = event.x - previousX
                        val dy = event.y - previousY
                        previousX = event.x
                        previousY = event.y
                        queueEvent {
                            if (translation) Native.move(engine, dx*0.003f, -dy*0.003f)
                            else Native.orbit(engine, dx*0.008f, dy*0.008f)
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

        fun controls(vararg items: Pair<String, () -> Unit>) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setBackgroundColor(panel)
            }
            for ((title, action) in items) {
                val button = Button(this).apply {
                    text = title
                    textSize = 11f
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.rgb(34, 55, 72))
                    setOnClickListener { action() }
                }
                row.addView(button, LinearLayout.LayoutParams(0, 56.dp(), 1f).apply {
                    setMargins(3.dp(), 3.dp(), 3.dp(), 3.dp())
                })
            }
            root.addView(row)
        }
        fun act(action: () -> Unit) {
            surface.queueEvent {
                action()
                val text = Native.sceneInfo(engine)
                runOnUiThread { inspector.text = text }
            }
        }
        controls(
            "Блок" to { act { Native.add(engine, 0) } },
            "Сфера" to { act { Native.add(engine, 1) } },
            "Цилиндр" to { act { Native.add(engine, 2) } }
        )
        controls(
            "Выбрать" to { act { Native.selectNext(engine) } },
            "Выдавить" to { act { Native.extrude(engine, 0.05f) } },
            "Subdivide" to { act { Native.subdivide(engine) } }
        )
        controls(
            "Двигать" to { translation = !translation; inspector.text = if (translation) "Режим перемещения" else "Режим камеры" },
            "Материал" to { act { Native.material(engine, 1) } },
            "Сохранить" to {
                surface.queueEvent {
                    val project = Native.serialize(engine)
                    runOnUiThread {
                        File(filesDir, "project.zms").writeText(project)
                        inspector.text = "Проект сохранён • private Android storage"
                    }
                }
            },
            "Открыть" to {
                val file = File(filesDir, "project.zms")
                if (file.exists()) {
                    val project = file.readText()
                    act { Native.restore(engine, project) }
                } else inspector.text = "Нет сохранённого проекта"
            }
        )
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
