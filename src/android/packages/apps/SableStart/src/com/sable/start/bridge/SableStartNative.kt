package org.sableos.start.bridge

object SableStartNative {
    init {
        System.loadLibrary("sable_start_core_jni")
    }

    external fun nativeCreate(): Long

    external fun nativeDestroy(
        handle: Long,
    )
}
