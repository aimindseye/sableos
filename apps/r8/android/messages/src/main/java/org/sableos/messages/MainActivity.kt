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
import androidx.compose.ui.text.font.FontWeight
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
            Intent(Intent.ACTION_SENDTO, uri).putExtra(
                "sms_body",
                draft,
            )

        return runCatching {
            startActivity(intent)
            true
        }.getOrDefault(false)
    }
}

private data class MessageThread(
    val title: String,
    val recipient: String,
    val source: String,
    val unread: Boolean,
    val messages: List<MessagePreview>,
)

private data class MessagePreview(
    val author: String,
    val body: String,
    val time: String,
    val outgoing: Boolean,
)

private val referenceThreads =
    listOf(
        MessageThread(
            title = "Messages reference",
            recipient = "+15550101000",
            source = "Android provider handoff",
            unread = true,
            messages =
                listOf(
                    MessagePreview(
                        author = "Hub",
                        body = "Conversation opens at latest and keeps composer visible.",
                        time = "09:40",
                        outgoing = false,
                    ),
                    MessagePreview(
                        author = "You",
                        body = "Provider owns delivery. Sable owns focus and handoff.",
                        time = "09:42",
                        outgoing = true,
                    ),
                    MessagePreview(
                        author = "Hub",
                        body = "Newest message stays above the composer on square displays.",
                        time = "09:43",
                        outgoing = false,
                    ),
                ),
        ),
        MessageThread(
            title = "Private mode",
            recipient = "+15550101001",
            source = "Redacted preview",
            unread = false,
            messages =
                listOf(
                    MessagePreview(
                        author = "System",
                        body = "Body hidden until provider and lock policy allow display.",
                        time = "08:12",
                        outgoing = false,
                    ),
                ),
        ),
    )

@Composable
private fun MessagesApp(
    onProviderHandoff: (String, String) -> Boolean,
) {
    var selectedThread by remember {
        mutableStateOf(referenceThreads.first())
    }
    var draft by remember {
        mutableStateOf("")
    }
    var status by remember {
        mutableStateOf("provider-safe handoff ready")
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
        Text(
            text = "messages",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "latest anchored · provider owned · Hub compatible",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.height(SableSpacing.Xl))
        ConversationList(
            selectedThread = selectedThread,
            onSelect = {
                selectedThread = it
                draft = ""
                status = "opened latest conversation"
            },
        )

        Spacer(Modifier.height(SableSpacing.Xl))
        LatestConversation(
            thread = selectedThread,
            draft = draft,
            status = status,
            onDraftChange = {
                draft = it
            },
            onProviderHandoff = {
                val ok = onProviderHandoff(selectedThread.recipient, draft)
                status =
                    if (ok) {
                        "handoff opened in Android messaging provider"
                    } else {
                        "no compatible messaging provider was available"
                    }
            },
        )
    }
}

@Composable
private fun ConversationList(
    selectedThread: MessageThread,
    onSelect: (MessageThread) -> Unit,
) {
    SectionHeader("latest conversations")
    referenceThreads.forEach { thread ->
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(thread) }
                    .padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = thread.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight =
                        if (thread.unread) {
                            FontWeight.SemiBold
                        } else {
                            FontWeight.Normal
                        },
                )
                Text(
                    text = thread.messages.last().body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = if (thread == selectedThread) "current" else thread.messages.last().time,
                style = MaterialTheme.typography.labelLarge,
                color =
                    if (thread == selectedThread) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            )
        }
        Hairline()
    }
}

@Composable
private fun LatestConversation(
    thread: MessageThread,
    draft: String,
    status: String,
    onDraftChange: (String) -> Unit,
    onProviderHandoff: () -> Unit,
) {
    SectionHeader(thread.title)
    Text(
        text = thread.source,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    Spacer(Modifier.height(SableSpacing.Md))
    thread.messages.takeLast(3).forEach { message ->
        MessageBubble(message)
        Spacer(Modifier.height(SableSpacing.Sm))
    }

    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = SableSpacing.Md),
    ) {
        Text(
            text = "latest message always visible · history/search explicit",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }

    OutlinedTextField(
        value = draft,
        onValueChange = onDraftChange,
        modifier = Modifier.fillMaxWidth(),
        label = {
            Text("draft for provider handoff")
        },
        supportingText = {
            Text("Enter opens Android provider handoff after user action")
        },
        minLines = 2,
    )

    Spacer(Modifier.height(SableSpacing.Md))
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = status,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "custom SMS/RCS/MMS stack: no",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.width(SableSpacing.Md))
        Button(onClick = onProviderHandoff) {
            Text("open provider")
        }
    }
}

@Composable
private fun MessageBubble(message: MessagePreview) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement =
            if (message.outgoing) {
                Arrangement.End
            } else {
                Arrangement.Start
            },
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth(0.82f)
                    .background(
                        color =
                            if (message.outgoing) {
                                MaterialTheme.colorScheme.primaryContainer
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                        shape = MaterialTheme.shapes.large,
                    )
                    .padding(SableSpacing.Md),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = message.author,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = message.time,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = message.body,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineMedium,
        color = MaterialTheme.colorScheme.onBackground,
    )
}

@Composable
private fun Hairline() {
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}
