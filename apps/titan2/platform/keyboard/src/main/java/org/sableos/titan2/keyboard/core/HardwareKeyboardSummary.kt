package org.sableos.titan2.keyboard.core

/**
 * Human-readable physical keyboard status. Never guesses hardware key legends, backlight controls
 * or the keyboard controller firmware version; Android InputDevice is the source of truth.
 */
object HardwareKeyboardSummary {
    fun describe(alphabetic: Int, other: Int): String {
        require(alphabetic >= 0 && other >= 0)
        val keyboard = if (alphabetic > 0) {
            "Android reports $alphabetic alphabetic hardware keyboard(s)."
        } else {
            "No alphabetic hardware keyboard currently reported by Android."
        }
        return "$keyboard On-screen input remains available for PINs, passwords and recovery. " +
            "Hardware key and backlight shortcuts depend on the actual device firmware; " +
            "Q25 Sym/backlight instructions do not apply to Titan 2."
    }
}
