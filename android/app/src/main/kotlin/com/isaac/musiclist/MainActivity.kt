package com.isaac.musiclist

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Expone a Flutter el historial, las canciones nuevas en directo, los permisos
 * y las descargas a la carpeta elegida.
 */
class MainActivity : FlutterActivity() {
    private var events: EventChannel.EventSink? = null
    private val onTrack: (Track) -> Unit = { events?.success(it.toMap()) }

    /** Respuesta pendiente mientras el usuario elige carpeta. */
    private var pendingFolder: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val store = TrackStore.get(this)

        MethodChannel(messenger, "musiclist/tracks").setMethodCallHandler { call, result ->
            when (call.method) {
                "getAll" -> store.all { tracks -> result.success(tracks.map(Track::toMap)) }
                "delete" -> store.delete(call.arguments as String) { result.success(null) }
                "setDescargado" -> store.setDescargado(
                    call.argument<String>("id")!!,
                    call.argument<Boolean>("value")!!,
                ) { result.success(null) }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "musiclist/track_updates").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                    store.addListener(onTrack)
                }

                override fun onCancel(arguments: Any?) {
                    store.removeListener(onTrack)
                    events = null
                }
            },
        )

        MethodChannel(messenger, "musiclist/permissions").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationAccess" -> result.success(SpotifyListenerService.isEnabled(this))
                "openNotificationAccess" -> {
                    SpotifyListenerService.openSettings(this)
                    result.success(null)
                }
                "isBatteryUnrestricted" -> result.success(
                    getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName),
                )
                "requestBatteryUnrestricted" -> {
                    requestBatteryUnrestricted()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "musiclist/downloads").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFolder" -> {
                    pendingFolder?.success(null)
                    pendingFolder = result
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_FOLDER)
                }
                "download" -> Downloads.download(
                    this,
                    call.argument<String>("url")!!,
                    call.argument<String>("folder")!!,
                    call.argument<String>("baseName")!!,
                ) { outcome ->
                    outcome.fold(
                        { result.success(it) },
                        { result.error("DOWNLOAD", it.message ?: it.toString(), null) },
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Vuelta del selector de carpetas del sistema. */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_FOLDER) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingFolder ?: return
        pendingFolder = null
        val folder = data?.data
        if (resultCode != RESULT_OK || folder == null) {
            result.success(null) // el usuario canceló
            return
        }
        // Conserva el permiso de escritura aunque se reinicie el móvil.
        contentResolver.takePersistableUriPermission(
            folder,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        result.success(mapOf("uri" to folder.toString(), "name" to Downloads.folderName(folder)))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Si el motor muere sin cancelar la suscripción, no queda el oyente colgado.
        TrackStore.get(this).removeListener(onTrack)
        events = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Diálogo del sistema: «¿Permitir que la app se ejecute siempre en segundo plano?». */
    private fun requestBatteryUnrestricted() {
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
            )
        } catch (e: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    private companion object {
        const val PICK_FOLDER = 4201
    }
}
