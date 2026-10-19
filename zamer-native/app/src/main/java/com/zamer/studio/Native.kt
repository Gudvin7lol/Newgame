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
    external fun pan(engine: Long, deltaX: Float, deltaY: Float)
    external fun focusSelected(engine: Long): Boolean
    external fun pick(engine: Long, x: Float, y: Float): Int
    external fun pickFace(engine: Long, x: Float, y: Float): Int
    external fun setElementMode(engine: Long, mode: Int)
    external fun pickElement(engine: Long, x: Float, y: Float, mode: Int): Int
    external fun nudgeElement(engine: Long, axis: Int, metres: Float): Boolean
    external fun splitEdge(engine: Long): Boolean
    external fun loopCut(engine: Long): Boolean
    external fun bevelEdge(engine: Long, metres: Float, segments: Int): Boolean
    external fun duplicate(engine: Long): Boolean
    external fun deleteSelected(engine: Long): Boolean
    external fun markBridgeFace(engine: Long): Boolean
    external fun bridgeFaces(engine: Long): Boolean
    /** Call from GL thread. Mode 1=Move XYZ, 3=Scale XYZ, 0=none. */
    external fun setGizmoMode(engine: Long, mode: Int)
    external fun beginGizmo(engine: Long, x: Float, y: Float): Int
    external fun dragGizmo(engine: Long, dx: Float, dy: Float): Boolean
    external fun dragRotate(engine: Long, dx: Float, dy: Float): Boolean
    external fun endGizmo(engine: Long)
    external fun undo(engine: Long): Boolean
    external fun redo(engine: Long): Boolean
    external fun checkpoint(engine: Long)
    /** 0=translate XYZ metres; 1=rotate Y radians; 2=scale XYZ metres */
    external fun transform(engine: Long, mode: Int, axis: Int, amount: Float): Boolean
    external fun inset(engine: Long, fraction: Float): Boolean
    external fun add(engine: Long, type: Int)
    external fun selectNext(engine: Long)
    external fun move(engine: Long, dx: Float, dz: Float)
    external fun extrude(engine: Long, metres: Float)
    external fun subdivide(engine: Long)
    external fun material(engine: Long, index: Int)
    external fun setPbr(engine: Long, rgb: Int, metallic: Float, roughness: Float): Boolean
    external fun setSmooth(engine: Long, enabled: Boolean): Boolean
    external fun materialState(engine: Long): String
    external fun setPattern(engine: Long, pattern: Int, uvScale: Float): Boolean
    external fun exportGlb(engine: Long): ByteArray
    external fun sceneInfo(engine: Long): String
    external fun serialize(engine: Long): String
    external fun restore(engine: Long, serialized: String): Boolean
}
