package at.flowzym.flex_device

import android.content.Context
import android.graphics.*
import android.view.View

/** Native camera controls use the same restrained cream/olive palette as FLEX. */
internal class CaptureShutter(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    var progress = 0f
        set(value) {
            field = value
            invalidate()
        }

    init {
        contentDescription = "Aufnehmen"
        isClickable = true
        isFocusable = true
    }

    override fun onDraw(canvas: Canvas) {
        val size = minOf(width, height).toFloat()
        val r = size * .38f
        val x = width / 2f
        val y = height / 2f
        paint.color = Color.rgb(98, 109, 67)
        paint.alpha = if (isEnabled) 255 else 80
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = size * .025f
        canvas.drawCircle(x, y, r, paint)
        paint.style = Paint.Style.FILL
        canvas.drawCircle(x, y, r - size * .07f, paint)
        if (progress > 0f) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = size * .055f
            paint.strokeCap = Paint.Cap.ROUND
            canvas.drawArc(RectF(x - r, y - r, x + r, y + r), -90f, 360 * progress, false, paint)
        }
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        invalidate()
    }
}

internal class ScannerGlyph(context: Context, private val glyph: String) : View(context) {
    private val paint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            strokeWidth = 1.8f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            style = Paint.Style.STROKE
            color = Color.rgb(98, 109, 67)
        }

    init {
        isClickable = true
        isFocusable = true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val size = 24 * resources.displayMetrics.density
        canvas.save()
        canvas.translate((width - size) / 2, (height - size) / 2)
        canvas.scale(size / 24, size / 24)
        paint.alpha = if (isEnabled) 255 else 90
        when (glyph) {
            "back" -> {
                canvas.drawLine(19f, 12f, 5f, 12f, paint)
                canvas.drawLine(5f, 12f, 11f, 6f, paint)
                canvas.drawLine(5f, 12f, 11f, 18f, paint)
            }
            "light" -> {
                val path =
                    Path().apply {
                        moveTo(13f, 2f)
                        lineTo(5f, 13f)
                        lineTo(11f, 13f)
                        lineTo(10f, 22f)
                        lineTo(19f, 10f)
                        lineTo(13f, 10f)
                        close()
                    }
                if (isSelected) paint.style = Paint.Style.FILL
                canvas.drawPath(path, paint)
                paint.style = Paint.Style.STROKE
            }
        }
        canvas.restore()
    }

    override fun setSelected(selected: Boolean) {
        super.setSelected(selected)
        invalidate()
    }
}
