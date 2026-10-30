package com.bayynat.app.audio

import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Media3 playback service. The app supplies a URI from a source it is allowed
 * to use; no copyrighted recitation or adhan recording is bundled by default.
 */
@OptIn(UnstableApi::class)
class QuranAudioService : MediaSessionService() {
    private var player: ExoPlayer? = null
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val exoPlayer = ExoPlayer.Builder(this).build()
        player = exoPlayer
        mediaSession = MediaSession.Builder(this, exoPlayer).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onDestroy() {
        mediaSession?.release()
        player?.release()
        mediaSession = null
        player = null
        super.onDestroy()
    }

    companion object {
        fun mediaItem(uri: String, title: String): MediaItem =
            MediaItem.Builder().setUri(uri).setMediaMetadata(
                androidx.media3.common.MediaMetadata.Builder().setTitle(title).build()
            ).build()
    }
}
