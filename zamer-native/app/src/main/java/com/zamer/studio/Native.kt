package com.zamer.studio

/** JNI facade. Every mutation and GL call runs on GLSurfaceView's GL thread. */
object Native {
    init { System.loadLibrary("zamerengine") }
    external fun create(): Long
    external fun destroy(engine: Long)
    external fun initGl(engine: Long)
    external fun graphicsStatus(engine: Long): String
    external fun resize(engine: Long, width: Int, height: Int)
    external fun draw(engine: Long)
    external fun orbit(engine: Long, dx: Float, dy: Float)
    external fun zoom(engine: Long, factor: Float)
    external fun add(engine: Long, type: Int)
    external fun selectNext(engine: Long)
    external fun move(engine: Long, dx: Float, dz: Float)
    external fun extrude(engine: Long, metres: Float)
    external fun subdivide(engine: Long)
    external fun material(engine: Long, index: Int)
    external fun sceneInfo(engine: Long): String
    external fun serialize(engine: Long): String
    external fun restore(engine: Long, serialized: String): Boolean
}
