package org.sableos.media

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SableSpacing

internal val MediaPink = Color(0xFFFF4F9A)
internal val MediaPurple = Color(0xFF7A42E8)
internal val MediaBlue = Color(0xFF4D9CFF)
internal val MediaGreen = Color(0xFF35C66B)
internal val MediaOrange = Color(0xFFF28C45)

internal enum class MediaDestination(
    val label: String,
) {
    Collection("music"),
    Podcasts("podcasts"),
    NowPlaying("now playing"),
    Radio("radio"),
    ManageStations("manage"),
    AddStation("add"),
    Queue("queue"),
    PlaylistEditor("playlist"),
    Settings("settings"),
}

internal enum class LibraryPivot(
    val label: String,
) {
    Songs("songs"),
    Artists("artists"),
    Albums("albums"),
    Favorites("favorites"),
    Playlists("playlists"),
}

internal data class MediaScreenState(
    destination: MediaDestination,
    libraryPivot: LibraryPivot,
    localItems: List<LocalAudioItem>,
    podcastSubscriptions: List<PodcastSubscription>,
    savedPodcastEpisodeIds: Set<String>,
    playedPodcastEpisodeIds: Set<String>,
    podcastFeedUrl: String,
    podcastBusy: Boolean,
    podcastMessage: String?,
    stations: List<RadioStation>,
    playback: PlaybackUiState,
    favoriteAudioUris: Set<String>,
    favoriteStationIds: Set<String>,
    playlists: List<MediaPlaylist>,
    settings: MediaSettings,
    playlistName: String,
    selectedPlaylistUris: Set<String>,
    editingPlaylist: MediaPlaylist?,
    showFavoriteStationsOnly: Boolean,
    stationName: String,
    stationUrl: String,
    editingStation: RadioStation?,
    message: String?,
)

internal data class MediaScreenActions(
    val onDestinationChange: (MediaDestination) -> Unit,
    val onLibraryPivotChange: (LibraryPivot) -> Unit,
    val onAddLocalAudio: () -> Unit,
    val onAddLocalFolder: () -> Unit,
    val onPlayLocal: (Int) -> Unit,
    val onRemoveLocal: (LocalAudioItem) -> Unit,
    val onToggleFavoriteAudio: (LocalAudioItem) -> Unit,
    val onPodcastFeedUrlChange: (String) -> Unit,
    val onAddPodcastFeed: () -> Unit,
    val onRefreshPodcasts: () -> Unit,
    val onRemovePodcastSubscription: (PodcastSubscription) -> Unit,
    val onPlayPodcastEpisode: (PodcastEpisode) -> Unit,
    val onQueuePodcastEpisode: (PodcastEpisode) -> Unit,
    val onToggleSavedPodcastEpisode: (PodcastEpisode) -> Unit,
    val onPlayStation: (RadioStation) -> Unit,
    val onToggleFavoriteStation: (RadioStation) -> Unit,
    val onRadioFavoritesOnlyChange: (Boolean) -> Unit,
    val onAddStation: () -> Unit,
    val onManageStations: () -> Unit,
    val onEditStation: (RadioStation) -> Unit,
    val onDeleteStation: (RadioStation) -> Unit,
    val onStationNameChange: (String) -> Unit,
    val onStationUrlChange: (String) -> Unit,
    val onSaveNewStation: () -> Unit,
    val onSaveEditedStation: () -> Unit,
    val onCancelStationFlow: () -> Unit,
    val onCreatePlaylist: () -> Unit,
    val onEditPlaylist: (MediaPlaylist) -> Unit,
    val onDeletePlaylist: (MediaPlaylist) -> Unit,
    val onPlayPlaylist: (MediaPlaylist) -> Unit,
    val onPlaylistNameChange: (String) -> Unit,
    val onTogglePlaylistItem: (String) -> Unit,
    val onSavePlaylist: () -> Unit,
    val onCancelPlaylistEditor: () -> Unit,
    val onSettingsChange: (MediaSettings) -> Unit,
    val onPlayQueueIndex: (Int) -> Unit,
    val onMoveQueueItem: (Int, Int) -> Unit,
    val onRemoveQueueItem: (Int) -> Unit,
    val onPlayPause: () -> Unit,
    val onPrevious: () -> Unit,
    val onNext: () -> Unit,
    val onStop: () -> Unit,
    val onSeek: (Long) -> Unit,
)

@Composable
internal fun MediaScreen(
    state: MediaScreenState,
    actions: MediaScreenActions,
) {
    val destination = state.destination
    val libraryPivot = state.libraryPivot
    val localItems = state.localItems
    val podcastSubscriptions = state.podcastSubscriptions
    val savedPodcastEpisodeIds = state.savedPodcastEpisodeIds
    val playedPodcastEpisodeIds = state.playedPodcastEpisodeIds
    val podcastFeedUrl = state.podcastFeedUrl
    val podcastBusy = state.podcastBusy
    val podcastMessage = state.podcastMessage
    val stations = state.stations
    val playback = state.playback
    val favoriteAudioUris = state.favoriteAudioUris
    val favoriteStationIds = state.favoriteStationIds
    val playlists = state.playlists
    val settings = state.settings
    val playlistName = state.playlistName
    val selectedPlaylistUris = state.selectedPlaylistUris
    val editingPlaylist = state.editingPlaylist
    val showFavoriteStationsOnly = state.showFavoriteStationsOnly
    val stationName = state.stationName
    val stationUrl = state.stationUrl
    val editingStation = state.editingStation
    val message = state.message
    val onDestinationChange = actions.onDestinationChange
    val onLibraryPivotChange = actions.onLibraryPivotChange
    val onAddLocalAudio = actions.onAddLocalAudio
    val onAddLocalFolder = actions.onAddLocalFolder
    val onPlayLocal = actions.onPlayLocal
    val onRemoveLocal = actions.onRemoveLocal
    val onToggleFavoriteAudio = actions.onToggleFavoriteAudio
    val onPodcastFeedUrlChange = actions.onPodcastFeedUrlChange
    val onAddPodcastFeed = actions.onAddPodcastFeed
    val onRefreshPodcasts = actions.onRefreshPodcasts
    val onRemovePodcastSubscription = actions.onRemovePodcastSubscription
    val onPlayPodcastEpisode = actions.onPlayPodcastEpisode
    val onQueuePodcastEpisode = actions.onQueuePodcastEpisode
    val onToggleSavedPodcastEpisode = actions.onToggleSavedPodcastEpisode
    val onPlayStation = actions.onPlayStation
    val onToggleFavoriteStation = actions.onToggleFavoriteStation
    val onRadioFavoritesOnlyChange = actions.onRadioFavoritesOnlyChange
    val onAddStation = actions.onAddStation
    val onManageStations = actions.onManageStations
    val onEditStation = actions.onEditStation
    val onDeleteStation = actions.onDeleteStation
    val onStationNameChange = actions.onStationNameChange
    val onStationUrlChange = actions.onStationUrlChange
    val onSaveNewStation = actions.onSaveNewStation
    val onSaveEditedStation = actions.onSaveEditedStation
    val onCancelStationFlow = actions.onCancelStationFlow
    val onCreatePlaylist = actions.onCreatePlaylist
    val onEditPlaylist = actions.onEditPlaylist
    val onDeletePlaylist = actions.onDeletePlaylist
    val onPlayPlaylist = actions.onPlayPlaylist
    val onPlaylistNameChange = actions.onPlaylistNameChange
    val onTogglePlaylistItem = actions.onTogglePlaylistItem
    val onSavePlaylist = actions.onSavePlaylist
    val onCancelPlaylistEditor = actions.onCancelPlaylistEditor
    val onSettingsChange = actions.onSettingsChange
    val onPlayQueueIndex = actions.onPlayQueueIndex
    val onMoveQueueItem = actions.onMoveQueueItem
    val onRemoveQueueItem = actions.onRemoveQueueItem
    val onPlayPause = actions.onPlayPause
    val onPrevious = actions.onPrevious
    val onNext = actions.onNext
    val onStop = actions.onStop
    val onSeek = actions.onSeek
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        if (destination == MediaDestination.Collection) {
            CollectionScreen(
                pivot = libraryPivot,
                localItems = localItems,
                playback = playback,
                favoriteAudioUris = favoriteAudioUris,
                playlists = playlists,
                showMiniPlayer = settings.showMiniPlayer,
                onDestinationChange = onDestinationChange,
                onPivotChange = onLibraryPivotChange,
                onAddLocalAudio = onAddLocalAudio,
                onAddLocalFolder = onAddLocalFolder,
                onPlay = onPlayLocal,
                onRemove = onRemoveLocal,
                onToggleFavorite = onToggleFavoriteAudio,
                onCreatePlaylist = onCreatePlaylist,
                onEditPlaylist = onEditPlaylist,
                onDeletePlaylist = onDeletePlaylist,
                onPlayPlaylist = onPlayPlaylist,
                onOpenNowPlaying = {
                    onDestinationChange(MediaDestination.NowPlaying)
                },
            )
        } else {
            LazyColumn(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .safeDrawingPadding()
                        .imePadding(),
                contentPadding =
                    PaddingValues(
                        horizontal = SableSpacing.ScreenHorizontal,
                        vertical = SableSpacing.ScreenVertical,
                    ),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            ) {
                item {
                    SableHeroHeader(
                        eyebrow = "Sable Media",
                        title =
                            when (destination) {
                                MediaDestination.Podcasts -> "podcasts"
                                MediaDestination.Radio,
                                MediaDestination.ManageStations,
                                MediaDestination.AddStation,
                                -> "radio"
                                MediaDestination.NowPlaying,
                                MediaDestination.Queue,
                                -> "playing"
                                MediaDestination.Settings -> "settings"
                                else -> "media"
                            },
                        subtitle = "Music, podcasts, and radio in one private playback flow.",
                    )
                }

                item {
                    PrimaryPivot(
                        destination = destination,
                        onSelect = onDestinationChange,
                    )
                }

                if (
                    destination == MediaDestination.NowPlaying ||
                    destination == MediaDestination.Podcasts ||
                    destination == MediaDestination.Radio
                ) {
                    item {
                        MediaUtilityBar(
                            queueCount = playback.queue.size,
                            upNextCount =
                                playback.queue.count { item ->
                                    item.index > playback.currentIndex
                                },
                            onQueue = {
                                onDestinationChange(MediaDestination.Queue)
                            },
                            onSettings = {
                                onDestinationChange(MediaDestination.Settings)
                            },
                        )
                    }
                }

                item {
                    when (destination) {
                        MediaDestination.Collection -> Unit

                        MediaDestination.Podcasts ->
                            PodcastScreen(
                                subscriptions = podcastSubscriptions,
                                savedEpisodeIds = savedPodcastEpisodeIds,
                                playedEpisodeIds = playedPodcastEpisodeIds,
                                feedUrl = podcastFeedUrl,
                                busy = podcastBusy,
                                message = podcastMessage,
                                playback = playback,
                                showMiniPlayer = settings.showMiniPlayer,
                                onFeedUrlChange = onPodcastFeedUrlChange,
                                onAddFeed = onAddPodcastFeed,
                                onRefresh = onRefreshPodcasts,
                                onRemoveSubscription = onRemovePodcastSubscription,
                                onPlayEpisode = onPlayPodcastEpisode,
                                onQueueEpisode = onQueuePodcastEpisode,
                                onToggleSavedEpisode = onToggleSavedPodcastEpisode,
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
                                favoriteStationIds = favoriteStationIds,
                                showFavoritesOnly = showFavoriteStationsOnly,
                                showMiniPlayer = settings.showMiniPlayer,
                                message = message,
                                onPlay = onPlayStation,
                                onToggleFavorite = onToggleFavoriteStation,
                                onFavoritesOnlyChange = onRadioFavoritesOnlyChange,
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

                        MediaDestination.Queue ->
                            QueueScreen(
                                playback = playback,
                                onPlayIndex = onPlayQueueIndex,
                                onMove = onMoveQueueItem,
                                onRemove = onRemoveQueueItem,
                                onPlayPause = onPlayPause,
                                onPrevious = onPrevious,
                                onNext = onNext,
                                onStop = onStop,
                                onBack = {
                                    onDestinationChange(MediaDestination.NowPlaying)
                                },
                            )

                        MediaDestination.PlaylistEditor ->
                            PlaylistEditorScreen(
                                editingPlaylist = editingPlaylist,
                                playlistName = playlistName,
                                selectedUris = selectedPlaylistUris,
                                localItems = localItems,
                                onNameChange = onPlaylistNameChange,
                                onToggleItem = onTogglePlaylistItem,
                                onSave = onSavePlaylist,
                                onCancel = onCancelPlaylistEditor,
                            )

                        MediaDestination.Settings ->
                            SettingsScreen(
                                settings = settings,
                                onSettingsChange = onSettingsChange,
                                onBack = {
                                    onDestinationChange(MediaDestination.Collection)
                                },
                            )
                    }
                }
            }
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

            MediaDestination.Queue -> MediaDestination.NowPlaying
            MediaDestination.PlaylistEditor -> MediaDestination.Collection
            MediaDestination.Settings -> null
            else -> destination
        }

    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Xl),
    ) {
        listOf(
            MediaDestination.Collection,
            MediaDestination.Podcasts,
            MediaDestination.Radio,
            MediaDestination.NowPlaying,
        ).forEach { item ->
            val active = current != null && item == current
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
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight =
                            if (active) {
                                FontWeight.Medium
                            } else {
                                FontWeight.Light
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
private fun MediaUtilityBar(
    queueCount: Int,
    upNextCount: Int,
    onQueue: () -> Unit,
    onSettings: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (queueCount > 1) {
            Surface(
                onClick = onQueue,
                color = Color.Transparent,
                contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
            ) {
                Text(
                    text = "up next · $upNextCount",
                    modifier = Modifier.padding(12.dp),
                    style = MaterialTheme.typography.labelLarge,
                )
            }
        }
        Surface(
            onClick = onSettings,
            color = Color.Transparent,
            contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        ) {
            Text(
                text = "settings",
                modifier = Modifier.padding(12.dp),
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

@Composable
private fun CollectionScreen(
    pivot: LibraryPivot,
    localItems: List<LocalAudioItem>,
    playback: PlaybackUiState,
    favoriteAudioUris: Set<String>,
    playlists: List<MediaPlaylist>,
    showMiniPlayer: Boolean,
    onDestinationChange: (MediaDestination) -> Unit,
    onPivotChange: (LibraryPivot) -> Unit,
    onAddLocalAudio: () -> Unit,
    onAddLocalFolder: () -> Unit,
    onPlay: (Int) -> Unit,
    onRemove: (LocalAudioItem) -> Unit,
    onToggleFavorite: (LocalAudioItem) -> Unit,
    onCreatePlaylist: () -> Unit,
    onEditPlaylist: (MediaPlaylist) -> Unit,
    onDeletePlaylist: (MediaPlaylist) -> Unit,
    onPlayPlaylist: (MediaPlaylist) -> Unit,
    onOpenNowPlaying: () -> Unit,
) {
    val artistGroups =
        remember(localItems) {
            localItems
                .groupBy { it.artist }
                .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                .entries
                .map { it.key to it.value }
        }
    val albumGroups =
        remember(localItems) {
            localItems
                .groupBy { it.album }
                .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                .entries
                .map { it.key to it.value }
        }
    val favorites =
        remember(localItems, favoriteAudioUris) {
            localItems.filter { item ->
                item.uri in favoriteAudioUris
            }
        }
    val indexByUri =
        remember(localItems) {
            localItems
                .mapIndexed { index, item -> item.uri to index }
                .toMap()
        }

    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .imePadding(),
        contentPadding =
            PaddingValues(
                horizontal = SableSpacing.ScreenHorizontal,
                vertical = SableSpacing.ScreenVertical,
            ),
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        item {
            SableHeroHeader(
                eyebrow = "Sable Media",
                title = "music",
                subtitle = "Your local collection, playlists, and one continuous playback queue.",
            )
        }

        item {
            PrimaryPivot(
                destination = MediaDestination.Collection,
                onSelect = onDestinationChange,
            )
        }

        item {
            MediaUtilityBar(
                queueCount = playback.queue.size,
                upNextCount =
                    playback.queue.count { item ->
                        item.index > playback.currentIndex
                    },
                onQueue = {
                    onDestinationChange(MediaDestination.Queue)
                },
                onSettings = {
                    onDestinationChange(MediaDestination.Settings)
                },
            )
        }

        item {
            Text(
                text = "collection",
                style = MaterialTheme.typography.headlineLarge,
            )
        }

        item {
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
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
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                SableActionButton(
                    text = "Add audio files",
                    modifier = Modifier.weight(1f),
                    onClick = onAddLocalAudio,
                )
                SableActionButton(
                    text = "Import folder",
                    primary = false,
                    modifier = Modifier.weight(1f),
                    onClick = onAddLocalFolder,
                )
            }
        }

        if (localItems.isEmpty()) {
            item {
                EmptyPanel(
                    title = "No local audio yet",
                    detail =
                        "Choose audio with Android's document picker. Sable keeps access only to files you explicitly select.",
                )
            }
        } else {
            when (pivot) {
                LibraryPivot.Songs ->
                    items(
                        count = localItems.size,
                        key = { index -> localItems[index].uri },
                    ) { index ->
                        val item = localItems[index]
                        LocalTrackRow(
                            item = item,
                            accent = accentFor(index),
                            favorite = item.uri in favoriteAudioUris,
                            onToggleFavorite = { onToggleFavorite(item) },
                            onPlay = { onPlay(index) },
                            onRemove = { onRemove(item) },
                        )
                    }

                LibraryPivot.Artists ->
                    items(
                        count = artistGroups.size,
                        key = { index -> artistGroups[index].first },
                    ) { index ->
                        val (artist, tracks) = artistGroups[index]
                        LibraryGroupRow(
                            title = artist,
                            detail = "${tracks.size} track${if (tracks.size == 1) "" else "s"}",
                            accent = accentFor(artist.hashCode()),
                            onClick = {
                                indexByUri[tracks.first().uri]?.let(onPlay)
                            },
                        )
                    }

                LibraryPivot.Albums ->
                    items(
                        count = albumGroups.size,
                        key = { index -> albumGroups[index].first },
                    ) { index ->
                        val (album, tracks) = albumGroups[index]
                        LibraryGroupRow(
                            title = album,
                            detail = tracks.first().artist,
                            accent = accentFor(album.hashCode()),
                            onClick = {
                                val firstIndex = indexByUri[tracks.first().uri] ?: return@LibraryGroupRow
                                onPlay(firstIndex)
                            },
                        )
                    }

                LibraryPivot.Favorites ->
                    if (favorites.isEmpty()) {
                        item {
                            C2InfoPanel(
                                title = "No favorite tracks",
                                detail = "Mark local tracks with ★ to keep a quick local favorites view.",
                            )
                        }
                    } else {
                        items(
                            count = favorites.size,
                            key = { index -> favorites[index].uri },
                        ) { favoriteIndex ->
                            val item = favorites[favoriteIndex]
                            val sourceIndex = indexByUri[item.uri] ?: 0
                            LocalTrackRow(
                                item = item,
                                accent = accentFor(sourceIndex),
                                favorite = true,
                                onToggleFavorite = { onToggleFavorite(item) },
                                onPlay = { onPlay(sourceIndex) },
                                onRemove = { onRemove(item) },
                            )
                        }
                    }

                LibraryPivot.Playlists -> {
                    item {
                        SableActionButton(
                            text = "Create playlist",
                            modifier = Modifier.fillMaxWidth(),
                            onClick = onCreatePlaylist,
                        )
                    }

                    if (playlists.isEmpty()) {
                        item {
                            C2InfoPanel(
                                title = "No playlists yet",
                                detail = "Create a local playlist from audio already added to Sable Media.",
                            )
                        }
                    } else {
                        items(
                            count = playlists.size,
                            key = { index -> playlists[index].id },
                        ) { index ->
                            val playlist = playlists[index]
                            PlaylistCard(
                                playlist = playlist,
                                availableItems = localItems,
                                onPlay = { onPlayPlaylist(playlist) },
                                onEdit = { onEditPlaylist(playlist) },
                                onDelete = { onDeletePlaylist(playlist) },
                            )
                        }
                    }
                }
            }
        }

        if (showMiniPlayer && playback.title != "Nothing queued") {
            item {
                MiniPlayer(
                    playback = playback,
                    onClick = onOpenNowPlaying,
                )
            }
        }
    }
}

@Composable
private fun LocalTrackRow(
    item: LocalAudioItem,
    accent: Color,
    favorite: Boolean,
    onToggleFavorite: () -> Unit,
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
                text = if (favorite) "★" else "☆",
                onClick = onToggleFavorite,
            )
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
private fun PlaylistCard(
    playlist: MediaPlaylist,
    availableItems: List<LocalAudioItem>,
    onPlay: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val trackCount =
        playlist.itemUris.count { uri ->
            availableItems.any { it.uri == uri }
        }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Md),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = playlist.name,
                style = MaterialTheme.typography.titleLarge,
            )
            Text(
                text = "$trackCount track${if (trackCount == 1) "" else "s"}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                    text = "Edit",
                    primary = false,
                    modifier = Modifier.weight(1f),
                    onClick = onEdit,
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
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
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

        Column(
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            Text(
                text = playback.title,
                style = MaterialTheme.typography.headlineMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = playback.source,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

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

    }
}

@Composable
private fun RadioScreen(
    stations: List<RadioStation>,
    playback: PlaybackUiState,
    favoriteStationIds: Set<String>,
    showFavoritesOnly: Boolean,
    showMiniPlayer: Boolean,
    message: String?,
    onPlay: (RadioStation) -> Unit,
    onToggleFavorite: (RadioStation) -> Unit,
    onFavoritesOnlyChange: (Boolean) -> Unit,
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

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
        ) {
            Surface(
                onClick = { onFavoritesOnlyChange(false) },
                color = Color.Transparent,
                contentColor =
                    if (!showFavoritesOnly) {
                        MediaPink
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            ) {
                Text(
                    text = "stations",
                    modifier = Modifier.padding(vertical = 8.dp),
                    style = MaterialTheme.typography.titleMedium,
                )
            }
            Surface(
                onClick = { onFavoritesOnlyChange(true) },
                color = Color.Transparent,
                contentColor =
                    if (showFavoritesOnly) {
                        MediaPink
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            ) {
                Text(
                    text = "favorites",
                    modifier = Modifier.padding(vertical = 8.dp),
                    style = MaterialTheme.typography.titleMedium,
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

        val visibleStations =
            if (showFavoritesOnly) {
                stations.filter { it.id in favoriteStationIds }
            } else {
                stations
            }

        if (visibleStations.isEmpty()) {
            EmptyPanel(
                title =
                    if (showFavoritesOnly) {
                        "No favorite stations"
                    } else {
                        "No saved stations"
                    },
                detail =
                    if (showFavoritesOnly) {
                        "Mark stations with ★ to keep a quick local favorites view."
                    } else {
                        "Add a station by name and direct HTTP(S) stream URL."
                    },
            )
        } else {
            visibleStations.forEach { station ->
                RadioStationRow(
                    station = station,
                    favorite = station.id in favoriteStationIds,
                    onToggleFavorite = { onToggleFavorite(station) },
                    onPlay = { onPlay(station) },
                )
            }
        }

        SableActionButton(
            text = "Add new station",
            modifier = Modifier.fillMaxWidth(),
            onClick = onAdd,
        )

        if (showMiniPlayer && playback.title != "Nothing queued") {
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
    favorite: Boolean,
    onToggleFavorite: () -> Unit,
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
                text = if (favorite) "★" else "☆",
                onClick = onToggleFavorite,
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
                .aspectRatio(if (large) 1.9f else 1f)
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
