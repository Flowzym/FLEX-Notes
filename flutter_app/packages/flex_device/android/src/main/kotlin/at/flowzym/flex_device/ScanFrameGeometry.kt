package at.flowzym.flex_device

import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Bound bitmap allocation before decoding, and retain CameraX viewport edges. */
internal object ScanFrameGeometry {
    data class Crop(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width
            get() = right - left

        val height
            get() = bottom - top
    }

    fun decodeSample(width: Int, height: Int, maxSide: Int = 3200): Int {
        require(width in 1..65535 && height in 1..65535 && maxSide > 0)
        var sample = 1
        while (ceil(max(width, height).toDouble() / sample) > maxSide) sample *= 2
        return sample
    }

    data class Preview(val corners: FloatArray, val width: Int, val height: Int)

    fun preview(outline: FloatArray, width: Int, height: Int, maxSide: Int): Preview? {
        if (outline.size != 8 || outline.any { !it.isFinite() || it !in 0f..1f }) return null
        val corners = FloatArray(8) { i -> outline[i] * (if (i % 2 == 0) width else height) }
        fun distance(a: Int, b: Int) = hypot(
            corners[2 * a] - corners[2 * b], corners[2 * a + 1] - corners[2 * b + 1],
        )
        val w = max(distance(0, 1), distance(3, 2))
        val h = max(distance(0, 3), distance(1, 2))
        if (w < 1 || h < 1) return null
        val scale = min(1f, maxSide / max(w, h))
        return Preview(corners, max(1, (w * scale).roundToInt()), max(1, (h * scale).roundToInt()))
    }

    fun scaledCrop(crop: Crop, sourceWidth: Int, sourceHeight: Int, width: Int, height: Int): Crop {
        require(sourceWidth > 0 && sourceHeight > 0 && width > 0 && height > 0)
        val left = floor(crop.left.toDouble() * width / sourceWidth).toInt().coerceIn(0, width - 1)
        val top = floor(crop.top.toDouble() * height / sourceHeight).toInt().coerceIn(0, height - 1)
        return Crop(
            left,
            top,
            ceil(crop.right.toDouble() * width / sourceWidth).toInt().coerceIn(left + 1, width),
            ceil(crop.bottom.toDouble() * height / sourceHeight).toInt().coerceIn(top + 1, height),
        )
    }
}
