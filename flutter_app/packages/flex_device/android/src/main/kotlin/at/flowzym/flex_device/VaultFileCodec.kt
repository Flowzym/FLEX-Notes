package at.flowzym.flex_device

import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Versioned authenticated file envelope. Names are authenticated as well. */
class VaultFileCodec(private val key: SecretKey) {
    companion object {
        private val magic = "FLEXFILE1".toByteArray(Charsets.US_ASCII)
        const val overhead = 37
        fun encrypted(bytes: ByteArray): Boolean = bytes.size >= magic.size &&
            bytes.copyOfRange(0, magic.size).contentEquals(magic)
    }
    fun encode(bytes: ByteArray, name: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        require(cipher.iv.size == 12)
        cipher.updateAAD(("FLEXFILE1:" + name).toByteArray(Charsets.UTF_8))
        return magic + cipher.iv + cipher.doFinal(bytes)
    }
    fun decode(bytes: ByteArray, name: String): ByteArray {
        require(encrypted(bytes) && bytes.size > overhead)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(9, 21)))
        cipher.updateAAD(("FLEXFILE1:" + name).toByteArray(Charsets.UTF_8))
        return cipher.doFinal(bytes, 21, bytes.size - 21)
    }
}
