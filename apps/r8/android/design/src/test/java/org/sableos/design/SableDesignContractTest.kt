package org.sableos.design

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SableDesignContractTest {
    @Test
    fun corruptValuesFallBackSafely() {
        assertEquals(AppearanceMode.FollowSystem, AppearanceMode.fromStableValue("bad"))
        assertEquals(AccentPreset.Blue, AccentPreset.fromStableValue(null))
    }

    @Test
    fun stableValuesRoundTrip() {
        AppearanceMode.entries.forEach { mode ->
            assertEquals(mode, AppearanceMode.fromStableValue(mode.stableValue))
        }
        AccentPreset.entries.forEach { accent ->
            assertEquals(accent, AccentPreset.fromStableValue(accent.stableValue))
        }
    }

    @Test
    fun uiContractKeepsTouchTargetsAndCornersIntentional() {
        assertEquals(2, SableDesignContract.SCHEMA_VERSION)
        assertTrue(SableDesignContract.MIN_TOUCH_TARGET_DP >= 48)
        assertEquals(SableCornerStyle.Compact, SableCornerStyle.DEFAULT)
        // The original Compact style stays at 6dp; opt-in Rounded is 12dp.
        assertEquals(6, SableShapeTable.forStyle(SableCornerStyle.Compact).maxDp)
        assertEquals(12, SableShapeTable.forStyle(SableCornerStyle.Rounded).maxDp)
        assertEquals(
            SableShapeTable.Compact.maxDp,
            SableDesignContract.MAX_COMPACT_CORNER_RADIUS_DP,
        )
        assertEquals(
            SableShapeTable.Rounded.maxDp,
            SableDesignContract.MAX_ROUNDED_CORNER_RADIUS_DP,
        )
        assertEquals(
            SableDesignContract.MAX_ROUNDED_CORNER_RADIUS_DP,
            SableDesignContract.MAX_STANDARD_CORNER_RADIUS_DP,
        )
        assertTrue(
            SableDesignContract.SCREEN_HORIZONTAL_PADDING_DP >=
                SableDesignContract.SCREEN_VERTICAL_PADDING_DP,
        )
    }

    @Test
    fun globalAppearanceContractIsStableAndNarrow() {
        assertEquals(
            "org.sableos.appearance",
            SableGlobalAppearanceContract.AUTHORITY,
        )
        assertTrue(
            SableGlobalAppearanceContract.AUTHORITY !=
                "org.sableos.start.appearance",
        )
        assertEquals(
            "appearance",
            SableGlobalAppearanceContract.PATH_APPEARANCE,
        )
        assertEquals(
            "mode",
            SableGlobalAppearanceContract.COLUMN_MODE,
        )
        assertEquals(
            "accent",
            SableGlobalAppearanceContract.COLUMN_ACCENT,
        )
    }

    @Test
    fun motionDurationsIncreaseByEmphasis() {
        assertTrue(
            SableDesignContract.FAST_MOTION_MS <
                SableDesignContract.STANDARD_MOTION_MS,
        )
        assertTrue(
            SableDesignContract.STANDARD_MOTION_MS <
                SableDesignContract.EMPHASIZED_MOTION_MS,
        )
    }
}
