package com.isaac.musiclist

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Escucha la sesión multimedia de Spotify (los mismos datos que enseña su
 * notificación) y guarda cada canción nueva que empieza a sonar.
 *
 * Android mantiene este servicio vinculado mientras tenga «Acceso a
 * notificaciones», así que funciona con la app cerrada y la pantalla apagada.
 * No sondea nada: solo despierta cuando Spotify cambia de canción o de estado.
 */
class SpotifyListenerService : NotificationListenerService() {

    private val handler = Handler(Looper.getMainLooper())
    private val component by lazy { ComponentName(this, SpotifyListenerService::class.java) }
    private val sessions by lazy { getSystemService(MediaSessionManager::class.java) }
    private var spotify: MediaController? = null

    private val sessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { watch(it) }

    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = record()
        override fun onPlaybackStateChanged(state: PlaybackState?) = record()
        override fun onSessionDestroyed() = watch(null)
    }

    override fun onListenerConnected() {
        sessions.addOnActiveSessionsChangedListener(sessionsListener, component, handler)
        watchActiveSessions()
        // Recién vinculado, la sesión de Spotify puede tardar un poco en aparecer.
        handler.postDelayed(::watchActiveSessions, 3_000)
    }

    override fun onListenerDisconnected() {
        handler.removeCallbacksAndMessages(null)
        sessions.removeOnActiveSessionsChangedListener(sessionsListener)
        watch(null)
        // Pide al sistema que vuelva a vincularlo (no hace nada si el
        // usuario ha retirado el permiso).
        try {
            requestRebind(component)
        } catch (e: RuntimeException) {
            Log.w(TAG, "No se pudo pedir la revinculación", e)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Red de seguridad: si Spotify publica su notificación y aún no
        // vigilamos su sesión, se busca otra vez.
        if (spotify == null && sbn.packageName == SPOTIFY) watchActiveSessions()
    }

    private fun watchActiveSessions() {
        try {
            watch(sessions.getActiveSessions(component))
        } catch (e: SecurityException) {
            // Se ha retirado el acceso a notificaciones.
        }
    }

    /** Se engancha a la sesión de Spotify de [controllers], o se suelta si no está. */
    private fun watch(controllers: List<MediaController>?) {
        val next = controllers?.firstOrNull { it.packageName == SPOTIFY }
        if (next?.sessionToken == spotify?.sessionToken) return
        spotify?.unregisterCallback(callback)
        spotify = next
        next?.registerCallback(callback, handler)
        record()
    }

    /** Aplica las reglas de negocio a lo que suena y lo guarda si procede. */
    private fun record() {
        val controller = spotify ?: return
        // En pausa (o cargando, parado…): no se procesa nada.
        if (controller.playbackState?.state != PlaybackState.STATE_PLAYING) return
        val metadata = controller.metadata ?: return
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?.takeIf { it.isNotBlank() } ?: return
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST).orEmpty()
        val mediaId = metadata.getString(MediaMetadata.METADATA_KEY_MEDIA_ID)
        val isAd = metadata.getLong(METADATA_KEY_ADVERTISEMENT) == 1L
        Log.d(TAG, "Spotify reproduce: $mediaId · $title · $artist")

        val id = SpotifyRules.trackId(mediaId, title, artist, isAd) ?: return
        val cover = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
        TrackStore.get(this).saveIfAbsent(id, title, artist, cover)
    }

    companion object {
        private const val TAG = "MusicList"
        private const val SPOTIFY = "com.spotify.music"
        private const val METADATA_KEY_ADVERTISEMENT = "android.media.metadata.ADVERTISEMENT"

        /** ¿Ha concedido el usuario «Acceso a notificaciones» a este servicio? */
        fun isEnabled(context: Context): Boolean {
            val component = ComponentName(context, SpotifyListenerService::class.java)
            return if (Build.VERSION.SDK_INT >= 27) {
                context.getSystemService(NotificationManager::class.java)
                    .isNotificationListenerAccessGranted(component)
            } else {
                Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                    ?.contains(component.flattenToString()) == true
            }
        }

        /** Abre el ajuste de acceso a notificaciones, si se puede directamente en esta app. */
        fun openSettings(context: Context) {
            val list = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            val intent = if (Build.VERSION.SDK_INT >= 30) {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    ComponentName(context, SpotifyListenerService::class.java).flattenToString(),
                )
            } else {
                list
            }
            try {
                context.startActivity(intent)
            } catch (e: ActivityNotFoundException) {
                context.startActivity(list)
            }
        }
    }
}
