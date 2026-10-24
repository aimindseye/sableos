package org.sableos.media

/** Only a focused, non-editable Now Playing surface may consume Space. */
internal object MediaNowPlayingKeyPolicy {
    fun shouldTogglePlayPause(
        isSpace: Boolean,
        hasItem: Boolean,
        hasModifiers: Boolean,
    ): Boolean = isSpace && hasItem && !hasModifiers
}
