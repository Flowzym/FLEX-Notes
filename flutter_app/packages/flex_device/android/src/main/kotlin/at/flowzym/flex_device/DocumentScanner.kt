package at.flowzym.flex_device

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** CameraX capture; pending pages are encrypted and scoped to a durable draft. */
class DocumentScanner(private val context: Context) {
    companion object {
        const val requestCode = 46023
    }

    private var pending: MethodChannel.Result? = null
    private var owner: String? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun start(activity: Activity?, draftId: String?, limit: Int, result: MethodChannel.Result) {
        if (
            activity == null ||
                pending != null ||
                draftId == null ||
                !Regex("[a-zA-Z0-9_-]{1,120}").matches(draftId)
        ) {
            result.error("scanner_busy", "Bitte den Scanentwurf erneut öffnen.", null)
            return
        }
        pending = result
        owner = draftId
        try {
            activity.startActivityForResult(
                Intent(activity, FlexScannerActivity::class.java)
                    .putExtra("owner", draftId)
                    .putExtra("limit", limit.coerceIn(1, 25)),
                requestCode,
            )
        } catch (_: Exception) {
            pending = null
            result.error(
                "scanner_unavailable",
                "Die Dokumentkamera konnte nicht gestartet werden.",
                null,
            )
        }
    }

    fun recover(draftId: String?, result: MethodChannel.Result) = read(draftId, result)

    private fun read(draftId: String?, result: MethodChannel.Result) {
        worker.execute {
            try {
                val pages = ScanCaptureStore(context, requireNotNull(draftId)).pages()
                main.post { result.success(pages) }
            } catch (_: Exception) {
                main.post {
                    result.error(
                        "scanner_read",
                        "Aufnahmen konnten nicht geladen werden. Der Scanentwurf bleibt erhalten.",
                        null,
                    )
                }
            }
        }
    }

    fun finish(draftId: String?, token: String?, result: MethodChannel.Result) {
        worker.execute {
            try {
                ScanCaptureStore(context, requireNotNull(draftId))
                    .acknowledge(requireNotNull(token))
                main.post { result.success(null) }
            } catch (_: Exception) {
                main.post {
                    result.error(
                        "scanner_ack",
                        "Aufnahme wurde gespeichert; Kamera-Zwischenspeicher konnte noch nicht freigegeben werden.",
                        null,
                    )
                }
            }
        }
    }

    fun discard(draftId: String?, result: MethodChannel.Result) {
        worker.execute {
            try {
                ScanCaptureStore(context, requireNotNull(draftId)).discard()
                main.post { result.success(null) }
            } catch (_: Exception) {
                main.post {
                    result.error(
                        "scanner_cleanup",
                        "Aufnahmen konnten noch nicht entfernt werden.",
                        null,
                    )
                }
            }
        }
    }

    fun activityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val result = pending ?: return true
        pending = null
        // Even cancellation after a lifecycle interruption may leave durable pages.
        read(owner, result)
        return true
    }

    fun close() {
        pending?.error("scanner_closed", "Scanentwurf öffnen, um die Aufnahmen fortzusetzen.", null)
        pending = null
    }

    fun dispose() {
        close()
        worker.shutdown()
    }
}
