package org.sableos.media

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.design.applySableDarkSystemBars

private val MediaPink = Color(0xFFFF4F9A)
private val MediaPurple = Color(0xFF7A42E8)
private val MediaBlue = Color(0xFF4D9CFF)
private val MediaGreen = Color(0xFF37D67A)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applySableDarkSystemBars(window)

        setContent {
            SableTheme {
                var stationUrl by remember { mutableStateOf("") }
                var playbackState by remember { mutableStateOf("ready") }
                var sourceTitle by remember { mutableStateOf("nothing queued") }
                var sourceKind by remember { mutableStateOf("local music or radio") }

                val picker =
                    rememberLauncherForActivityResult(
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
                            playbackState = "playing"
                            sourceTitle = uri.lastPathSegment?.substringAfterLast('/') ?: "local audio"
                            sourceKind = "local audio"
                        }
                    }

                SableScrollableScreen {
                    SableHeroHeader(
                        eyebrow = "Sable Media",
                        title = "music",
                        subtitle = "Your sound, local first. Direct radio when you choose it.",
                    )

                    NowPlayingArtwork(
                        playbackState = playbackState,
                        sourceTitle = sourceTitle,
                        sourceKind = sourceKind,
                    )

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
                                playbackState = "paused"
                            },
                        )
                        SableActionButton(
                            text = "Play",
                            modifier = Modifier.weight(1f),
                            onClick = {
                                sendPlaybackAction(PlaybackService.ACTION_RESUME)
                                playbackState = "playing"
                            },
                        )
                        SableActionButton(
                            text = "Stop",
                            primary = false,
                            modifier = Modifier.weight(1f),
                            onClick = {
                                sendPlaybackAction(PlaybackService.ACTION_STOP)
                                playbackState = "stopped"
                            },
                        )
                    }

                    SableSectionHeader("library")
                    MediaSourceTile(
                        title = "open local audio",
                        subtitle = "Choose a track from this device",
                        accent = MediaBlue,
                        onClick = {
                            picker.launch(arrayOf("audio/*"))
                        },
                    )

                    SableSectionHeader("radio")
                    MediaSourceTile(
                        title = "direct stream",
                        subtitle = "No discovery feed. Paste the station you want.",
                        accent = MediaPink,
                        onClick = {},
                    )

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
                                playbackState = "playing"
                                sourceTitle = candidate
                                sourceKind = "internet radio"
                            } else {
                                playbackState = "check URL"
                                sourceTitle = "Enter an HTTP or HTTPS stream"
                                sourceKind = "radio"
                            }
                        },
                    )

                    Text(
                        text =
                            "Media3 handles playback, audio focus and the media session. " +
                                "Local files stay local; radio connects only to the URL you enter.",
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
        startService(
            Intent(this, PlaybackService::class.java)
                .setAction(action),
        )
    }
}

@androidx.compose.runtime.Composable
private fun NowPlayingArtwork(
    playbackState: String,
    sourceTitle: String,
    sourceKind: String,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(1.08f)
                    .background(
                        brush =
                            Brush.linearGradient(
                                colors =
                                    listOf(
                                        MediaPurple,
                                        MediaPink,
                                        MediaBlue,
                                    ),
                            ),
                        shape = MaterialTheme.shapes.large,
                    )
                    .padding(SableSpacing.Xl),
        ) {
            Text(
                text = "SABLE\nMUSIC",
                modifier = Modifier.align(Alignment.BottomStart),
                style = MaterialTheme.typography.displayLarge,
                fontWeight = FontWeight.Light,
                color = Color.White,
            )

            Surface(
                modifier = Modifier.align(Alignment.TopEnd),
                shape = MaterialTheme.shapes.small,
                color = Color.Black.copy(alpha = 0.42f),
            ) {
                Text(
                    text = playbackState,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White,
                )
            }
        }

        Text(
            text = sourceTitle,
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
            maxLines = 2,
        )
        Text(
            text = sourceKind,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@androidx.compose.runtime.Composable
private fun MediaSourceTile(
    title: String,
    subtitle: String,
    accent: Color,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Stretch,
        ) {
            Box(
                modifier =
                    Modifier
                        .background(accent)
                        .padding(horizontal = 4.dp),
            )

            Column(
                modifier =
                    Modifier
                        .weight(1f)
                        .padding(SableSpacing.Lg),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = "→",
                modifier =
                    Modifier
                        .align(Alignment.CenterVertically)
                        .padding(end = SableSpacing.Lg),
                style = MaterialTheme.typography.titleLarge,
                color = accent,
            )
        }
    }
}
