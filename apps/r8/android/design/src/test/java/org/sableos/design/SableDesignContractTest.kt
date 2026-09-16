package org.sableos.design

import org.junit.Assert.assertEquals
import org.junit.Test

class SableDesignContractTest {
    @Test fun corruptValuesFallBackSafely() {
        assertEquals(AppearanceMode.FollowSystem, AppearanceMode.fromStableValue("bad"))
        assertEquals(AccentPreset.Blue, AccentPreset.fromStableValue(null))
    }

    @Test fun stableValuesRoundTrip() {
        AppearanceMode.entries.forEach { mode ->
            assertEquals(mode, AppearanceMode.fromStableValue(mode.stableValue))
        }
        AccentPreset.entries.forEach { accent ->
            assertEquals(accent, AccentPreset.fromStableValue(accent.stableValue))
        }
    }
}
