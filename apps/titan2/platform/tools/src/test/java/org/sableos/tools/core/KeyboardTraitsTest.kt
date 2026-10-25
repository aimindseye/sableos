package org.sableos.tools.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyboardTraitsTest {
    private val q25 = LegacyQ25TestFixture.profile.keyboard

    private fun ids(k: KeyboardTraits) = TextEntryTest.casesFor(k).map { it.id }

    private fun props(vararg kv: Pair<String, String>): (String) -> String {
        val m = kv.toMap()
        return { m[it].orEmpty() }
    }

    @Test fun q25DeclaresBlackBerryClassicKeys() {
        assertEquals(setOf(Modifier.ALT, Modifier.SHIFT, Modifier.SYM), q25.modifiers)
        assertTrue(q25.digitsOnAltLayer)
        assertEquals(KeyboardLightSource.INPUT_LIGHTS, q25.light)
    }

    @Test fun q25TextEntryNeverAsksForFn() {
        val cases = TextEntryTest.casesFor(q25)
        assertFalse(cases.any { it.modifier == Modifier.FN })
        assertTrue(cases.all { it.modifier == null || it.modifier in q25.modifiers })
        assertEquals(
            listOf(
                "letters",
                "numbers",
                "symbols",
                "shift",
                "alt_digits",
                "alt",
                "sym",
                "bt_pairing",
                "wifi_password",
                "pin",
                "software_fallback"
            ),
            ids(q25)
        )
    }

    @Test fun undeclaredProfilesKeepTheSpecList() {
        val undeclared = listOf(
            ToolsDeviceProfile.Titan2,
            ToolsDeviceProfile.Unknown,
            ToolsDeviceProfile.ZinwaQ27
        )
        undeclared.forEach {
            assertEquals(KeyboardTraits.GENERIC, it.keyboard)
            assertEquals(TextEntryTest.CASES, TextEntryTest.casesFor(it.keyboard))
        }
        assertTrue("fn" in ids(KeyboardTraits.GENERIC))
    }

    @Test fun keyboardWithoutModifiersOnlyGetsPlainCases() {
        val bare = KeyboardTraits(emptySet(), digitsOnAltLayer = true)
        assertTrue(TextEntryTest.casesFor(bare).all { it.modifier == null })
    }

    @Test fun q25ReleaseGateCanPass() {
        val cases = TextEntryTest.casesFor(q25)
        val summary = TextEntryTest.summary(cases.associate { it.id to CaseResult.PASS }, cases)
        assertEquals("11/11 PASS, 0 FAIL, 0 NOT_RUN", summary.first().value)
    }

    @Test fun shiftAndAltDigitChecks() {
        val cases = TextEntryTest.casesFor(q25).associateBy { it.id }
        val shift = cases.getValue("shift")
        val s = KeyCommands.META_SHIFT_ON
        val a = KeyCommands.META_ALT_ON
        val upper = listOf(TypedKey(s, 'S'.code))
        assertEquals(CaseResult.PASS, TextEntryTest.check(shift, "S", upper))
        val lower = listOf(TypedKey(0, 's'.code))
        assertEquals(CaseResult.FAIL, TextEntryTest.check(shift, "s", lower))

        val digits = cases.getValue("alt_digits")
        val altKeys = "2468".map { TypedKey(a, it.code) }
        assertEquals(CaseResult.PASS, TextEntryTest.check(digits, "2468", altKeys))
        // Right text but typed without Alt (number row or soft keyboard): not the Alt layer.
        val plain = "2468".map { TypedKey(0, it.code) }
        assertEquals(CaseResult.FAIL, TextEntryTest.check(digits, "2468", plain))
        assertEquals(CaseResult.FAIL, TextEntryTest.check(digits, "2468", emptyList()))
        assertEquals(CaseResult.FAIL, TextEntryTest.check(digits, "246", altKeys.take(3)))
    }

    @Test fun q25BacklightDriverAbsentFromTitan2ProductionApi() {
        assertEquals(
            setOf(KeyboardLightSource.INPUT_LIGHTS, KeyboardLightSource.NONE),
            KeyboardLightSource.entries.toSet()
        )
    }

    @Test fun genericLightUsesInputLights() {
        val src = KeyboardLightSource.INPUT_LIGHTS
        val none = KeyboardLight.read(src, props(), emptyList())
        assertEquals(KeyboardLightState.UNKNOWN, none.state)
        val some = KeyboardLight.read(src, props(), listOf("kbd"))
        assertEquals(KeyboardLightState.PRESENT, some.state)
        assertEquals(
            KeyboardLightState.NOT_SUPPORTED,
            KeyboardLight.read(KeyboardLightSource.NONE, props(), listOf("kbd")).state
        )
    }

    @Test fun attentionOffersKeyboardSettings() {
        assertTrue(SettingsLink.KEYBOARD in Handoffs.forTool(Tool.ATTENTION))
    }

    @Test fun dialerCodeReceiverEnabledFromInstall() {
        val manifest = java.io.File("src/main/AndroidManifest.xml")
        if (!manifest.exists()) return
        val receiver = Regex("<receiver[^>]*SecretCodeReceiver[^>]*>")
            .find(manifest.readText())?.value.orEmpty()
        assertTrue(receiver.contains("android:enabled=\"true\""))
        val senderOnly = "android:permission=\"android.permission.MODIFY_PHONE_STATE\""
        assertTrue(receiver.contains(senderOnly))
    }
}
