package org.sableos.messages

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.sableos.design.SableGlobalTheme
import org.sableos.design.SableSpacing

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            SableGlobalTheme(window = window) {
                MessagesApp(
                    onProviderHandoff = ::openProviderConversation,
                )
            }
        }
    }

    private fun openProviderConversation(
        recipient: String,
        draft: String,
    ): Boolean {
        val uri = Uri.parse("smsto:${Uri.encode(recipient)}")
        val intent =
            Intent(Intent.ACTION_SENDTO, uri)
                .putExtra("sms_body", draft)
        return runCatching {
            startActivity(intent)
        }.isSuccess
    }
}

@Composable
private fun MessagesApp(
    onProviderHandoff: (String, String) -> Boolean,
) {
    var selectedThread by remember { mutableStateOf(sampleThreads.first()) }
    var draft by remember { mutableStateOf("Typing reply…") }
    var handoffStatus by remember {
        mutableStateOf("Provider-safe handoff retained. No custom SMS/RCS/MMS stack.")
    }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.Xl,
                ),
    ) {
        Header()
        Spacer(Modifier.height(SableSpacing.Xl))
        LatestAnchoredThread(
            thread = selectedThread,
            draft = draft,
            onDraftChanged = { draft = it },
            onProviderHandoff = {
                handoffStatus =
                    if (onProviderHandoff(selectedThread.route, draft)) {
                        "Provider handoff opened for ${selectedThread.person}."
                    } else {
                        "No provider accepted smsto: handoff on this build."
                    }
            },
        )
        Spacer(Modifier.height(SableSpacing.Xl))
        HistoryModePanel()
        Spacer(Modifier.height(SableSpacing.Xl))
        ConversationList(
            selectedThread = selectedThread,
            onSelectThread = { selectedThread = it },
        )
        Spacer(Modifier.height(SableSpacing.Xl))
        PrivacyAndProviderPanel(status = handoffStatus)
        Spacer(Modifier.height(SableSpacing.Xl))
        KeyboardModel()
    }
}

@Composable
private fun Header() {
    Column {
        Text(
            text = "messages",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text =
                "Titan 2 visual target · square display + physical keyboard · " +
                    "latest message always visible",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text =
                "MESSAGES_CONVERSATION_UX · " +
                    "MESSAGES_CONVERSATION_VISUAL_CONFIRMATION",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun LatestAnchoredThread(
    thread: ConversationThread,
    draft: String,
    onDraftChanged: (String) -> Unit,
    onProviderHandoff: () -> Unit,
) {
    SectionCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = thread.person,
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Text(
                    text = "SMS · Private OK · Hub handoff compatible",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            StatusPill("latest")
        }

        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text = "Recent context · anchored to latest",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(SableSpacing.Md))

        thread.messages.forEach { message ->
            MessageBubble(message)
            Spacer(Modifier.height(8.dp))
        }

        StatusPill("LATEST_MESSAGE_ALWAYS_VISIBLE · AUTO_ADVANCED")
        Spacer(Modifier.height(SableSpacing.Md))
        Composer(
            draft = draft,
            onDraftChanged = onDraftChanged,
            onProviderHandoff = onProviderHandoff,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text = "Onscreen keyboard fallback keeps draft and latest visible.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun MessageBubble(message: MessageLine) {
    val alignment =
        if (message.outgoing) {
            Alignment.CenterEnd
        } else {
            Alignment.CenterStart
        }
    val bubbleColor =
        if (message.outgoing) {
            MaterialTheme.colorScheme.primaryContainer
        } else {
            MaterialTheme.colorScheme.surface
        }
    val textColor =
        if (message.outgoing) {
            MaterialTheme.colorScheme.onPrimaryContainer
        } else {
            MaterialTheme.colorScheme.onSurface
        }

    Box(
        modifier = Modifier.fillMaxWidth(),
        contentAlignment = alignment,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth(0.82f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(bubbleColor)
                    .padding(SableSpacing.Md),
        ) {
            Text(
                text = message.body,
                style = MaterialTheme.typography.bodyLarge,
                color = textColor,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text = message.time + if (message.latest) " · Latest msg" else "",
                style = MaterialTheme.typography.labelLarge,
                color = textColor,
            )
        }
    }
}

@Composable
private fun Composer(
    draft: String,
    onDraftChanged: (String) -> Unit,
    onProviderHandoff: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(SableSpacing.Md),
    ) {
        Text(
            text = "Composer · physical keyboard primary",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = draft,
            onValueChange = onDraftChanged,
            modifier = Modifier.fillMaxWidth(),
            singleLine = false,
            minLines = 2,
            label = { Text("Shared physical + onscreen draft") },
        )
        Spacer(Modifier.height(SableSpacing.Md))
        Button(
            onClick = onProviderHandoff,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Open provider with smsto: draft")
        }
    }
}

@Composable
private fun HistoryModePanel() {
    SectionCard {
        Text(
            text = "History mode",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "Older messages are explicit: search, unread jump, date jump or page mode.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        StatusPill("New message — Enter to latest")
        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text = "No yanking focus while deliberately viewing history. Esc returns latest.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ConversationList(
    selectedThread: ConversationThread,
    onSelectThread: (ConversationThread) -> Unit,
) {
    SectionCard {
        Text(
            text = "Conversation list · latest first",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "Hub-style rows: Up/Down focus, / search, Enter opens latest.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        sampleThreads.forEach { thread ->
            ConversationRow(
                thread = thread,
                selected = thread == selectedThread,
                onClick = { onSelectThread(thread) },
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        }
    }
}

@Composable
private fun ConversationRow(
    thread: ConversationThread,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .background(
                    if (selected) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.background
                    },
                )
                .padding(vertical = SableSpacing.Md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.primary),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = thread.person.take(1),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onPrimary,
            )
        }
        Spacer(Modifier.width(SableSpacing.Md))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = thread.person,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = thread.preview,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = thread.badge,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun PrivacyAndProviderPanel(status: String) {
    SectionCard {
        Text(
            text = "Privacy and provider ownership",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        RedactionRow("Locked/private mode", "Message body hidden when locked")
        RedactionRow("Source restricted", "Contact/source policy aware")
        RedactionRow("Provider-safe handoff", status)
        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text = "custom SMS/RCS/MMS stack: no · unsupported provider actions: no",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RedactionRow(
    label: String,
    detail: String,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun KeyboardModel() {
    SectionCard {
        Text(
            text = "Keyboard model",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        Shortcut("Enter", "provider-safe send/open")
        Shortcut("Shift+Enter", "newline")
        Shortcut("/", "search conversation")
        Shortcut("PageUp", "explicit history page")
        Shortcut("End / Ctrl+L", "return to latest")
    }
}

@Composable
private fun Shortcut(
    key: String,
    action: String,
) {
    Row(
        modifier = Modifier.padding(vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StatusPill(key)
        Spacer(Modifier.width(SableSpacing.Md))
        Text(
            text = action,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
    }
}

@Composable
private fun SectionCard(content: @Composable Column.() -> Unit) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(SableSpacing.Md),
        content = content,
    )
}

@Composable
private fun StatusPill(text: String) {
    Box(
        modifier =
            Modifier
                .clip(RoundedCornerShape(999.dp))
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
        )
    }
}

private data class ConversationThread(
    val person: String,
    val route: String,
    val preview: String,
    val badge: String,
    val messages: List<MessageLine>,
)

private data class MessageLine(
    val body: String,
    val time: String,
    val outgoing: Boolean,
    val latest: Boolean = false,
)

private val sampleThreads =
    listOf(
        ConversationThread(
            person = "Maya Patel",
            route = "+15550101010",
            preview = "Just got off. Latest msg",
            badge = "2",
            messages =
                listOf(
                    MessageLine(
                        body = "Train arrives 7:18",
                        time = "7:09",
                        outgoing = false,
                    ),
                    MessageLine(
                        body = "I’ll meet you outside.",
                        time = "7:10",
                        outgoing = true,
                    ),
                    MessageLine(
                        body = "Just got off. Latest msg",
                        time = "7:12",
                        outgoing = false,
                        latest = true,
                    ),
                ),
        ),
        ConversationThread(
            person = "Team thread",
            route = "+15550101011",
            preview = "Calendar changed",
            badge = "1",
            messages =
                listOf(
                    MessageLine(
                        body = "Calendar changed. Can you confirm?",
                        time = "6:44",
                        outgoing = false,
                        latest = true,
                    ),
                ),
        ),
        ConversationThread(
            person = "Provider route",
            route = "+15550101012",
            preview = "Open source app for unsupported actions",
            badge = "›",
            messages =
                listOf(
                    MessageLine(
                        body = "Open source app for unsupported actions.",
                        time = "5:30",
                        outgoing = false,
                        latest = true,
                    ),
                ),
        ),
    )
