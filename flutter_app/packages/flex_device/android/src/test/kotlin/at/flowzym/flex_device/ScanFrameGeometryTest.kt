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
}
