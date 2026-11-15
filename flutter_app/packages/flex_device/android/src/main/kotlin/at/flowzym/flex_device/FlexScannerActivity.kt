package at.flowzym.flex_device

import android.Manifest
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.graphics.*
import android.graphics.drawable.GradientDrawable
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
    private lateinit var shutter: CaptureShutter
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
    private val stability = ScanStability()
    private lateinit var thumbnail: ImageView
    private lateinit var countLabel: TextView
    private lateinit var documentMode: Button
    private lateinit var photoModeButton: Button
    @Volatile private var photoMode = false
    private var reviewing = false
    private var thumbnailBitmap: Bitmap? = null
    private var heldMessageUntil = 0L
    private var captureProgress = 0f
    private var pageCount = 0
    private var focusPoint: PointF? = null
    private var lastAnalysis = 0L
    private var lastShot = 0L
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
        photoMode = intent.getBooleanExtra("photo", false)
        automatic = getPreferences(MODE_PRIVATE).getBoolean("automatic", false)
        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(cream)
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
        val toolbar =
            LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(8.dp, 4.dp, 8.dp, 4.dp)
            }
        toolbar.addView(
            ScannerGlyph(this, "back").apply {
                contentDescription = "Zurück"
                setOnClickListener { leave() }
            },
            LinearLayout.LayoutParams(48.dp, 48.dp),
        )
        toolbar.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_VERTICAL
                addView(
                    TextView(this@FlexScannerActivity).apply {
                        text = "FLEX."
                        textSize = 10f
                        letterSpacing = .08f
                        setTextColor(olive)
                    }
                )
                addView(
                    TextView(this@FlexScannerActivity).apply {
                        text = "Aufnahme"
                        textSize = 19f
                        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                        setTextColor(Color.rgb(40, 43, 37))
                    }
                )
            },
            LinearLayout.LayoutParams(0, 52.dp, 1f),
        )
        toolbar.addView(
            ScannerGlyph(this, "light").apply {
                contentDescription = "Kameralicht einschalten"
                setOnClickListener {
                    camera?.let { camera ->
                        if (camera.cameraInfo.hasFlashUnit()) {
                            flash = !flash
                            camera.cameraControl.enableTorch(flash)
                            isSelected = flash
                            contentDescription =
                                if (flash) "Kameralicht ausschalten" else "Kameralicht einschalten"
                        } else message("Kein Kameralicht verfügbar")
                    }
                }
            },
            LinearLayout.LayoutParams(48.dp, 48.dp),
        )
        root.addView(toolbar)
        val frame = FrameLayout(this).apply { setBackgroundColor(Color.rgb(24, 26, 23)) }
        preview =
            PreviewView(this).apply {
                scaleType = PreviewView.ScaleType.FIT_CENTER
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            }
        frame.addView(preview, FrameLayout.LayoutParams(-1, -1))
        overlay = EdgeOverlay()
        frame.addView(overlay, FrameLayout.LayoutParams(-1, -1))
        status =
            TextView(this).apply {
                text = "Kamera wird gestartet …"
                setTextColor(Color.WHITE)
                textSize = 13f
                gravity = Gravity.CENTER
                setPadding(16.dp, 10.dp, 16.dp, 10.dp)
                background = shape(Color.argb(210, 30, 33, 27), 22f)
                accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
            }
        frame.addView(
            status,
            FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
                setMargins(16.dp, 12.dp, 16.dp, 18.dp)
            },
        )
        root.addView(frame, LinearLayout.LayoutParams(-1, 0, 1f))
        val modes =
            LinearLayout(this).apply {
                gravity = Gravity.CENTER
                setPadding(16.dp, 10.dp, 16.dp, 0)
            }
        documentMode = button("Dokument") { setPhotoMode(false) }
        photoModeButton = button("Foto") { setPhotoMode(true) }
        modes.addView(documentMode, LinearLayout.LayoutParams(0, 44.dp, 1f))
        modes.addView(photoModeButton, LinearLayout.LayoutParams(0, 44.dp, 1f))
        autoButton =
            button(if (automatic) "Auto an" else "Auto aus") {
                automatic = !automatic
                getPreferences(MODE_PRIVATE).edit().putBoolean("automatic", automatic).apply()
                stability.restartCountdown()
                updateModes()
            }
        modes.addView(autoButton, LinearLayout.LayoutParams(0, 44.dp, 1f))
        root.addView(modes)
        val actions =
            LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(20.dp, 2.dp, 20.dp, 8.dp)
            }
        val stack =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
            }
        thumbnail =
            ImageView(this).apply {
                contentDescription = "Letzte Aufnahme ansehen"
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = shape(Color.rgb(231, 231, 220), 10f)
                clipToOutline = true
                isFocusable = true
                setOnClickListener { showLastCapture() }
            }
        stack.addView(thumbnail, LinearLayout.LayoutParams(48.dp, 56.dp))
        countLabel =
            TextView(this).apply {
                textSize = 11f
                gravity = Gravity.CENTER
                setTextColor(olive)
            }
        stack.addView(countLabel)
        actions.addView(stack, LinearLayout.LayoutParams(0, -2, 1f))
        shutter =
            CaptureShutter(this).apply {
                isEnabled = false
                setOnClickListener { takePhoto() }
            }
        actions.addView(shutter, LinearLayout.LayoutParams(96.dp, 96.dp))
        done =
            button("Weiter") {
                setResult(RESULT_OK)
                finish()
            }
        actions.addView(done, LinearLayout.LayoutParams(0, 48.dp, 1f))
        root.addView(actions)
        updateModes()
        updateCount()
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
            if (event.action == MotionEvent.ACTION_UP && !zoom.isInProgress) {
                focusPoint = PointF(event.x, event.y)
                overlay.invalidate()
                overlay.postDelayed(
                    {
                        focusPoint = null
                        overlay.invalidate()
                    },
                    700,
                )
                stability.restartCountdown()
                camera
                    ?.cameraControl
                    ?.startFocusAndMetering(
                        FocusMeteringAction.Builder(
                                preview.meteringPointFactory.createPoint(event.x, event.y)
                            )
                            .build()
                    )
            }
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

    private fun shape(color: Int, radius: Float) =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius * resources.displayMetrics.density
        }

    private fun button(label: String, action: () -> Unit) =
        Button(this).apply {
            text = label
            isAllCaps = false
            textSize = 13f
            setTextColor(olive)
            minWidth = 0
            minimumWidth = 0
            minHeight = 44.dp
            setPadding(6.dp, 0, 6.dp, 0)
            stateListAnimator = null
            background = shape(Color.TRANSPARENT, 22f)
            setOnClickListener { action() }
        }

    private fun showStatus(text: String) {
        if (status.text.toString() != text) status.text = text
    }

    private fun message(text: String) {
        showStatus(text)
        heldMessageUntil = SystemClock.elapsedRealtime() + 2200
    }

    private fun setPhotoMode(photo: Boolean) {
        if (busy) return
        photoMode = photo
        current = null
        stability.reset()
        updateModes()
        message(
            if (photo) "Foto · ohne automatischen Zuschnitt"
            else "Alle vier Dokumentränder ins Bild bringen"
        )
    }

    private fun updateModes() {
        for ((view, active) in listOf(documentMode to !photoMode, photoModeButton to photoMode)) {
            view.background =
                shape(if (active) Color.rgb(224, 228, 211) else Color.TRANSPARENT, 22f)
            view.isSelected = active
            view.isEnabled = !busy
        }
        autoButton.text = if (automatic) "Auto an" else "Auto aus"
        autoButton.isSelected = automatic && !photoMode
        autoButton.isEnabled = !photoMode && !busy
        autoButton.contentDescription =
            if (automatic) "Automatische Aufnahme ausschalten"
            else "Automatische Aufnahme einschalten"
        autoButton.alpha = if (photoMode) .35f else 1f
        shutter.progress = 0f
        overlay.invalidate()
    }

    private fun refreshThumbnail() {
        executor.execute {
            val bitmap =
                try {
                    store.lastImage()?.let { bytes ->
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                        var sample = 1
                        while (max(bounds.outWidth, bounds.outHeight) / sample > 200) sample *= 2
                        BitmapFactory.decodeByteArray(
                            bytes,
                            0,
                            bytes.size,
                            BitmapFactory.Options().apply { inSampleSize = sample },
                        )
                    }
                } catch (_: Exception) {
                    null
                }
            runOnUiThread {
                if (isDestroyed || isFinishing) {
                    bitmap?.recycle()
                    return@runOnUiThread
                }
                val previous = thumbnailBitmap
                thumbnailBitmap = bitmap
                thumbnail.setImageBitmap(bitmap)
                previous?.recycle()
            }
        }
    }

    private fun showLastCapture() {
        if (busy || reviewing || store.count() == 0) return
        reviewing = true
        stability.restartCountdown()
        val picture =
            ImageView(this).apply {
                setImageBitmap(thumbnailBitmap)
                adjustViewBounds = true
                scaleType = ImageView.ScaleType.FIT_CENTER
                setPadding(12.dp, 12.dp, 12.dp, 12.dp)
            }
        val dialog =
            AlertDialog.Builder(this)
                .setTitle("Aufnahme ${store.count()}")
                .setView(picture)
                .setPositiveButton("Weiter scannen", null)
                .setNegativeButton("Entfernen") { _, _ ->
                    store.lastToken()?.let { store.acknowledge(it) }
                    updateCount()
                }
                .create()
        var fullImage: Bitmap? = null
        dialog.setOnDismissListener {
            reviewing = false
            stability.restartCountdown()
            picture.setImageDrawable(null)
            fullImage?.recycle()
        }
        dialog.show()
        dialog.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        executor.execute {
            val bitmap =
                try {
                    store.lastImage()?.let { bytes ->
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                        var sample = 1
                        while (max(bounds.outWidth, bounds.outHeight) / sample > 1200) sample *= 2
                        BitmapFactory.decodeByteArray(
                            bytes,
                            0,
                            bytes.size,
                            BitmapFactory.Options().apply { inSampleSize = sample },
                        )
                    }
                } catch (_: Exception) {
                    null
                }
            runOnUiThread {
                if (!dialog.isShowing || isDestroyed) bitmap?.recycle()
                else if (bitmap != null) {
                    fullImage = bitmap
                    picture.setImageBitmap(bitmap)
                }
            }
        }
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
                    message(
                        if (photoMode) "Foto aufnehmen · Antippen zum Scharfstellen"
                        else "Dokument ins Bild bringen · Ränder werden live erkannt"
                    )
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
            val wasPhoto = photoMode
            val found = if (wasPhoto) null else DocumentEdges.detect(values, sw, sh)
            val brightness = values.average()
            runOnUiThread {
                if (isFinishing || isDestroyed) return@runOnUiThread
                imageAspect = sw.toFloat() / sh
                if (busy || reviewing || wasPhoto != photoMode || now < lastShot)
                    return@runOnUiThread
                val frame = stability.update(found, now)
                current = if (photoMode) null else frame.quad
                captureProgress = if (automatic && !photoMode) frame.progress else 0f
                shutter.progress = captureProgress
                overlay.invalidate()
                if (now >= heldMessageUntil) {
                    showStatus(
                        when {
                            pageCount >= limit -> "Serie vollständig · Weiter zur Bearbeitung"
                            photoMode -> "Foto · Antippen zum Scharfstellen"
                            automatic && frame.nextPage -> "Gespeichert · nächste Seite einlegen"
                            found == null && brightness < 55 ->
                                "Mehr Licht hilft bei der Kantenerkennung"
                            found == null -> "Alle vier Dokumentränder ins Bild bringen"
                            found.confidence < .8 -> "Ränder prüfen · manuell aufnehmen"
                            frame.progress < .35f -> "Ränder gefunden · ruhig halten"
                            automatic -> "Ruhig halten · automatische Aufnahme"
                            else -> "Ränder erkannt · bereit zur Aufnahme"
                        }
                    )
                }
                if (automatic && !photoMode && frame.ready && !reviewing) takePhoto()
            }
        } catch (_: Exception) {
            /* A failed analysis never interrupts the camera. */
        } finally {
            image.close()
        }
    }

    private fun takePhoto() {
        val still = capture ?: return
        if (busy || leaving || isFinishing || pageCount >= limit) return
        busy = true
        shutter.isEnabled = false
        done.isEnabled = false
        updateModes()
        val takingPhoto = photoMode
        status.text = "Aufnahme wird gesichert …"
        lastShot = SystemClock.elapsedRealtime()
        stability.didCapture(lastShot)
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
                        val edges =
                            if (takingPhoto) null
                            else DocumentEdges.detect(luma, small.width, small.height)
                        ByteArrayOutputStream().use { out ->
                            normalized.compress(Bitmap.CompressFormat.JPEG, 92, out)
                            store.add(out.toByteArray(), edges, takingPhoto)
                        }
                        runOnUiThread {
                            busy = false
                            if (leaving) {
                                setResult(RESULT_OK)
                                finish()
                                return@runOnUiThread
                            }
                            updateCount()
                            message("Aufnahme ${store.count()} gespeichert")
                            overlay
                                .animate()
                                .alpha(.2f)
                                .setDuration(90)
                                .withEndAction {
                                    overlay.animate().alpha(1f).setDuration(160).start()
                                }
                                .start()
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
        pageCount = count
        countLabel.text = "$count / $limit"
        done.text = if (count == 0) "Weiter" else "Weiter ($count)"
        done.isEnabled = !busy && count > 0
        done.background = shape(if (count > 0) olive else Color.rgb(231, 231, 220), 24f)
        done.setTextColor(if (count > 0) Color.WHITE else olive)
        thumbnail.isEnabled = count > 0 && !busy
        shutter.isEnabled = !busy && capture != null && count < limit
        updateModes()
        refreshThumbnail()
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
        if (::thumbnail.isInitialized) thumbnail.setImageDrawable(null)
        thumbnailBitmap?.recycle()
        super.onDestroy()
    }

    private inner class EdgeOverlay : View(this@FlexScannerActivity) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            focusPoint?.let { point ->
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 2.dp.toFloat()
                paint.color = Color.WHITE
                canvas.drawCircle(point.x, point.y, 24.dp.toFloat(), paint)
            }
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
            paint.color = Color.argb(26, 218, 230, 181)
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3.dp.toFloat()
            paint.color = if (captureProgress > .35f) Color.rgb(207, 223, 164) else Color.WHITE
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.FILL
            for (p in points) canvas.drawCircle(p.x, p.y, 5.dp.toFloat(), paint)
        }
    }
}
