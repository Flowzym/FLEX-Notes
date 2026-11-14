package at.flowzym.flex_device

import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/** Bound bitmap allocation before decoding, and retain CameraX viewport edges. */
internal object ScanFrameGeometry {
    data class Crop(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width
            get() = right - left

        val height
            get() = bottom - top
    }

    fun decodeSample(width: Int, height: Int): Int {
        require(width in 1..65535 && height in 1..65535)
        var sample = 1
        while (ceil(max(width, height).toDouble() / sample) > 3200) sample *= 2
        return sample
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
