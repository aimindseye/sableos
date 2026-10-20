package org.sableos.titan2.keyboard.core

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HardwareKeyboardSummaryTest {
    @Test fun unboundHardwareNeverClaimsSupport() {
        val msg = HardwareKeyboardSummary.describe(0, 1)
        assertTrue(msg.contains("No alphabetic"))
        assertTrue(msg.contains("On-screen input remains available"))
    }

    @Test fun detectedHardwareReflectsOnlyFrameworkClassification() {
        val msg = HardwareKeyboardSummary.describe(1, 0)
        assertTrue(msg.contains("1 alphabetic hardware keyboard"))
        assertFalse(msg.contains("Keyboard firmware version"))
        assertTrue(msg.contains("Q25 Sym/backlight instructions do not apply"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun negativeCountsFailClosed() {
        HardwareKeyboardSummary.describe(-1, 0)
    }
}
