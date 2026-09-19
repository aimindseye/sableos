package org.sableos.media.preview

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
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
import androidx.compose.ui.unit.sp
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSpacing

private val MediaPink = Color(0xFFFF4F9A)
private val MediaPurple = Color(0xFF7A42E8)
private val MediaBlue = Color(0xFF4D9CFF)
private val MediaGreen = Color(0xFF35C66B)
private val MediaOrange = Color(0xFFF28C45)

private enum class MediaPreviewDestination(
    val label: String,
) {
    Collection("collection"),
    NowPlaying("now playing"),
    Radio("radio"),
    Stations("stations"),
}

private enum class LibraryPivot(
    val label: String,
) {
    Artists("artists"),
    Albums("albums"),
    Songs("songs"),
    Playlists("playlists"),
}

private data class PreviewTrack(
    val title: String,
    val artist: String,
    val subtitle: String,
    val accent: Color,
)

private data class PreviewStation(
    val name: String,
    val location: String,
    val url: String,
    val favorite: Boolean = false,
)

private val previewTracks =
    listOf(
        PreviewTrack(
            title = "Midnight Circuit",
            artist = "Sable Sessions",
            subtitle = "Night Drive",
            accent = MediaPurple,
        ),
        PreviewTrack(
            title = "Glass City",
            artist = "Northbound",
            subtitle = "Local Files",
            accent = MediaBlue,
        ),
        PreviewTrack(
            title = "Signal Bloom",
            artist = "Afterlight",
            subtitle = "Collected Tracks",
            accent = MediaPink,
        ),
        PreviewTrack(
            title = "Horizon",
            artist = "Parallel Lines",
            subtitle = "Offline Mix",
            accent = MediaOrange,
        ),
    )

private val previewStations =
    listOf(
        PreviewStation(
            name = "K-Rock 92.3",
            location = "New York, US",
            url = "https://radio.example/krock",
            favorite = true,
        ),
        PreviewStation(
            name = "Nightwave FM",
            location = "Toronto, CA",
            url = "https://radio.example/nightwave",
        ),
        PreviewStation(
            name = "City Beats",
            location = "London, UK",
            url = "https://radio.example/citybeats",
            favorite = true,
        ),
    )

@Composable
internal fun MediaDesignPreviewScreen() {
    var destination by remember {
        mutableStateOf(MediaPreviewDestination.Collection)
    }
    var libraryPivot by remember {
        mutableStateOf(LibraryPivot.Artists)
    }
    var position by remember {
        mutableFloatStateOf(0.38f)
    }
    var playing by remember {
        mutableStateOf(true)
    }
    var stations by remember {
        mutableStateOf(previewStations)
    }
    var editingStation by remember {
        mutableStateOf<PreviewStation?>(null)
    }
    var stationName by remember {
        mutableStateOf("")
    }
    var stationUrl by remember {
        mutableStateOf("")
    }

    fun beginAddStation() {
        editingStation = null
        stationName = ""
        stationUrl = ""
        destination = MediaPreviewDestination.Stations
    }

    fun beginEditStation(station: PreviewStation) {
        editingStation = station
        stationName = station.name
        stationUrl = station.url
        destination = MediaPreviewDestination.Stations
    }

    fun saveStation() {
        val name = stationName.trim()
        val url = stationUrl.trim()
        if (name.isBlank() || url.isBlank()) return

        val editing = editingStation
        stations =
            if (editing == null) {
                stations +
                    PreviewStation(
                        name = name,
                        location = "Saved locally",
                        url = url,
                    )
            } else {
                stations.map { station ->
                    if (station == editing) {
                        station.copy(
                            name = name,
                            url = url,
                        )
                    } else {
                        station
                    }
                }
            }

        editingStation = null
        stationName = ""
        stationUrl = ""
        destination = MediaPreviewDestination.Radio
    }

    SableScrollableScreen {
        SableHeroHeader(
            eyebrow = "Sable Media · UI-C1A preview",
            title = "music",
            subtitle = "Local playback and user-managed live radio.",
        )

        MediaPrimaryPivot(
            destination = destination,
            onCollection = {
                destination = MediaPreviewDestination.Collection
            },
            onNowPlaying = {
                destination = MediaPreviewDestination.NowPlaying
            },
            onRadio = {
                destination = MediaPreviewDestination.Radio
            },
        )

        when (destination) {
            MediaPreviewDestination.Collection ->
                CollectionPreview(
                    libraryPivot = libraryPivot,
                    onLibraryPivot = { libraryPivot = it },
                    onOpenNowPlaying = {
                        destination = MediaPreviewDestination.NowPlaying
                    },
                )

            MediaPreviewDestination.NowPlaying ->
                NowPlayingPreview(
                    position = position,
                    playing = playing,
                    onPositionChange = { position = it },
                    onPlayPause = { playing = !playing },
                )

            MediaPreviewDestination.Radio ->
                RadioPreview(
                    stations = stations,
                    onPlayStation = {
                        destination = MediaPreviewDestination.NowPlaying
                    },
                    onEditStation = ::beginEditStation,
                    onManageStations = {
                        editingStation = null
                        stationName = ""
                        stationUrl = ""
                        destination = MediaPreviewDestination.Stations
                    },
                    onAddStation = ::beginAddStation,
                )

            MediaPreviewDestination.Stations ->
                StationManagementPreview(
                    stations = stations,
                    stationName = stationName,
                    stationUrl = stationUrl,
                    editingStation = editingStation,
                    onStationNameChange = { stationName = it },
                    onStationUrlChange = { stationUrl = it },
                    onEdit = ::beginEditStation,
                    onRemove = { target ->
                        stations = stations.filterNot { it == target }
                        if (editingStation == target) {
                            editingStation = null
                            stationName = ""
                            stationUrl = ""
                        }
                    },
                    onSave = ::saveStation,
                    onCancel = {
                        editingStation = null
                        stationName = ""
                        stationUrl = ""
                        destination = MediaPreviewDestination.Radio
                    },
                    onBack = {
                        destination = MediaPreviewDestination.Radio
                    },
                )
        }
    }
}

@Composable
private fun MediaPrimaryPivot(
    destination: MediaPreviewDestination,
    onCollection: () -> Unit,
    onNowPlaying: () -> Unit,
    onRadio: () -> Unit,
) {
    val entries =
        listOf(
            MediaPreviewDestination.Collection to onCollection,
            MediaPreviewDestination.NowPlaying to onNowPlaying,
            MediaPreviewDestination.Radio to onRadio,
        )

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        entries.forEach { (item, onClick) ->
            PivotItem(
                text = item.label,
                active =
                    destination == item ||
                        (
                            destination == MediaPreviewDestination.Stations &&
                                item == MediaPreviewDestination.Radio
                        ),
                onClick = onClick,
            )
        }
    }
}

@Composable
private fun PivotItem(
    text: String,
    active: Boolean,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
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
                text = text,
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

@Composable
private fun CollectionPreview(
    libraryPivot: LibraryPivot,
    onLibraryPivot: (LibraryPivot) -> Unit,
    onOpenNowPlaying: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "collection",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            LibraryPivot.entries.forEach { item ->
                Surface(
                    onClick = { onLibraryPivot(item) },
                    color = Color.Transparent,
                    contentColor =
                        if (item == libraryPivot) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                ) {
                    Text(
                        text = item.label,
                        modifier = Modifier.padding(vertical = 8.dp),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }
        }

        previewTracks.forEach { track ->
            LibraryRow(
                track = track,
                onClick = onOpenNowPlaying,
            )
        }

        MiniPlayerPreview(
            onClick = onOpenNowPlaying,
        )
    }
}

@Composable
private fun LibraryRow(
    track: PreviewTrack,
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
        tonalElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Md),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ArtworkTile(
                accent = track.accent,
                modifier = Modifier.width(64.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = track.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = track.artist,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = track.subtitle,
                    style = MaterialTheme.typography.labelLarge,
                    color = track.accent,
                )
            }
            Text(
                text = "▶",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun NowPlayingPreview(
    position: Float,
    playing: Boolean,
    onPositionChange: (Float) -> Unit,
    onPlayPause: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = "now playing",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )

        ArtworkTile(
            accent = MediaPurple,
            modifier = Modifier.fillMaxWidth(),
            large = true,
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            Text(
                text = "Midnight Circuit",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = "Sable Sessions",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Slider(
            value = position,
            onValueChange = onPositionChange,
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "1:30",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "3:45",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            PlayerButton(
                text = "shuffle",
                modifier = Modifier.weight(1f),
            )
            PlayerButton(
                text = "◀",
                modifier = Modifier.weight(1f),
            )
            PlayerButton(
                text = if (playing) "❚❚" else "▶",
                active = true,
                modifier = Modifier.weight(1f),
                onClick = onPlayPause,
            )
            PlayerButton(
                text = "▶",
                modifier = Modifier.weight(1f),
            )
            PlayerButton(
                text = "repeat",
                modifier = Modifier.weight(1f),
            )
        }

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
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            ) {
                Text(
                    text = "up next",
                    style = MaterialTheme.typography.titleLarge,
                )
                previewTracks.drop(1).take(3).forEach { track ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ArtworkTile(
                            accent = track.accent,
                            modifier = Modifier.width(42.dp),
                        )
                        Column(
                            modifier = Modifier.weight(1f),
                        ) {
                            Text(
                                text = track.title,
                                style = MaterialTheme.typography.bodyLarge,
                            )
                            Text(
                                text = track.artist,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            text = "+",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PlayerButton(
    text: String,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    onClick: () -> Unit = {},
) {
    Surface(
        onClick = onClick,
        modifier = modifier.heightIn(min = 52.dp),
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
                fontSize =
                    if (text == "shuffle" || text == "repeat") {
                        11.sp
                    } else {
                        18.sp
                    },
            )
        }
    }
}

@Composable
private fun RadioPreview(
    stations: List<PreviewStation>,
    onPlayStation: (PreviewStation) -> Unit,
    onEditStation: (PreviewStation) -> Unit,
    onManageStations: () -> Unit,
    onAddStation: () -> Unit,
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
                color = MaterialTheme.colorScheme.onBackground,
            )
            SableActionButton(
                text = "Manage",
                primary = false,
                onClick = onManageStations,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = "stations",
                style = MaterialTheme.typography.titleMedium,
                color = MediaPink,
            )
            Text(
                text = "favorites",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        stations.forEach { station ->
            RadioStationPreviewRow(
                station = station,
                onPlay = { onPlayStation(station) },
                onEdit = { onEditStation(station) },
            )
        }

        SableActionButton(
            text = "Add new station",
            modifier = Modifier.fillMaxWidth(),
            onClick = onAddStation,
        )

        MiniPlayerPreview(
            onClick = {
                if (stations.isNotEmpty()) {
                    onPlayStation(stations.first())
                }
            },
        )
    }
}

@Composable
private fun RadioStationPreviewRow(
    station: PreviewStation,
    onPlay: () -> Unit,
    onEdit: () -> Unit,
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
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = station.name,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.titleMedium,
                    )
                    if (station.favorite) {
                        Text(
                            text = "★",
                            color = MediaPink,
                        )
                    }
                }
                Text(
                    text = station.location,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Surface(
                onClick = onEdit,
                modifier = Modifier.width(44.dp),
                color = Color.Transparent,
            ) {
                Box(
                    modifier = Modifier.aspectRatio(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "✎",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Surface(
                onClick = onPlay,
                modifier = Modifier.width(48.dp),
                shape = MaterialTheme.shapes.small,
                color = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ) {
                Box(
                    modifier = Modifier.aspectRatio(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("▶")
                }
            }
        }
    }
}

@Composable
private fun StationManagementPreview(
    stations: List<PreviewStation>,
    stationName: String,
    stationUrl: String,
    editingStation: PreviewStation?,
    onStationNameChange: (String) -> Unit,
    onStationUrlChange: (String) -> Unit,
    onEdit: (PreviewStation) -> Unit,
    onRemove: (PreviewStation) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
    onBack: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
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
                text = "station management",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
        }

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
                        onClick = { onRemove(station) },
                    )
                }
            }
        }

        Text(
            text =
                if (editingStation == null) {
                    "add station"
                } else {
                    "edit station"
                },
            style = MaterialTheme.typography.titleLarge,
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
            label = { Text("Stream URL") },
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
                text = "Save",
                modifier = Modifier.weight(1f),
                onClick = onSave,
            )
        }

        Text(
            text =
                "Preview data only. Production wiring will use the existing local station repository and Media3 session.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
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
private fun MiniPlayerPreview(
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
                accent = MediaPurple,
                modifier = Modifier.width(48.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = "Midnight Circuit",
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = "Sable Sessions",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = "◀",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "▶",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "▶",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
