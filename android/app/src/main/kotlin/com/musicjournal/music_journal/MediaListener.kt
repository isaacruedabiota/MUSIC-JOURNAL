package com.musicjournal.music_journal

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState

/**
 * Lee "que suena ahora" en CUALQUIER app de musica del sistema usando
 * MediaSessionManager. Requiere que el usuario haya concedido "Acceso a
 * notificaciones" a [NowPlayingNotificationListenerService].
 *
 * Notifica cambios via [onChanged] con un mapa listo para pasar a Flutter
 * (o null cuando no hay nada reproduciendose).
 */
class MediaListener(private val context: Context) {

    private val sessionManager =
        context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager

    private val componentName =
        ComponentName(context, NowPlayingNotificationListenerService::class.java)

    /** Callback hacia Flutter. El caller se encarga de saltar al hilo principal. */
    var onChanged: ((Map<String, Any?>?) -> Unit)? = null

    private val callbacks = mutableMapOf<MediaController, MediaController.Callback>()
    private var active: MediaController? = null
    private var started = false

    private val sessionsChangedListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            rebind(controllers ?: emptyList())
        }

    /** Empieza a escuchar. Seguro de llamar varias veces. */
    fun start() {
        if (started) return
        try {
            sessionManager.addOnActiveSessionsChangedListener(
                sessionsChangedListener, componentName
            )
            rebind(sessionManager.getActiveSessions(componentName))
            started = true
        } catch (e: SecurityException) {
            // El permiso de acceso a notificaciones no esta concedido todavia.
            onChanged?.invoke(null)
        }
    }

    fun stop() {
        if (!started) return
        try {
            sessionManager.removeOnActiveSessionsChangedListener(sessionsChangedListener)
        } catch (_: Exception) {
        }
        callbacks.forEach { (c, cb) -> c.unregisterCallback(cb) }
        callbacks.clear()
        active = null
        started = false
    }

    /** Lectura puntual del estado actual (para getNowPlaying del MethodChannel). */
    fun currentNowPlaying(): Map<String, Any?>? {
        return try {
            val controllers = sessionManager.getActiveSessions(componentName)
            val controller = pickActive(controllers)
            controller?.let { readMetadata(it) }
        } catch (e: SecurityException) {
            null
        }
    }

    private fun rebind(controllers: List<MediaController>) {
        // Quitamos callbacks viejos.
        callbacks.forEach { (c, cb) -> c.unregisterCallback(cb) }
        callbacks.clear()

        // Registramos callback en cada controller para enterarnos de cambios.
        controllers.forEach { controller ->
            val cb = object : MediaController.Callback() {
                override fun onMetadataChanged(metadata: MediaMetadata?) {
                    emitFrom(controllers)
                }

                override fun onPlaybackStateChanged(state: PlaybackState?) {
                    emitFrom(controllers)
                }

                override fun onSessionDestroyed() {
                    emitFrom(controllers)
                }
            }
            controller.registerCallback(cb)
            callbacks[controller] = cb
        }

        emitFrom(controllers)
    }

    private fun emitFrom(controllers: List<MediaController>) {
        active = pickActive(controllers)
        onChanged?.invoke(active?.let { readMetadata(it) })
    }

    /** Preferimos la sesion que esta REPRODUCIENDO; si no, la primera. */
    private fun pickActive(controllers: List<MediaController>): MediaController? {
        return controllers.firstOrNull {
            it.playbackState?.state == PlaybackState.STATE_PLAYING
        } ?: controllers.firstOrNull()
    }

    private fun readMetadata(controller: MediaController): Map<String, Any?>? {
        val md = controller.metadata ?: return null
        val title = md.getString(MediaMetadata.METADATA_KEY_TITLE)
        if (title.isNullOrBlank()) return null

        val artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
        val album = md.getString(MediaMetadata.METADATA_KEY_ALBUM)
        val duration = md.getLong(MediaMetadata.METADATA_KEY_DURATION)
        val isPlaying = controller.playbackState?.state == PlaybackState.STATE_PLAYING

        return mapOf(
            "title" to title,
            "artist" to (artist ?: ""),
            "album" to (album ?: ""),
            "durationMs" to duration,
            "isPlaying" to isPlaying,
            "packageName" to controller.packageName
        )
    }
}
