package at.flowzym.flex_device

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import java.io.ByteArrayOutputStream
import java.io.File

/** App-private, bounded files; identifiers can never address arbitrary paths. */
class MaterialStorage(private val context: Context) {
    companion object {
        val methods = setOf("writeMaterial", "readMaterial", "hasMaterial", "removeMaterial", "pdfMaterialInfo", "renderMaterialPage", "openMaterial")
        private const val limit = 20_000_000
    }
    private fun file(call: MethodCall): File {
        val key = requireNotNull(call.argument<String>("key"))
        require(Regex("[a-zA-Z0-9_-]{1,120}").matches(key))
        val directory = File(context.filesDir, "materials")
        if (!directory.exists() && !directory.mkdirs()) throw java.io.IOException("No material directory")
        return File(directory, key)
    }
    fun perform(call: MethodCall): Any? {
        val target = file(call)
        val vault = PrivateStorage(context)
        return synchronized(PrivateStorage.monitor) { when (call.method) {
            "hasMaterial" -> target.isFile && target.length() in 1..(limit + VaultFileCodec.overhead).toLong()
            "writeMaterial" -> {
                val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                require(bytes.isNotEmpty() && bytes.size <= limit)
                vault.write(target, bytes)
                null
            }
            "removeMaterial" -> { if (target.exists() && !target.delete()) throw java.io.IOException("Cannot remove material"); null }
            "readMaterial" -> { require(target.length() in 1..(limit + VaultFileCodec.overhead).toLong()); vault.read(target) }
            "openMaterial" -> {
                require(target.isFile)
                val extension = call.argument<String>("extension")
                require(extension == "pdf" || extension == "docx")
                val name = (call.argument<String>("name") ?: "Material.$extension").replace(Regex("[/\\\\\\r\\n]"), "_").take(160)
                val exports = File(context.cacheDir, "flex-open").apply { mkdirs() }
                val exported = File.createTempFile("document-", ".$extension", exports)
                java.io.FileOutputStream(exported).use { it.write(vault.read(target)); it.fd.sync() }
                val uri = FileProvider.getUriForFile(context, context.packageName + ".materials", exported, name)
                val mime = if (extension == "pdf") "application/pdf" else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                null
            }
            "pdfMaterialInfo", "renderMaterialPage" -> {
                require(target.length() in 1..(limit + VaultFileCodec.overhead).toLong())
                val decoded = File.createTempFile("flex-render-", ".pdf", context.cacheDir)
                try {
                java.io.FileOutputStream(decoded).use { it.write(vault.read(target)) }
                PdfRenderer(ParcelFileDescriptor.open(decoded, ParcelFileDescriptor.MODE_READ_ONLY)).use { renderer ->
                    require(renderer.pageCount in 1..2000)
                    if (call.method == "pdfMaterialInfo") mapOf("pages" to renderer.pageCount)
                    else {
                        val index = requireNotNull(call.argument<Int>("page"))
                        require(index in 0 until renderer.pageCount)
                        renderer.openPage(index).use { page ->
                            val width = (call.argument<Int>("width") ?: 1000).coerceIn(300, 1600)
                            val height = (width.toDouble() * page.height / page.width).toInt().coerceIn(1, 4000)
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            try {
                                bitmap.eraseColor(Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                ByteArrayOutputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, out); out.toByteArray() }
                            } finally { bitmap.recycle() }
                        }
                    }
                }
                } finally { decoded.delete() }
            }
            else -> throw IllegalArgumentException("Unknown material operation")
        } }
    }
}
