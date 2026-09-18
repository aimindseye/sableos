package org.sableos.media

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SablePageHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.design.SableTile

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SableTheme {
                var stationUrl by remember { mutableStateOf("") }
                var status by remember { mutableStateOf("Ready") }

                val picker = rememberLauncherForActivityResult(
                    ActivityResultContracts.OpenDocument(),
                ) { uri ->
                    if (uri != null) {
                        try {
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                        } catch (_: SecurityException) {
                            // Some providers grant transient access only.
                        }
                        playUri(uri)
                        status = "Playing local audio"
                    }
                }

                SableScrollableScreen {
                    SablePageHeader(
                        title = "Media",
                        subtitle = "Music · Radio",
                    )

                    SablePanel {
                        Text(
                            "Now playing",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            status,
                            style = MaterialTheme.typography.headlineMedium,
                        )
                    }

                    SableSectionHeader("Music")
                    SableTile(
                        title = "Open local audio",
                        subtitle = "Choose a track from this device",
                        onClick = {
                            picker.launch(arrayOf("audio/*"))
                        },
                    )

                    SableSectionHeader("Internet radio")
                    OutlinedTextField(
                        value = stationUrl,
                        onValueChange = { stationUrl = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        label = { Text("HTTP(S) stream URL") },
                    )
                    SableActionButton(
                        text = "Play station",
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            val candidate = stationUrl.trim()
                            if (
                                candidate.startsWith("http://") ||
                                candidate.startsWith("https://")
                            ) {
                                playUri(Uri.parse(candidate))
                                status = "Playing radio stream"
                            } else {
                                status = "Enter an HTTP or HTTPS station URL"
                            }
                        },
                    )

                    SableSectionHeader("Playback")
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                    ) {
                        SableActionButton(
                            text = "Pause",
                            primary = false,
                            modifier = Modifier.weight(1f),
                            onClick = {
                                sendPlaybackAction(PlaybackService.ACTION_PAUSE)
                                status = "Paused"
                            },
                        )
                        SableActionButton(
                            text = "Resume",
                            modifier = Modifier.weight(1f),
                            onClick = {
                                sendPlaybackAction(PlaybackService.ACTION_RESUME)
                                status = "Playing"
                            },
                        )
                        SableActionButton(
                            text = "Stop",
                            primary = false,
                            modifier = Modifier.weight(1f),
                            onClick = {
                                sendPlaybackAction(PlaybackService.ACTION_STOP)
                                status = "Stopped"
                            },
                        )
                    }

                    Text(
                        "Media3 owns playback, audio routing, focus and session lifecycle. " +
                            "Sable keeps the player surface direct and content-first.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    private fun playUri(uri: Uri) {
        startService(
            Intent(this, PlaybackService::class.java)
                .setAction(PlaybackService.ACTION_PLAY_URI)
                .setData(uri),
        )
    }

    private fun sendPlaybackAction(action: String) {
        startService(Intent(this, PlaybackService::class.java).setAction(action))
    }
}
