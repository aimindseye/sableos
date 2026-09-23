package org.sableos.hub.ui

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.sableos.design.SableActionButton
import org.sableos.design.SableListRow
import org.sableos.design.SablePageHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScreen
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSpacing
import org.sableos.hub.HubConversation
import org.sableos.hub.HubMessage
import org.sableos.hub.HubSendResult
import org.sableos.hub.HubSnapshot
import java.text.DateFormat
import java.util.Date

private enum class HubPivot {
    Messages,
    People,
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
    snapshot: HubSnapshot?,
    onRequestAccess: () -> Unit,
    onSendSms: (String, String) -> HubSendResult,
    onOpenAndroidMessaging: (String?, String?) -> Boolean,
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

    if (snapshot == null) {
        SableScreen {
            SablePageHeader(
                title = "messages",
                subtitle = "SMS conversations and people, kept local to this device.",
            )
            SablePanel {
                Text(
                    text = "Loading conversations…",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        return
    }

    when (val current = route) {
        is HubRoute.Root -> {
            SableScreen {
                SablePageHeader(
                    title = "messages",
                    subtitle = "SMS conversations and people, kept local to this device.",
                )

                HubPivotRow(
                    selected = current.pivot,
                    onSelect = { pivot ->
                        route = HubRoute.Root(pivot)
                        search = ""
                        statusMessage = null
                    },
                )

                statusMessage?.let { message ->
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                when (current.pivot) {
                    HubPivot.Messages ->
                        MessagesPivot(
                            modifier = Modifier.weight(1f),
                            snapshot = snapshot,
                            search = search,
                            onSearchChange = { search = it },
                            onConversation = {
                                route = HubRoute.Conversation(it)
                            },
                            onCompose = {
                                route = HubRoute.Compose()
                            },
                            onRequestAccess = onRequestAccess,
                        )

                    HubPivot.People ->
                        PeoplePivot(
                            modifier = Modifier.weight(1f),
                            snapshot = snapshot,
                            search = search,
                            onSearchChange = { search = it },
                            onCompose = { number ->
                                route = HubRoute.Compose(number)
                            },
                            onRequestAccess = onRequestAccess,
                        )
                }
            }
        }

        is HubRoute.Conversation -> {
            val threadMessages =
                snapshot.messages
                    .filter {
                        it.threadId == current.conversation.threadId
                    }.sortedBy { it.dateMillis }
                    .takeLast(MAX_VISIBLE_THREAD_MESSAGES)

            SableScreen {
                ConversationView(
                    modifier = Modifier.weight(1f),
                    conversation = current.conversation,
                    messages = threadMessages,
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
        }

        is HubRoute.Compose -> {
            SableScrollableScreen {
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
                    onOpenMmsComposer = { recipient, body ->
                        val opened =
                            onOpenAndroidMessaging(
                                recipient.takeIf { it.isNotBlank() },
                                body.takeIf { it.isNotBlank() },
                            )
                        statusMessage =
                            if (opened) {
                                "Opened the system MMS composer."
                            } else {
                                "MMS composer is unavailable."
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
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        HubPivot.entries.forEach { pivot ->
            TextButton(
                onClick = { onSelect(pivot) },
                modifier = Modifier.heightIn(min = 48.dp),
                contentPadding = PaddingValues(horizontal = 0.dp),
            ) {
                Text(
                    text = pivot.name.lowercase(),
                    style = MaterialTheme.typography.titleLarge,
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
private fun ColumnScope.MessagesPivot(
    modifier: Modifier,
    snapshot: HubSnapshot,
    search: String,
    onSearchChange: (String) -> Unit,
    onConversation: (HubConversation) -> Unit,
    onCompose: () -> Unit,
    onRequestAccess: () -> Unit,
) {
    if (!snapshot.capabilities.canReadSms || !snapshot.capabilities.canSendSms) {
        MessagesAccessPrompt(
            snapshot = snapshot,
            onRequestAccess = onRequestAccess,
        )
    }

    SableActionButton(
        text = "new message",
        onClick = onCompose,
    )

    OutlinedTextField(
        value = search,
        onValueChange = onSearchChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Search conversations") },
    )

    val query = search.trim()
    val conversations =
        if (query.isBlank()) {
            snapshot.conversations
        } else {
            snapshot.conversations.filter { conversation ->
                conversation.displayName.contains(query, ignoreCase = true) ||
                    conversation.address.contains(query, ignoreCase = true) ||
                    conversation.lastBody.contains(query, ignoreCase = true)
            }
        }

    if (conversations.isEmpty()) {
        Text(
            text =
                when {
                    !snapshot.capabilities.canReadSms ->
                        "Grant Messages access to show SMS conversations."
                    query.isNotBlank() ->
                        "No matching conversations."
                    else ->
                        "No conversations yet."
                },
            modifier = Modifier.padding(vertical = SableSpacing.Lg),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    } else {
        LazyColumn(
            modifier = modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            items(
                items = conversations.take(MAX_VISIBLE_CONVERSATIONS),
                key = { conversation ->
                    conversation.threadId.toString() + ":" + conversation.address
                },
            ) { conversation ->
                ConversationRow(
                    conversation = conversation,
                    onClick = { onConversation(conversation) },
                )
            }
        }
    }
}

@Composable
private fun MessagesAccessPrompt(
    snapshot: HubSnapshot,
    onRequestAccess: () -> Unit,
) {
    val detail =
        when {
            snapshot.capabilities.canReadSms ->
                "Allow sending access to send SMS from Sable Messages."
            else ->
                "Allow SMS access to read conversations and send messages."
        }

    SablePanel {
        Text(
            text = "SMS access needed",
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SableActionButton(
            text = "Review access",
            primary = false,
            onClick = onRequestAccess,
        )
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
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = conversation.lastBody.take(120),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(
            horizontalAlignment = Alignment.End,
        ) {
            Text(
                text = clockTime(conversation.lastDateMillis),
                style = MaterialTheme.typography.bodyMedium,
                color = accent,
            )
            if (unread) {
                Text(
                    text = conversation.unreadCount.toString(),
                    style = MaterialTheme.typography.labelLarge,
                    color = Color(0xFF35C66B),
                )
            }
        }
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
private fun ColumnScope.PeoplePivot(
    modifier: Modifier,
    snapshot: HubSnapshot,
    search: String,
    onSearchChange: (String) -> Unit,
    onCompose: (String) -> Unit,
    onRequestAccess: () -> Unit,
) {
    if (!snapshot.capabilities.canReadContacts) {
        SablePanel {
            Text(
                text = "Contacts access is optional and only improves people matching.",
                style = MaterialTheme.typography.bodyMedium,
            )
            SableActionButton(
                text = "Review access",
                primary = false,
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
        Text(
            text = "No matching people are available.",
            modifier = Modifier.padding(vertical = SableSpacing.Lg),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    } else {
        LazyColumn(
            modifier = modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            items(
                items = people.take(MAX_VISIBLE_PEOPLE),
                key = { person ->
                    person.id.toString() + ":" + person.phoneNumber
                },
            ) { person ->
                SableListRow(
                    title = person.displayName,
                    subtitle = person.phoneNumber,
                    onClick = { onCompose(person.phoneNumber) },
                )
            }
        }
    }
}

@Composable
private fun ColumnScope.ConversationView(
    modifier: Modifier,
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

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
    ) {
        items(
            items = messages,
            key = HubMessage::id,
        ) { message ->
            MessageBubble(message)
        }
    }
}

@Composable
private fun MessageBubble(message: HubMessage) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement =
            if (message.incoming) {
                Arrangement.Start
            } else {
                Arrangement.End
            },
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 320.dp),
            shape = RoundedCornerShape(18.dp),
            color =
                if (message.incoming) {
                    MaterialTheme.colorScheme.surfaceVariant
                } else {
                    MaterialTheme.colorScheme.primaryContainer
                },
        ) {
            Column(
                modifier = Modifier.padding(SableSpacing.Md),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                Text(
                    text = message.body.ifBlank { "Empty SMS body" },
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = relativeTime(message.dateMillis),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
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
    onOpenMmsComposer: (String, String) -> Unit,
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
        title = "new message",
        subtitle = "Send SMS, or hand off to the system MMS composer for attachments.",
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
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
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
                text = "SMS sending needs permission.",
                style = MaterialTheme.typography.bodyMedium,
            )
            SableActionButton(
                text = "Review access",
                primary = false,
                onClick = onRequestAccess,
            )
        }
    }

    SableActionButton(
        text = "MMS / attachment",
        primary = false,
        onClick = {
            onOpenMmsComposer(recipient.trim(), body)
        },
    )

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

private const val MAX_VISIBLE_CONVERSATIONS = 120
private const val MAX_VISIBLE_THREAD_MESSAGES = 250
private const val MAX_VISIBLE_PEOPLE = 300
