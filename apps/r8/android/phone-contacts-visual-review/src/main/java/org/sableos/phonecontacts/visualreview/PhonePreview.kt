package org.sableos.phonecontacts.visualreview

import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import org.sableos.design.SableSpacing

private data class CallRow(
    val initials: String,
    val name: String,
    val detail: String,
    val meta: String,
)

@Composable
internal fun PhonePreview(surface: String) {
    when (surface) {
        "dialpad" -> PhoneDialpadScreen()
        "in-call" -> PhoneInCallScreen()
        else -> PhoneRecentsScreen()
    }
}

@Composable
private fun PhoneRecentsScreen() {
    val calls =
        listOf(
            CallRow("AM", "Avery Morgan", "mobile · outgoing", "8:02 AM"),
            CallRow("JS", "Jordan Singh", "mobile · missed", "Yesterday"),
            CallRow("NW", "Northwind Studio", "+1 212 555 0184 · incoming", "Sat"),
            CallRow("RK", "Rina Kapoor", "work · outgoing", "Fri"),
            CallRow("SC", "Sable Care", "+1 800 555 0142 · incoming", "Thu"),
        )

    SablePreviewPage(
        title = "phone",
        subtitle = "private calls · Android Telecom",
    ) {
        AccentAction(
            title = "search contacts + calls",
            detail = "local results · no ambient network search",
        )
        Spacer(Modifier.height(SableSpacing.Lg))
        SectionLabel("recent")

        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
        ) {
            calls.forEach { call ->
                CallHistoryRow(call)
            }
        }

        FlatPrimaryAction(text = "dialpad")
        PhoneBottomNavigation(selected = "recent")
    }
}

@Composable
private fun CallHistoryRow(call: CallRow) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        InitialAvatar(call.initials)
        Spacer(Modifier.width(SableSpacing.Md))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = call.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = call.detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = call.meta,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.End,
        )
    }
    Hairline()
}

@Composable
private fun PhoneBottomNavigation(selected: String) {
    Hairline()
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(top = SableSpacing.Md),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        listOf("favorites", "recent", "contacts", "voicemail").forEach { label ->
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color =
                    if (label == selected) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            )
        }
    }
}

@Composable
private fun PhoneDialpadScreen() {
    SablePreviewPage(
        title = "dial",
        subtitle = "number entry",
    ) {
        Text(
            text = "+1 201 555 0148",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = SableSpacing.Xl),
            textAlign = TextAlign.End,
        )
        Hairline()
        Spacer(Modifier.height(SableSpacing.Xl))

        val keys =
            listOf(
                listOf("1", "2\nABC", "3\nDEF"),
                listOf("4\nGHI", "5\nJKL", "6\nMNO"),
                listOf("7\nPQRS", "8\nTUV", "9\nWXYZ"),
                listOf("*", "0\n+", "#"),
            )

        keys.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                row.forEach { key ->
                    Text(
                        text = key,
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onBackground,
                        modifier =
                            Modifier
                                .weight(1f)
                                .padding(vertical = 16.dp),
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))
        FlatPrimaryAction(text = "call")
        PhoneBottomNavigation(selected = "recent")
    }
}

@Composable
private fun PhoneInCallScreen() {
    SablePreviewPage(
        title = "call",
        subtitle = "Android Telecom session",
    ) {
        Spacer(Modifier.height(SableSpacing.Xxl))
        InitialAvatar(
            initials = "AM",
            size = 92,
        )
        Spacer(Modifier.height(SableSpacing.Lg))
        Text(
            text = "Avery Morgan",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = "mobile · +1 201 555 0148",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(SableSpacing.Sm))
        Text(
            text = "04:18",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
        )

        Spacer(Modifier.height(SableSpacing.Xxl))
        CallControlGrid()

        Spacer(Modifier.weight(1f))
        FlatDangerAction(text = "end call")
    }
}

@Composable
private fun CallControlGrid() {
    listOf(
        listOf("mute", "keypad", "speaker"),
        listOf("add call", "hold", "contacts"),
    ).forEach { labels ->
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = SableSpacing.Md),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            labels.forEach { label ->
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(
                        modifier =
                            Modifier
                                .size(44.dp)
                                .border(
                                    width = 1.dp,
                                    color = MaterialTheme.colorScheme.outline,
                                    shape = CircleShape,
                                ),
                    )
                    Spacer(Modifier.height(SableSpacing.Sm))
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
