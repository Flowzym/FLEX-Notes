package at.flowzym.flex_device

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.UUID

/** Engine-owned bounded streams. No archive-sized channel messages or buffers. */
class StreamFiles(private val context: Context) {
    companion object {
        val methods = setOf("beginBackupWrite", "beginBackupRead", "writeFileChunk", "finishFileWrite", "abortFileWrite", "readFileChunk", "closeFileRead")
        private const val maxBytes = 220_000_000L
        private val backupName = Regex("FLEX-Auto-[0-9TZ-]+-[a-f0-9-]+\\.(json|flexbackup)")
    }
    private data class Write(val uri: Uri, val output: OutputStream, val finalName: String?,
        val hash: MessageDigest = MessageDigest.getInstance("SHA-256"), var count: Long = 0)
    private data class Read(val input: InputStream, var count: Long = 0)
    private val writers = mutableMapOf<String, Write>()
    private val readers = mutableMapOf<String, Read>()
    @Synchronized fun startWrite(uri: Uri, finalName: String? = null): String {
        require(uri.scheme == "content" && writers.size < 2)
        val output = context.contentResolver.openOutputStream(uri, "wt") ?: error("No stream")
        val token = UUID.randomUUID().toString()
        writers[token] = Write(uri, output, finalName)
        return token
    }
    @Synchronized fun perform(call: MethodCall): Any? {
        if (call.method == "beginBackupWrite" || call.method == "beginBackupRead") {
            val folder = Uri.parse(requireNotNull(call.argument<String>("folder")))
            require(folder.scheme == "content")
            val root = DocumentsContract.buildDocumentUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
            if (call.method == "beginBackupWrite") {
                val name = requireNotNull(call.argument<String>("name"))
                require(backupName.matches(name))
                val uri = DocumentsContract.createDocument(context.contentResolver, root, "application/octet-stream", "$name.partial") ?: error("No document")
                try { return mapOf("token" to startWrite(uri, name), "uri" to uri.toString()) }
                catch (e: Exception) { try { DocumentsContract.deleteDocument(context.contentResolver, uri) } catch (_: Exception) {} ; throw e }
            }
            val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
            var allowed = false
            context.contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)!!.use {
                while (it.moveToNext()) {
                    if (backupName.matches(it.getString(1)) && DocumentsContract.buildDocumentUriUsingTree(folder, it.getString(0)) == uri) allowed = true
                }
            }
            require(allowed && readers.size < 4)
            val token = UUID.randomUUID().toString()
            readers[token] = Read(context.contentResolver.openInputStream(uri) ?: error("No stream"))
            return token
        }
        val token = requireNotNull(call.argument<String>("token"))
        return when (call.method) {
            "writeFileChunk" -> {
                val item = requireNotNull(writers[token])
                val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                require(bytes.size in 1..262144 && item.count + bytes.size <= maxBytes)
                item.output.write(bytes); item.hash.update(bytes); item.count += bytes.size
                null
            }
            "finishFileWrite" -> {
                val item = requireNotNull(writers[token])
                item.output.flush(); item.output.close()
                val expected = item.hash.digest()
                val actual = MessageDigest.getInstance("SHA-256")
                var count = 0L
                context.contentResolver.openInputStream(item.uri)!!.use { input ->
                    val buffer = ByteArray(65536)
                    while (true) { val n = input.read(buffer); if (n < 0) break; count += n; require(count <= maxBytes); actual.update(buffer, 0, n) }
                }
                require(count == item.count && MessageDigest.isEqual(expected, actual.digest())) { "Verification failed" }
                // A process death may leave a .partial file, never a listed successful backup.
                val completed = if (item.finalName == null) item.uri else
                    DocumentsContract.renameDocument(context.contentResolver, item.uri, item.finalName)
                        ?: error("Provider cannot finalize the backup")
                writers.remove(token)
                completed.toString()
            }
            "abortFileWrite" -> { abort(token); null }
            "readFileChunk" -> {
                val item = requireNotNull(readers[token])
                val buffer = ByteArray(262144)
                val n = item.input.read(buffer)
                if (n < 0) null else { item.count += n; require(item.count <= maxBytes); buffer.copyOf(n) }
            }
            "closeFileRead" -> { readers.remove(token)?.input?.close(); null }
            else -> error("Unknown stream operation")
        }
    }
    @Synchronized private fun abort(token: String) {
        val item = writers.remove(token) ?: return
        try { item.output.close() } finally { DocumentsContract.deleteDocument(context.contentResolver, item.uri) }
    }
    @Synchronized fun close() {
        for (token in writers.keys.toList()) { try { abort(token) } catch (_: Exception) {} }
        for (item in readers.values) { try { item.input.close() } catch (_: Exception) {} }
        readers.clear()
    }
}
