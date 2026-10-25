package org.sableos.media

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaNowPlayingKeyPolicyTest {
    @Test
    fun unmodifiedSpaceTogglesWhenAnItemExists() {
        assertTrue(MediaNowPlayingKeyPolicy.shouldTogglePlayPause(true, true, false))
    }

    @Test
    fun emptyPlaybackDoesNotConsumeSpace() {
        assertFalse(MediaNowPlayingKeyPolicy.shouldTogglePlayPause(true, false, false))
    }

    @Test
    fun modifiersDoNotHijackPlatformShortcuts() {
        assertFalse(MediaNowPlayingKeyPolicy.shouldTogglePlayPause(true, true, true))
    }

    @Test
    fun otherKeysRetainExistingJkqRouting() {
        assertFalse(MediaNowPlayingKeyPolicy.shouldTogglePlayPause(false, true, false))
    }
}
