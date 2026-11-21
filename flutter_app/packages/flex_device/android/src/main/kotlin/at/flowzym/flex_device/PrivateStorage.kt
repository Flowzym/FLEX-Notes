package at.flowzym.flex_device

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Device-bound key: no PIN dependency so verified background backups still run.
 * Missing/invalid keys fail closed, never silently generate a replacement. */
class PrivateStorage(private val context: Context) {
    companion object {
        private const val alias = "flex.private-storage.v1"
        val monitor = Any()
    }
    private fun codec(): VaultFileCodec {
        val wrapped = File(context.noBackupFilesDir, "flex-database-key.v1")
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!keyStore.containsAlias(alias)) {
            require(!wrapped.exists() && !File(context.filesDir, "flex_notizbuch_encrypted_v1.sqlite").exists()) {
                "Existing storage key is unavailable"
            }
            val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            generator.init(KeyGenParameterSpec.Builder(alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setKeySize(256).build())
            generator.generateKey()
        }
        return VaultFileCodec(keyStore.getKey(alias, null) as SecretKey)
    }
    fun databaseKey(): String = synchronized(monitor) {
        val wrapped = File(context.noBackupFilesDir, "flex-database-key.v1")
        val codec = codec()
        if (!wrapped.exists()) {
            require(!File(context.filesDir, "flex_notizbuch_encrypted_v1.sqlite").exists())
            val raw = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val encrypted = codec.encode(raw, "database")
            atomicWrite(wrapped, encrypted)
        }
        require(wrapped.length() == (32 + VaultFileCodec.overhead).toLong())
        val raw = codec.decode(wrapped.readBytes(), "database")
        require(raw.size == 32)
        raw.joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    fun read(file: File): ByteArray = synchronized(monitor) {
        require(file.length() in 1..(20_000_000 + VaultFileCodec.overhead).toLong())
        val bytes = file.readBytes()
        if (VaultFileCodec.encrypted(bytes)) codec().decode(bytes, file.name)
        else {
            // Only known legacy formats can enter the migration path. Damaged
            // ciphertext must never be accepted as a new plaintext document.
            require(isLegacyDocument(bytes)) { "Unknown document format" }
            write(file, bytes)
            bytes
        }
    }
    fun write(file: File, bytes: ByteArray) = synchronized(monitor) {
        require(bytes.isNotEmpty() && bytes.size <= 20_000_000)
        val codec = codec()
        val encrypted = codec.encode(bytes, file.name)
        require(java.security.MessageDigest.isEqual(bytes, codec.decode(encrypted, file.name)))
        atomicWrite(file, encrypted)
    }
    fun migrateMaterials() = synchronized(monitor) {
        val directory = File(context.filesDir, "materials")
        for (file in directory.listFiles().orEmpty()) {
            if (file.isFile && Regex("[a-zA-Z0-9_-]{1,120}").matches(file.name)) {
                val header = ByteArray(9)
                java.io.FileInputStream(file).use { it.read(header) }
                if (!VaultFileCodec.encrypted(header)) read(file)
            }
            else if (file.isFile && file.name.startsWith("material-") && file.name.endsWith(".tmp")) file.delete()
        }
        for (file in context.cacheDir.listFiles().orEmpty()) {
            if (file.isFile && file.name.startsWith("flex-render-") && file.name.endsWith(".pdf")) file.delete()
        }
        val exports = File(context.cacheDir, "flex-open")
        for (file in exports.listFiles().orEmpty()) {
            if (file.isFile && System.currentTimeMillis() - file.lastModified() > 3_600_000) file.delete()
        }
    }
    private fun isLegacyDocument(b: ByteArray): Boolean {
        fun prefix(vararg values: Int) = b.size >= values.size && values.indices.all { (b[it].toInt() and 255) == values[it] }
        return prefix(0x25,0x50,0x44,0x46) || prefix(0xff,0xd8,0xff) ||
            prefix(0x89,0x50,0x4e,0x47) || prefix(0x50,0x4b,0x03,0x04) ||
            prefix(0x52,0x49,0x46,0x46)
    }
    private fun atomicWrite(target: File, bytes: ByteArray) {
        target.parentFile!!.mkdirs()
        val temporary = File.createTempFile("material-", ".tmp", target.parentFile)
        try {
            FileOutputStream(temporary).use { it.write(bytes); it.fd.sync() }
            require(java.security.MessageDigest.isEqual(bytes, temporary.readBytes()))
            if (!temporary.renameTo(target)) throw java.io.IOException("Cannot commit protected file")
        } finally { temporary.delete() }
    }
}
