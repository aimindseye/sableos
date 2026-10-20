package org.sableos.titan2.keyboard.android

import android.view.InputDevice
import org.sableos.titan2.keyboard.core.HardwareKeyboardSummary

/** Reads only framework-reported keyboard classes; no device probing or global input capture. */
internal object HardwareKeyboardStatus {
    fun display(): String {
        var alphabetic = 0
        var other = 0
        for (id in InputDevice.getDeviceIds()) {
            val dev = InputDevice.getDevice(id) ?: continue
            if (dev.isVirtual) continue
            when (dev.keyboardType) {
                InputDevice.KEYBOARD_TYPE_ALPHABETIC -> alphabetic++
                InputDevice.KEYBOARD_TYPE_NON_ALPHABETIC -> other++
            }
        }
        return HardwareKeyboardSummary.describe(alphabetic, other)
    }
}
