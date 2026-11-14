package at.flowzym.flex_device

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/** Pending imports are encrypted and durable; the app never imports on receipt. */
class IncomingShares(private val context: Context) {
    companion object {
        private val monitor = Any()
        val methods = setOf("pendingShares", "discardShares", "clearShareError")
        val actions = setOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_VIEW)
    }
    private val vault get() = PrivateStorage(context)
    private val stateFile get() = File(context.noBackupFilesDir, "incoming-shares.v1")
    private fun state(): JSONObject = if (stateFile.exists()) JSONObject(String(vault.read(stateFile), Charsets.UTF_8)) else JSONObject().put("items", JSONArray())
    private fun save(value: JSONObject) = vault.write(stateFile, value.toString().toByteArray(Charsets.UTF_8))
    @Suppress("DEPRECATION")
    fun takeUris(intent: Intent): List<Uri>? {
        if (intent.action !in actions) return null
        val action = intent.action
        val uris = when (action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.toList().orEmpty()
            else -> listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        }.ifEmpty { (0 until (intent.clipData?.itemCount ?: 0)).mapNotNull { intent.clipData?.getItemAt(it)?.uri } }
        // Activity recreation must not enqueue the same intent again.
        intent.action = null
        return uris.distinct()
    }
    fun receive(uris: List<Uri>) = synchronized(monitor) {
        val created = mutableListOf<File>()
        try {
            val current = state()
            val items = current.getJSONArray("items")
            require(uris.isNotEmpty() && items.length() + uris.size <= 20)
            var total = (0 until items.length()).sumOf { items.getJSONObject(it).getLong("size") }
            val added = mutableListOf<JSONObject>()
            for (uri in uris) {
                require(uri.scheme == "content" && uri.authority != context.packageName + ".materials")
                var name = "Dokument"
                context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
                    if (it.moveToFirst()) {
                        if (!it.isNull(0)) name = it.getString(0)
                        if (!it.isNull(1) && it.getLong(1) >= 0) require(it.getLong(1) in 1..20_000_000)
                    }
                }
                name = name.replace(Regex("[\\p{Cntrl}/\\\\]"), "_").take(150).ifBlank { "Dokument" }
                val mime = context.contentResolver.getType(uri).orEmpty().lowercase()
                val ext = name.substringAfterLast('.', "").lowercase()
                val kind = when {
                    mime == "application/pdf" || ext == "pdf" -> "pdf"
                    mime == "application/vnd.openxmlformats-officedocument.wordprocessingml.document" || ext == "docx" -> "docx"
                    mime in setOf("image/jpeg", "image/png", "image/webp") || ext in setOf("jpg", "jpeg", "png", "webp") -> "image"
                    else -> error("Unsupported file")
                }
                val bytes = context.contentResolver.openInputStream(uri)!!.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(65536)
                    while (true) {
                        val n = input.read(buffer); if (n < 0) break
                        require(output.size().toLong() + n <= 20_000_000 && total + output.size() + n <= 100_000_000)
                        output.write(buffer, 0, n)
                    }
                    output.toByteArray()
                }
                require(bytes.isNotEmpty())
                val id = UUID.randomUUID().toString()
                val key = "incoming_$id"
                val file = File(File(context.filesDir, "materials"), key)
                created.add(file); vault.write(file, bytes)
                total += bytes.size
                added.add(JSONObject().put("id", id).put("key", key).put("name", name).put("kind", kind).put("size", bytes.size))
            }
            for (item in added) items.put(item)
            current.remove("error")
            save(current)
        } catch (_: Exception) {
            for (file in created) file.delete()
            val current = state().put("error", "Die Übergabe konnte nicht vollständig übernommen werden. Bitte PDF, DOCX, JPG, PNG oder WebP verwenden: bis 20 MB je Datei, höchstens 20 Dateien und 100 MB im Eingang.")
            save(current)
        }
    }
    fun pending(): Map<String, Any> = synchronized(monitor) {
        val current = state(); val items = current.getJSONArray("items")
        val referenced = (0 until items.length()).map { items.getJSONObject(it).getString("key") }.toSet()
        for (file in File(context.filesDir, "materials").listFiles().orEmpty()) {
            if (file.isFile && Regex("incoming_[a-f0-9-]{36}").matches(file.name) && file.name !in referenced) file.delete()
        }
        mapOf("items" to (0 until items.length()).map { index ->
            val item = items.getJSONObject(index)
            mapOf("id" to item.getString("id"), "key" to item.getString("key"), "name" to item.getString("name"), "kind" to item.getString("kind"), "size" to item.getInt("size"))
        }, "error" to current.optString("error", ""))
    }
    fun discard(ids: List<String>) = synchronized(monitor) {
        val current = state(); val items = current.getJSONArray("items")
        val keep = JSONArray(); val removed = mutableListOf<String>()
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            if (item.getString("id") in ids) removed.add(item.getString("key")) else keep.put(item)
        }
        current.put("items", keep); save(current)
        for (key in removed) File(File(context.filesDir, "materials"), key).delete()
    }
    fun clearError() = synchronized(monitor) { val current = state(); current.remove("error"); save(current) }
}
