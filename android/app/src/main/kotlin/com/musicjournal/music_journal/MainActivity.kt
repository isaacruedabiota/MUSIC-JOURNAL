package com.musicjournal.music_journal

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "music_journal/media"
    private val eventChannelName = "music_journal/media_events"

    private var mediaListener: MediaListener? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val listener = MediaListener(applicationContext)
        mediaListener = listener

        // --- MethodChannel: permisos y lectura puntual ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isNotificationAccessGranted())
                    "openPermissionSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        )
                        result.success(null)
                    }
                    "getNowPlaying" -> result.success(listener.currentNowPlaying())
                    "start" -> {
                        listener.start()
                        result.success(null)
                    }
                    "stop" -> {
                        listener.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // --- EventChannel: stream de cambios de "que suena ahora" ---
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // Los callbacks de media llegan en hilos de fondo:
                    // saltamos al hilo principal antes de tocar el sink.
                    listener.onChanged = { data ->
                        mainHandler.post { eventSink?.success(data) }
                    }
                    listener.start()
                }

                override fun onCancel(arguments: Any?) {
                    listener.onChanged = null
                    listener.stop()
                    eventSink = null
                }
            })
    }

    /** ¿El usuario concedio "Acceso a notificaciones" a nuestra app? */
    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return enabled.split(":").any { it.contains(packageName) }
    }

    override fun onDestroy() {
        mediaListener?.stop()
        super.onDestroy()
    }
}
