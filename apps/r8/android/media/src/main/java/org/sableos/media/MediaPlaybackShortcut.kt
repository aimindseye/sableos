package org.sableos.media

/**
 * Titan 2 Q25 Media Now Playing shortcuts (source candidate, not installed acceptance).
 * Input fields and modified key combinations always win.
 */
internal enum class MediaPlaybackShortcut {
    Previous,
    Next,
    Queue,
}

internal data class MediaPlaybackModifiers(
    val alt: Boolean = false,
    val ctrl: Boolean = false,
    val meta: Boolean = false,
    val shift: Boolean = false,
) {
    fun isPressed(): Boolean = alt || ctrl || meta || shift
}

internal fun mediaPlaybackShortcut(
    key: Char,
    editingText: Boolean,
    modifiers: MediaPlaybackModifiers = MediaPlaybackModifiers(),
): MediaPlaybackShortcut? {
    if (editingText || modifiers.isPressed()) return null
    return when (key.lowercaseChar()) {
        'j' -> MediaPlaybackShortcut.Previous
        'k' -> MediaPlaybackShortcut.Next
        'q' -> MediaPlaybackShortcut.Queue
        else -> null
    }
}
