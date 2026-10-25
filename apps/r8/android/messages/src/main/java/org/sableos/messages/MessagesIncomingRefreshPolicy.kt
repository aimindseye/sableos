package org.sableos.messages

/**
 * Detect a new latest incoming SMS in an already-authorized provider snapshot.
 * The first permitted snapshot is a baseline, never a synthetic notification.
 * Thread/message IDs originate with Android Telephony; there is no SMS write path.
 */
object MessagesIncomingRefreshPolicy {
    fun hasNewLatestIncoming(
        previous: List<SableThread>?,
        current: List<SableThread>,
    ): Boolean {
        if (previous == null) return false
        val previousLatest = previous.associate { it.id to it.messages.lastOrNull()?.id }
        return current.any { thread ->
            val newest = thread.messages.lastOrNull()
            newest != null && newest.incoming &&
                newest.id != previousLatest[thread.id] &&
                (previousLatest[thread.id] != null || thread.unreadCount > 0)
        }
    }
}
