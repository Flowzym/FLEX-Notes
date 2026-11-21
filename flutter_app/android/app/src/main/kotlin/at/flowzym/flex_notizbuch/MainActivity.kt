package at.flowzym.flex_notizbuch

import at.flowzym.flex_device.StreamFiles
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val writer = Executors.newSingleThreadExecutor()
    private val streams by lazy { StreamFiles(this) }
    private var quickAccess: FlexQuickAccess? = null
    private var pendingStream = false
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        quickAccess = FlexQuickAccess(this, flutterEngine.dartExecutor.binaryMessenger).also { it.accept(intent) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "at.flowzym.flex_notizbuch/files")
            .setMethodCallHandler { call, result ->
                if (call.method in StreamFiles.methods) {
                    writer.execute {
                        try { val value = streams.perform(call); runOnUiThread { result.success(value) } }
                        catch (_: Exception) { runOnUiThread { result.error("file_stream", "Speichern oder Prüfen der Sicherung fehlgeschlagen.", null) } }
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "saveFile" && call.method != "beginFileStream") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("save_busy", "Ein Speicherdialog ist bereits geöffnet.", null)
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isNullOrBlank() || (bytes == null && call.method == "saveFile")) {
                    result.error("invalid_file", "Dateiname oder Inhalt fehlt.", null)
                    return@setMethodCallHandler
                }
                pendingStream = call.method == "beginFileStream"
                pendingSave = result
                pendingBytes = bytes
                try {
                    // Storage Access Framework: only the user-selected document
                    // is writable; no broad storage permission is necessary.
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("mime") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, SAVE_DOCUMENT)
                } catch (error: Exception) {
                    finishSave("save_unavailable", "Der Android-Speicherdialog konnte nicht geöffnet werden.")
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_DOCUMENT || pendingSave == null) return
        if (resultCode != Activity.RESULT_OK) {
            finishSave(saved = false)
            return
        }
        val uri = data?.data
        if (pendingStream && uri != null) {
            val result = pendingSave
            pendingSave = null; pendingStream = false
            writer.execute {
                try { val token = streams.startWrite(uri); runOnUiThread { result?.success(token) } }
                catch (_: Exception) { runOnUiThread { result?.error("file_stream", "Sicherungsdatei konnte nicht geöffnet werden.", null) } }
            }
            return
        }
        val bytes = pendingBytes
        if (uri == null || bytes == null) {
            finishSave("save_failed", "Android hat kein beschreibbares Dokument zurückgegeben.")
            return
        }
        writer.execute {
            try {
                val stream = contentResolver.openOutputStream(uri, "wt")
                    ?: throw java.io.IOException("No document stream")
                stream.use { it.write(bytes) }
                runOnUiThread { finishSave(saved = true) }
            } catch (error: Exception) {
                runOnUiThread {
                    finishSave("save_failed", "Die Datei konnte nicht gespeichert werden. Bitte Speicherort und freien Platz prüfen.")
                }
            }
        }
    }

    private fun finishSave(code: String? = null, message: String? = null, saved: Boolean = false) {
        val result = pendingSave
        val wasStream = pendingStream
        pendingSave = null
        pendingBytes = null
        pendingStream = false
        if (code == null) result?.success(if (wasStream) null else saved) else result?.error(code, message, null)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        quickAccess?.accept(intent)
    }

    override fun onDestroy() {
        quickAccess?.dispose()
        finishSave("activity_closed", "Der Speicherdialog wurde geschlossen.")
        writer.execute { streams.close() }
        writer.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val SAVE_DOCUMENT = 46021
    }
}
