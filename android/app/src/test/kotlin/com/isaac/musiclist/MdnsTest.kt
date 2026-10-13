package com.isaac.musiclist

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MdnsTest {
    private fun hex(text: String) = text.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    // Capturados de la Raspberry real (pi-isaac.local → 192.168.1.31).
    private val query = "1234000000010000000000000870692d6973616163056c6f63616c0000010001"
    private val response = "1234840000010001000000000870692d6973616163056c6f63616c0000010001" +
        "c00c000100010000000a0004c0a8011f"

    @Test
    fun `la consulta es la misma que entiende la Raspberry`() {
        assertArrayEquals(hex(query), Mdns.query("pi-isaac.local", 0x1234))
    }

    @Test
    fun `lee la IP de la respuesta`() {
        assertArrayEquals(
            byteArrayOf(192.toByte(), 168.toByte(), 1, 31),
            Mdns.parseA(hex(response), 0x1234),
        )
    }

    @Test
    fun `ignora respuestas a otra consulta, consultas y paquetes cortados`() {
        assertNull(Mdns.parseA(hex(response), 0x9999))
        assertNull(Mdns.parseA(hex(query), 0x1234))
        assertNull(Mdns.parseA(hex(response).copyOf(40), 0x1234))
    }
}
