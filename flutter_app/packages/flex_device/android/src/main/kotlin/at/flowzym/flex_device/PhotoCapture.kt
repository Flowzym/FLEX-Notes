package at.flowzym.flex_device

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/** Full resolution camera output; retained until Dart durably acknowledges it. */
class PhotoCapture(private val context: Context) {
    private val prefs = context.getSharedPreferences("flex_photo_capture", Context.MODE_PRIVATE)
    private var pending: MethodChannel.Result? = null
    private val code = 46024
    private fun file(token: String) = File(File(context.cacheDir, "flex-camera"), "$token.jpg")
    fun owner(): String? = prefs.getString("owner", null)
    fun start(activity: Activity?, owner: String?, result: MethodChannel.Result) {
        if (activity == null || owner.isNullOrBlank() || pending != null || prefs.contains("token")) {
            result.error("photo_busy", "Bitte die ausstehende Fotoaufnahme zuerst im Entwurf fortsetzen.", null); return
        }
        val token = UUID.randomUUID().toString()
        val output = file(token)
        try {
            output.parentFile!!.mkdirs()
            output.createNewFile()
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.materials", output)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.clipData = ClipData.newRawUri("FLEX Foto", uri)
            check(prefs.edit().putString("token", token).putString("owner", owner).commit())
            pending = result
            activity.startActivityForResult(intent, code)
        } catch (_: Exception) {
            pending = null; output.delete(); prefs.edit().clear().commit()
            result.error("photo_unavailable", "Die Kamera konnte nicht geöffnet werden. Alternativ ein Bild aus Dateien hinzufügen.", null)
        }
    }
    private fun payload(owner: String?): Map<String, Any>? {
        if (owner != prefs.getString("owner", null)) return null
        val token = prefs.getString("token", null) ?: return null
        val source = file(token)
        if (!source.exists() || source.length() == 0L) { source.delete(); prefs.edit().clear().commit(); return null }
        check(source.length() <= 20_000_000) { "Bitte ein Foto bis zu 20 MB aufnehmen." }
        return mapOf("token" to token, "bytes" to source.readBytes())
    }
    fun recover(owner: String?, result: MethodChannel.Result) {
        try { result.success(payload(owner)) }
        catch (e: Exception) { result.error("photo_read", e.message, null) }
    }
    fun discard(owner: String?, result: MethodChannel.Result) {
        if (owner == prefs.getString("owner", null)) {
            prefs.getString("token", null)?.let { file(it).delete() }
            prefs.edit().clear().commit()
        }
        result.success(null)
    }
    fun finish(owner: String?, token: String?, result: MethodChannel.Result) {
        if (owner == prefs.getString("owner", null) && token == prefs.getString("token", null)) {
            if (token != null) file(token).delete()
            prefs.edit().clear().commit()
        }
        result.success(null)
    }
    fun activityResult(request: Int, status: Int): Boolean {
        if (request != code) return false
        val result = pending; pending = null
        if (status != Activity.RESULT_OK) {
            prefs.getString("token", null)?.let { file(it).delete() }
            prefs.edit().clear().commit(); result?.success(null); return true
        }
        try { result?.success(payload(prefs.getString("owner", null))) }
        catch (e: Exception) { result?.error("photo_read", e.message, null) }
        return true
    }
    fun close() { pending?.error("photo_closed", "Fotoaufnahme im Entwurf fortsetzen.", null); pending = null }
}
