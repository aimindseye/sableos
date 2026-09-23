package org.sableos.media

import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

/**
 * Bounded process-local handoff for a local playback queue.
 *
 * Sable Media's Activity and PlaybackService intentionally run in the same
 * process. Sending thousands of URI/title/artist strings through an Intent
 * duplicates the full library and can exceed Binder transaction limits. Keep
 * at most one pending request in-process and send only its opaque token.
 */
internal data class PlaybackQueueRequest(
    val token: String,
    val items: List<LocalAudioItem>,
    val startIndex: Int,
)

internal object PlaybackQueueRequestStore {
    private val pending = AtomicReference<PlaybackQueueRequest?>(null)

    fun publish(
        items: List<LocalAudioItem>,
        startIndex: Int,
    ): String {
        require(items.isNotEmpty())

        val token = UUID.randomUUID().toString()
        pending.set(
            PlaybackQueueRequest(
                token = token,
                items = items.toList(),
                startIndex = startIndex.coerceIn(0, items.lastIndex),
            ),
        )
        return token
    }

    fun consume(token: String): PlaybackQueueRequest? {
        while (true) {
            val current = pending.get() ?: return null
            if (current.token != token) {
                return null
            }
            if (pending.compareAndSet(current, null)) {
                return current
            }
        }
    }
}
