package org.sableos.hub.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SablePageHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScreen
import org.sableos.design.SableSpacing
import org.sableos.hub.ConnectedAppCandidate
import org.sableos.hub.ConnectedAppKey
import org.sableos.hub.ConnectedAppPolicy

@Composable
internal fun ConnectedAppsScreen(
    candidates: List<ConnectedAppCandidate>,
    policies: Map<ConnectedAppKey, ConnectedAppPolicy>,
    notificationAccessGranted: Boolean,
    loading: Boolean,
    onOpenNotificationAccess: () -> Unit,
    onPolicyChanged: (ConnectedAppPolicy) -> Unit,
) {
    SableScreen {
        SablePageHeader(
            title = "connected apps",
            subtitle =
                "Choose installed apps that may contribute notification-derived conversations.",
        )

        SablePanel {
            Text(
                text =
                    if (notificationAccessGranted) {
                        "Notification access is enabled."
                    } else {
                        "Notification access is required before connected apps can contribute messages."
                    },
                style = MaterialTheme.typography.bodyMedium,
            )
            SableActionButton(
                text =
                    if (notificationAccessGranted) {
                        "Review notification access"
                    } else {
                        "Enable notification access"
                    },
                primary = !notificationAccessGranted,
                onClick = onOpenNotificationAccess,
            )
        }

        Text(
            text =
                "Sable does not sign into these services. The installed app keeps networking, " +
                    "encryption, account state and complete history.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        if (loading) {
            Text(
                text = "Loading installed apps…",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                items(
                    items = candidates,
                    key = { candidate ->
                        candidate.key.packageName + ":" + candidate.key.userSerial
                    },
                ) { candidate ->
                    val policy =
                        policies[candidate.key]
                            ?: ConnectedAppPolicy(key = candidate.key)
                    ConnectedAppRow(
                        candidate = candidate,
                        policy = policy,
                        onPolicyChanged = onPolicyChanged,
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun ConnectedAppRow(
    candidate: ConnectedAppCandidate,
    policy: ConnectedAppPolicy,
    onPolicyChanged: (ConnectedAppPolicy) -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = SableSpacing.Sm),
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = candidate.label,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = candidate.key.packageName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = candidate.profileLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = policy.includeInMessages,
                onCheckedChange = { enabled ->
                    onPolicyChanged(
                        policy.copy(includeInMessages = enabled).normalized(),
                    )
                },
            )
        }

        PolicySwitchRow(
            label = "Allow quick reply",
            checked = policy.allowQuickReply,
            enabled = policy.includeInMessages,
            onCheckedChange = { enabled ->
                onPolicyChanged(policy.copy(allowQuickReply = enabled))
            },
        )
        PolicySwitchRow(
            label = "Hide from SableLauncher",
            checked = policy.hideFromLauncher,
            enabled = policy.includeInMessages,
            onCheckedChange = { enabled ->
                onPolicyChanged(policy.copy(hideFromLauncher = enabled))
            },
        )
        TextButton(
            enabled = policy.includeInMessages,
            onClick = {
                onPolicyChanged(
                    policy.copy(
                        retention = policy.retention.next(),
                    ),
                )
            },
        ) {
            Text("History retention: ${policy.retention.label}")
        }
    }
}

@Composable
private fun PolicySwitchRow(
    label: String,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            color =
                if (enabled) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
        )
        Switch(
            checked = checked,
            enabled = enabled,
            onCheckedChange = onCheckedChange,
        )
    }
}
