package org.sableos.start.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.sableos.design.SableListRow
import org.sableos.design.SablePageHeader
import org.sableos.design.SableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.start.model.AppEntry

@Composable
fun SableStartRoot(
    apps: List<AppEntry>,
    onLaunchApp: (AppEntry) -> Unit,
) {
    SableTheme {
        SableScreen {
            SablePageHeader(
                title = "Start",
                subtitle = "SableOS",
            )

            SableSectionHeader(
                title = "All apps",
            )

            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                items(
                    items = apps,
                    key = {
                        "${it.user}:${it.component.flattenToString()}"
                    },
                ) { app ->
                    SableListRow(
                        title = app.label,
                        onClick = {
                            onLaunchApp(app)
                        },
                    )
                }
            }
        }
    }
}
