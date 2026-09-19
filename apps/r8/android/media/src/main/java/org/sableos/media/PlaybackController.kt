package org.sableos.media

import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken

internal data class PlaybackUiState(
    val connected: Boolean = false,
    val title: String = "Nothing queued",
    val source: String = "Local music or radio",
    val isPlaying: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val hasPrevious: Boolean = false,
    val hasNext: Boolean = false,
)

internal class PlaybackController(
    context: Context,
    private val onStateChanged: (PlaybackUiState) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var controller: MediaController? = null
    private var closed = false

    private val listener =
        object : Player.Listener {
            override fun onEvents(
                player: Player,
                events: Player.Events,
            ) {
                publishState()
            }
        }

    private val ticker =
        object : Runnable {
            override fun run() {
                if (closed) return
                publishState()
                handler.postDelayed(this, 500L)
            }
        }

    init {
        val token =
            SessionToken(
                context,
                ComponentName(
                    context,
                    PlaybackService::class.java,
                ),
            )

        val future =
            MediaController.Builder(
                context,
                token,
            ).buildAsync()

        future.addListener(
            {
                runCatching { future.get() }
                    .onSuccess { resolved ->
                        handler.post {
                            if (closed) {
                                resolved.release()
                            } else {
                                controller = resolved
                                resolved.addListener(listener)
                                publishState()
                                handler.post(ticker)
                            }
                        }
                    }
            },
            { command -> command.run() },
        )
    }

    fun play() {
        controller?.play()
    }

    fun pause() {
        controller?.pause()
    }

    fun stop() {
        controller?.stop()
    }

    fun seekTo(positionMs: Long) {
        controller?.seekTo(positionMs.coerceAtLeast(0L))
    }

    fun previous() {
        controller?.seekToPreviousMediaItem()
    }

    fun next() {
        controller?.seekToNextMediaItem()
    }

    fun close() {
        closed = true
        handler.removeCallbacksAndMessages(null)
        controller?.removeListener(listener)
        controller?.release()
        controller = null
    }

    private fun publishState() {
        val player = controller

        if (player == null) {
            onStateChanged(PlaybackUiState())
            return
        }

        val duration =
            player.duration
                .takeIf { it != C.TIME_UNSET && it > 0L }
                ?: 0L

        val metadata = player.mediaMetadata
        val title =
            metadata.title
                ?.toString()
                ?.takeIf { it.isNotBlank() }
                ?: "Nothing queued"
        val source =
            metadata.artist
                ?.toString()
                ?.takeIf { it.isNotBlank() }
                ?: "Local music or radio"

        onStateChanged(
            PlaybackUiState(
                connected = true,
                title = title,
                source = source,
                isPlaying = player.isPlaying,
                positionMs = player.currentPosition.coerceAtLeast(0L),
                durationMs = duration,
                hasPrevious = player.hasPreviousMediaItem(),
                hasNext = player.hasNextMediaItem(),
            ),
        )
    }
}
