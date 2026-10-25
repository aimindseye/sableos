package org.sableos.messages

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MessagesIncomingRefreshPolicyTest {
    private fun thread(
        id: String,
        message: String,
        incoming: Boolean = true,
        unread: Int = 1,
    ) = SableThread(
        id = id,
        person = "Test contact",
        route = "test-only",
        source = "Android SMS provider · read-only",
        priority = 1,
        unreadCount = unread,
        messages =
            listOf(
                SableMessage(
                    id = message,
                    sender = "Test",
                    body = "synthetic",
                    time = "",
                    incoming = incoming,
                ),
            ),
    )

    @Test fun firstSnapshotCannotTriggerIncomingNotification() {
        assertFalse(
            MessagesIncomingRefreshPolicy.hasNewLatestIncoming(null, listOf(thread("1", "100"))),
        )
    }

    @Test fun unchangedOrReorderedFeedCannotTriggerIncomingNotification() {
        val old = listOf(thread("1", "100"), thread("2", "200"))
        assertFalse(MessagesIncomingRefreshPolicy.hasNewLatestIncoming(old, old.reversed()))
    }

    @Test fun newIncomingInExistingConversationNotifies() {
        assertTrue(
            MessagesIncomingRefreshPolicy.hasNewLatestIncoming(
                listOf(thread("1", "100")),
                listOf(thread("1", "101")),
            ),
        )
    }

    @Test fun outgoingMessageDoesNotTriggerIncomingNotification() {
        assertFalse(
            MessagesIncomingRefreshPolicy.hasNewLatestIncoming(
                listOf(thread("1", "100")),
                listOf(thread("1", "101", incoming = false)),
            ),
        )
    }

    @Test fun newlyDiscoveredUnreadConversationNotifiesButReadConversationDoesNot() {
        assertTrue(
            MessagesIncomingRefreshPolicy.hasNewLatestIncoming(
                emptyList(),
                listOf(thread("new", "101")),
            ),
        )
        assertFalse(
            MessagesIncomingRefreshPolicy.hasNewLatestIncoming(
                emptyList(),
                listOf(thread("new", "101", unread = 0)),
            ),
        )
    }
}
