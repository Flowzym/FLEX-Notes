package at.flowzym.flex_device

import kotlin.math.*
import org.junit.Assert.*
import org.junit.Test

class DocumentEdgesTest {
    private val w = 240
    private val h = 320

    private fun page(inverted: Boolean = false, skew: Boolean = false): IntArray =
        IntArray(w * h) { i ->
            val x = i % w
            val y = i / w
            val left = if (skew) 30 + y / 18 else 32
            val right = if (skew) 210 - y / 24 else 208
            val inside = y in 35..285 && x in left..right
            val base = if (inside) 220 - (y / 10) else 35 + (x / 16)
            val text = inside && y % 23 in 8..10 && x in left + 12..right - 16
            val v = if (text) 70 else base + (i * 13 % 7) - 3
            if (inverted) 255 - v else v
        }

    @Test
    fun findsPaperWithTextAndGradient() {
        val quad = DocumentEdges.detect(page(), w, h)
        assertNotNull(quad)
        assertEquals(4, quad!!.points.size)
        val expected =
            listOf(
                32.0 / 239 to 35.0 / 319,
                208.0 / 239 to 35.0 / 319,
                208.0 / 239 to 285.0 / 319,
                32.0 / 239 to 285.0 / 319,
            )
        quad.points.zip(expected).forEach { (point, pair) ->
            assertEquals(pair.first, point.x, 0.04)
            assertEquals(pair.second, point.y, 0.04)
        }
        assertTrue(quad.confidence > 0.8)
    }

    @Test
    fun detectsPerspectiveAndDarkPaper() {
        for (inverted in listOf(false, true)) {
            val quad = DocumentEdges.detect(page(inverted, true), w, h)
            assertNotNull(quad)
            assertTrue(quad!!.points[0].x < quad.points[3].x)
            assertTrue(quad.points[1].x > quad.points[2].x)
        }
    }

    @Test
    fun detectsPalePaperOnALightDeskWithoutInventingEdgesInNoise() {
        val frame =
            IntArray(w * h) { i ->
                val inside = i % w in 32..208 && i / w in 35..285
                (if (inside) 199 else 183) + (i * 13 % 3) - 1
            }
        val quad = DocumentEdges.detect(frame, w, h)
        assertNotNull(quad)
        assertEquals(32.0 / 239, quad!!.points[0].x, .04)
        assertEquals(285.0 / 319, quad.points[2].y, .04)
        assertNull(DocumentEdges.detect(IntArray(w * h) { 183 + (it * 13 % 7) }, w, h))
    }

    @Test
    fun rejectsUniformOrCutOffFrames() {
        assertNull(DocumentEdges.detect(IntArray(w * h) { 160 }, w, h))
        assertNull(DocumentEdges.detect(IntArray(w * h) { if (it % w < 100) 35 else 230 }, w, h))
    }

    @Test
    fun boundedInputRejectsOversizedOrTruncatedFrames() {
        for (block in
            listOf<() -> Unit>(
                { DocumentEdges.detect(IntArray(5), w, h) },
                { DocumentEdges.detect(IntArray(700 * 700), 700, 700) },
            )) {
            try {
                block()
                fail("input must be rejected")
            } catch (_: IllegalArgumentException) {}
        }
    }
}
