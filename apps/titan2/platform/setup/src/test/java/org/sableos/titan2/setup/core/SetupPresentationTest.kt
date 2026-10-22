package org.sableos.titan2.setup.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SetupPresentationTest {
    @Test fun numberedChecklistIsBounded() {
        assertEquals("Review 1 of 5", SetupPresentation.stepLabel(0, 5))
        assertEquals("Review 5 of 5", SetupPresentation.stepLabel(4, 5))
    }

    @Test(expected = IllegalArgumentException::class)
    fun outOfBoundsIsRejected() {
        SetupPresentation.stepLabel(5, 5)
    }

    @Test fun wifiInstructionsRespectAndroidOwnership() {
        assertTrue(SetupPresentation.WIFI_HELP.contains("Android Wi-Fi Settings"))
        assertTrue(SetupPresentation.WIFI_HELP.contains("does not configure Wi-Fi"))
    }
}
