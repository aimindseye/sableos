package org.sableos.titan2.camera.core

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraPreviewInputPolicyTest {
    @Test fun directFingerUpReveals() {
        assertTrue(CameraPreviewInputPolicy.revealControls(0x1002, 1, 1))
    }

    @Test fun directStylusUpReveals() {
        assertTrue(CameraPreviewInputPolicy.revealControls(0x1002, 2, 1))
    }

    @Test fun mouseAndTrackpadAreIgnored() {
        assertFalse(CameraPreviewInputPolicy.revealControls(0x2002, 3, 1))
        assertFalse(CameraPreviewInputPolicy.revealControls(0x2002, 1, 1))
    }

    @Test fun touchMoveAndDownDoNotToggle() {
        assertFalse(CameraPreviewInputPolicy.revealControls(0x1002, 1, 0))
        assertFalse(CameraPreviewInputPolicy.revealControls(0x1002, 1, 2))
    }

    @Test fun unknownSourceNeverToggles() {
        assertFalse(CameraPreviewInputPolicy.revealControls(0, 1, 1))
    }
}
