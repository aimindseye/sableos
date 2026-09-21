package org.sableos.hub.ui

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
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
import java.text.DateFormat
import java.util.Date

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
        mutableStateOf<HubRoute>(HubRoute.Root(HubPivot.Messages))
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
                    title = "messages",
                    subtitle = "One visible Sable communication surface; transport detail stays secondary.",
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
                        "No conversations yet."
                    } else {
                        "Grant Messages access to show your SMS conversations."
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
    SableActionButton(
        text = "+  new message",
        primary = false,
        onClick = onCompose,
    )

    Spacer(Modifier.height(SableSpacing.Sm))

    if (snapshot.conversations.isEmpty()) {
        SablePanel {
            Text(
                text =
                    if (snapshot.capabilities.canReadSms) {
                        "No conversations yet."
                    } else {
                        "Grant Messages access to show your conversations."
                    },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        snapshot.conversations.take(80).forEach { conversation ->
            ConversationRow(
                conversation = conversation,
                onClick = { onConversation(conversation) },
            )
        }
    }

    Spacer(Modifier.height(SableSpacing.Md))
    ApprovedMessagingStatusPanel(
        snapshot = snapshot,
        onRequestAccess = onRequestAccess,
        onOpenAndroidMessaging = onOpenAndroidMessaging,
    )
}

@Composable
private fun ApprovedMessagingStatusPanel(
    snapshot: HubSnapshot,
    onRequestAccess: () -> Unit,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
) {
    val ready =
        snapshot.capabilities.canReadSms &&
            snapshot.capabilities.canSendSms

    SablePanel {
        Text(
            text = "Messaging status",
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text =
                if (ready) {
                    "SMS ready · MMS/RCS can open the system messaging service when needed."
                } else {
                    "Grant Messages access for SMS. MMS/RCS can use the system messaging service when needed."
                },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (!ready) {
            Spacer(Modifier.height(SableSpacing.Sm))
            SableActionButton(
                text = "Review access",
                primary = false,
                onClick = onRequestAccess,
            )
        }
    }
}

@Composable
private fun ConversationRow(
    conversation: HubConversation,
    onClick: () -> Unit,
) {
    val unread = conversation.unreadCount > 0
    val accent =
        if (unread) {
            Color(0xFF35C66B)
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        }
    val initial =
        conversation.displayName
            .trim()
            .firstOrNull()
            ?.uppercaseChar()
            ?.toString()
            ?: "?"

    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(48.dp)
                    .background(
                        if (unread) {
                            Color(0xFF0B3524)
                        } else {
                            MaterialTheme.colorScheme.surfaceVariant
                        },
                        CircleShape,
                    ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = initial,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = conversation.displayName,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = conversation.lastBody.take(80),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
        Spacer(Modifier.width(10.dp))
        Text(
            text = clockTime(conversation.lastDateMillis),
            style = MaterialTheme.typography.titleMedium,
            color = accent,
        )
    }
    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant),
    )
}

private fun clockTime(epochMillis: Long): String =
    DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMillis))

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
                "Services open in private, isolated web sessions when a native integration is not available.",
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
    val subtitle =
        when (provider.capabilityClass) {
            ProviderCapabilityClass.NativeData -> "Integrated"
            ProviderCapabilityClass.AndroidNotification -> "Notification access"
            ProviderCapabilityClass.SupportedApi -> "Connected service"
            ProviderCapabilityClass.Web ->
                if (provider.id == "whatsapp") {
                    "Private web session · availability depends on provider support"
                } else {
                    "Private web session"
                }
            ProviderCapabilityClass.Unavailable -> "Unavailable"
        }

    SableTile(
        title = provider.displayName,
        subtitle = subtitle,
        onClick = onOpen,
    )
}

@Composable
private fun AccessPanel(
    snapshot: HubSnapshot,
    onRequestAccess: () -> Unit,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
) {
    val accessText =
        when {
            snapshot.capabilities.canReadSms && snapshot.capabilities.canSendSms ->
                "SMS access is ready."
            snapshot.capabilities.canReadSms ->
                "Conversations are available. Grant send access to send SMS."
            else ->
                "Grant Messages access to show conversations and send SMS."
        }

    val peopleText =
        if (snapshot.capabilities.canReadContacts) {
            "People matching is available."
        } else {
            "Contacts access is optional and only improves people matching."
        }

    SablePanel {
        Text(
            text = "Messages",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = accessText,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = peopleText,
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
                text = "MMS / RCS",
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
        subtitle = "Write a message.",
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
