package org.sableos.hub

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HubModelsTest {
    @Test
    fun providerCatalogUsesExplicitWebCapabilityAndUniqueIds() {
        val providers = HubProviderCatalog.providers

        assertEquals(4, providers.size)
        assertEquals(
            providers.size,
            providers.map { it.id }.toSet().size,
        )
        assertTrue(
            providers.all {
                it.capabilityClass == ProviderCapabilityClass.Web
            },
        )
    }

    @Test
    fun providerHostAllowlistAcceptsSubdomainsButRejectsLookalikes() {
        val provider =
            requireNotNull(HubProviderCatalog.byId("linkedin"))

        assertTrue(provider.allowsHost("www.linkedin.com"))
        assertTrue(provider.allowsHost("linkedin.com"))
        assertFalse(provider.allowsHost("linkedin.com.example.org"))
        assertFalse(provider.allowsHost("example.org"))
    }

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
}
