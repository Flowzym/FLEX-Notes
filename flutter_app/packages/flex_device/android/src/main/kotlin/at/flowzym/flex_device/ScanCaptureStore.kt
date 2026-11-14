package at.flowzym.flex_device

import android.content.Context
import java.io.File
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/** Encrypted pending pages; acknowledge only after Flutter persists its draft. */
class ScanCaptureStore(context: Context, val owner: String) {
    private val vault = PrivateStorage(context)
    private val directory: File
    private val manifest: File

    init {
        require(Regex("[a-zA-Z0-9_-]{1,120}").matches(owner))
        directory = File(File(context.filesDir, "pending-scans"), owner).apply { mkdirs() }
        manifest = File(directory, "pages")
    }

    private fun rows(): JSONArray =
        if (manifest.exists()) JSONArray(String(vault.read(manifest), Charsets.UTF_8))
        else JSONArray()

    private fun write(rows: JSONArray) {
        vault.write(manifest, rows.toString().toByteArray(Charsets.UTF_8))
    }

    fun lastToken(): String? =
        synchronized(PrivateStorage.monitor) {
            val pages = rows()
            if (pages.length() == 0) null
            else pages.getJSONObject(pages.length() - 1).getString("token")
        }

    fun count(): Int = synchronized(PrivateStorage.monitor) { rows().length() }

    fun add(bytes: ByteArray, quad: DocumentEdges.Quad?): String =
        synchronized(PrivateStorage.monitor) {
            val pages = rows()
            require(pages.length() < 25 && bytes.size <= 10_000_000)
            require(
                directory.listFiles().orEmpty().sumOf { it.length() } + bytes.size <= 40_000_000
            )
            val token = UUID.randomUUID().toString()
            val file = File(directory, token)
            vault.write(file, bytes)
            val row = JSONObject().put("token", token)
            if (quad != null) row.put("corners", JSONArray(quad.points.map { listOf(it.x, it.y) }))
            pages.put(row)
            try {
                write(pages)
            } catch (e: Exception) {
                file.delete()
                throw e
            }
            token
        }

    fun pages(): List<Map<String, Any>> =
        synchronized(PrivateStorage.monitor) {
            val pages = rows()
            require(pages.length() <= 25)
            (0 until pages.length()).map { i ->
                val row = pages.getJSONObject(i)
                val token = row.getString("token")
                require(Regex("[a-f0-9-]{36}").matches(token))
                val result =
                    mutableMapOf<String, Any>(
                        "token" to token,
                        "bytes" to vault.read(File(directory, token)),
                    )
                row.optJSONArray("corners")?.let { corners ->
                    result["corners"] =
                        (0 until corners.length()).map { n ->
                            listOf(
                                corners.getJSONArray(n).getDouble(0),
                                corners.getJSONArray(n).getDouble(1),
                            )
                        }
                }
                result
            }
        }

    fun acknowledge(token: String) =
        synchronized(PrivateStorage.monitor) {
            require(Regex("[a-f0-9-]{36}").matches(token))
            val old = rows()
            val next = JSONArray()
            for (i in 0 until old.length()) if (old.getJSONObject(i).getString("token") != token)
                next.put(old.getJSONObject(i))
            write(next)
            File(directory, token).delete()
            if (next.length() == 0) {
                manifest.delete()
                directory.delete()
            }
        }

    fun discard() =
        synchronized(PrivateStorage.monitor) {
            directory.listFiles().orEmpty().forEach { check(it.delete()) }
            check(!directory.exists() || directory.delete())
        }
}
