package org.sableos.messages

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MessagesGlobalKeyPolicyTest {
    @Test fun globalFallbackNeverSynthesizesPhysicalText() {
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerTyping))
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.TypeToFilter))
    }

    @Test fun unfocusedEnterCannotLaunchProviderSend() {
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerEnterSend))
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerAltEnterProviderSend))
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerShiftEnterNewline))
    }

    @Test fun globalBackspaceCannotChangeAnUnfocusedDraft() {
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerBackspace))
        assertFalse(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ComposerDelete))
    }

    @Test fun explicitNavigationAndSearchRemainAvailable() {
        assertTrue(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.ReturnToLatest))
        assertTrue(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.PageUpHistory))
        assertTrue(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.SearchInConversation))
        assertTrue(MessagesGlobalKeyPolicy.shouldHandle(MessagesAction.OpenFocusedConversation))
    }
}
