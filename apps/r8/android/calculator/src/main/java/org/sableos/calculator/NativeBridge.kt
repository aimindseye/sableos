package org.sableos.calculator

internal object NativeBridge {
    init {
        System.loadLibrary("sable_calculator_jni")
    }

    external fun selfTest(): String
}
