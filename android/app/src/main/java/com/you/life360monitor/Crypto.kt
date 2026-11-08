package com.you.life360monitor

import android.util.Base64
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object Crypto {
    private val master: ByteArray =
        MessageDigest.getInstance("SHA-256").digest(BuildConfig.TOKEN.toByteArray())
    private val rng = SecureRandom()
    private val window = 1_000_000_000L

    @Volatile private var upCount = 0L
    private val downSeen = LongArray(4)

    private fun derive(dir: Byte, n: Long): ByteArray {
        val salt = ByteBuffer.allocate(9).put(dir).putLong(n).array()
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(master, "HmacSHA256"))
        val prk = mac.doFinal(salt)
        mac.init(SecretKeySpec(prk, "HmacSHA256"))
        return mac.doFinal("l360.v2".toByteArray()).copyOf(32)
    }

    @Synchronized
    fun seal(plain: String, dir: Byte = 0): String? {
        return try {
            upCount += 1
            val iv = ByteArray(12).also { rng.nextBytes(it) }
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(derive(dir, upCount), "AES"), GCMParameterSpec(128, iv))
            val ct = c.doFinal(plain.toByteArray())
            Base64.encodeToString(ByteBuffer.allocate(9).put(dir).putLong(upCount).array() + iv + ct, Base64.NO_WRAP)
        } catch (e: Exception) { null }
    }

    @Synchronized
    fun open(b64: String): String? {
        return try {
            val raw = Base64.decode(b64, Base64.NO_WRAP)
            val dir = raw[0]
            if (dir > 3) return null
            val n = ByteBuffer.wrap(raw, 1, 8).long
            val seen = downSeen[dir.toInt()]
            if (n > seen || seen - n > window) {
                downSeen[dir.toInt()] = n
                val c = Cipher.getInstance("AES/GCM/NoPadding")
                c.init(Cipher.DECRYPT_MODE, SecretKeySpec(derive(dir, n), "AES"),
                       GCMParameterSpec(128, raw.copyOfRange(9, 21)))
                String(c.doFinal(raw, 21, raw.size - 21))
            } else null
        } catch (e: Exception) { null }
    }

    fun topic(): String {
        val h = MessageDigest.getInstance("SHA-256").digest(BuildConfig.TOKEN.toByteArray())
        return "l360/" + h.take(12).joinToString("") { "%02x".format(it) }
    }
}
