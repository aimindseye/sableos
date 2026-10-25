package org.sableos.tools.core

/** Test-only legacy device fixture. Not compiled into the Titan 2 APK. */
internal object LegacyQ25TestFixture {
    private val diagnostic = (listOf(
        Capability.COMPASS, Capability.BUBBLE_LEVEL, Capability.PLUMB_BOB,
        Capability.PROTRACTOR, Capability.PICTURE_HANGING, Capability.HEIGHT_ESTIMATE,
        Capability.PEDOMETER, Capability.FLASHLIGHT, Capability.MAGNIFIER,
        Capability.NOISE_METER, Capability.SPEEDOMETER, Capability.FM_RADIO
    )).associateWith { Declaration(Declared.DIAGNOSTIC_ONLY, "test fixture only") }

    val profile = ToolsDeviceProfile(
        "zinwa-q25", "Zinwa Q25",
        diagnostic + mapOf(
            Capability.IR_REMOTE to Declaration(Declared.UNSUPPORTED, "test fixture only"),
            Capability.IR_LEARNING to Declaration(Declared.UNSUPPORTED, "test fixture only"),
            Capability.SUBSCREEN_COMPANION to Declaration(Declared.UNSUPPORTED, "test fixture only")
        ),
        KeyboardTraits(
            setOf(Modifier.ALT, Modifier.SHIFT, Modifier.SYM),
            digitsOnAltLayer = true,
            light = KeyboardLightSource.INPUT_LIGHTS
        )
    )
}
