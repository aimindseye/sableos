package org.sableos.hub

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

data class HubSendResult(
    val success: Boolean,
    val message: String,
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
            }.map { (key, grouped) ->
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
            }.sortedByDescending { it.lastDateMillis }

    private data class ConversationKey(
        val threadId: Long,
        val address: String,
    )
}
