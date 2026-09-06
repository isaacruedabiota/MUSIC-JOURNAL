package com.musicjournal.music_journal

import android.service.notification.NotificationListenerService

/**
 * Servicio requerido para poder leer las sesiones de media de otras apps.
 *
 * No necesitamos procesar las notificaciones aqui: la sola existencia de este
 * servicio (y que el usuario conceda "Acceso a notificaciones") es lo que
 * habilita a MediaSessionManager.getActiveSessions() a devolver los
 * MediaController de Spotify, YouTube Music, etc.
 *
 * Toda la lectura de metadatos se hace en [MediaListener].
 */
class NowPlayingNotificationListenerService : NotificationListenerService()
