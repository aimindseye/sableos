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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.design.applySableDarkSystemBars

private val MediaPink = Color(0xFFFF4F9A)
private val MediaPurple = Color(0xFF7A42E8)
private val MediaBlue = Color(0xFF4D9CFF)
private val MediaGreen = Color(0xFF37D67A)

private enum class MediaPage(val label: String) {
    Collection("collection"),
    NowPlaying("now playing"),
    Radio("radio"),
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applySableDarkSystemBars(window)

        setContent {
            SableTheme {
                var page by remember { mutableStateOf(MediaPage.Collection) }
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
                            sourceTitle =
                                uri.lastPathSegment
                                    ?.substringAfterLast('/')
                                    ?.ifBlank { "local audio" }
                                    ?: "local audio"
                            sourceKind = "local audio"
                            page = MediaPage.NowPlaying
                        }
                    }

                SableScrollableScreen {
                    SableHeroHeader(
                        eyebrow = "Sable Media",
                        title = "music",
                        subtitle = "Local first. Direct radio when you choose it.",
                    )

                    MediaPivotBar(
                        current = page,
                        onSelect = { page = it },
                    )

                    when (page) {
                        MediaPage.Collection ->
                            CollectionPage(
                                onOpenLocal = {
                                    picker.launch(arrayOf("audio/*"))
                                },
                            )

                        MediaPage.NowPlaying ->
                            NowPlayingPage(
                                playbackState = playbackState,
                                sourceTitle = sourceTitle,
                                sourceKind = sourceKind,
                                onPause = {
                                    sendPlaybackAction(
                                        PlaybackService.ACTION_PAUSE,
                                    )
                                    playbackState = "paused"
                                },
                                onPlay = {
                                    sendPlaybackAction(
                                        PlaybackService.ACTION_RESUME,
                                    )
                                    playbackState = "playing"
                                },
                                onStop = {
                                    sendPlaybackAction(
                                        PlaybackService.ACTION_STOP,
                                    )
                                    playbackState = "stopped"
                                },
                            )

                        MediaPage.Radio ->
                            RadioPage(
                                stationUrl = stationUrl,
                                onStationUrlChange = { stationUrl = it },
                                onPlayStation = {
                                    val candidate = stationUrl.trim()
                                    if (
                                        candidate.startsWith("http://") ||
                                        candidate.startsWith("https://")
                                    ) {
                                        playUri(Uri.parse(candidate))
                                        playbackState = "playing"
                                        sourceTitle = candidate
                                        sourceKind = "internet radio"
                                        page = MediaPage.NowPlaying
                                    } else {
                                        playbackState = "check URL"
                                        sourceTitle = "Enter an HTTP or HTTPS stream"
                                        sourceKind = "radio"
                                        page = MediaPage.NowPlaying
                                    }
                                },
                            )
                    }
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

@Composable
private fun MediaPivotBar(
    current: MediaPage,
    onSelect: (MediaPage) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        MediaPage.entries.forEach { page ->
            Surface(
                onClick = { onSelect(page) },
                modifier = Modifier.heightIn(min = 48.dp),
                color = Color.Transparent,
                contentColor =
                    if (current == page) {
                        MediaPink
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
                ) {
                    Text(
                        text = page.label,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight =
                            if (current == page) {
                                FontWeight.Medium
                            } else {
                                FontWeight.Normal
                            },
                    )
                    Box(
                        modifier =
                            Modifier
                                .width(if (current == page) 34.dp else 12.dp)
                                .height(3.dp)
                                .background(
                                    if (current == page) {
                                        MediaPink
                                    } else {
                                        MaterialTheme.colorScheme.outlineVariant
                                    },
                                ),
                    )
                }
            }
        }
    }
}

@Composable
private fun CollectionPage(
    onOpenLocal: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "collection",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )

        MediaSourceTile(
            title = "open local audio",
            subtitle = "Choose a track from this device",
            accent = MediaBlue,
            onClick = onOpenLocal,
        )

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 0.dp,
        ) {
            Column(
                modifier = Modifier.padding(SableSpacing.Lg),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                Text(
                    text = "history",
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    text =
                        "Sable Media does not create a persistent listening-history feed. " +
                            "Playback state stays focused on what you explicitly open.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun NowPlayingPage(
    playbackState: String,
    sourceTitle: String,
    sourceKind: String,
    onPause: () -> Unit,
    onPlay: () -> Unit,
    onStop: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .weight(0.42f)
                        .aspectRatio(1f)
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
                        .padding(SableSpacing.Md),
            ) {
                Text(
                    text = "S",
                    modifier = Modifier.align(Alignment.BottomStart),
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Light,
                    color = Color.White,
                )
            }

            Column(
                modifier = Modifier.weight(0.58f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                Text(
                    text = playbackState,
                    style = MaterialTheme.typography.labelLarge,
                    color = MediaGreen,
                )
                Text(
                    text = sourceTitle,
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                    maxLines = 3,
                )
                Text(
                    text = sourceKind,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableActionButton(
                text = "Pause",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = onPause,
            )
            SableActionButton(
                text = "Play",
                modifier = Modifier.weight(1f),
                onClick = onPlay,
            )
            SableActionButton(
                text = "Stop",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = onStop,
            )
        }

        Text(
            text =
                "Media3 owns playback, audio focus and session lifecycle. " +
                    "Sable shows only source state it actually knows.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RadioPage(
    stationUrl: String,
    onStationUrlChange: (String) -> Unit,
    onPlayStation: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "radio",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )

        MediaSourceTile(
            title = "direct stream",
            subtitle = "No discovery feed. Paste the station you want.",
            accent = MediaPink,
            onClick = {},
        )

        OutlinedTextField(
            value = stationUrl,
            onValueChange = onStationUrlChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("HTTP(S) stream URL") },
        )

        SableActionButton(
            text = "Play station",
            modifier = Modifier.fillMaxWidth(),
            onClick = onPlayStation,
        )

        Text(
            text =
                "Radio connects only to the URL you enter. " +
                    "Sable does not add a tracking or recommendation service.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
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
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .width(4.dp)
                        .height(72.dp)
                        .background(accent),
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
                        .padding(end = SableSpacing.Lg),
                style = MaterialTheme.typography.titleLarge,
                color = accent,
            )
        }
    }
}
