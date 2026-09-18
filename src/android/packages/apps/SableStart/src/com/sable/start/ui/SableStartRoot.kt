package org.sableos.start.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import org.sableos.design.SableListRow
import org.sableos.design.SablePageHeader
import org.sableos.design.SableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.start.platform.LauncherAppsRepository

@Composable
fun SableStartRoot(
    repository: LauncherAppsRepository,
) {
    val apps = remember {
        repository.loadApps()
    }

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
                            repository.launch(app)
                        },
                    )
                }
            }
        }
    }
}
