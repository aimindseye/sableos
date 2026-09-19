package org.sableos.media

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import org.sableos.design.SableTheme
import org.sableos.design.applySableDarkSystemBars

class MainActivity : ComponentActivity() {
    private var playbackState by mutableStateOf(PlaybackUiState())
    private lateinit var playbackController: PlaybackController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applySableDarkSystemBars(window)

        val localAudioRepository = LocalAudioRepository(applicationContext)
        val stationRepository = RadioStationRepository(applicationContext)
        val libraryStateRepository = MediaLibraryStateRepository(applicationContext)
        val settingsRepository = MediaSettingsRepository(applicationContext)
        val initialSettings = settingsRepository.load()

        playbackController =
            PlaybackController(applicationContext) { state ->
                playbackState = state
            }

        setContent {
            var settings by remember {
                mutableStateOf(initialSettings)
            }
            var destination by remember {
                mutableStateOf(
                    when (initialSettings.startPage) {
                        MediaStartPage.Collection -> MediaDestination.Collection
                        MediaStartPage.Radio -> MediaDestination.Radio
                    },
                )
            }
            var libraryPivot by remember {
                mutableStateOf(LibraryPivot.Songs)
            }
            var localItems by remember {
                mutableStateOf(localAudioRepository.loadItems())
            }
            var stations by remember {
                mutableStateOf(stationRepository.loadStations())
            }
            var favoriteAudioUris by remember {
                mutableStateOf(libraryStateRepository.loadFavoriteAudioUris())
            }
            var favoriteStationIds by remember {
                mutableStateOf(libraryStateRepository.loadFavoriteStationIds())
            }
            var playlists by remember {
                mutableStateOf(
                    libraryStateRepository.pruneMissingAudio(
                        current = libraryStateRepository.loadPlaylists(),
                        validUris = localItems.map { it.uri }.toSet(),
                    ),
                )
            }
            var showFavoriteStationsOnly by remember {
                mutableStateOf(false)
            }

            var editingStation by remember {
                mutableStateOf<RadioStation?>(null)
            }
            var stationName by remember {
                mutableStateOf("")
            }
            var stationUrl by remember {
                mutableStateOf("")
            }

            var editingPlaylist by remember {
                mutableStateOf<MediaPlaylist?>(null)
            }
            var playlistName by remember {
                mutableStateOf("")
            }
            var selectedPlaylistUris by remember {
                mutableStateOf(emptySet<String>())
            }

            var message by remember {
                mutableStateOf<String?>(null)
            }

            DisposableEffect(
                settings.keepScreenAwakeWhilePlaying,
                playbackState.isPlaying,
            ) {
                val shouldKeepAwake =
                    settings.keepScreenAwakeWhilePlaying &&
                        playbackState.isPlaying

                if (shouldKeepAwake) {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                    )
                } else {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                    )
                }

                onDispose {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                    )
                }
            }

            fun clearStationForm() {
                editingStation = null
                stationName = ""
                stationUrl = ""
            }

            fun clearPlaylistForm() {
                editingPlaylist = null
                playlistName = ""
                selectedPlaylistUris = emptySet()
            }

            val localAudioPicker =
                rememberLauncherForActivityResult(
                    ActivityResultContracts.OpenMultipleDocuments(),
                ) { uris ->
                    if (uris.isEmpty()) {
                        return@rememberLauncherForActivityResult
                    }

                    uris.forEach { uri ->
                        runCatching {
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                        }
                    }

                    localItems =
                        localAudioRepository.addUris(
                            current = localItems,
                            uris = uris,
                        )
                    playlists =
                        libraryStateRepository.pruneMissingAudio(
                            current = playlists,
                            validUris = localItems.map { it.uri }.toSet(),
                        )
                    libraryPivot = LibraryPivot.Songs
                    message =
                        "${uris.size} local audio file${if (uris.size == 1) "" else "s"} added."
                }

            SableTheme {
                MediaScreen(
                    destination = destination,
                    libraryPivot = libraryPivot,
                    localItems = localItems,
                    stations = stations,
                    playback = playbackState,
                    favoriteAudioUris = favoriteAudioUris,
                    favoriteStationIds = favoriteStationIds,
                    playlists = playlists,
                    settings = settings,
                    playlistName = playlistName,
                    selectedPlaylistUris = selectedPlaylistUris,
                    editingPlaylist = editingPlaylist,
                    showFavoriteStationsOnly = showFavoriteStationsOnly,
                    stationName = stationName,
                    stationUrl = stationUrl,
                    editingStation = editingStation,
                    message = message,
                    onDestinationChange = { next ->
                        destination = next
                        message = null

                        if (
                            next != MediaDestination.ManageStations &&
                            next != MediaDestination.AddStation
                        ) {
                            clearStationForm()
                        }

                        if (next != MediaDestination.PlaylistEditor) {
                            clearPlaylistForm()
                        }
                    },
                    onLibraryPivotChange = {
                        libraryPivot = it
                    },
                    onAddLocalAudio = {
                        localAudioPicker.launch(arrayOf("audio/*"))
                    },
                    onPlayLocal = { selectedIndex ->
                        playLocalQueue(
                            items = localItems,
                            startIndex = selectedIndex,
                        )
                        destination = MediaDestination.NowPlaying
                    },
                    onRemoveLocal = { item ->
                        localItems =
                            localAudioRepository.remove(
                                current = localItems,
                                uri = item.uri,
                            )

                        if (item.uri in favoriteAudioUris) {
                            favoriteAudioUris =
                                libraryStateRepository.toggleFavoriteAudio(
                                    current = favoriteAudioUris,
                                    uri = item.uri,
                                )
                        }

                        playlists =
                            libraryStateRepository.pruneMissingAudio(
                                current = playlists,
                                validUris = localItems.map { it.uri }.toSet(),
                            )

                        message = "Removed from the Sable Media collection."
                    },
                    onToggleFavoriteAudio = { item ->
                        favoriteAudioUris =
                            libraryStateRepository.toggleFavoriteAudio(
                                current = favoriteAudioUris,
                                uri = item.uri,
                            )
                    },
                    onPlayStation = { station ->
                        playUri(
                            uri = Uri.parse(station.url),
                            title = station.name,
                            source = "live radio",
                        )
                        destination = MediaDestination.NowPlaying
                    },
                    onToggleFavoriteStation = { station ->
                        favoriteStationIds =
                            libraryStateRepository.toggleFavoriteStation(
                                current = favoriteStationIds,
                                stationId = station.id,
                            )
                    },
                    onRadioFavoritesOnlyChange = {
                        showFavoriteStationsOnly = it
                    },
                    onAddStation = {
                        clearStationForm()
                        message = null
                        destination = MediaDestination.AddStation
                    },
                    onManageStations = {
                        clearStationForm()
                        message = null
                        destination = MediaDestination.ManageStations
                    },
                    onEditStation = { station ->
                        editingStation = station
                        stationName = station.name
                        stationUrl = station.url
                        message = null
                    },
                    onDeleteStation = { station ->
                        stations =
                            stationRepository.deleteStation(
                                current = stations,
                                id = station.id,
                            )

                        if (station.id in favoriteStationIds) {
                            favoriteStationIds =
                                libraryStateRepository.toggleFavoriteStation(
                                    current = favoriteStationIds,
                                    stationId = station.id,
                                )
                        }

                        if (editingStation?.id == station.id) {
                            clearStationForm()
                        }

                        message = "Station removed."
                    },
                    onStationNameChange = {
                        stationName = it
                        message = null
                    },
                    onStationUrlChange = {
                        stationUrl = it
                        message = null
                    },
                    onSaveNewStation = {
                        val candidate = stationUrl.trim()

                        if (!RadioStationRepository.isSupportedUrl(candidate)) {
                            message = "Station URL must use HTTP or HTTPS."
                        } else {
                            stations =
                                stationRepository.saveStation(
                                    current = stations,
                                    name = stationName,
                                    url = candidate,
                                )
                            clearStationForm()
                            message = "Station saved locally."
                            destination = MediaDestination.Radio
                        }
                    },
                    onSaveEditedStation = {
                        val editing = editingStation
                        val candidate = stationUrl.trim()

                        when {
                            editing == null ->
                                message = "Choose a station to edit."

                            !RadioStationRepository.isSupportedUrl(candidate) ->
                                message = "Station URL must use HTTP or HTTPS."

                            else -> {
                                stations =
                                    stationRepository.updateStation(
                                        current = stations,
                                        id = editing.id,
                                        name = stationName,
                                        url = candidate,
                                    )
                                clearStationForm()
                                message = "Station updated."
                            }
                        }
                    },
                    onCancelStationFlow = {
                        if (destination == MediaDestination.AddStation) {
                            clearStationForm()
                            message = null
                            destination = MediaDestination.Radio
                        } else {
                            clearStationForm()
                            message = null
                        }
                    },
                    onCreatePlaylist = {
                        clearPlaylistForm()
                        message = null
                        destination = MediaDestination.PlaylistEditor
                    },
                    onEditPlaylist = { playlist ->
                        editingPlaylist = playlist
                        playlistName = playlist.name
                        selectedPlaylistUris = playlist.itemUris.toSet()
                        message = null
                        destination = MediaDestination.PlaylistEditor
                    },
                    onDeletePlaylist = { playlist ->
                        playlists =
                            libraryStateRepository.deletePlaylist(
                                current = playlists,
                                playlistId = playlist.id,
                            )
                        message = "Playlist removed."
                    },
                    onPlayPlaylist = { playlist ->
                        val byUri =
                            localItems.associateBy { item ->
                                item.uri
                            }
                        val queue =
                            playlist.itemUris.mapNotNull { uri ->
                                byUri[uri]
                            }

                        if (queue.isEmpty()) {
                            message = "This playlist has no available tracks."
                        } else {
                            playLocalQueue(
                                items = queue,
                                startIndex = 0,
                            )
                            destination = MediaDestination.NowPlaying
                        }
                    },
                    onPlaylistNameChange = {
                        playlistName = it
                    },
                    onTogglePlaylistItem = { uri ->
                        selectedPlaylistUris =
                            selectedPlaylistUris
                                .toMutableSet()
                                .apply {
                                    if (!add(uri)) {
                                        remove(uri)
                                    }
                                }
                                .toSet()
                    },
                    onSavePlaylist = {
                        playlists =
                            libraryStateRepository.savePlaylist(
                                current = playlists,
                                editingId = editingPlaylist?.id,
                                name = playlistName,
                                itemUris = selectedPlaylistUris,
                            )
                        clearPlaylistForm()
                        libraryPivot = LibraryPivot.Playlists
                        destination = MediaDestination.Collection
                        message = "Playlist saved locally."
                    },
                    onCancelPlaylistEditor = {
                        clearPlaylistForm()
                        libraryPivot = LibraryPivot.Playlists
                        destination = MediaDestination.Collection
                        message = null
                    },
                    onSettingsChange = { updated ->
                        settings = updated
                        settingsRepository.save(updated)
                    },
                    onPlayQueueIndex = playbackController::playQueueIndex,
                    onMoveQueueItem = playbackController::moveQueueItem,
                    onRemoveQueueItem = playbackController::removeQueueItem,
                    onPlayPause = {
                        if (playbackState.isPlaying) {
                            playbackController.pause()
                        } else {
                            playbackController.play()
                        }
                    },
                    onPrevious = playbackController::previous,
                    onNext = playbackController::next,
                    onStop = playbackController::stop,
                    onSeek = playbackController::seekTo,
                )
            }
        }
    }

    override fun onDestroy() {
        playbackController.close()
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )
        super.onDestroy()
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

    private fun playLocalQueue(
        items: List<LocalAudioItem>,
        startIndex: Int,
    ) {
        if (items.isEmpty()) return

        startService(
            Intent(this, PlaybackService::class.java)
                .setAction(PlaybackService.ACTION_PLAY_QUEUE)
                .putStringArrayListExtra(
                    PlaybackService.EXTRA_URIS,
                    ArrayList(items.map { it.uri }),
                )
                .putStringArrayListExtra(
                    PlaybackService.EXTRA_TITLES,
                    ArrayList(items.map { it.title }),
                )
                .putStringArrayListExtra(
                    PlaybackService.EXTRA_ARTISTS,
                    ArrayList(items.map { it.artist }),
                )
                .putExtra(
                    PlaybackService.EXTRA_START_INDEX,
                    startIndex.coerceIn(0, items.lastIndex),
                ),
        )
    }
}
