package org.sableos.media

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
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

        playbackController =
            PlaybackController(applicationContext) { state ->
                playbackState = state
            }

        setContent {
            var destination by remember {
                mutableStateOf(MediaDestination.Collection)
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
            var editingStation by remember {
                mutableStateOf<RadioStation?>(null)
            }
            var stationName by remember {
                mutableStateOf("")
            }
            var stationUrl by remember {
                mutableStateOf("")
            }
            var message by remember {
                mutableStateOf<String?>(null)
            }

            fun clearStationForm() {
                editingStation = null
                stationName = ""
                stationUrl = ""
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
                        message = "Removed from the Sable Media collection."
                    },
                    onPlayStation = { station ->
                        playUri(
                            uri = Uri.parse(station.url),
                            title = station.name,
                            source = "live radio",
                        )
                        destination = MediaDestination.NowPlaying
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
