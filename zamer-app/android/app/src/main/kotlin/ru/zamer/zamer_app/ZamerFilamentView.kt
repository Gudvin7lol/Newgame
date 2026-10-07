package ru.zamer.zamer_app

import android.content.Context
import android.graphics.Bitmap
import android.view.Choreographer
import android.view.SurfaceView
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
    companion object {
        init {
            Utils.init()
        }
    }

    private val surfaceView = SurfaceView(context).apply {
        setZOrderOnTop(false)
        setBackgroundColor(android.graphics.Color.rgb(28, 31, 34))
    }

    private val modelViewer = ModelViewer(
        surfaceView = surfaceView,
        manipulator = null,
    )

    private val channel = MethodChannel(
        messenger,
        "ru.zamer.zamer_app/filament/$viewId",
    )

    private var disposed = false
    private var currentFov = 58.0
    private var currentNear = 0.04
    private var currentFar = 180.0

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (disposed) return
            modelViewer.render(frameTimeNanos)
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    init {
        configureLighting()
        configureQuality("quality")
        channel.setMethodCallHandler(this)

        val glb = creationParams?.get("glb")
        if (glb is ByteArray && glb.isNotEmpty()) {
            loadGlb(glb)
        }
        @Suppress("UNCHECKED_CAST")
        (creationParams?.get("camera") as? Map<String, Any?>)?.let(::setCamera)
        (creationParams?.get("quality") as? String)?.let(::configureQuality)

        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    override fun getView(): android.view.View = surfaceView

    override fun dispose() {
        disposed = true
        Choreographer.getInstance().removeFrameCallback(frameCallback)
        channel.setMethodCallHandler(null)
        // ModelViewer releases its Filament resources when SurfaceView detaches.
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "loadGlb" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("bad_glb", "GLB payload is empty.", null)
                    } else {
                        loadGlb(bytes)
                        result.success(true)
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
                    configureQuality(call.argument<String>("quality") ?: "quality")
                    result.success(true)
                }

                "capture" -> {
                    modelViewer.debugGetNextFrameCallback { bitmap ->
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                        result.success(output.toByteArray())
                    }
                }

                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error(
                "filament_error",
                error.message ?: error.javaClass.simpleName,
                null,
            )
        }
    }

    private fun loadGlb(bytes: ByteArray) {
        modelViewer.loadModelGlb(ByteBuffer.wrap(bytes))
    }

    private fun configureLighting() {
        val engine = modelViewer.engine
        val scene = modelViewer.scene

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
        val sun = lightManager.getInstance(modelViewer.light)
        lightManager.setIntensity(sun, 58_000.0f)
        lightManager.setColor(sun, 1.0f, 0.965f, 0.91f)
        lightManager.setDirection(sun, -0.46f, -1.0f, -0.34f)
    }

    private fun configureQuality(value: String) {
        val view = modelViewer.view
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

        modelViewer.camera.lookAt(
            eyeX, eyeY, eyeZ,
            targetX, targetY, targetZ,
            0.0, 1.0, 0.0,
        )
        val width = surfaceView.width.coerceAtLeast(1)
        val height = surfaceView.height.coerceAtLeast(1)
        val aspect = width.toDouble() / height.toDouble()
        modelViewer.camera.setProjection(
            currentFov,
            aspect,
            currentNear,
            currentFar,
            Camera.Fov.VERTICAL,
        )
    }
}
