package ru.zamer.zamer_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.view.Choreographer
import android.view.Gravity
import android.view.TextureView
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import com.google.android.filament.Camera
import com.google.android.filament.IndirectLight
import com.google.android.filament.Skybox
import com.google.android.filament.View
import com.google.android.filament.utils.ModelViewer
import com.google.android.filament.utils.Utils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class ZamerFilamentViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val viewType = "ru.zamer.zamer_app/filament"
    }

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView = ZamerFilamentView(
        context = context,
        viewId = viewId,
        messenger = messenger,
        creationParams = args as? Map<*, *>,
    )
}

private class ZamerFilamentView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    creationParams: Map<*, *>?,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val root = FrameLayout(context).apply {
        setBackgroundColor(Color.rgb(28, 31, 34))
    }

    private val textureView = TextureView(context).apply {
        isOpaque = true
        setBackgroundColor(Color.rgb(28, 31, 34))
    }

    private val diagnosticView = TextView(context).apply {
        setTextColor(Color.WHITE)
        setBackgroundColor(Color.argb(220, 28, 31, 34))
        gravity = Gravity.CENTER
        textSize = 13f
        setPadding(32, 32, 32, 32)
        visibility = android.view.View.GONE
    }

    private val channel = MethodChannel(
        messenger,
        "ru.zamer.zamer_app/filament/$viewId",
    )

    private var modelViewer: ModelViewer? = null
    private var disposed = false
    private var initError: String? = null
    private var currentFov = 58.0
    private var currentNear = 0.04
    private var currentFar = 180.0
    private var lastGlbBytes = 0
    private var renderedFrames = 0L

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (disposed) return
            try {
                if (modelViewer?.render(frameTimeNanos) == true) {
                    renderedFrames++
                }
            } catch (error: Throwable) {
                fail("render", error)
            }
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    init {
        root.addView(
            textureView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        root.addView(
            diagnosticView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        channel.setMethodCallHandler(this)

        try {
            // Utils.init() also calls Filament.init().
            Utils.init()
            val viewer = ModelViewer(
                textureView = textureView,
                manipulator = null,
            )
            modelViewer = viewer
            configureLighting(viewer)
            configureQuality(viewer, "quality")

            @Suppress("UNCHECKED_CAST")
            (creationParams?.get("camera") as? Map<String, Any?>)?.let(::setCamera)
            (creationParams?.get("quality") as? String)?.let {
                configureQuality(viewer, it)
            }

            Choreographer.getInstance().postFrameCallback(frameCallback)
        } catch (error: Throwable) {
            fail("init", error)
        }
    }

    override fun getView(): android.view.View = root

    override fun dispose() {
        disposed = true
        Choreographer.getInstance().removeFrameCallback(frameCallback)
        channel.setMethodCallHandler(null)
        try {
            modelViewer?.destroyModel()
        } catch (_: Throwable) {
        }
        modelViewer = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> {
                    result.success(
                        mapOf(
                            "ready" to (modelViewer != null && initError == null),
                            "error" to initError,
                            "textureAvailable" to textureView.isAvailable,
                            "width" to textureView.width,
                            "height" to textureView.height,
                            "glbBytes" to lastGlbBytes,
                            "renderedFrames" to renderedFrames,
                        ),
                    )
                }

                "loadGlb" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("bad_glb", "GLB payload is empty.", null)
                    } else {
                        loadGlb(bytes)
                        result.success(
                            mapOf(
                                "loaded" to true,
                                "bytes" to bytes.size,
                                "textureAvailable" to textureView.isAvailable,
                            ),
                        )
                    }
                }

                "setCamera" -> {
                    @Suppress("UNCHECKED_CAST")
                    val camera = call.arguments as? Map<String, Any?>
                    if (camera == null) {
                        result.error("bad_camera", "Camera payload is missing.", null)
                    } else {
                        setCamera(camera)
                        result.success(true)
                    }
                }

                "setQuality" -> {
                    val viewer = requireViewer()
                    configureQuality(
                        viewer,
                        call.argument<String>("quality") ?: "quality",
                    )
                    result.success(true)
                }

                "capture" -> {
                    val viewer = requireViewer()
                    viewer.debugGetNextFrameCallback { bitmap ->
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                        result.success(output.toByteArray())
                    }
                }

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            fail(call.method, error)
            result.error(
                "filament_error",
                initError ?: error.message ?: error.javaClass.simpleName,
                null,
            )
        }
    }

    private fun requireViewer(): ModelViewer =
        modelViewer ?: throw IllegalStateException(
            initError ?: "Filament ModelViewer is not initialized.",
        )

    private fun loadGlb(bytes: ByteArray) {
        val viewer = requireViewer()
        viewer.loadModelGlb(ByteBuffer.wrap(bytes))
        lastGlbBytes = bytes.size
        hideDiagnostic()
    }

    private fun configureLighting(viewer: ModelViewer) {
        val engine = viewer.engine
        val scene = viewer.scene

        val harmonics = floatArrayOf(
            0.72f, 0.76f, 0.82f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
            0.00f, 0.00f, 0.00f,
        )
        scene.indirectLight = IndirectLight.Builder()
            .irradiance(3, harmonics)
            .intensity(18_000.0f)
            .build(engine)

        scene.skybox = Skybox.Builder()
            .color(0.035f, 0.042f, 0.050f, 1.0f)
            .build(engine)

        val lightManager = engine.lightManager
        val sun = lightManager.getInstance(viewer.light)
        lightManager.setIntensity(sun, 58_000.0f)
        lightManager.setColor(sun, 1.0f, 0.965f, 0.91f)
        lightManager.setDirection(sun, -0.46f, -1.0f, -0.34f)
    }

    private fun configureQuality(viewer: ModelViewer, value: String) {
        val view = viewer.view
        val high = value != "performance"

        view.renderQuality = view.renderQuality.apply {
            hdrColorBuffer = if (high) {
                View.QualityLevel.HIGH
            } else {
                View.QualityLevel.MEDIUM
            }
        }
        view.dynamicResolutionOptions = view.dynamicResolutionOptions.apply {
            enabled = !high
            quality = View.QualityLevel.MEDIUM
        }
        view.multiSampleAntiAliasingOptions =
            view.multiSampleAntiAliasingOptions.apply {
                enabled = true
            }
        view.antiAliasing = View.AntiAliasing.FXAA
        view.ambientOcclusionOptions = view.ambientOcclusionOptions.apply {
            enabled = high
        }
        view.bloomOptions = view.bloomOptions.apply {
            enabled = high
        }
    }

    private fun setCamera(payload: Map<String, Any?>) {
        val viewer = requireViewer()

        fun n(key: String, fallback: Double): Double =
            (payload[key] as? Number)?.toDouble() ?: fallback

        val eyeX = n("eyeX", 3.5)
        val eyeY = n("eyeY", 2.2)
        val eyeZ = n("eyeZ", 3.5)
        val targetX = n("targetX", 0.0)
        val targetY = n("targetY", 1.0)
        val targetZ = n("targetZ", 0.0)
        currentFov = n("fov", currentFov)
        currentNear = n("near", currentNear)
        currentFar = n("far", currentFar)

        viewer.camera.lookAt(
            eyeX, eyeY, eyeZ,
            targetX, targetY, targetZ,
            0.0, 1.0, 0.0,
        )
        val width = textureView.width.coerceAtLeast(1)
        val height = textureView.height.coerceAtLeast(1)
        val aspect = width.toDouble() / height.toDouble()
        viewer.camera.setProjection(
            currentFov,
            aspect,
            currentNear,
            currentFar,
            Camera.Fov.VERTICAL,
        )
    }

    private fun fail(stage: String, error: Throwable) {
        val message = buildString {
            append("Filament ")
            append(stage)
            append(": ")
            append(error.javaClass.simpleName)
            val details = error.message
            if (!details.isNullOrBlank()) {
                append("\n")
                append(details)
            }
        }
        initError = message
        diagnosticView.text = message
        diagnosticView.visibility = android.view.View.VISIBLE
    }

    private fun hideDiagnostic() {
        if (initError == null) {
            diagnosticView.visibility = android.view.View.GONE
        }
    }
}
