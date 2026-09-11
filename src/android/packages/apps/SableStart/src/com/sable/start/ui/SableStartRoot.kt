package org.sableos.start.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import org.sableos.start.platform.LauncherAppsRepository

@Composable
fun SableStartRoot(
    repository: LauncherAppsRepository,
) {
    val apps = remember {
        repository.loadApps()
    }

    MaterialTheme {
        Column(
            modifier = Modifier.fillMaxSize(),
        ) {
            Text(
                text = "Sable Start",
            )

            LazyColumn {
                items(
                    items = apps,
                    key = {
                        "${it.user}:${it.component.flattenToString()}"
                    },
                ) { app ->
                    Text(
                        text = app.label,
                        modifier =
                            Modifier.clickable {
                                repository.launch(app)
                            },
                    )
                }
            }
        }
    }
}
