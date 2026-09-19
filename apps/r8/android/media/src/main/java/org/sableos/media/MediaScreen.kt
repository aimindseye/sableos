package org.sableos.media

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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

internal val MediaPink = Color(0xFFFF4F9A)
internal val MediaPurple = Color(0xFF7A42E8)
internal val MediaBlue = Color(0xFF4D9CFF)
internal val MediaGreen = Color(0xFF35C66B)
internal val MediaOrange = Color(0xFFF28C45)

internal enum class MediaDestination(
    val label: String,
) {
    Collection("collection"),
    NowPlaying("now playing"),
    Radio("radio"),
    ManageStations("manage"),
    AddStation("add"),
}

internal enum class LibraryPivot(
    val label: String,
) {
    Songs("songs"),
    Artists("artists"),
    Albums("albums"),
}

@Composable
internal fun MediaScreen(
    destination: MediaDestination,
    libraryPivot: LibraryPivot,
    localItems: List<LocalAudioItem>,
    stations: List<RadioStation>,
    playback: PlaybackUiState,
    stationName: String,
    stationUrl: String,
    editingStation: RadioStation?,
    message: String?,
    onDestinationChange: (MediaDestination) -> Unit,
    onLibraryPivotChange: (LibraryPivot) -> Unit,
    onAddLocalAudio: () -> Unit,
    onPlayLocal: (Int) -> Unit,
    onRemoveLocal: (LocalAudioItem) -> Unit,
    onPlayStation: (RadioStation) -> Unit,
    onAddStation: () -> Unit,
    onManageStations: () -> Unit,
    onEditStation: (RadioStation) -> Unit,
    onDeleteStation: (RadioStation) -> Unit,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
    onSaveNewStation: () -> Unit,
    onSaveEditedStation: () -> Unit,
    onCancelStationFlow: () -> Unit,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onStop: () -> Unit,
    onSeek: (Long) -> Unit,
) {
    SableScrollableScreen {
        SableHeroHeader(
            eyebrow = "Sable Media",
            title = "music",
            subtitle = "Local playback and user-managed live radio.",
        )

        PrimaryPivot(
            destination = destination,
            onSelect = onDestinationChange,
        )

        when (destination) {
            MediaDestination.Collection ->
                CollectionScreen(
                    pivot = libraryPivot,
                    items = localItems,
                    playback = playback,
                    onPivotChange = onLibraryPivotChange,
                    onAddLocalAudio = onAddLocalAudio,
                    onPlay = onPlayLocal,
                    onRemove = onRemoveLocal,
                    onOpenNowPlaying = {
                        onDestinationChange(MediaDestination.NowPlaying)
                    },
                )

            MediaDestination.NowPlaying ->
                NowPlayingScreen(
                    playback = playback,
                    onPlayPause = onPlayPause,
                    onPrevious = onPrevious,
                    onNext = onNext,
                    onStop = onStop,
                    onSeek = onSeek,
                )

            MediaDestination.Radio ->
                RadioScreen(
                    stations = stations,
                    playback = playback,
                    message = message,
                    onPlay = onPlayStation,
                    onManage = onManageStations,
                    onAdd = onAddStation,
                    onOpenNowPlaying = {
                        onDestinationChange(MediaDestination.NowPlaying)
                    },
                )

            MediaDestination.ManageStations ->
                ManageStationsScreen(
                    stations = stations,
                    editingStation = editingStation,
                    stationName = stationName,
                    stationUrl = stationUrl,
                    message = message,
                    onEdit = onEditStation,
                    onDelete = onDeleteStation,
                    onStationNameChange = onStationNameChange,
                    onStationUrlChange = onStationUrlChange,
                    onSave = onSaveEditedStation,
                    onCancelEdit = onCancelStationFlow,
                    onBack = {
                        onDestinationChange(MediaDestination.Radio)
                    },
                )

            MediaDestination.AddStation ->
                AddStationScreen(
                    stationName = stationName,
                    stationUrl = stationUrl,
                    message = message,
                    onStationNameChange = onStationNameChange,
                    onStationUrlChange = onStationUrlChange,
                    onSave = onSaveNewStation,
                    onCancel = onCancelStationFlow,
                )
        }
    }
}

@Composable
private fun PrimaryPivot(
    destination: MediaDestination,
    onSelect: (MediaDestination) -> Unit,
) {
    val current =
        when (destination) {
            MediaDestination.ManageStations,
            MediaDestination.AddStation,
            -> MediaDestination.Radio

            else -> destination
        }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        listOf(
            MediaDestination.Collection,
            MediaDestination.NowPlaying,
            MediaDestination.Radio,
        ).forEach { item ->
            val active = item == current
            Surface(
                onClick = { onSelect(item) },
                modifier = Modifier.heightIn(min = 48.dp),
                color = Color.Transparent,
                contentColor =
                    if (active) {
                        MediaPink
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight =
                            if (active) {
                                FontWeight.Medium
                            } else {
                                FontWeight.Normal
                            },
                    )
                    Box(
                        modifier =
                            Modifier
                                .width(if (active) 34.dp else 12.dp)
                                .height(3.dp)
                                .background(
                                    if (active) {
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
private fun CollectionScreen(
    pivot: LibraryPivot,
    items: List<LocalAudioItem>,
    playback: PlaybackUiState,
    onPivotChange: (LibraryPivot) -> Unit,
    onAddLocalAudio: () -> Unit,
    onPlay: (Int) -> Unit,
    onRemove: (LocalAudioItem) -> Unit,
    onOpenNowPlaying: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "collection",
            style = MaterialTheme.typography.headlineLarge,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
        ) {
            LibraryPivot.entries.forEach { item ->
                Surface(
                    onClick = { onPivotChange(item) },
                    color = Color.Transparent,
                    contentColor =
                        if (item == pivot) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                ) {
                    Text(
                        text = item.label,
                        modifier = Modifier.padding(vertical = 8.dp),
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
            }
        }

        SableActionButton(
            text = "Add local audio",
            modifier = Modifier.fillMaxWidth(),
            onClick = onAddLocalAudio,
        )

        if (items.isEmpty()) {
            EmptyPanel(
                title = "No local audio yet",
                detail =
                    "Choose audio with Android's document picker. Sable keeps access only to files you explicitly select.",
            )
        } else {
            when (pivot) {
                LibraryPivot.Songs ->
                    items.forEachIndexed { index, item ->
                        LocalTrackRow(
                            item = item,
                            accent = accentFor(index),
                            onPlay = { onPlay(index) },
                            onRemove = { onRemove(item) },
                        )
                    }

                LibraryPivot.Artists ->
                    items
                        .groupBy { it.artist }
                        .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                        .entries
                        .forEach { (artist, tracks) ->
                            LibraryGroupRow(
                                title = artist,
                                detail = "${tracks.size} track${if (tracks.size == 1) "" else "s"}",
                                accent = accentFor(artist.hashCode()),
                                onClick = {
                                    onPlay(items.indexOf(tracks.first()))
                                },
                            )
                        }

                LibraryPivot.Albums ->
                    items
                        .groupBy { it.album }
                        .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                        .entries
                        .forEach { (album, tracks) ->
                            LibraryGroupRow(
                                title = album,
                                detail = tracks.first().artist,
                                accent = accentFor(album.hashCode()),
                                onClick = {
                                    onPlay(items.indexOf(tracks.first()))
                                },
                            )
                        }
            }
        }

        if (playback.title != "Nothing queued") {
            MiniPlayer(
                playback = playback,
                onClick = onOpenNowPlaying,
            )
        }
    }
}

@Composable
private fun LocalTrackRow(
    item: LocalAudioItem,
    accent: Color,
    onPlay: () -> Unit,
    onRemove: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
        tonalElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Md),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ArtworkTile(
                accent = accent,
                modifier = Modifier.width(58.dp),
            )

            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = item.artist,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = item.album,
                    style = MaterialTheme.typography.labelLarge,
                    color = accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            CompactAction(
                text = "×",
                onClick = onRemove,
            )
            CompactAction(
                text = "▶",
                active = true,
                onClick = onPlay,
            )
        }
    }
}

@Composable
private fun LibraryGroupRow(
    title: String,
    detail: String,
    accent: Color,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Md),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ArtworkTile(
                accent = accent,
                modifier = Modifier.width(58.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = "▶",
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.titleLarge,
            )
        }
    }
}

@Composable
private fun NowPlayingScreen(
    playback: PlaybackUiState,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onStop: () -> Unit,
    onSeek: (Long) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "now playing",
            style = MaterialTheme.typography.headlineLarge,
        )

        ArtworkTile(
            accent = accentFor(playback.title.hashCode()),
            modifier = Modifier.fillMaxWidth(),
            large = true,
        )

        Text(
            text = playback.title,
            style = MaterialTheme.typography.headlineLarge,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = playback.source,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        val duration = playback.durationMs.coerceAtLeast(0L)
        val sliderMax = duration.takeIf { it > 0L }?.toFloat() ?: 1f
        val sliderValue =
            playback.positionMs
                .coerceIn(0L, duration.takeIf { it > 0L } ?: 0L)
                .toFloat()

        Slider(
            value = sliderValue,
            onValueChange = { value ->
                if (duration > 0L) {
                    onSeek(value.toLong())
                }
            },
            valueRange = 0f..sliderMax,
            enabled = duration > 0L,
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = formatDuration(playback.positionMs),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text =
                    if (duration > 0L) {
                        formatDuration(duration)
                    } else {
                        "LIVE"
                    },
                style = MaterialTheme.typography.bodyMedium,
                color =
                    if (duration > 0L) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MediaPink
                    },
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            PlayerButton(
                text = "◀",
                enabled = playback.hasPrevious,
                modifier = Modifier.weight(1f),
                onClick = onPrevious,
            )
            PlayerButton(
                text = if (playback.isPlaying) "❚❚" else "▶",
                active = true,
                modifier = Modifier.weight(1f),
                onClick = onPlayPause,
            )
            PlayerButton(
                text = "▶",
                enabled = playback.hasNext,
                modifier = Modifier.weight(1f),
                onClick = onNext,
            )
            PlayerButton(
                text = "■",
                modifier = Modifier.weight(1f),
                onClick = onStop,
            )
        }

        Text(
            text =
                if (duration > 0L) {
                    "Playback position and metadata come from the active Media3 session."
                } else {
                    "Live streams do not expose a fixed duration. Playback state still comes from Media3."
                },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RadioScreen(
    stations: List<RadioStation>,
    playback: PlaybackUiState,
    message: String?,
    onPlay: (RadioStation) -> Unit,
    onManage: () -> Unit,
    onAdd: () -> Unit,
    onOpenNowPlaying: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "internet radio",
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.headlineLarge,
            )
            SableActionButton(
                text = "Manage",
                primary = false,
                onClick = onManage,
            )
        }

        message?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        if (stations.isEmpty()) {
            EmptyPanel(
                title = "No saved stations",
                detail = "Add a station by name and direct HTTP(S) stream URL.",
            )
        } else {
            stations.forEach { station ->
                RadioStationRow(
                    station = station,
                    onPlay = { onPlay(station) },
                )
            }
        }

        SableActionButton(
            text = "Add new station",
            modifier = Modifier.fillMaxWidth(),
            onClick = onAdd,
        )

        if (playback.title != "Nothing queued") {
            MiniPlayer(
                playback = playback,
                onClick = onOpenNowPlaying,
            )
        }
    }
}

@Composable
private fun RadioStationRow(
    station: RadioStation,
    onPlay: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Md),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                modifier = Modifier.width(48.dp),
                shape = MaterialTheme.shapes.small,
                color = MediaPink.copy(alpha = 0.18f),
                border = BorderStroke(1.dp, MediaPink.copy(alpha = 0.7f)),
            ) {
                Box(
                    modifier = Modifier.aspectRatio(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "LIVE",
                        style = MaterialTheme.typography.labelLarge,
                        color = MediaPink,
                    )
                }
            }
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = station.name,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = station.url,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            CompactAction(
                text = "▶",
                active = true,
                onClick = onPlay,
            )
        }
    }
}

@Composable
private fun ManageStationsScreen(
    stations: List<RadioStation>,
    editingStation: RadioStation?,
    stationName: String,
    stationUrl: String,
    message: String?,
    onEdit: (RadioStation) -> Unit,
    onDelete: (RadioStation) -> Unit,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
    onSave: () -> Unit,
    onCancelEdit: () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        BackTitle(
            title = "station management",
            onBack = onBack,
        )

        stations.forEach { station ->
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.surface,
                border =
                    BorderStroke(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant,
                    ),
            ) {
                Row(
                    modifier = Modifier.padding(SableSpacing.Md),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(
                            text = station.name,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            text = station.url,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    SableActionButton(
                        text = "Edit",
                        primary = false,
                        onClick = { onEdit(station) },
                    )
                    SableActionButton(
                        text = "Remove",
                        primary = false,
                        onClick = { onDelete(station) },
                    )
                }
            }
        }

        if (editingStation != null) {
            Text(
                text = "edit station",
                style = MaterialTheme.typography.titleLarge,
            )
            StationFields(
                stationName = stationName,
                stationUrl = stationUrl,
                onStationNameChange = onStationNameChange,
                onStationUrlChange = onStationUrlChange,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                SableActionButton(
                    text = "Cancel edit",
                    primary = false,
                    modifier = Modifier.weight(1f),
                    onClick = onCancelEdit,
                )
                SableActionButton(
                    text = "Save changes",
                    modifier = Modifier.weight(1f),
                    onClick = onSave,
                )
            }
        }

        message?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Text(
            text = "Manage edits and removes existing stations only. Use Add new station from Radio to create one.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun AddStationScreen(
    stationName: String,
    stationUrl: String,
    message: String?,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        BackTitle(
            title = "add station",
            onBack = onCancel,
        )

        Text(
            text = "Add one live-radio stream. Existing stations are managed separately.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        StationFields(
            stationName = stationName,
            stationUrl = stationUrl,
            onStationNameChange = onStationNameChange,
            onStationUrlChange = onStationUrlChange,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableActionButton(
                text = "Cancel",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = onCancel,
            )
            SableActionButton(
                text = "Add station",
                modifier = Modifier.weight(1f),
                onClick = onSave,
            )
        }

        message?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun StationFields(
    stationName: String,
    stationUrl: String,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
) {
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
}

@Composable
private fun BackTitle(
    title: String,
    onBack: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Surface(
            onClick = onBack,
            modifier = Modifier.width(48.dp),
            color = Color.Transparent,
        ) {
            Box(
                modifier = Modifier.aspectRatio(1f),
                contentAlignment = Alignment.CenterStart,
            ) {
                Text(
                    text = "‹",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
        )
    }
}

@Composable
private fun MiniPlayer(
    playback: PlaybackUiState,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Md),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ArtworkTile(
                accent = accentFor(playback.title.hashCode()),
                modifier = Modifier.width(48.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = playback.title,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = playback.source,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = if (playback.isPlaying) "❚❚" else "▶",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun ArtworkTile(
    accent: Color,
    modifier: Modifier = Modifier,
    large: Boolean = false,
) {
    Box(
        modifier =
            modifier
                .aspectRatio(1f)
                .background(
                    brush =
                        Brush.linearGradient(
                            colors =
                                listOf(
                                    accent,
                                    MediaPink,
                                    MediaBlue,
                                ),
                        ),
                    shape =
                        if (large) {
                            MaterialTheme.shapes.large
                        } else {
                            MaterialTheme.shapes.medium
                        },
                )
                .padding(
                    if (large) {
                        SableSpacing.Xl
                    } else {
                        SableSpacing.Sm
                    },
                ),
    ) {
        Text(
            text = "S",
            modifier = Modifier.align(Alignment.BottomStart),
            style =
                if (large) {
                    MaterialTheme.typography.displayLarge
                } else {
                    MaterialTheme.typography.titleLarge
                },
            fontWeight = FontWeight.Light,
            color = Color.White,
        )
    }
}

@Composable
private fun CompactAction(
    text: String,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.width(48.dp),
        shape = MaterialTheme.shapes.small,
        color =
            if (active) {
                MaterialTheme.colorScheme.primary
            } else {
                Color.Transparent
            },
        contentColor =
            if (active) {
                MaterialTheme.colorScheme.onPrimary
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
        border =
            if (active) {
                null
            } else {
                BorderStroke(
                    1.dp,
                    MaterialTheme.colorScheme.outlineVariant,
                )
            },
    ) {
        Box(
            modifier = Modifier.aspectRatio(1f),
            contentAlignment = Alignment.Center,
        ) {
            Text(text)
        }
    }
}

@Composable
private fun PlayerButton(
    text: String,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.heightIn(min = 54.dp),
        shape = MaterialTheme.shapes.medium,
        color =
            if (active) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.surfaceVariant
            },
        contentColor =
            if (active) {
                MaterialTheme.colorScheme.onPrimary
            } else {
                MaterialTheme.colorScheme.onSurface
            },
        border =
            BorderStroke(
                1.dp,
                if (active) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.outlineVariant
                },
            ),
    ) {
        Box(
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.titleLarge,
            )
        }
    }
}

@Composable
private fun EmptyPanel(
    title: String,
    detail: String,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
            )
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

private fun accentFor(seed: Int): Color {
    val palette =
        listOf(
            MediaPurple,
            MediaBlue,
            MediaPink,
            MediaOrange,
            MediaGreen,
        )

    return palette[Math.floorMod(seed, palette.size)]
}

private fun formatDuration(valueMs: Long): String {
    val totalSeconds = valueMs.coerceAtLeast(0L) / 1000L
    val minutes = totalSeconds / 60L
    val seconds = totalSeconds % 60L
    return "$minutes:${seconds.toString().padStart(2, '0')}"
}
