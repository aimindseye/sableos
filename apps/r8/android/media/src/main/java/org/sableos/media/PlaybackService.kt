package org.sableos.media

import android.content.Intent
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

class PlaybackService : MediaSessionService() {
    private var player: ExoPlayer? = null
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val exoPlayer =
            ExoPlayer.Builder(this).build().also { resolvedPlayer ->
                resolvedPlayer.addListener(
                    object : Player.Listener {
                        override fun onMediaItemTransition(
                            mediaItem: MediaItem?,
                            reason: Int,
                        ) {
                            MediaSnapshotStore.update(
                                this@PlaybackService,
                                resolvedPlayer,
                            )
                        }

                        override fun onIsPlayingChanged(isPlaying: Boolean) {
                            MediaSnapshotStore.update(
                                this@PlaybackService,
                                resolvedPlayer,
                            )
                        }
                    },
                )
            }

        player = exoPlayer
        session =
            MediaSession
                .Builder(this, exoPlayer)
                .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_PLAY_URI -> {
                intent.data?.let { uri ->
                    play(
                        uri = uri,
                        title = intent.getStringExtra(EXTRA_TITLE),
                        source = intent.getStringExtra(EXTRA_SOURCE),
                    )
                }
            }

            ACTION_PLAY_QUEUE -> {
                playQueue(
                    uris = intent.getStringArrayListExtra(EXTRA_URIS).orEmpty(),
                    titles = intent.getStringArrayListExtra(EXTRA_TITLES).orEmpty(),
                    artists = intent.getStringArrayListExtra(EXTRA_ARTISTS).orEmpty(),
                    startIndex = intent.getIntExtra(EXTRA_START_INDEX, 0),
                )
            }

            ACTION_PAUSE -> {
                player?.pause()
            }

            ACTION_RESUME -> {
                player?.play()
            }

            ACTION_STOP -> {
                player?.stop()
                MediaSnapshotStore.clear(this)
            }

            ACTION_PREVIOUS -> {
                player?.seekToPreviousMediaItem()
            }

            ACTION_NEXT -> {
                player?.seekToNextMediaItem()
            }
        }

        return super.onStartCommand(intent, flags, startId)
    }

    private fun play(
        uri: Uri,
        title: String?,
        source: String?,
    ) {
        val metadata =
            MediaMetadata
                .Builder()
                .setTitle(title?.takeIf { it.isNotBlank() } ?: "Sable Media")
                .setArtist(source?.takeIf { it.isNotBlank() })
                .build()

        val mediaItem =
            MediaItem
                .Builder()
                .setUri(uri)
                .setMediaMetadata(metadata)
                .build()

        player?.apply {
            setMediaItem(mediaItem)
            prepare()
            play()
        }
    }

    private fun playQueue(
        uris: List<String>,
        titles: List<String>,
        artists: List<String>,
        startIndex: Int,
    ) {
        if (uris.isEmpty()) {
            return
        }

        val items =
            uris.mapIndexed { index, value ->
                mediaItem(
                    uri = value,
                    title = titles.getOrNull(index),
                    artist = artists.getOrNull(index),
                )
            }

        player?.apply {
            setMediaItems(
                items,
                startIndex.coerceIn(0, items.lastIndex),
                0L,
            )
            prepare()
            play()
        }
    }

    private fun mediaItem(
        uri: String,
        title: String?,
        artist: String?,
    ): MediaItem {
        val metadata =
            MediaMetadata
                .Builder()
                .setTitle(title?.takeIf { it.isNotBlank() } ?: "Local audio")
                .setArtist(artist?.takeIf { it.isNotBlank() } ?: "Unknown artist")
                .build()

        return MediaItem
            .Builder()
            .setUri(Uri.parse(uri))
            .setMediaMetadata(metadata)
            .build()
    }

    override fun onDestroy() {
        session?.release()
        session = null
        player?.release()
        player = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_PLAY_URI = "org.sableos.media.PLAY_URI"
        const val ACTION_PAUSE = "org.sableos.media.PAUSE"
        const val ACTION_RESUME = "org.sableos.media.RESUME"
        const val ACTION_STOP = "org.sableos.media.STOP"
        const val ACTION_PREVIOUS = "org.sableos.media.PREVIOUS"
        const val ACTION_NEXT = "org.sableos.media.NEXT"
        const val ACTION_PLAY_QUEUE = "org.sableos.media.PLAY_QUEUE"

        const val EXTRA_TITLE = "org.sableos.media.TITLE"
        const val EXTRA_SOURCE = "org.sableos.media.SOURCE"
        const val EXTRA_URIS = "org.sableos.media.URIS"
        const val EXTRA_TITLES = "org.sableos.media.TITLES"
        const val EXTRA_ARTISTS = "org.sableos.media.ARTISTS"
        const val EXTRA_START_INDEX = "org.sableos.media.START_INDEX"
    }
}
