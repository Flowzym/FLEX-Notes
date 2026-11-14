package at.flowzym.flex_device

import android.Manifest
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.graphics.*
import android.os.Bundle
import android.os.SystemClock
import android.view.*
import android.widget.*
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.*

class FlexScannerActivity : ComponentActivity() {
    private lateinit var preview: PreviewView
    private lateinit var overlay: EdgeOverlay
    private lateinit var status: TextView
    private lateinit var shutter: Button
    private lateinit var done: Button
    private lateinit var store: ScanCaptureStore
    private lateinit var autoButton: Button
    private val executor = Executors.newSingleThreadExecutor()
    private var provider: ProcessCameraProvider? = null
    private var camera: androidx.camera.core.Camera? = null
    private var capture: ImageCapture? = null
    private var limit = 25
    private var busy = false
    private var leaving = false
    private var automatic = false
    private var flash = false
    private var current: DocumentEdges.Quad? = null
    private var stable = 0
    private var lastAnalysis = 0L
    private var lastShot = 0L
    private var waitingForMovement = false
    private var lastCaptured: DocumentEdges.Quad? = null
    private var imageAspect = 0.75f
    private val cream = Color.rgb(250, 247, 242)
    private val olive = Color.rgb(98, 109, 67)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        val owner = intent.getStringExtra("owner")
        if (owner == null || !Regex("[a-zA-Z0-9_-]{1,120}").matches(owner)) {
            finish()
            return
        }
        store = ScanCaptureStore(this, owner)
        limit = intent.getIntExtra("limit", 25).coerceIn(1, 25)
        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(cream)
                setPadding(0, 0, 0, 0)
            }
        root.setOnApplyWindowInsetsListener { view, insets ->
            view.setPadding(
                insets.systemWindowInsetLeft,
                insets.systemWindowInsetTop,
                insets.systemWindowInsetRight,
                insets.systemWindowInsetBottom,
            )
            insets
        }
        val toolbar = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        toolbar.addView(button("Zurück") { leave() })
        toolbar.addView(
            TextView(this).apply {
                text = "FLEX.  Dokument scannen"
                setTextColor(olive)
                textSize = 16f
            },
            LinearLayout.LayoutParams(0, 56.dp, 1f),
        )
        toolbar.addView(
            button("Licht") {
                camera?.let {
                    if (it.cameraInfo.hasFlashUnit()) {
                        flash = !flash
                        it.cameraControl.enableTorch(flash)
                    } else status.text = "Dieses Gerät hat kein Kameralicht."
                }
            }
        )
        root.addView(toolbar)
        val frame = FrameLayout(this)
        preview =
            PreviewView(this).apply {
                scaleType = PreviewView.ScaleType.FIT_CENTER
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            }
        frame.addView(preview, FrameLayout.LayoutParams(-1, -1))
        overlay = EdgeOverlay()
        frame.addView(overlay, FrameLayout.LayoutParams(-1, -1))
        root.addView(frame, LinearLayout.LayoutParams(-1, 0, 1f))
        status =
            TextView(this).apply {
                text = "Kamera wird gestartet …"
                setTextColor(olive)
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(12.dp, 10.dp, 12.dp, 10.dp)
                minHeight = 48.dp
            }
        root.addView(status)
        val actions = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        autoButton =
            button("Auto aus") {
                automatic = !automatic
                autoButton.text = if (automatic) "Auto an" else "Auto aus"
                stable = 0
            }
        actions.addView(autoButton, LinearLayout.LayoutParams(0, 56.dp, 1f))
        shutter = button("Aufnehmen") { takePhoto() }.apply { isEnabled = false }
        actions.addView(shutter, LinearLayout.LayoutParams(0, 56.dp, 1.4f))
        done =
            button("Fertig (${store.count()})") {
                setResult(RESULT_OK)
                finish()
            }
        actions.addView(done, LinearLayout.LayoutParams(0, 56.dp, 1f))
        root.addView(actions)
        root.addView(
            button("Letzte Aufnahme entfernen") {
                if (!busy) {
                    val last = store.lastToken()
                    if (last != null)
                        AlertDialog.Builder(this)
                            .setMessage("Letzte Aufnahme entfernen?")
                            .setNegativeButton("Abbrechen", null)
                            .setPositiveButton("Entfernen") { _, _ ->
                                store.acknowledge(last)
                                updateCount()
                            }
                            .show()
                }
            }
        )
        setContentView(root)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = leave()
            },
        )
        val zoom =
            ScaleGestureDetector(
                this,
                object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                    override fun onScale(detector: ScaleGestureDetector): Boolean {
                        camera?.let {
                            val state = it.cameraInfo.zoomState.value ?: return true
                            it.cameraControl.setZoomRatio(
                                (state.zoomRatio * detector.scaleFactor).coerceIn(
                                    state.minZoomRatio,
                                    state.maxZoomRatio,
                                )
                            )
                        }
                        return true
                    }
                },
            )
        preview.setOnTouchListener { _, event ->
            zoom.onTouchEvent(event)
            if (event.action == MotionEvent.ACTION_UP && !zoom.isInProgress)
                camera
                    ?.cameraControl
                    ?.startFocusAndMetering(
                        FocusMeteringAction.Builder(
                                preview.meteringPointFactory.createPoint(event.x, event.y)
                            )
                            .build()
                    )
            true
        }
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
            preview.post { bindCamera() }
        else requestPermissions(arrayOf(Manifest.permission.CAMERA), 46028)
    }

    override fun onRequestPermissionsResult(
        code: Int,
        permissions: Array<String>,
        results: IntArray,
    ) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 46028) {
            if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED)
                preview.post { bindCamera() }
            else
                status.text =
                    "Kamerazugriff nicht erlaubt. Bitte in den Android-App-Einstellungen freigeben."
        }
    }

    private val Int.dp: Int
        get() = (this * resources.displayMetrics.density).roundToInt()

    private fun button(label: String, action: () -> Unit) =
        Button(this).apply {
            text = label
            isAllCaps = false
            textSize = 13f
            setTextColor(olive)
            minHeight = 48.dp
            setOnClickListener { action() }
        }

    private fun bindCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener(
            {
                if (isFinishing || isDestroyed) return@addListener
                try {
                    val p = future.get()
                    provider = p
                    val live =
                        Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).build().also {
                            it.setSurfaceProvider(preview.surfaceProvider)
                        }
                    val still =
                        ImageCapture.Builder()
                            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                            .build()
                    capture = still
                    val analysis =
                        ImageAnalysis.Builder()
                            .setTargetResolution(android.util.Size(640, 480))
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                    analysis.setAnalyzer(executor) { image -> analyze(image) }
                    p.unbindAll()
                    val group =
                        UseCaseGroup.Builder()
                            .addUseCase(live)
                            .addUseCase(still)
                            .addUseCase(analysis)
                    preview.viewPort?.let { group.setViewPort(it) }
                    camera =
                        p.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, group.build())
                    shutter.isEnabled = store.count() < limit
                    status.text =
                        "Dokument vollständig ins Bild bringen. Antippen zum Scharfstellen."
                } catch (_: Exception) {
                    status.text = "Kamera nicht verfügbar. Bitte schließen und erneut versuchen."
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun analyze(image: ImageProxy) {
        try {
            val now = SystemClock.elapsedRealtime()
            if (now - lastAnalysis < 130) return
            lastAnalysis = now
            val crop = image.cropRect
            val rotation = image.imageInfo.rotationDegrees
            val sample = max(1, max(crop.width(), crop.height()) / 300)
            val w = crop.width() / sample
            val h = crop.height() / sample
            if (w < 24 || h < 24) return
            val sw = if (rotation % 180 == 0) w else h
            val sh = if (rotation % 180 == 0) h else w
            val values = IntArray(sw * sh)
            val plane = image.planes[0]
            val buffer = plane.buffer
            for (y in 0 until h) for (x in 0 until w) {
                val value =
                    buffer
                        .get(
                            (crop.top + y * sample) * plane.rowStride +
                                (crop.left + x * sample) * plane.pixelStride
                        )
                        .toInt() and 255
                val at =
                    when (rotation) {
                        90 -> x * sw + (h - 1 - y)
                        180 -> (h - 1 - y) * sw + (w - 1 - x)
                        270 -> (w - 1 - x) * sw + y
                        else -> y * sw + x
                    }
                values[at] = value
            }
            val found = DocumentEdges.detect(values, sw, sh)
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                imageAspect = sw.toFloat() / sh
                val previous = current
                val distance =
                    if (previous == null || found == null) 1.0
                    else
                        previous.points.zip(found.points).maxOf { (a, b) ->
                            hypot(a.x - b.x, a.y - b.y)
                        }
                stable = if (distance < 0.018) stable + 1 else 0
                current = found
                if (
                    waitingForMovement &&
                        (found == null ||
                            lastCaptured?.points?.zip(found.points)?.maxOf { (a, b) ->
                                hypot(a.x - b.x, a.y - b.y)
                            } ?: 1.0 > 0.09)
                )
                    waitingForMovement = false
                overlay.invalidate()
                if (!busy)
                    status.text =
                        if (found == null)
                            "Keine sicheren Ränder · Aufnahme und manueller Zuschnitt möglich"
                        else if (stable >= 5) "Ränder erkannt · ruhig halten"
                        else "Ränder werden ausgerichtet …"
                if (
                    automatic &&
                        found != null &&
                        found.confidence > 0.8 &&
                        stable >= 7 &&
                        !waitingForMovement &&
                        now - lastShot > 1800
                )
                    takePhoto()
            }
        } catch (_: Exception) {
            /* A failed analysis never interrupts the camera. */
        } finally {
            image.close()
        }
    }

    private fun takePhoto() {
        val still = capture ?: return
        if (busy || leaving || isFinishing || store.count() >= limit) return
        busy = true
        shutter.isEnabled = false
        done.isEnabled = false
        status.text = "Aufnahme wird gesichert …"
        lastShot = SystemClock.elapsedRealtime()
        lastCaptured = current
        waitingForMovement = true
        // Re-detect on the actual still so motion between preview and shutter
        // cannot apply stale corners to a different page.
        still.takePicture(
            executor,
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    val bitmaps = mutableSetOf<Bitmap>()
                    try {
                        val buffer = image.planes[0].buffer
                        require(buffer.remaining() in 1..(40 * 1024 * 1024))
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                        val options =
                            BitmapFactory.Options().apply {
                                inSampleSize =
                                    ScanFrameGeometry.decodeSample(
                                        bounds.outWidth,
                                        bounds.outHeight,
                                    )
                            }
                        val raw =
                            (BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                                    ?: error("decode"))
                                .also { bitmaps.add(it) }
                        val viewport = image.cropRect
                        val crop =
                            ScanFrameGeometry.scaledCrop(
                                ScanFrameGeometry.Crop(
                                    viewport.left,
                                    viewport.top,
                                    viewport.right,
                                    viewport.bottom,
                                ),
                                image.width,
                                image.height,
                                raw.width,
                                raw.height,
                            )
                        val cut =
                            Bitmap.createBitmap(
                                    raw,
                                    crop.left,
                                    crop.top,
                                    crop.width,
                                    crop.height,
                                )
                                .also { bitmaps.add(it) }
                        val rotated =
                            Bitmap.createBitmap(
                                    cut,
                                    0,
                                    0,
                                    cut.width,
                                    cut.height,
                                    Matrix().apply {
                                        postRotate(image.imageInfo.rotationDegrees.toFloat())
                                    },
                                    true,
                                )
                                .also { bitmaps.add(it) }
                        val scale = min(1.0, 2400.0 / max(rotated.width, rotated.height))
                        val normalized =
                            Bitmap.createScaledBitmap(
                                    rotated,
                                    max(1, (rotated.width * scale).toInt()),
                                    max(1, (rotated.height * scale).toInt()),
                                    true,
                                )
                                .also { bitmaps.add(it) }
                        val factor = 300.0 / max(normalized.width, normalized.height)
                        val small =
                            Bitmap.createScaledBitmap(
                                    normalized,
                                    max(24, (normalized.width * factor).toInt()),
                                    max(24, (normalized.height * factor).toInt()),
                                    true,
                                )
                                .also { bitmaps.add(it) }
                        val pixels = IntArray(small.width * small.height)
                        small.getPixels(pixels, 0, small.width, 0, 0, small.width, small.height)
                        val luma =
                            IntArray(pixels.size) { i ->
                                val c = pixels[i]
                                (Color.red(c) * 77 + Color.green(c) * 150 + Color.blue(c) * 29) /
                                    256
                            }
                        val edges = DocumentEdges.detect(luma, small.width, small.height)
                        ByteArrayOutputStream().use { out ->
                            normalized.compress(Bitmap.CompressFormat.JPEG, 92, out)
                            store.add(out.toByteArray(), edges)
                        }
                        runOnUiThread {
                            busy = false
                            if (leaving) {
                                setResult(RESULT_OK)
                                finish()
                                return@runOnUiThread
                            }
                            updateCount()
                            status.text = "Seite gespeichert · nächste aufnehmen oder fertig"
                            shutter.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                        }
                    } catch (_: Exception) {
                        runOnUiThread {
                            busy = false
                            if (leaving) {
                                setResult(RESULT_OK)
                                finish()
                                return@runOnUiThread
                            }
                            updateCount()
                            status.text =
                                "Aufnahme konnte nicht gespeichert werden. Vorhandene Seiten bleiben erhalten."
                        }
                    } finally {
                        bitmaps.forEach { if (!it.isRecycled) it.recycle() }
                        image.close()
                    }
                }

                override fun onError(error: ImageCaptureException) {
                    runOnUiThread {
                        busy = false
                        if (leaving) {
                            setResult(RESULT_OK)
                            finish()
                            return@runOnUiThread
                        }
                        updateCount()
                        status.text = "Aufnahme fehlgeschlagen. Bitte erneut versuchen."
                    }
                }
            },
        )
    }

    private fun updateCount() {
        val count = store.count()
        done.text = "Fertig ($count)"
        done.isEnabled = !busy
        shutter.isEnabled = !busy && capture != null && count < limit
    }

    private fun leave() {
        if (busy) return
        if (store.count() == 0) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }
        AlertDialog.Builder(this)
            .setTitle("Aufnahmen übernehmen?")
            .setMessage("${store.count()} Seiten wurden gespeichert.")
            .setPositiveButton("Übernehmen") { _, _ ->
                setResult(RESULT_OK)
                finish()
            }
            .setNeutralButton("Weiter scannen", null)
            .setNegativeButton("Verwerfen") { _, _ ->
                store.discard()
                setResult(RESULT_CANCELED)
                finish()
            }
            .show()
    }

    override fun onStop() {
        super.onStop()
        if (!isFinishing && !isChangingConfigurations) {
            leaving = true
            if (!busy) {
                setResult(RESULT_CANCELED)
                finish()
            }
        }
    }

    override fun onDestroy() {
        provider?.unbindAll()
        executor.shutdown()
        super.onDestroy()
    }

    private inner class EdgeOverlay : View(this@FlexScannerActivity) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val quad = current ?: return
            val dw = min(width.toFloat(), height * imageAspect)
            val dh = dw / imageAspect
            val left = (width - dw) / 2
            val top = (height - dh) / 2
            val points =
                quad.points.map { PointF(left + it.x.toFloat() * dw, top + it.y.toFloat() * dh) }
            val path =
                Path().apply {
                    moveTo(points[0].x, points[0].y)
                    for (p in points.drop(1)) lineTo(p.x, p.y)
                    close()
                }
            paint.style = Paint.Style.FILL
            paint.color = Color.argb(30, 210, 235, 150)
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3.dp.toFloat()
            paint.color = if (stable >= 5) Color.rgb(212, 234, 151) else Color.WHITE
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.FILL
            for (p in points) canvas.drawCircle(p.x, p.y, 5.dp.toFloat(), paint)
        }
    }
}
