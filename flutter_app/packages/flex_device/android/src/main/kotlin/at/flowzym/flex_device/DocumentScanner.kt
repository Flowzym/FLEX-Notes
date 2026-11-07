package at.flowzym.flex_device

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.ConnectionResult
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** ML Kit owns camera permission, edge detection and perspective correction.
 * Only normalized page pixels cross the Flutter bridge; no URI is accepted
 * from Dart and no original is copied to public storage. */
class DocumentScanner(private val context: Context) {
    companion object { const val requestCode = 46023 }
    private var pending: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun start(activity: Activity?, limit: Int, result: MethodChannel.Result) {
        if (activity == null || pending != null) {
            result.error("scanner_busy", "Der Scanner ist gerade nicht verfügbar.", null); return
        }
        pending = result
        val availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)
        if (availability != ConnectionResult.SUCCESS) {
            fail("Die automatische Dokumenterkennung ist nicht verfügbar (Google Play-Dienste: $availability). Bitte die normale Kamera verwenden."); return
        }
        try {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(limit.coerceIn(1, 25))
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                if (pending !== result) return@addOnSuccessListener
                try {
                    activity.startIntentSenderForResult(sender, requestCode, null, 0, 0, 0)
                } catch (_: Exception) { fail("Der Scanner konnte nicht gestartet werden. Bilder können über Dateien hinzugefügt werden.") }
            }
            .addOnFailureListener {
                if (pending === result) fail("Die automatische Dokumenterkennung konnte nicht gestartet werden. Bitte die normale Kamera verwenden. Google Play-Dienste können ein Update oder einen Moduldownload benötigen.")
            }
        } catch (_: Exception) {
            fail("Die automatische Dokumenterkennung konnte nicht geöffnet werden. Bitte die normale Kamera verwenden.")
        }
    }
    private fun fail(message: String) {
        val result = pending; pending = null
        result?.error("scanner_unavailable", message, null)
    }
    fun activityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val result = pending ?: return true
        if (status != Activity.RESULT_OK) { pending = null; result.success(null); return true }
        val pages = GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages
        if (pages.isNullOrEmpty() || pages.size > 25) { fail("Der Scan enthält keine gültigen Seiten."); return true }
        worker.execute {
            try {
                var total = 0
                val images = pages.map { page ->
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    context.contentResolver.openInputStream(page.imageUri)!!.use { BitmapFactory.decodeStream(it, null, bounds) }
                    require(bounds.outWidth > 0 && bounds.outHeight > 0)
                    var sample = 1
                    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 4800) sample *= 2
                    val options = BitmapFactory.Options().apply { inSampleSize = sample }
                    val original = context.contentResolver.openInputStream(page.imageUri)!!.use { BitmapFactory.decodeStream(it, null, options) } ?: throw IllegalArgumentException()
                    try {
                        val scale = minOf(1.0, 2400.0 / maxOf(original.width, original.height))
                        val resized = Bitmap.createScaledBitmap(original, maxOf(1, (original.width * scale).toInt()), maxOf(1, (original.height * scale).toInt()), true)
                        try {
                            ByteArrayOutputStream().use { out ->
                                resized.compress(Bitmap.CompressFormat.JPEG, 90, out)
                                val bytes = out.toByteArray()
                                total += bytes.size
                                require(total <= 40_000_000)
                                bytes
                            }
                        } finally { if (resized !== original) resized.recycle() }
                    } finally { original.recycle() }
                }
                main.post { if (pending === result) { pending = null; result.success(images) } }
            } catch (_: Exception) { main.post { if (pending === result) fail("Die Scanseiten konnten nicht verarbeitet werden. Bitte weniger Seiten aufnehmen.") } }
        }
        return true
    }
    fun close() { fail("Scanner geschlossen. Bereits gespeicherte Entwürfe bleiben erhalten.") }
    fun dispose() { close(); worker.shutdown() }
}
