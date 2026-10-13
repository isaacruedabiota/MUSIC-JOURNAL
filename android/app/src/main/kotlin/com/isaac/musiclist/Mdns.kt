package com.isaac.musiclist

import java.io.ByteArrayOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException

/**
 * Resuelve nombres `.local` (p. ej. `pi-isaac.local`) con una consulta mDNS de
 * un solo uso (RFC 6762 §5.1). Hace falta porque algunos móviles, como el
 * Realme, no los resuelven aunque estén en la misma Wi-Fi.
 *
 * La consulta sale de un puerto cualquiera, así que el equipo responde
 * directamente al móvil (sin multicast de vuelta, sin permisos extra).
 */
object Mdns {
    private val group = InetAddress.getByAddress(byteArrayOf(224.toByte(), 0, 0, 251.toByte()))
    private const val PORT = 5353
    private const val TYPE_A = 1

    /**
     * IPv4 de [host] en la red local, o `null` si nadie contesta. Repite la
     * consulta cada segundo hasta [tries] veces: el primer paquete multicast
     * a veces se pierde (p. ej. con la Wi-Fi en ahorro de energía).
     */
    fun resolve(host: String, socket: DatagramSocket = DatagramSocket(), tries: Int = 3): InetAddress? =
        socket.use {
            val id = (System.nanoTime() and 0xFFFF).toInt()
            val query = query(host, id)
            val buffer = ByteArray(1500)
            repeat(tries) { _ ->
                it.send(DatagramPacket(query, query.size, group, PORT))
                val deadline = System.currentTimeMillis() + 1_000
                while (true) {
                    val left = deadline - System.currentTimeMillis()
                    if (left <= 0) break
                    it.soTimeout = left.toInt()
                    val packet = DatagramPacket(buffer, buffer.size)
                    try {
                        it.receive(packet)
                    } catch (e: SocketTimeoutException) {
                        break
                    }
                    parseA(buffer.copyOf(packet.length), id)?.let { ip ->
                        return InetAddress.getByAddress(host, ip)
                    }
                }
            }
            null
        }

    /** Paquete DNS que pregunta por la dirección IPv4 (registro A) de [host]. */
    fun query(host: String, id: Int): ByteArray = ByteArrayOutputStream().apply {
        writeShort(id)
        writeShort(0) // consulta estándar
        writeShort(1) // una pregunta
        repeat(3) { writeShort(0) }
        for (label in host.trimEnd('.').split('.')) {
            val bytes = label.toByteArray()
            write(bytes.size)
            write(bytes)
        }
        write(0)
        writeShort(TYPE_A)
        writeShort(1) // clase IN
    }.toByteArray()

    /**
     * Primera dirección IPv4 de la respuesta [packet] a la consulta [id], o
     * `null` si no es una respuesta a ella o no trae ninguna.
     */
    fun parseA(packet: ByteArray, id: Int): ByteArray? {
        if (packet.size < 12) return null
        fun u16(at: Int) = ((packet[at].toInt() and 0xFF) shl 8) or (packet[at + 1].toInt() and 0xFF)
        val isResponse = u16(2) and 0x8000 != 0
        if (u16(0) != id || !isResponse) return null

        var at = 12
        repeat(u16(4)) { at = skipName(packet, at) + 4 } // preguntas
        val records = u16(6) + u16(8) + u16(10)
        repeat(records) {
            at = skipName(packet, at)
            if (at + 10 > packet.size) return null
            val type = u16(at)
            val length = u16(at + 8)
            at += 10
            if (at + length > packet.size) return null
            if (type == TYPE_A && length == 4) return packet.copyOfRange(at, at + 4)
            at += length
        }
        return null
    }

    /** Posición justo después de un nombre DNS (etiquetas o puntero comprimido). */
    private fun skipName(packet: ByteArray, start: Int): Int {
        var at = start
        while (at < packet.size) {
            val length = packet[at].toInt() and 0xFF
            when {
                length == 0 -> return at + 1
                length and 0xC0 == 0xC0 -> return at + 2
                else -> at += length + 1
            }
        }
        return at
    }

    private fun ByteArrayOutputStream.writeShort(value: Int) {
        write(value shr 8 and 0xFF)
        write(value and 0xFF)
    }
}
