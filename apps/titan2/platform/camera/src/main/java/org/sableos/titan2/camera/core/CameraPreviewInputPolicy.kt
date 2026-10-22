package org.sableos.titan2.camera.core

/**
 * Only direct screen contact can reveal touch chrome over a camera preview.
 * Android's public MotionEvent constants are copied as stable integer values
 * so the decision is pure/JVM-testable and does not require a device or HAL.
 *
 * Trackpad-generated SOURCE_MOUSE, a stylus hover, key events, and a touch
 * DOWN/MOVE are never translated into a second artificial preview tap.
 */
object CameraPreviewInputPolicy {
    const val SOURCE_TOUCHSCREEN = 0x00001002
    const val TOOL_FINGER = 1
    const val TOOL_STYLUS = 2
    const val ACTION_UP = 1

    fun isDirectTouch(source: Int, toolType: Int): Boolean =
        (source and SOURCE_TOUCHSCREEN) == SOURCE_TOUCHSCREEN &&
            (toolType == TOOL_FINGER || toolType == TOOL_STYLUS)

    fun revealControls(source: Int, toolType: Int, actionMasked: Int): Boolean =
        isDirectTouch(source, toolType) && actionMasked == ACTION_UP
}
