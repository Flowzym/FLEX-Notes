package at.flowzym.flex_device

import org.junit.Test
import org.junit.Assert.*
import javax.crypto.spec.SecretKeySpec

class VaultFileCodecTest {
    private val codec = VaultFileCodec(SecretKeySpec(ByteArray(32) { it.toByte() }, "AES"))
    @Test fun roundTripUsesUniqueNoncesAndContainsNoPlaintext() {
        val plain = "Confidential pupil observation".toByteArray()
        val a = codec.encode(plain, "document")
        val b = codec.encode(plain, "document")
        assertFalse(a.contentEquals(b))
        assertFalse(String(a).contains(String(plain)))
        assertArrayEquals(plain, codec.decode(a, "document"))
    }
    @Test fun rejectsChangesWrongKeyAndRenaming() {
        val original = codec.encode(ByteArray(1000) { it.toByte() }, "document")
        for (offset in listOf(0, 10, 21, original.lastIndex)) {
            val changed = original.clone().also { it[offset] = (it[offset].toInt() xor 1).toByte() }
            assertThrows(Exception::class.java) { codec.decode(changed, "document") }
        }
        assertThrows(Exception::class.java) { codec.decode(original, "other") }
        val other = VaultFileCodec(SecretKeySpec(ByteArray(32) { 99.toByte() }, "AES"))
        assertThrows(Exception::class.java) { other.decode(original, "document") }
        assertThrows(Exception::class.java) { codec.decode(original.copyOf(20), "document") }
    }
}
