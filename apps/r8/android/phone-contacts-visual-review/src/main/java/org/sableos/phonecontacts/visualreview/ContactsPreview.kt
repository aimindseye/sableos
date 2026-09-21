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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.design.SableSpacing

private data class ContactRow(
    val initials: String,
    val name: String,
    val detail: String,
)

@Composable
internal fun ContactsPreview(surface: String) {
    when (surface) {
        "detail" -> ContactsDetailScreen()
        else -> ContactsListScreen()
    }
}

@Composable
private fun ContactsListScreen() {
    val contacts =
        listOf(
            "A" to
                listOf(
                    ContactRow("AM", "Avery Morgan", "mobile · +1 201 555 0148"),
                    ContactRow("AR", "Alex Rivera", "work · +1 212 555 0137"),
                ),
            "J" to
                listOf(
                    ContactRow("JS", "Jordan Singh", "mobile · +1 973 555 0109"),
                ),
            "N" to
                listOf(
                    ContactRow("NW", "Northwind Studio", "work · +1 212 555 0184"),
                ),
            "R" to
                listOf(
                    ContactRow("RK", "Rina Kapoor", "mobile · +1 201 555 0121"),
                ),
            "S" to
                listOf(
                    ContactRow("SC", "Sable Care", "support · +1 800 555 0142"),
                ),
        )

    SablePreviewPage(
        title = "contacts",
        subtitle = "people · groups · accounts",
    ) {
        AccentAction(
            title = "search + add",
            detail = "contacts · groups · accounts",
        )
        Spacer(Modifier.height(SableSpacing.Lg))

        Box(modifier = Modifier.weight(1f)) {
            Column(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(end = 28.dp)
                        .verticalScroll(rememberScrollState()),
            ) {
                contacts.forEach { (section, rows) ->
                    SectionLabel(section)
                    rows.forEach { row ->
                        ContactListRow(row)
                    }
                }
            }
            ContactsRail(
                modifier =
                    Modifier
                        .align(Alignment.CenterEnd)
                        .fillMaxHeight(),
            )
        }

        FlatPrimaryAction(text = "new contact")
    }
}

@Composable
private fun ContactListRow(contact: ContactRow) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        InitialAvatar(contact.initials)
        Spacer(Modifier.width(SableSpacing.Md))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = contact.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = contact.detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = "›",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    Hairline()
}

@Composable
private fun ContactsRail(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        listOf("A", "J", "N", "R", "S").forEachIndexed { index, label ->
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color =
                    if (index == 0) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                modifier = Modifier.padding(vertical = 4.dp),
            )
        }
    }
}

@Composable
private fun ContactsDetailScreen() {
    SablePreviewPage(
        title = "contact",
        subtitle = "contact details",
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            InitialAvatar(
                initials = "AM",
                size = 84,
            )
            Spacer(Modifier.width(SableSpacing.Lg))
            Column {
                Text(
                    text = "Avery Morgan",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Text(
                    text = "personal · local contact",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            ContactAction(glyph = "☎", label = "call")
            ContactAction(glyph = "…", label = "message")
            ContactAction(glyph = "@", label = "email")
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        ContactField(
            label = "mobile",
            value = "+1 201 555 0148",
        )
        ContactField(
            label = "email",
            value = "avery@example.test",
        )
        ContactField(
            label = "address",
            value = "Jersey City, NJ",
        )

        Spacer(Modifier.weight(1f))
        Hairline()
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = SableSpacing.Lg),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            listOf("edit", "share", "more").forEach { action ->
                Text(
                    text = action,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun ContactAction(
    glyph: String,
    label: String,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircleGlyph(
            glyph = glyph,
            accent = true,
        )
        Spacer(Modifier.height(SableSpacing.Sm))
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun ContactField(
    label: String,
    value: String,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = SableSpacing.Md),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(SableSpacing.Xs))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
    }
    Hairline()
}
