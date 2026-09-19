package org.sableos.hub

enum class ProviderCapabilityClass {
    NativeData,
    AndroidNotification,
    SupportedApi,
    Web,
    Unavailable,
}

data class HubProvider(
    val id: String,
    val displayName: String,
    val capabilityClass: ProviderCapabilityClass,
    val startUrl: String,
    val allowedHosts: Set<String>,
    val note: String,
) {
    fun allowsHost(host: String?): Boolean {
        val normalized = host?.lowercase()?.trimEnd('.') ?: return false
        return allowedHosts.any { allowed ->
            normalized == allowed || normalized.endsWith("." + allowed)
        }
    }
}

object HubProviderCatalog {
    val providers: List<HubProvider> =
        listOf(
            HubProvider(
                id = "whatsapp",
                displayName = "WhatsApp",
                capabilityClass = ProviderCapabilityClass.Web,
                startUrl = "https://web.whatsapp.com/",
                allowedHosts = setOf("whatsapp.com"),
                note = "WEB · isolated session · availability depends on provider web support",
            ),
            HubProvider(
                id = "instagram",
                displayName = "Instagram",
                capabilityClass = ProviderCapabilityClass.Web,
                startUrl = "https://www.instagram.com/direct/inbox/",
                allowedHosts = setOf("instagram.com"),
                note = "WEB · isolated session",
            ),
            HubProvider(
                id = "messenger",
                displayName = "Facebook / Messenger",
                capabilityClass = ProviderCapabilityClass.Web,
                startUrl = "https://www.messenger.com/",
                allowedHosts = setOf("messenger.com", "facebook.com"),
                note = "WEB · isolated session",
            ),
            HubProvider(
                id = "linkedin",
                displayName = "LinkedIn",
                capabilityClass = ProviderCapabilityClass.Web,
                startUrl = "https://www.linkedin.com/messaging/",
                allowedHosts = setOf("linkedin.com"),
                note = "WEB · isolated session",
            ),
        )

    fun byId(id: String): HubProvider? =
        providers.firstOrNull { it.id == id }
}

data class HubMessage(
    val id: Long,
    val threadId: Long,
    val address: String,
    val body: String,
    val dateMillis: Long,
    val incoming: Boolean,
    val read: Boolean,
)

data class HubConversation(
    val threadId: Long,
    val address: String,
    val displayName: String,
    val lastBody: String,
    val lastDateMillis: Long,
    val unreadCount: Int,
)

data class HubPerson(
    val id: Long,
    val displayName: String,
    val phoneNumber: String,
)

data class HubCapabilities(
    val hasTelephony: Boolean,
    val canReadSms: Boolean,
    val canSendSms: Boolean,
    val canReadContacts: Boolean,
    val isDefaultSmsRoleHolder: Boolean,
)

data class HubSnapshot(
    val capabilities: HubCapabilities,
    val conversations: List<HubConversation>,
    val messages: List<HubMessage>,
    val people: List<HubPerson>,
)

object HubConversationReducer {
    fun reduce(
        messages: List<HubMessage>,
        displayNameForAddress: (String) -> String = { it },
    ): List<HubConversation> =
        messages
            .groupBy { message ->
                ConversationKey(
                    threadId = message.threadId,
                    address = message.address,
                )
            }
            .map { (key, grouped) ->
                val ordered = grouped.sortedByDescending { it.dateMillis }
                val latest = ordered.first()
                HubConversation(
                    threadId = key.threadId,
                    address = key.address,
                    displayName = displayNameForAddress(key.address),
                    lastBody = latest.body,
                    lastDateMillis = latest.dateMillis,
                    unreadCount = ordered.count { it.incoming && !it.read },
                )
            }
            .sortedByDescending { it.lastDateMillis }

    private data class ConversationKey(
        val threadId: Long,
        val address: String,
    )
}
