package org.sableos.messages

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MessagesExposureGateTest {
    @Test fun lockedStateFailsClosed() {
        assertFalse(MessagesExposureGate.showConversations(androidUserLocked = true))
    }

    @Test fun unlockedStateMayShowAppOwnedUi() {
        assertTrue(MessagesExposureGate.showConversations(androidUserLocked = false))
    }
}
