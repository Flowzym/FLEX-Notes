package at.flowzym.flex_device

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Explicit on-device engine only. Recognized text is delivered transiently; no audio recording,
 * log, file or network recognizer fallback is created.
 */
class OnDeviceDictation(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {
    private val channel = MethodChannel(messenger, "at.flowzym.flex_notizbuch/dictation")
    private var binding: ActivityPluginBinding? = null
    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null
    private var language = "de-DE"
    private var session = 0

    init {
        channel.setMethodCallHandler(this)
    }

    fun attach(value: ActivityPluginBinding) {
        detach()
        binding = value
        value.addRequestPermissionsResultListener(this)
    }

    fun detach() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        cancel()
    }

    fun dispose() {
        detach()
        channel.setMethodCallHandler(null)
    }

    private fun available(): Boolean =
        try {
            Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } catch (_: Exception) {
            false
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(available())
            "cancel" -> {
                cancel()
                result.success(null)
            }
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "start" -> {
                if (!available()) {
                    result.error(
                        "unavailable",
                        "Lokales Diktat benötigt Android 12 oder neuer und ein verfügbares Offline-Sprachpaket. Du kannst die Diktierfunktion deiner Tastatur verwenden.",
                        null,
                    )
                    return
                }
                if (pending != null || recognizer != null) {
                    result.error("busy", "Ein Diktat läuft bereits.", null)
                    return
                }
                val activity = binding?.activity
                if (activity == null) {
                    result.error("unavailable", "Bitte FLEX im Vordergrund öffnen.", null)
                    return
                }
                language = if (call.argument<String>("language") == "en-GB") "en-GB" else "de-DE"
                pending = result
                if (
                    ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
                        PackageManager.PERMISSION_GRANTED
                ) {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        PERMISSION,
                    )
                } else start()
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        code: Int,
        permissions: Array<out String>,
        results: IntArray,
    ): Boolean {
        if (code != PERMISSION) return false
        if (pending == null) return true
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) start()
        else {
            pending?.error(
                "permission",
                "Bitte Mikrofonzugriff in den Android-Einstellungen erlauben.",
                null,
            )
            pending = null
        }
        return true
    }

    private fun emit(token: Int, state: String, text: String = "") {
        if (token == session) channel.invokeMethod("event", mapOf("state" to state, "text" to text))
    }

    private fun start() {
        val reply = pending ?: return
        pending = null
        val token = ++session
        try {
            if (Build.VERSION.SDK_INT < 31) throw IllegalStateException()
            val speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            recognizer = speech
            run {
                speech.setRecognitionListener(
                    object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) = emit(token, "listening")

                        override fun onBeginningOfSpeech() = Unit

                        override fun onRmsChanged(rmsdB: Float) = Unit

                        override fun onBufferReceived(buffer: ByteArray?) = Unit

                        override fun onEndOfSpeech() = emit(token, "processing")

                        override fun onPartialResults(results: Bundle?) =
                            emit(token, "partial", text(results))

                        override fun onResults(results: Bundle?) {
                            if (token != session) return
                            emit(token, "final", text(results))
                            release()
                        }

                        override fun onError(code: Int) {
                            if (token != session) return
                            val message =
                                when (code) {
                                    SpeechRecognizer.ERROR_NO_MATCH,
                                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                                        "Keine Sprache erkannt. Bitte erneut versuchen."
                                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                                        "Der Mikrofonzugriff wurde nicht erlaubt."
                                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                                    SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                                        "Das Offline-Sprachpaket fehlt. Bitte in den Android-Spracheinstellungen installieren oder eine andere Sprache wählen."
                                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                                        "Das Mikrofon wird gerade verwendet. Bitte erneut versuchen."
                                    else ->
                                        "Das lokale Diktat wurde unterbrochen. Bereits erkannter Text bleibt in der Vorschau."
                                }
                            emit(token, "error", message)
                            release()
                        }

                        override fun onEvent(eventType: Int, params: Bundle?) = Unit
                    }
                )
                speech.startListening(
                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                        )
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                )
            }
            reply.success(null)
        } catch (_: Exception) {
            release()
            reply.error(
                "unavailable",
                "Das lokale Sprachmodell konnte nicht gestartet werden. Bitte das Offline-Sprachpaket prüfen.",
                null,
            )
        }
    }

    private fun text(bundle: Bundle?): String {
        val value =
            bundle
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                .orEmpty()
        val end = value.offsetByCodePoints(0, minOf(value.codePointCount(0, value.length), 12000))
        return value.substring(0, end)
    }

    private fun release() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun cancel() {
        ++session
        val reply = pending
        pending = null
        reply?.error("interrupted", "Das Diktat wurde unterbrochen.", null)
        recognizer?.cancel()
        release()
    }

    companion object {
        private const val PERMISSION = 46027
    }
}
