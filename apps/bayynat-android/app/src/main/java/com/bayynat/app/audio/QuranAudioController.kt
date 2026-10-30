package com.bayynat.app.audio

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.MediaMetadata
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import java.util.concurrent.Executor

@OptIn(UnstableApi::class)
class QuranAudioController(context: Context) {
    private val appContext = context.applicationContext
    private val executor = Executor { command -> command.run() }
    private val future = MediaController.Builder(
        appContext,
        SessionToken(appContext, ComponentName(appContext, QuranAudioService::class.java))
    ).buildAsync()

    fun play(uri: Uri, title: String) {
        future.addListener({
            runCatching {
                val controller = future.get()
                val item = MediaItem.Builder()
                    .setUri(uri)
                    .setMediaMetadata(MediaMetadata.Builder().setTitle(title).build())
                    .build()
                controller.setMediaItem(item)
                controller.prepare()
                controller.play()
            }
        }, executor)
    }

    fun playPlaylist(uris: List<String>, title: String) {
        if (uris.isEmpty()) return
        future.addListener({
            runCatching {
                val controller = future.get()
                val items = uris.mapIndexed { index, uri ->
                    MediaItem.Builder()
                        .setUri(uri)
                        .setMediaMetadata(MediaMetadata.Builder().setTitle("$title • ${index + 1}").build())
                        .build()
                }
                controller.setMediaItems(items)
                controller.prepare()
                controller.play()
            }
        }, executor)
    }

    fun pause() {
        future.addListener({ runCatching { future.get().pause() } }, executor)
    }

    fun resume() {
        future.addListener({ runCatching { future.get().play() } }, executor)
    }

    fun stop() {
        future.addListener({ runCatching { future.get().stop() } }, executor)
    }

    fun release() {
        MediaController.releaseFuture(future)
    }
}
