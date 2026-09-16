package org.sableos.games

internal object NativeBridge {
    init {
        System.loadLibrary("sable_games_jni")
    }

    external fun selfTest(): String
}
