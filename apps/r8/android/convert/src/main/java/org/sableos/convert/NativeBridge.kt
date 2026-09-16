package org.sableos.convert

internal object NativeBridge {
    init {
        System.loadLibrary("sable_convert_jni")
    }

    external fun selfTest(): String
}
