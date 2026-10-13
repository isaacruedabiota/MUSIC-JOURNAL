package com.isaac.musiclist

/**
 * Reglas de negocio: qué de lo que suena en Spotify se guarda y con qué ID.
 * Kotlin puro, sin clases de Android, para poder probarlo con JUnit.
 */
object SpotifyRules {
    private const val TRACK_URI = "spotify:track:"

    /**
     * ID con el que guardar lo que suena, o `null` si hay que ignorarlo.
     *
     * Spotify publica en su sesión multimedia el URI de lo que reproduce:
     * `spotify:track:<id>` en canciones, `spotify:episode:…` en podcasts,
     * `spotify:ad:…` en anuncios y `spotify:local:…` en archivos locales.
     */
    fun trackId(mediaId: String?, title: String, artist: String, isAd: Boolean): String? = when {
        isAd -> null
        mediaId != null && mediaId.startsWith(TRACK_URI) -> mediaId.removePrefix(TRACK_URI)
        // Podcasts, anuncios, archivos locales o cualquier otro tipo: fuera.
        mediaId != null && mediaId.startsWith("spotify:") -> null
        // Sin URI de Spotify: se identifica por título + artista para poder
        // deduplicar igualmente (en este caso ya no se distinguen los podcasts).
        else -> "meta:" + "$title|$artist".lowercase()
    }
}
