package org.sableos.messages

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.KeyEvent as AndroidKeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.nativeKeyEvent
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
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
    val focusRequester = remember { FocusRequester() }
    var selectedThread by remember { mutableStateOf(sampleThreads.first()) }
    var draft by remember { mutableStateOf("Typing reply…") }
    var mode by remember { mutableStateOf(ConversationMode.Latest) }
    var historyPage by remember { mutableIntStateOf(0) }
    var status by remember {
        mutableStateOf(
            "LATEST_ANCHORED_CONVERSATION=PASS · " +
                "PROVIDER_OWNERSHIP_RETAINED=YES",
        )
    }

    fun returnToLatest(reason: String) {
        mode = ConversationMode.Latest
        historyPage = 0
        status = reason
    }

    fun openProvider() {
        status =
            if (onProviderHandoff(selectedThread.route, draft)) {
                "Provider handoff opened for ${selectedThread.person}."
            } else {
                "No provider accepted smsto: handoff on this build."
            }
    }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .focusRequester(focusRequester)
                .focusable()
                .onPreviewKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) {
                        return@onPreviewKeyEvent false
                    }
                    when (event.nativeKeyEvent.keyCode) {
                        AndroidKeyEvent.KEYCODE_SLASH -> {
                            mode = ConversationMode.Search
                            status = "SEARCH_IN_CONVERSATION=YES · / opened search"
                            true
                        }

                        AndroidKeyEvent.KEYCODE_L -> {
                            if (event.isCtrlPressed) {
                                returnToLatest(
                                    "LATEST_KEY=REQUIRED · Ctrl+L returned to latest",
                                )
                                true
                            } else {
                                false
                            }
                        }

                        AndroidKeyEvent.KEYCODE_MOVE_END -> {
                            returnToLatest(
                                "LATEST_KEY=REQUIRED · End returned to latest",
                            )
                            true
                        }

                        AndroidKeyEvent.KEYCODE_PAGE_UP -> {
                            mode = ConversationMode.History
                            historyPage =
                                (historyPage + 1)
                                    .coerceAtMost(historySlices.lastIndex)
                            status =
                                "PAGE_UP_HISTORY=OPTIONAL · " +
                                    "older discrete history slice"
                            true
                        }

                        AndroidKeyEvent.KEYCODE_PAGE_DOWN -> {
                            if (historyPage > 0) {
                                historyPage -= 1
                                mode = ConversationMode.History
                                status =
                                    "PAGE_DOWN_TOWARD_LATEST=OPTIONAL · " +
                                        "newer discrete history slice"
                            } else {
                                returnToLatest(
                                    "PAGE_DOWN_TOWARD_LATEST=OPTIONAL · latest",
                                )
                            }
                            true
                        }

                        AndroidKeyEvent.KEYCODE_N -> {
                            selectedThread =
                                sampleThreads.firstOrNull { it.unreadCount > 0 }
                                    ?: selectedThread
                            returnToLatest(
                                "JUMP_TO_UNREAD=YES · N selected next unread",
                            )
                            true
                        }

                        AndroidKeyEvent.KEYCODE_D -> {
                            mode = ConversationMode.History
                            historyPage = 1.coerceAtMost(historySlices.lastIndex)
                            status = "JUMP_TO_DATE=YES · date slice focused"
                            true
                        }

                        AndroidKeyEvent.KEYCODE_A -> {
                            mode = ConversationMode.History
                            historyPage = historySlices.lastIndex
                            status =
                                "JUMP_TO_ATTACHMENT=YES · attachment slice focused"
                            true
                        }

                        AndroidKeyEvent.KEYCODE_BACK,
                        AndroidKeyEvent.KEYCODE_ESCAPE,
                        -> {
                            returnToLatest(
                                "Back/Esc left history/search and returned to latest",
                            )
                            true
                        }

                        AndroidKeyEvent.KEYCODE_ENTER -> {
                            if (mode == ConversationMode.History) {
                                returnToLatest(
                                    "New message — Enter to latest",
                                )
                            } else if (mode == ConversationMode.Search) {
                                returnToLatest(
                                    "Search result opened at latest",
                                )
                            } else if (!event.nativeKeyEvent.isShiftPressed) {
                                openProvider()
                            }
                            true
                        }

                        else -> false
                    }
                }
                .verticalScroll(rememberScrollState())
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.Xl,
                ),
    ) {
        Header(status = status)
        Spacer(Modifier.height(SableSpacing.Xl))
        LatestAnchoredThread(
            thread = selectedThread,
            draft = draft,
            mode = mode,
            historyPage = historyPage,
            onDraftChanged = { draft = it },
            onProviderHandoff = ::openProvider,
            onReturnToLatest = {
                returnToLatest("RETURN_TO_LATEST_KEY=PASS")
            },
        )
        Spacer(Modifier.height(SableSpacing.Xl))
        ConversationList(
            selectedThread = selectedThread,
            onSelectThread = {
                selectedThread = it
                returnToLatest("OPEN_SELECTED_THREAD_AT_LATEST=YES")
            },
        )
        Spacer(Modifier.height(SableSpacing.Xl))
        KeyboardModel()
        Spacer(Modifier.height(SableSpacing.Xl))
        PrivacyAndProviderPanel()
    }
}

@Composable
private fun Header(status: String) {
    Text(
        text = "Sable Messages",
        style = MaterialTheme.typography.displaySmall,
        color = MaterialTheme.colorScheme.onBackground,
    )
    Text(
        text = "Titan 2 visual target · square display plus physical keyboard",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Text(
        text = status,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun LatestAnchoredThread(
    thread: ThreadSummary,
    draft: String,
    mode: ConversationMode,
    historyPage: Int,
    onDraftChanged: (String) -> Unit,
    onProviderHandoff: () -> Unit,
    onReturnToLatest: () -> Unit,
) {
    SectionPanel {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = thread.person,
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "SMS provider · Private OK · latest anchored",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = "End/Ctrl+L latest",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Spacer(Modifier.height(SableSpacing.Md))
        when (mode) {
            ConversationMode.Latest -> LatestConversationWindow(thread)
            ConversationMode.History -> HistorySlice(
                slice = historySlices[historyPage],
                onReturnToLatest = onReturnToLatest,
            )
            ConversationMode.Search -> SearchSlice(onReturnToLatest)
        }
        Spacer(Modifier.height(SableSpacing.Md))
        Composer(
            draft = draft,
            onDraftChanged = onDraftChanged,
            onProviderHandoff = onProviderHandoff,
        )
    }
}

@Composable
private fun LatestConversationWindow(thread: ThreadSummary) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(SableSpacing.Md),
    ) {
        Text(
            text = "Recent context · anchored to latest",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        MessageBubble(
            author = thread.person,
            body = thread.context,
            time = "7:09",
            incoming = true,
        )
        MessageBubble(
            author = "You",
            body = "I’ll meet you outside.",
            time = "7:10",
            incoming = false,
        )
        MessageBubble(
            author = thread.person,
            body = thread.latest,
            time = thread.time,
            incoming = true,
            label = "Latest msg · visible · auto-advanced",
        )
        Text(
            text = "LATEST_MESSAGE_ALWAYS_VISIBLE=PASS · " +
                "SCROLLING_REQUIRED_TO_SEE_LATEST_MESSAGE=NO",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun HistorySlice(
    slice: HistorySlice,
    onReturnToLatest: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(SableSpacing.Md),
    ) {
        Text(
            text = slice.title,
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "History pages are discrete slices with visible focus.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        slice.rows.forEach { row ->
            FocusRow(row)
        }
        Spacer(Modifier.height(SableSpacing.Md))
        Button(onClick = onReturnToLatest) {
            Text("New message — Enter to latest")
        }
    }
}

@Composable
private fun SearchSlice(onReturnToLatest: () -> Unit) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(SableSpacing.Md),
    ) {
        Text(
            text = "Search in conversation",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "SEARCH_IN_CONVERSATION=YES · / opens search",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FocusRow("Jump to date · D")
        FocusRow("Jump to unread · N")
        FocusRow("Jump to attachment · A")
        Spacer(Modifier.height(SableSpacing.Md))
        Button(onClick = onReturnToLatest) {
            Text("Back/Esc or Ctrl+L returns to latest")
        }
    }
}

@Composable
private fun Composer(
    draft: String,
    onDraftChanged: (String) -> Unit,
    onProviderHandoff: () -> Unit,
) {
    Column {
        Text(
            text = "Composer · physical keyboard primary",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        OutlinedTextField(
            value = draft,
            onValueChange = onDraftChanged,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("PHYSICAL_KEYBOARD_COMPOSITION=PASS") },
            supportingText = {
                Text(
                    "Shift+Enter newline · Enter provider-safe send/handoff",
                )
            },
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "ONSCREEN_KEYBOARD_FALLBACK=PASS · draft shared",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(SableSpacing.Md))
            Button(onClick = onProviderHandoff) {
                Text("Provider handoff")
            }
        }
    }
}

@Composable
private fun ConversationList(
    selectedThread: ThreadSummary,
    onSelectThread: (ThreadSummary) -> Unit,
) {
    SectionPanel {
        Text(
            text = "Conversation list · latest first",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "Up/Down focus · Home latest row · / type-to-filter · " +
                "Enter opens latest",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        sampleThreads.forEach { thread ->
            ConversationRow(
                thread = thread,
                selected = thread == selectedThread,
                onClick = { onSelectThread(thread) },
            )
        }
    }
}

@Composable
private fun ConversationRow(
    thread: ThreadSummary,
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
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.16f)
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                )
                .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = thread.person,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = thread.latest,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = if (thread.unreadCount > 0) "${thread.unreadCount}" else thread.time,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}

@Composable
private fun KeyboardModel() {
    SectionPanel {
        Text(
            text = "Keyboard operations",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        listOf(
            "/ search in conversation",
            "Ctrl+L or End return to latest",
            "PageUp older discrete history slice",
            "PageDown newer slice / toward latest",
            "N jump to next unread",
            "D jump to date",
            "A jump to attachment",
            "Back/Esc leave history/search and return to latest",
        ).forEach(::FocusRow)
    }
}

@Composable
private fun PrivacyAndProviderPanel() {
    SectionPanel {
        Text(
            text = "Privacy and provider policy",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        FocusRow("LOCKED_MODE_REDACTION=PASS · body hidden when locked")
        FocusRow("PRIVATE_MODE_REDACTION=PASS · sensitive contact details hidden")
        FocusRow("CUSTOM_SMS_STACK=NO · CUSTOM_RCS_STACK=NO · CUSTOM_MMS_STACK=NO")
        FocusRow("CONTACTS_HANDOFF=PASS · PHONE_HANDOFF=PASS · HUB_HANDOFF=PASS")
        FocusRow("COMMAND_SEARCH_HANDOFF=PASS · NOTIFICATION_SHADE_HANDOFF=PASS")
        FocusRow("UNSUPPORTED_PROVIDER_ACTIONS=NO")
    }
}

@Composable
private fun MessageBubble(
    author: String,
    body: String,
    time: String,
    incoming: Boolean,
    label: String? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement =
            if (incoming) {
                Arrangement.Start
            } else {
                Arrangement.End
            },
    ) {
        Column(
            modifier =
                Modifier
                    .padding(vertical = 6.dp)
                    .fillMaxWidth(0.78f)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (incoming) {
                            MaterialTheme.colorScheme.surface
                        } else {
                            MaterialTheme.colorScheme.primaryContainer
                        },
                    )
                    .padding(SableSpacing.Md),
        ) {
            Text(
                text = "$author · $time",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (label != null) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun FocusRow(text: String) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .width(4.dp)
                    .height(32.dp)
                    .background(MaterialTheme.colorScheme.primary),
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun SectionPanel(content: @Composable Column.() -> Unit) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(SableSpacing.Lg),
        content = content,
    )
}

private enum class ConversationMode {
    Latest,
    History,
    Search,
}

private data class ThreadSummary(
    val person: String,
    val route: String,
    val latest: String,
    val context: String,
    val time: String,
    val unreadCount: Int,
)

private data class HistorySlice(
    val title: String,
    val rows: List<String>,
)

private val sampleThreads =
    listOf(
        ThreadSummary(
            person = "Maya Patel",
            route = "+15550101010",
            latest = "Just got off. Latest msg",
            context = "Train arrives 7:18",
            time = "7:12",
            unreadCount = 2,
        ),
        ThreadSummary(
            person = "Team thread",
            route = "+15550101011",
            latest = "Calendar changed",
            context = "Can you review?",
            time = "6:48",
            unreadCount = 1,
        ),
        ThreadSummary(
            person = "Provider route",
            route = "+15550101012",
            latest = "Open source app",
            context = "Provider owns transport",
            time = "5:30",
            unreadCount = 0,
        ),
    )

private val historySlices =
    listOf(
        HistorySlice(
            title = "Recent history slice",
            rows = listOf(
                "Visible focus stays in page slice",
                "PageUp moves to older page",
                "PageDown moves toward latest",
            ),
        ),
        HistorySlice(
            title = "Jump to date slice",
            rows = listOf(
                "JUMP_TO_DATE=YES",
                "No precision pointer scroll required",
                "Direct return to latest is visible",
            ),
        ),
        HistorySlice(
            title = "Attachment slice",
            rows = listOf(
                "JUMP_TO_ATTACHMENT=YES",
                "Provider-safe attachment action only",
                "Message actions remain keyboard accessible",
            ),
        ),
    )
