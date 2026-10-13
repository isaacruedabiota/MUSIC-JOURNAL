package com.isaac.musiclist

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/** Canción guardada. [toMap] es lo que recibe Flutter. */
data class Track(
    val id: String,
    val title: String,
    val artist: String,
    val coverPath: String?,
    val detectedAt: Long,
    /** Marca interna que la app no muestra; vale `false` al detectar la canción. */
    val descargado: Boolean = false,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "title" to title,
        "artist" to artist,
        "coverPath" to coverPath,
        "detectedAt" to detectedAt,
        "descargado" to descargado,
    )
}

/**
 * Historial en SQLite (el que trae Android, sin dependencias) y portadas en
 * JPEG. Todo el acceso a disco va en orden por un único hilo de fondo: sin
 * carreras y sin bloquear el hilo principal.
 */
class TrackStore private constructor(context: Context) :
    SQLiteOpenHelper(context, "tracks.db", null, 2) {

    private val coversDir = File(context.filesDir, "covers")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Solo se usa desde el hilo principal. */
    private val listeners = mutableSetOf<(Track) -> Unit>()

    // Última canción recibida y si ya no queda nada que hacer con ella
    // (guardada con portada, o borrada por el usuario mientras sonaba).
    // Solo se usan desde el hilo de disco.
    private var current: String? = null
    private var currentDone = false

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE tracks (id TEXT PRIMARY KEY, title TEXT NOT NULL, " +
                "artist TEXT NOT NULL, cover_path TEXT, detected_at INTEGER NOT NULL, " +
                "descargado INTEGER NOT NULL DEFAULT 0)"
        )
        db.execSQL("CREATE INDEX tracks_by_date ON tracks(detected_at)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // v2 añade `descargado`; las canciones ya guardadas empiezan en false.
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE tracks ADD COLUMN descargado INTEGER NOT NULL DEFAULT 0")
        }
    }

    /**
     * Guarda la canción si su ID no existe ya (clave primaria: nunca hay
     * duplicados). Si existía sin portada y ahora llega, se la añade.
     */
    fun saveIfAbsent(id: String, title: String, artist: String, cover: Bitmap?) = io.execute {
        // Spotify avisa varias veces por canción (play, seek, portada…): si con
        // esta ya no queda nada que hacer, ni se consulta la base de datos.
        if (id == current && currentDone) return@execute
        current = id
        val existing = find(id)
        val track = when {
            existing == null ->
                Track(id, title, artist, cover?.let { writeCover(id, it) }, System.currentTimeMillis())
                    .also { writableDatabase.insert("tracks", null, it.toValues()) }
            existing.coverPath == null && cover != null ->
                writeCover(id, cover)?.let { path ->
                    existing.copy(coverPath = path).also {
                        writableDatabase.update("tracks", it.toValues(), "id = ?", arrayOf(id))
                    }
                } ?: existing
            else -> existing
        }
        currentDone = track.coverPath != null
        if (track !== existing) publish(track)
    }

    /** Borra la canción y su portada del móvil. */
    fun delete(id: String, done: () -> Unit) = io.execute {
        find(id)?.coverPath?.let { File(it).delete() }
        writableDatabase.delete("tracks", "id = ?", arrayOf(id))
        // Si es la que está sonando, no se vuelve a añadir con los siguientes
        // avisos de Spotify; sí cuando se escuche de nuevo más adelante.
        if (id == current) currentDone = true
        main.post { done() }
    }

    /** Cambia la marca `descargado` de una canción (la app no la muestra). */
    fun setDescargado(id: String, value: Boolean, done: () -> Unit) = io.execute {
        val values = ContentValues().apply { put("descargado", value) }
        writableDatabase.update("tracks", values, "id = ?", arrayOf(id))
        find(id)?.let(::publish)
        main.post { done() }
    }

    /** Todas las canciones, de la más reciente a la más antigua. */
    fun all(callback: (List<Track>) -> Unit) = io.execute {
        val tracks = writableDatabase
            .rawQuery("SELECT $COLUMNS FROM tracks ORDER BY detected_at DESC", null)
            .use { cursor -> buildList { while (cursor.moveToNext()) add(cursor.toTrack()) } }
        main.post { callback(tracks) }
    }

    fun addListener(listener: (Track) -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: (Track) -> Unit) {
        listeners -= listener
    }

    /** Avisa a Flutter de una canción nueva o modificada. */
    private fun publish(track: Track) {
        main.post { listeners.forEach { it(track) } }
    }

    private fun find(id: String): Track? = writableDatabase
        .rawQuery("SELECT $COLUMNS FROM tracks WHERE id = ?", arrayOf(id))
        .use { if (it.moveToFirst()) it.toTrack() else null }

    /** Guarda la portada reducida a [COVER_SIZE] px en JPEG (unos 10 KB). */
    private fun writeCover(id: String, bitmap: Bitmap): String? = try {
        // Un bitmap HARDWARE no se puede escalar en CPU: se copia antes.
        val source = if (Build.VERSION.SDK_INT >= 26 && bitmap.config == Bitmap.Config.HARDWARE) {
            bitmap.copy(Bitmap.Config.ARGB_8888, false)
        } else {
            bitmap
        }
        val scale = COVER_SIZE.toFloat() / maxOf(source.width, source.height)
        val small = if (scale < 1f) {
            Bitmap.createScaledBitmap(
                source,
                (source.width * scale).roundToInt(),
                (source.height * scale).roundToInt(),
                true,
            )
        } else {
            source
        }
        coversDir.mkdirs()
        val file = File(coversDir, sha1(id) + ".jpg")
        file.outputStream().use { small.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        file.path
    } catch (e: Exception) {
        Log.w(TAG, "No se pudo guardar la portada de $id", e)
        null
    }

    private fun Cursor.toTrack() =
        Track(getString(0), getString(1), getString(2), getString(3), getLong(4), getInt(5) != 0)

    private fun Track.toValues() = ContentValues().apply {
        put("id", id)
        put("title", title)
        put("artist", artist)
        put("cover_path", coverPath)
        put("detected_at", detectedAt)
        put("descargado", descargado)
    }

    companion object {
        private const val TAG = "MusicList"
        private const val COLUMNS = "id, title, artist, cover_path, detected_at, descargado"
        private const val COVER_SIZE = 256

        @Volatile
        private var instance: TrackStore? = null

        fun get(context: Context): TrackStore = instance ?: synchronized(this) {
            instance ?: TrackStore(context.applicationContext).also { instance = it }
        }

        private fun sha1(text: String): String = MessageDigest.getInstance("SHA-1")
            .digest(text.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }
}
