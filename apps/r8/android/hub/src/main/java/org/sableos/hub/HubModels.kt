package org.sableos.hub

enum class HubConversationSource {
    Sms,
    ConnectedApp,
}

data class HubMessage(
    val id: Long,
    val threadId: Long,
    val address: String,
    val body: String,
    val dateMillis: Long,
    val incoming: Boolean,
    val read: Boolean,
    val source: HubConversationSource = HubConversationSource.Sms,
    val senderLabel: String? = null,
)

data class HubConversation(
    val threadId: Long,
    val address: String,
    val displayName: String,
    val lastBody: String,
    val lastDateMillis: Long,
    val unreadCount: Int,
    val source: HubConversationSource = HubConversationSource.Sms,
    val sourcePackage: String? = null,
    val sourceUserSerial: Long? = null,
    val sourceNotificationKey: String? = null,
    val sourceLabel: String? = null,
    val canQuickReply: Boolean = false,
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

data class ConnectedConversationReduction(
    val conversations: List<HubConversation>,
    val messages: List<HubMessage>,
)

object HubConnectedConversationReducer {
    fun reduce(
        records: List<ConnectedNotificationRecord>,
        canReply: (String) -> Boolean = { false },
    ): ConnectedConversationReduction {
        val grouped =
            records.groupBy { record ->
                ConnectedConversationKey(
                    key = record.key,
                    conversationId = record.conversationId,
                )
            }

        val messages = mutableListOf<HubMessage>()
        val conversations =
            grouped.map { (key, group) ->
                val ordered = group.sortedBy { it.timestampMillis }
                val latest = ordered.last()
                val threadId =
                    stableNegativeId(
                        key.key.packageName +
                            ":" +
                            key.key.userSerial +
                            ":" +
                            key.conversationId,
                    )

                ordered.forEach { record ->
                    messages +=
                        HubMessage(
                            id = stableNegativeId(record.id),
                            threadId = threadId,
                            address = record.conversationTitle,
                            body = record.body.orEmpty(),
                            dateMillis = record.timestampMillis,
                            incoming = record.incoming,
                            read = true,
                            source = HubConversationSource.ConnectedApp,
                            senderLabel = record.senderLabel,
                        )
                }

                HubConversation(
                    threadId = threadId,
                    address = latest.conversationId,
                    displayName = latest.conversationTitle,
                    lastBody = latest.body.orEmpty(),
                    lastDateMillis = latest.timestampMillis,
                    unreadCount = 0,
                    source = HubConversationSource.ConnectedApp,
                    sourcePackage = latest.key.packageName,
                    sourceUserSerial = latest.key.userSerial,
                    sourceNotificationKey = latest.notificationKey,
                    sourceLabel = latest.sourceLabel,
                    canQuickReply = canReply(latest.notificationKey),
                )
            }.sortedByDescending { conversation ->
                conversation.lastDateMillis
            }

        return ConnectedConversationReduction(
            conversations = conversations,
            messages =
                messages.sortedByDescending { message ->
                    message.dateMillis
                },
        )
    }

    private fun stableNegativeId(value: String): Long {
        var hash = FNV_OFFSET_BASIS
        value.encodeToByteArray().forEach { byte ->
            hash = hash xor (byte.toLong() and BYTE_MASK)
            hash *= FNV_PRIME
        }

        return when {
            hash == Long.MIN_VALUE -> Long.MIN_VALUE + 1L
            hash > 0L -> -hash
            hash == 0L -> -1L
            else -> hash
        }
    }

    private data class ConnectedConversationKey(
        val key: ConnectedAppKey,
        val conversationId: String,
    )

    private const val FNV_OFFSET_BASIS = -3750763034362895579L
    private const val FNV_PRIME = 1099511628211L
    private const val BYTE_MASK = 0xFFL
}

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
