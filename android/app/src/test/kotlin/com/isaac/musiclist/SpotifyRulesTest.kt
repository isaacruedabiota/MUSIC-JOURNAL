package com.isaac.musiclist

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class SpotifyRulesTest {
    private fun id(mediaId: String?, title: String = "Título", artist: String = "Artista", isAd: Boolean = false) =
        SpotifyRules.trackId(mediaId, title, artist, isAd)

    @Test
    fun `una cancion se guarda con su track ID de Spotify`() {
        assertEquals("4uLU6hMCjMI75M1A2tKUQC", id("spotify:track:4uLU6hMCjMI75M1A2tKUQC"))
    }

    @Test
    fun `los episodios de podcast se ignoran`() {
        assertNull(id("spotify:episode:512ojhOuo1ktJprKbVcKyQ"))
    }

    @Test
    fun `los anuncios se ignoran por URI o por la marca de anuncio`() {
        assertNull(id("spotify:ad:0abc123"))
        assertNull(id("spotify:track:4uLU6hMCjMI75M1A2tKUQC", isAd = true))
    }

    @Test
    fun `los archivos locales se ignoran`() {
        assertNull(id("spotify:local:Artista:Album:Titulo:215"))
    }

    @Test
    fun `sin URI de Spotify se deduplica por titulo y artista sin distinguir mayusculas`() {
        val key = id(null, title = "Canción", artist = "Artista")
        assertNotNull(key)
        assertEquals(key, id(null, title = "CANCIÓN", artist = "artista"))
        assertEquals(key, id("otro-formato", title = "canción", artist = "ARTISTA"))
    }
}
