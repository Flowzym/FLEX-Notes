package at.flowzym.flex_device

import kotlin.math.ceil
import org.junit.Assert.*
import org.junit.Test

class ScanFrameGeometryTest {
    @Test
    fun highResolutionSensorsStayBoundedBeforeBitmapAllocation() {
        for ((width, height) in listOf(4000 to 3000, 12000 to 9000, 16384 to 12288, 3001 to 2001)) {
            val sample = ScanFrameGeometry.decodeSample(width, height)
            val decodedWidth = ceil(width.toDouble() / sample).toInt()
            val decodedHeight = ceil(height.toDouble() / sample).toInt()
            assertTrue(decodedWidth <= 3200 && decodedHeight <= 3200)
            val crop =
                ScanFrameGeometry.scaledCrop(
                    ScanFrameGeometry.Crop(0, 0, width, height),
                    width,
                    height,
                    decodedWidth,
                    decodedHeight,
                )
            assertEquals(decodedWidth, crop.width)
            assertEquals(decodedHeight, crop.height)
        }
    }

    @Test
    fun viewportIncludesBoundaryPixelsAfterDownsampling() {
        val crop =
            ScanFrameGeometry.scaledCrop(
                ScanFrameGeometry.Crop(101, 203, 3987, 2799),
                4000,
                3000,
                2000,
                1500,
            )
        assertEquals(ScanFrameGeometry.Crop(50, 101, 1994, 1400), crop)
        val tiny =
            ScanFrameGeometry.scaledCrop(
                ScanFrameGeometry.Crop(3999, 2999, 4000, 3000),
                4000,
                3000,
                500,
                375,
            )
        assertEquals(1, tiny.width)
        assertEquals(1, tiny.height)
    }
    @Test
    fun storedOutlineControlsTheThumbnailAndFullPreviewAspectRatio() {
        val saved = floatArrayOf(.1f, .2f, .9f, .2f, .9f, .8f, .1f, .8f)
        val page = requireNotNull(ScanFrameGeometry.preview(saved, 1000, 600, 400))
        assertEquals(400, page.width)
        assertEquals(180, page.height)
        assertEquals(100f, page.corners[0])
        assertEquals(120f, page.corners[1])
        assertEquals(null, ScanFrameGeometry.preview(FloatArray(8), 1000, 600, 400))
        assertEquals(null, ScanFrameGeometry.preview(floatArrayOf(Float.NaN), 1000, 600, 400))
        assertEquals(8, ScanFrameGeometry.decodeSample(1200, 600, 200))
    }
}
