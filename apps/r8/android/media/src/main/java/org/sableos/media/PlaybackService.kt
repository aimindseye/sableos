package org.sableos.media

import android.content.Intent
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

class PlaybackService : MediaSessionService() {
    private var player: ExoPlayer? = null
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val exoPlayer = ExoPlayer.Builder(this).build()
        player = exoPlayer
        session = MediaSession.Builder(this, exoPlayer).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY_URI -> intent.data?.let(::play)
            ACTION_PAUSE -> player?.pause()
            ACTION_RESUME -> player?.play()
            ACTION_STOP -> player?.stop()
        }
        return super.onStartCommand(intent, flags, startId)
    }

    private fun play(uri: android.net.Uri) {
        player?.apply {
            setMediaItem(MediaItem.fromUri(uri))
            prepare()
            play()
        }
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
    }
}
