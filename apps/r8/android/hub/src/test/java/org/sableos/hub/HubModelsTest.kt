package org.sableos.hub

import org.junit.Assert.assertEquals
import org.junit.Test

class HubModelsTest {
    @Test
    fun reducerKeepsNewestMessageAndCountsUnreadIncoming() {
        val messages =
            listOf(
                HubMessage(
                    id = 1,
                    threadId = 10,
                    address = "+15551234567",
                    body = "older",
                    dateMillis = 100,
                    incoming = true,
                    read = false,
                ),
                HubMessage(
                    id = 2,
                    threadId = 10,
                    address = "+15551234567",
                    body = "newest",
                    dateMillis = 300,
                    incoming = false,
                    read = true,
                ),
                HubMessage(
                    id = 3,
                    threadId = 11,
                    address = "+15557654321",
                    body = "middle",
                    dateMillis = 200,
                    incoming = true,
                    read = false,
                ),
            )

        val reduced =
            HubConversationReducer.reduce(messages) { address ->
                if (address.endsWith("4567")) "Ada" else "Grace"
            }

        assertEquals(2, reduced.size)
        assertEquals("Ada", reduced.first().displayName)
        assertEquals("newest", reduced.first().lastBody)
        assertEquals(1, reduced.first().unreadCount)
        assertEquals("Grace", reduced[1].displayName)
    }

    @Test
    fun connectedReducerKeepsSourceBoundaryAndReplyCapability() {
        val key =
            ConnectedAppKey(
                packageName = "org.example.messaging",
                userSerial = 10L,
            )
        val records =
            listOf(
                ConnectedNotificationRecord(
                    id = "record-1",
                    key = key,
                    notificationKey = "notification-1",
                    conversationId = "alice",
                    conversationTitle = "Alice",
                    sourceLabel = "Example",
                    senderLabel = "Alice",
                    body = "hello",
                    timestampMillis = 100L,
                    incoming = true,
                ),
                ConnectedNotificationRecord(
                    id = "record-2",
                    key = key,
                    notificationKey = "notification-2",
                    conversationId = "alice",
                    conversationTitle = "Alice",
                    sourceLabel = "Example",
                    senderLabel = null,
                    body = "reply",
                    timestampMillis = 200L,
                    incoming = false,
                ),
            )

        val reduced =
            HubConnectedConversationReducer.reduce(records) { notificationKey ->
                notificationKey == "notification-2"
            }

        assertEquals(1, reduced.conversations.size)
        assertEquals(2, reduced.messages.size)
        assertEquals(HubConversationSource.ConnectedApp, reduced.conversations[0].source)
        assertEquals(true, reduced.conversations[0].canQuickReply)
        assertEquals(0, reduced.conversations[0].unreadCount)
        assertEquals(true, reduced.conversations[0].threadId < 0L)
    }
}
