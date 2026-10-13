package com.isaac.musiclist

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import java.io.IOException
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.net.UnknownHostException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Pide cada canción al servidor de descargas (un POST que devuelve el archivo)
 * y la guarda en la carpeta que eligió el usuario. Usa el selector de carpetas
 * del sistema (Storage Access Framework): no hacen falta permisos de
 * almacenamiento.
 */
object Downloads {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** IPs de nombres `.local` ya resueltos por mDNS en esta sesión. */
    private val localHosts = ConcurrentHashMap<String, String>()

    /** Nombre legible de la carpeta, p. ej. `Music/MusicList`. */
    fun folderName(folder: Uri): String =
        DocumentsContract.getTreeDocumentId(folder).substringAfter(':')
            .ifEmpty { "Almacenamiento interno" }

    /**
     * Hace `POST [url]` y guarda lo que devuelve en [folder] como
     * «[baseName].ext», con la extensión que indique el servidor. Lee y escribe
     * por trozos (no carga el archivo entero en memoria). Devuelve el nombre
     * del archivo creado.
     */
    fun download(
        context: Context,
        url: String,
        folder: String,
        baseName: String,
        done: (Result<String>) -> Unit,
    ) = io.execute {
        val result = runCatching {
            val connection = post(context, url)
            try {
                val extension = contentDispositionExtension(connection.getHeaderField("Content-Disposition"))
                    ?: connection.contentType?.substringBefore(';')?.trim()
                        ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
                    ?: "mp3"
                val fileName = "$baseName.$extension"
                // El tipo sale de la extensión; así el sistema no le añade otra.
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
                    ?: "application/octet-stream"
                val resolver = context.contentResolver
                val document = DocumentsContract.createDocument(resolver, parentOf(folder), mime, fileName)
                    ?: throw IOException("No se pudo crear el archivo en la carpeta elegida")
                try {
                    val output = resolver.openOutputStream(document)
                        ?: throw IOException("No se pudo escribir en la carpeta elegida")
                    output.use { out -> connection.inputStream.use { it.copyTo(out) } }
                } catch (e: Exception) {
                    // No dejar un archivo a medias.
                    runCatching { DocumentsContract.deleteDocument(resolver, document) }
                    throw e
                }
                fileName
            } finally {
                connection.disconnect()
            }
        }
        main.post { done(result) }
    }

    // POST con cuerpo vacío y «accept» de cualquier tipo, como el curl de ejemplo.
    private fun post(context: Context, url: String): HttpURLConnection {
        val connection = (reachable(context, URL(url)).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            setFixedLengthStreamingMode(0)
            setRequestProperty("accept", "*/*")
            connectTimeout = 15_000
            // El servidor puede tardar en preparar el archivo (buscarlo, convertirlo…).
            readTimeout = 10 * 60_000
        }
        connection.outputStream.close()
        val code = connection.responseCode
        if (code !in 200..299) {
            val body = connection.errorStream?.use { it.readBytes().decodeToString() }?.trim().orEmpty()
            connection.disconnect()
            throw IOException("El servidor respondió HTTP $code" + if (body.isEmpty()) "" else ": ${body.take(500)}")
        }
        return connection
    }

    /** [url] con el nombre `.local` cambiado por su IP si el móvil no sabe resolverlo. */
    private fun reachable(context: Context, url: URL): URL {
        val host = url.host
        if (!host.endsWith(".local", ignoreCase = true)) return url
        val ip = localHosts[host] ?: try {
            InetAddress.getByName(host)
            return url // el sistema sí lo resuelve
        } catch (e: UnknownHostException) {
            Mdns.resolve(host, wifiSocket(context))?.hostAddress?.also { localHosts[host] = it }
                ?: throw IOException(
                    "No se encuentra $host en la red. ¿Está el móvil en la misma Wi-Fi que el servidor?",
                )
        }
        return URL(url.protocol, ip, url.port, url.file)
    }

    /** Socket UDP que sale por la Wi-Fi aunque también haya datos móviles. */
    private fun wifiSocket(context: Context): DatagramSocket {
        val socket = DatagramSocket()
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        @Suppress("DEPRECATION")
        connectivity.allNetworks
            .firstOrNull {
                connectivity.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            ?.bindSocket(socket)
        return socket
    }

    /** Documento de la propia carpeta elegida. */
    private fun parentOf(folder: String): Uri {
        val tree = Uri.parse(folder)
        return DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
    }
}

/**
 * Extensión del nombre de archivo que trae una cabecera Content-Disposition,
 * p. ej. `mp3` de `attachment; filename*=utf-8''Melendi%20Jardin.mp3`.
 */
fun contentDispositionExtension(header: String?): String? {
    if (header == null) return null
    val name = Regex("""filename\*\s*=\s*[^']*'[^']*'([^;]+)""", RegexOption.IGNORE_CASE).find(header)
        ?: Regex("""filename\s*=\s*"?([^";]+)"?""", RegexOption.IGNORE_CASE).find(header)
    return name?.groupValues?.get(1)?.trim()
        ?.substringAfterLast('.', "")?.lowercase()
        ?.takeIf { it.isNotEmpty() && it.length <= 5 && it.all(Char::isLetterOrDigit) }
}
