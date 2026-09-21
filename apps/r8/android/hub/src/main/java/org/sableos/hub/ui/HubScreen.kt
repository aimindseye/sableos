package org.sableos.hub.ui

import android.text.format.DateUtils
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SableListRow
import org.sableos.design.SablePageHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTile
import org.sableos.hub.HubConversation
import org.sableos.hub.HubMessage
import org.sableos.hub.HubProvider
import org.sableos.hub.HubSendResult
import org.sableos.hub.HubSnapshot
import org.sableos.hub.ProviderCapabilityClass

private enum class HubPivot {
    All,
    Messages,
    People,
    Services,
}

private sealed interface HubRoute {
    data class Root(
        val pivot: HubPivot,
    ) : HubRoute

    data class Conversation(
        val conversation: HubConversation,
    ) : HubRoute

    data class Compose(
        val recipient: String = "",
    ) : HubRoute
}

@Composable
fun HubScreen(
    snapshot: HubSnapshot,
    providers: List<HubProvider>,
    onRefresh: () -> Unit,
    onRequestAccess: () -> Unit,
    onSendSms: (String, String) -> HubSendResult,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
    onOpenProvider: (String) -> Boolean,
) {
    var route by remember {
        mutableStateOf<HubRoute>(HubRoute.Root(HubPivot.All))
    }
    var search by remember {
        mutableStateOf("")
    }
    var statusMessage by remember {
        mutableStateOf<String?>(null)
    }

    SableScrollableScreen {
        when (val current = route) {
            is HubRoute.Root -> {
                SablePageHeader(
                    title = "Messages",
                    subtitle = "Conversations, people and services in one Sable surface.",
                )

                HubPivotRow(
                    selected = current.pivot,
                    onSelect = { pivot ->
                        route = HubRoute.Root(pivot)
                        statusMessage = null
                    },
                )

                statusMessage?.let { message ->
                    SablePanel {
                        Text(
                            text = message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                when (current.pivot) {
                    HubPivot.All ->
                        AllPivot(
                            snapshot = snapshot,
                            providers = providers,
                            onConversation = {
                                route = HubRoute.Conversation(it)
                            },
                            onCompose = {
                                route = HubRoute.Compose()
                            },
                            onRequestAccess = onRequestAccess,
                            onOpenAndroidMessaging = onOpenAndroidMessaging,
                            onOpenProvider = { provider ->
                                if (!onOpenProvider(provider.id)) {
                                    statusMessage =
                                        "That provider capsule could not be opened."
                                }
                            },
                        )

                    HubPivot.Messages ->
                        MessagesPivot(
                            snapshot = snapshot,
                            search = search,
                            onSearchChange = { search = it },
                            onConversation = {
                                route = HubRoute.Conversation(it)
                            },
                            onCompose = {
                                route = HubRoute.Compose()
                            },
                            onRefresh = onRefresh,
                            onRequestAccess = onRequestAccess,
                            onOpenAndroidMessaging = onOpenAndroidMessaging,
                        )

                    HubPivot.People ->
                        PeoplePivot(
                            snapshot = snapshot,
                            search = search,
                            onSearchChange = { search = it },
                            onCompose = { number ->
                                route = HubRoute.Compose(number)
                            },
                            onRequestAccess = onRequestAccess,
                        )

                    HubPivot.Services ->
                        ServicesPivot(
                            providers = providers,
                            onOpenProvider = { provider ->
                                if (!onOpenProvider(provider.id)) {
                                    statusMessage =
                                        "That provider capsule could not be opened."
                                }
                            },
                        )
                }
            }

            is HubRoute.Conversation -> {
                ConversationView(
                    conversation = current.conversation,
                    messages =
                        snapshot.messages
                            .filter {
                                it.threadId == current.conversation.threadId
                            }
                            .sortedBy { it.dateMillis },
                    onBack = {
                        route = HubRoute.Root(HubPivot.Messages)
                    },
                    onReply = {
                        route =
                            HubRoute.Compose(
                                recipient = current.conversation.address,
                            )
                    },
                )
            }

            is HubRoute.Compose -> {
                ComposeView(
                    initialRecipient = current.recipient,
                    canSendSms = snapshot.capabilities.canSendSms,
                    onBack = {
                        route = HubRoute.Root(HubPivot.Messages)
                    },
                    onRequestAccess = onRequestAccess,
                    onSendSms = { recipient, body ->
                        val result = onSendSms(recipient, body)
                        statusMessage = result.message
                        if (result.success) {
                            route = HubRoute.Root(HubPivot.Messages)
                        }
                        result
                    },
                    onOpenAndroidMessaging = { recipient, body ->
                        val opened =
                            onOpenAndroidMessaging(
                                recipient.takeIf { it.isNotBlank() },
                                body.takeIf { it.isNotBlank() },
                            )
                        statusMessage =
                            if (opened) {
                                "Opened the proven Android messaging transport."
                            } else {
                                "No Android messaging transport is available."
                            }
                    },
                )
            }
        }
    }
}

@Composable
private fun HubPivotRow(
    selected: HubPivot,
    onSelect: (HubPivot) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
    ) {
        HubPivot.entries.forEach { pivot ->
            TextButton(
                onClick = { onSelect(pivot) },
                modifier =
                    Modifier.weight(
                        if (pivot == HubPivot.Messages) 1.12f else 1f,
                    ),
                contentPadding = PaddingValues(horizontal = SableSpacing.Xs),
            ) {
                Text(
                    text = pivot.name.uppercase(),
                    maxLines = 1,
                    softWrap = false,
                    style = MaterialTheme.typography.labelLarge,
                    color =
                        if (pivot == selected) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                )
            }
        }
    }
}

@Composable
private fun AllPivot(
    snapshot: HubSnapshot,
    providers: List<HubProvider>,
    onConversation: (HubConversation) -> Unit,
    onCompose: () -> Unit,
    onRequestAccess: () -> Unit,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
    onOpenProvider: (HubProvider) -> Unit,
) {
    AccessPanel(
        snapshot = snapshot,
        onRequestAccess = onRequestAccess,
        onOpenAndroidMessaging = onOpenAndroidMessaging,
    )

    SableActionButton(
        text = "New message",
        onClick = onCompose,
    )

    SableSectionHeader("Recent conversations")
    if (snapshot.conversations.isEmpty()) {
        SablePanel {
            Text(
                text =
                    if (snapshot.capabilities.canReadSms) {
                        "No SMS conversations are available yet."
                    } else {
                        "SMS history is not available in Sable Messages yet."
                    },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        snapshot.conversations.take(5).forEach { conversation ->
            ConversationRow(
                conversation = conversation,
                onClick = { onConversation(conversation) },
            )
        }
    }

    SableSectionHeader("Services")
    providers.forEach { provider ->
        ProviderTile(
            provider = provider,
            onOpen = { onOpenProvider(provider) },
        )
    }
}

@Composable
private fun MessagesPivot(
    snapshot: HubSnapshot,
    search: String,
    onSearchChange: (String) -> Unit,
    onConversation: (HubConversation) -> Unit,
    onCompose: () -> Unit,
    onRefresh: () -> Unit,
    onRequestAccess: () -> Unit,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
) {
    AccessPanel(
        snapshot = snapshot,
        onRequestAccess = onRequestAccess,
        onOpenAndroidMessaging = onOpenAndroidMessaging,
    )

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
    ) {
        SableActionButton(
            text = "New message",
            modifier = Modifier.weight(1f),
            onClick = onCompose,
        )
        SableActionButton(
            text = "Refresh",
            modifier = Modifier.weight(1f),
            primary = false,
            onClick = onRefresh,
        )
    }

    OutlinedTextField(
        value = search,
        onValueChange = onSearchChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Search conversations") },
    )

    val query = search.trim()
    val filtered =
        if (query.isBlank()) {
            snapshot.conversations
        } else {
            snapshot.conversations.filter { conversation ->
                conversation.displayName.contains(query, ignoreCase = true) ||
                    conversation.address.contains(query, ignoreCase = true) ||
                    conversation.lastBody.contains(query, ignoreCase = true)
            }
        }

    if (filtered.isEmpty()) {
        SablePanel {
            Text(
                text =
                    if (snapshot.capabilities.canReadSms) {
                        "No matching conversations."
                    } else {
                        "Grant SMS access when available, or open the system messaging service."
                    },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        filtered.forEach { conversation ->
            ConversationRow(
                conversation = conversation,
                onClick = { onConversation(conversation) },
            )
        }
    }
}

@Composable
private fun ConversationRow(
    conversation: HubConversation,
    onClick: () -> Unit,
) {
    val unread =
        if (conversation.unreadCount > 0) {
            " · " + conversation.unreadCount + " unread"
        } else {
            ""
        }

    SableListRow(
        title = conversation.displayName,
        subtitle =
            conversation.lastBody.take(80) +
                unread +
                " · " +
                relativeTime(conversation.lastDateMillis),
        selected = conversation.unreadCount > 0,
        onClick = onClick,
    )
}

@Composable
private fun PeoplePivot(
    snapshot: HubSnapshot,
    search: String,
    onSearchChange: (String) -> Unit,
    onCompose: (String) -> Unit,
    onRequestAccess: () -> Unit,
) {
    if (!snapshot.capabilities.canReadContacts) {
        SablePanel {
            Text(
                text =
                    "People requires user-authorized Contacts access. No separate Sable contact database is created.",
                style = MaterialTheme.typography.bodyMedium,
            )
            SableActionButton(
                text = "Review access",
                onClick = onRequestAccess,
            )
        }
    }

    OutlinedTextField(
        value = search,
        onValueChange = onSearchChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Search people") },
    )

    val query = search.trim()
    val people =
        if (query.isBlank()) {
            snapshot.people
        } else {
            snapshot.people.filter { person ->
                person.displayName.contains(query, ignoreCase = true) ||
                    person.phoneNumber.contains(query, ignoreCase = true)
            }
        }

    if (people.isEmpty()) {
        SablePanel {
            Text(
                text = "No matching people are available.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        people.take(200).forEach { person ->
            SableListRow(
                title = person.displayName,
                subtitle = person.phoneNumber,
                onClick = { onCompose(person.phoneNumber) },
            )
        }
    }
}

@Composable
private fun ServicesPivot(
    providers: List<HubProvider>,
    onOpenProvider: (HubProvider) -> Unit,
) {
    SablePanel {
        Text(
            text =
                "Provider capsules are isolated WEB sessions when no suitable consumer messaging API exists. Sable does not call them native integrations.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    providers.forEach { provider ->
        ProviderTile(
            provider = provider,
            onOpen = { onOpenProvider(provider) },
        )
    }
}

@Composable
private fun ProviderTile(
    provider: HubProvider,
    onOpen: () -> Unit,
) {
    val capability =
        when (provider.capabilityClass) {
            ProviderCapabilityClass.NativeData -> "NATIVE DATA"
            ProviderCapabilityClass.AndroidNotification -> "ANDROID NOTIFICATION"
            ProviderCapabilityClass.SupportedApi -> "SUPPORTED API"
            ProviderCapabilityClass.Web -> "WEB"
            ProviderCapabilityClass.Unavailable -> "UNAVAILABLE"
        }

    SableTile(
        title = provider.displayName,
        subtitle = capability + " · " + provider.note,
        onClick = onOpen,
    )
}

@Composable
private fun AccessPanel(
    snapshot: HubSnapshot,
    onRequestAccess: () -> Unit,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
) {
    val capabilityText =
        buildString {
            append(
                if (snapshot.capabilities.canReadSms) {
                    "SMS history: available"
                } else {
                    "SMS history: unavailable"
                },
            )
            append(" · ")
            append(
                if (snapshot.capabilities.canSendSms) {
                    "send: available"
                } else {
                    "send: unavailable"
                },
            )
            append(" · ")
            append(
                if (snapshot.capabilities.canReadContacts) {
                    "people: available"
                } else {
                    "people: unavailable"
                },
            )
        }

    SablePanel {
        Text(
            text = "Messaging status",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = capabilityText,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text =
                if (snapshot.capabilities.isDefaultSmsRoleHolder) {
                    "Sable Messages is handling SMS directly on this device."
                } else {
                    "Sable Messages can read and send SMS when access is granted. MMS/RCS can open the system messaging service when needed."
                },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableActionButton(
                text = "Review access",
                modifier = Modifier.weight(1f),
                onClick = onRequestAccess,
            )
            SableActionButton(
                text = "Open MMS / RCS",
                modifier = Modifier.weight(1f),
                primary = false,
                onClick = {
                    onOpenAndroidMessaging(null, null)
                },
            )
        }
    }
}

@Composable
private fun ConversationView(
    conversation: HubConversation,
    messages: List<HubMessage>,
    onBack: () -> Unit,
    onReply: () -> Unit,
) {
    SablePageHeader(
        title = conversation.displayName,
        subtitle = conversation.address,
    )

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
    ) {
        SableActionButton(
            text = "Back",
            modifier = Modifier.weight(1f),
            primary = false,
            onClick = onBack,
        )
        SableActionButton(
            text = "Reply",
            modifier = Modifier.weight(1f),
            onClick = onReply,
        )
    }

    messages.forEach { message ->
        SablePanel {
            Text(
                text = if (message.incoming) "INCOMING" else "SENT",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = message.body.ifBlank { "Empty SMS body" },
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = relativeTime(message.dateMillis),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ComposeView(
    initialRecipient: String,
    canSendSms: Boolean,
    onBack: () -> Unit,
    onRequestAccess: () -> Unit,
    onSendSms: (String, String) -> HubSendResult,
    onOpenAndroidMessaging: (String, String) -> Unit,
) {
    var recipient by remember(initialRecipient) {
        mutableStateOf(initialRecipient)
    }
    var body by remember {
        mutableStateOf("")
    }
    var localStatus by remember {
        mutableStateOf<String?>(null)
    }

    SablePageHeader(
        title = "New message",
        subtitle = "Write an SMS here. MMS/RCS can be handed off when needed.",
    )

    OutlinedTextField(
        value = recipient,
        onValueChange = { recipient = it },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Phone number") },
    )

    OutlinedTextField(
        value = body,
        onValueChange = { body = it },
        modifier = Modifier.fillMaxWidth(),
        minLines = 4,
        label = { Text("Message") },
    )

    localStatus?.let { message ->
        SablePanel {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }

    if (canSendSms) {
        SableActionButton(
            text = "Send SMS",
            onClick = {
                val result = onSendSms(recipient.trim(), body)
                localStatus = result.message
            },
        )
    } else {
        SablePanel {
            Text(
                text =
                    "SMS sending needs access. Review permissions here, or continue this draft in the system messaging service.",
                style = MaterialTheme.typography.bodyMedium,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                SableActionButton(
                    text = "Review access",
                    modifier = Modifier.weight(1f),
                    onClick = onRequestAccess,
                )
                SableActionButton(
                    text = "Open messaging",
                    modifier = Modifier.weight(1f),
                    primary = false,
                    onClick = {
                        onOpenAndroidMessaging(recipient.trim(), body)
                    },
                )
            }
        }
    }

    SableActionButton(
        text = "Back",
        primary = false,
        onClick = onBack,
    )
}

private fun relativeTime(timestamp: Long): String =
    DateUtils.getRelativeTimeSpanString(
        timestamp,
        System.currentTimeMillis(),
        DateUtils.MINUTE_IN_MILLIS,
    ).toString()
