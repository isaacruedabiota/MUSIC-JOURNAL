package com.isaac.musiclist

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ContentDispositionTest {
    @Test
    fun `saca la extension del nombre que manda el servidor`() {
        // Cabecera real de pi-isaac.local:8010.
        assertEquals(
            "mp3",
            contentDispositionExtension("attachment; filename*=utf-8''Melendi%20%20Jardin%20con%20enanitos.mp3"),
        )
        assertEquals("m4a", contentDispositionExtension("attachment; filename=\"Cancion.M4A\""))
    }

    @Test
    fun `sin nombre o sin extension no hay extension`() {
        assertNull(contentDispositionExtension(null))
        assertNull(contentDispositionExtension("attachment"))
        assertNull(contentDispositionExtension("attachment; filename=\"sin_extension\""))
    }
}
