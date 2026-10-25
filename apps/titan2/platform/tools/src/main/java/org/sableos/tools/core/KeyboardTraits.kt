package org.sableos.tools.core

/** Where a profile's keyboard backlight state can be read from. */
enum class KeyboardLightSource {
    /** Public `InputDevice.getLightsManager()` lights (generic Android keyboards). */
    INPUT_LIGHTS,

    /** The profile declares no keyboard light. */
    NONE
}

/**
 * Keyboard facts a profile declares for the diagnostics: which modifier keys exist (the critical text-entry test only
 * asks for these), whether digits live on the Alt layer, and how the keyboard light is driven.
 */
data class KeyboardTraits(
    val modifiers: Set<Modifier>,
    val digitsOnAltLayer: Boolean = false,
    val light: KeyboardLightSource = KeyboardLightSource.INPUT_LIGHTS
) {
    companion object {
        /**
         * Profiles with no keyboard evidence keep the spec's full list (HARDWARE_DIAGNOSTICS_AND_DIALER_CODES:
         * Alt, Sym, Fn) and the public lights API.
         */
        val GENERIC = KeyboardTraits(setOf(Modifier.ALT, Modifier.SYM, Modifier.FN))
    }
}

enum class KeyboardLightState { ON, OFF, PRESENT, NOT_SUPPORTED, UNKNOWN }

data class KeyboardLightReading(val state: KeyboardLightState, val detail: String)

/** Keyboard light diagnostic, driven by [KeyboardTraits.light]. Pure: the Android layer passes the readings in. */
object KeyboardLight {
    /** A retained function signature for existing callers; there is no device-property backend. */
    @Suppress("UNUSED_PARAMETER")
    fun read(
        source: KeyboardLightSource,
        prop: (String) -> String,
        inputLights: List<String>
    ): KeyboardLightReading = when (source) {
        KeyboardLightSource.NONE -> KeyboardLightReading(
            KeyboardLightState.NOT_SUPPORTED,
            "this profile declares no keyboard light"
        )

        KeyboardLightSource.INPUT_LIGHTS -> if (inputLights.isEmpty()) {
            KeyboardLightReading(KeyboardLightState.UNKNOWN, "no light exposed by any input device")
        } else {
            KeyboardLightReading(KeyboardLightState.PRESENT, inputLights.joinToString(", "))
        }
    }
}
