package at.flowzym.flex_device

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

class FlexDevicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    companion object {
        // One Android app process, including all foreground/WorkManager engines.
        private val backupLock = java.util.concurrent.Semaphore(1, true)
        private val lockWaiters = Executors.newCachedThreadPool()
    }
    private val lockTokens = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    @Volatile private var detached = false
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val writer = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var screenProtected = false
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private val maxBytes = 28_000_000
    private val backupName = Regex("FLEX-Auto-[0-9TZ-]+-[a-f0-9-]+\\.json")

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detached = false
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "at.flowzym.flex_notizbuch/device")
        channel.setMethodCallHandler(this)
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method in MaterialStorage.methods) {
            writer.execute {
                try {
                    val value = MaterialStorage(context).perform(call)
                    main.post { result.success(value) }
                } catch (_: Exception) {
                    main.post { result.error("material_storage", "Die Datei konnte nicht geöffnet werden. Bitte Dateiformat, Speicherplatz und verfügbare Anzeige-App prüfen.", null) }
                }
            }
            return
        }
        if (call.method == "acquireBackupLock") {
            lockWaiters.execute {
                backupLock.acquire()
                main.post {
                    if (detached) { backupLock.release() }
                    else {
                        val token = java.util.UUID.randomUUID().toString()
                        lockTokens.add(token)
                        result.success(token)
                    }
                }
            }
            return
        }
        if (call.method == "releaseBackupLock") {
            val token = call.argument<String>("token")
            if (token != null && lockTokens.remove(token)) backupLock.release()
            result.success(null); return
        }
        if (call.method == "protectScreen") {
            screenProtected = call.argument<Boolean>("enabled") == true
            if (screenProtected) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            else activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            result.success(null); return
        }
        if (call.method == "chooseBackupDirectory") {
            if (pending != null || activity == null) { result.error("directory_busy", "Ordnerauswahl derzeit nicht verfügbar.", null); return }
            pending = result
            try {
                activity!!.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                }, 46022)
            } catch (_: Exception) { pending = null; result.error("directory_unavailable", "Ordnerauswahl nicht verfügbar.", null) }
            return
        }
        if (call.method !in setOf("listBackups", "writeBackup", "readBackup", "deleteBackup")) { result.notImplemented(); return }
        writer.execute {
            try {
                val folder = Uri.parse(requireNotNull(call.argument<String>("folder")))
                require(folder.scheme == "content")
                val root = DocumentsContract.buildDocumentUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
                val children = list(folder)
                val value: Any? = when (call.method) {
                    "listBackups" -> children
                    "writeBackup" -> {
                        val name = requireNotNull(call.argument<String>("name"))
                        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                        require(backupName.matches(name) && bytes.size <= maxBytes)
                        val doc = DocumentsContract.createDocument(context.contentResolver, root, "application/json", name)
                            ?: throw java.io.IOException("No document")
                        try {
                            context.contentResolver.openOutputStream(doc, "wt")!!.use { it.write(bytes) }
                            doc.toString()
                        } catch (error: Exception) {
                            try { DocumentsContract.deleteDocument(context.contentResolver, doc) } catch (_: Exception) { }
                            throw error
                        }
                    }
                    else -> {
                        val uri = requireNotNull(call.argument<String>("uri"))
                        require(children.any { it["uri"] == uri })
                        val doc = Uri.parse(uri)
                        if (call.method == "deleteBackup") {
                            if (!DocumentsContract.deleteDocument(context.contentResolver, doc)) throw java.io.IOException("Delete failed")
                            null
                        } else {
                            context.contentResolver.openInputStream(doc)!!.use { input ->
                                val output = java.io.ByteArrayOutputStream()
                                val buffer = ByteArray(8192)
                                var read = input.read(buffer)
                                while (read >= 0) {
                                    require(output.size() + read <= maxBytes)
                                    output.write(buffer, 0, read)
                                    read = input.read(buffer)
                                }
                                output.toByteArray()
                            }
                        }
                    }
                }
                main.post { result.success(value) }
            } catch (_: Exception) {
                main.post { result.error("backup_storage", "Der Sicherungsordner ist nicht erreichbar oder die Datei konnte nicht verarbeitet werden. Bitte Ordnerzugriff und freien Speicher prüfen.", null) }
            }
        }
    }
    private fun list(folder: Uri): List<Map<String, Any>> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(folder, DocumentsContract.getTreeDocumentId(folder))
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED)
        val result = mutableListOf<Map<String, Any>>()
        val cursor = context.contentResolver.query(children, columns, null, null, null) ?: throw java.io.IOException("No directory")
        cursor.use {
            while (it.moveToNext()) {
                val name = it.getString(1)
                if (backupName.matches(name)) result.add(mapOf("uri" to DocumentsContract.buildDocumentUriUsingTree(folder, it.getString(0)).toString(), "name" to name, "size" to it.getLong(2), "modified" to it.getLong(3)))
            }
        }
        return result.sortedByDescending { it["name"] as String }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 46022) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { result.success(null); return true }
        try {
            val uri = data.data!!
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            require(flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0)
            context.contentResolver.takePersistableUriPermission(uri, flags)
            val root = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
            var name = "Sicherungsordner"
            context.contentResolver.query(root, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) name = it.getString(0) }
            result.success(mapOf("uri" to uri.toString(), "name" to name))
        } catch (_: Exception) { result.error("directory_permission", "Der Ordner erlaubt keinen dauerhaften Schreibzugriff.", null) }
        return true
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { this.binding = binding; activity = binding.activity; if (screenProtected) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE); binding.addActivityResultListener(this) }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() { binding?.removeActivityResultListener(this); binding = null; activity = null }
    override fun onDetachedFromActivity() { onDetachedFromActivityForConfigChanges(); pending?.error("activity_closed", "Ordnerauswahl geschlossen.", null); pending = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { detached = true; channel.setMethodCallHandler(null); for (token in lockTokens.toList()) { if (lockTokens.remove(token)) backupLock.release() }; writer.shutdown() }
}
