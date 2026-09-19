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
import androidx.compose.ui.text.style.TextOverflow
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

        val stationRepository = RadioStationRepository(applicationContext)

        setContent {
            SableTheme {
                var page by remember { mutableStateOf(MediaPage.Collection) }
                var playbackState by remember { mutableStateOf("ready") }
                var sourceTitle by remember { mutableStateOf("nothing queued") }
                var sourceKind by remember { mutableStateOf("local music or radio") }

                var stations by remember {
                    mutableStateOf(stationRepository.loadStations())
                }
                var stationName by remember { mutableStateOf("") }
                var stationUrl by remember { mutableStateOf("") }
                var radioStatus by remember {
                    mutableStateOf(
                        if (stations.isEmpty()) {
                            "No saved stations yet."
                        } else {
                            "${stations.size} saved station${if (stations.size == 1) "" else "s"}."
                        },
                    )
                }

                fun startPlayback(
                    uri: Uri,
                    title: String,
                    source: String,
                ) {
                    playUri(
                        uri = uri,
                        title = title,
                        source = source,
                    )
                    playbackState = "playing"
                    sourceTitle = title
                    sourceKind = source
                    page = MediaPage.NowPlaying
                }

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

                            val title =
                                uri.lastPathSegment
                                    ?.substringAfterLast('/')
                                    ?.ifBlank { "local audio" }
                                    ?: "local audio"

                            startPlayback(
                                uri = uri,
                                title = title,
                                source = "local audio",
                            )
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
                                stations = stations,
                                stationName = stationName,
                                stationUrl = stationUrl,
                                status = radioStatus,
                                onStationNameChange = { stationName = it },
                                onStationUrlChange = { stationUrl = it },
                                onSaveStation = {
                                    val candidate = stationUrl.trim()
                                    if (!RadioStationRepository.isSupportedUrl(candidate)) {
                                        radioStatus = "Station URL must use HTTP or HTTPS."
                                    } else {
                                        stations =
                                            stationRepository.saveStation(
                                                current = stations,
                                                name = stationName,
                                                url = candidate,
                                            )
                                        radioStatus = "Station saved locally."
                                        stationName = ""
                                        stationUrl = ""
                                    }
                                },
                                onPlayDirect = {
                                    val candidate = stationUrl.trim()
                                    if (RadioStationRepository.isSupportedUrl(candidate)) {
                                        val title =
                                            stationName.trim().ifBlank {
                                                Uri.parse(candidate).host ?: "live radio"
                                            }
                                        startPlayback(
                                            uri = Uri.parse(candidate),
                                            title = title,
                                            source = "internet radio",
                                        )
                                    } else {
                                        radioStatus = "Station URL must use HTTP or HTTPS."
                                    }
                                },
                                onPlayStation = { station ->
                                    startPlayback(
                                        uri = Uri.parse(station.url),
                                        title = station.name,
                                        source = "saved radio station",
                                    )
                                },
                                onDeleteStation = { station ->
                                    stations =
                                        stationRepository.deleteStation(
                                            current = stations,
                                            id = station.id,
                                        )
                                    radioStatus =
                                        if (stations.isEmpty()) {
                                            "No saved stations yet."
                                        } else {
                                            "Station removed."
                                        }
                                },
                            )
                    }
                }
            }
        }
    }

    private fun playUri(
        uri: Uri,
        title: String,
        source: String,
    ) {
        startService(
            Intent(this, PlaybackService::class.java)
                .setAction(PlaybackService.ACTION_PLAY_URI)
                .setData(uri)
                .putExtra(PlaybackService.EXTRA_TITLE, title)
                .putExtra(PlaybackService.EXTRA_SOURCE, source),
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
                    text = "privacy",
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    text =
                        "Sable Media does not create a persistent listening-history feed. " +
                            "Saved radio stations are stored locally on this device.",
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
                    overflow = TextOverflow.Ellipsis,
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
    stations: List<RadioStation>,
    stationName: String,
    stationUrl: String,
    status: String,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
    onSaveStation: () -> Unit,
    onPlayDirect: () -> Unit,
    onPlayStation: (RadioStation) -> Unit,
    onDeleteStation: (RadioStation) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "live radio",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Text(
            text = status,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        if (stations.isNotEmpty()) {
            Text(
                text = "saved stations",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )

            stations.forEach { station ->
                RadioStationCard(
                    station = station,
                    onPlay = { onPlayStation(station) },
                    onDelete = { onDeleteStation(station) },
                )
            }
        }

        Text(
            text = "add station",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )

        OutlinedTextField(
            value = stationName,
            onValueChange = onStationNameChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Station name") },
        )

        OutlinedTextField(
            value = stationUrl,
            onValueChange = onStationUrlChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("HTTP(S) stream URL") },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableActionButton(
                text = "Play now",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = onPlayDirect,
            )
            SableActionButton(
                text = "Save station",
                modifier = Modifier.weight(1f),
                onClick = onSaveStation,
            )
        }

        Text(
            text =
                "Station presets stay local. Playing a station connects directly to the " +
                    "stream URL you selected; no radio directory or recommendation service is contacted.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RadioStationCard(
    station: RadioStation,
    onPlay: () -> Unit,
    onDelete: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = station.name,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = station.url,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                SableActionButton(
                    text = "Play",
                    modifier = Modifier.weight(1f),
                    onClick = onPlay,
                )
                SableActionButton(
                    text = "Remove",
                    primary = false,
                    modifier = Modifier.weight(1f),
                    onClick = onDelete,
                )
            }
        }
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
                modifier = Modifier.padding(end = SableSpacing.Lg),
                style = MaterialTheme.typography.titleLarge,
                color = accent,
            )
        }
    }
}
