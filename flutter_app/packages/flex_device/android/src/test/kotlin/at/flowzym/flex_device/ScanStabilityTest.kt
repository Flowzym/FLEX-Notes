package at.flowzym.flex_device

import org.junit.Assert.*
import org.junit.Test

class ScanStabilityTest {
    private fun quad(shift: Double = 0.0) =
        DocumentEdges.Quad(
            listOf(.1 to .1, .8 to .1, .8 to .9, .1 to .9).map {
                DocumentEdges.Point(it.first + shift, it.second)
            },
            .95,
        )

    @Test
    fun waitsForTimeAndEnoughSamples() {
        val s = ScanStability()
        for (time in listOf(0L, 400L, 600L, 800L, 900L)) assertFalse(s.update(quad(), time).ready)
        assertTrue(s.update(quad(), 1200).ready)
        val slow = ScanStability()
        slow.update(quad(), 0)
        assertFalse(slow.update(quad(), 1500).ready)
    }

    @Test
    fun slowContinuousMovementDoesNotTriggerAShot() {
        val s = ScanStability()
        for (n in 0..20) assertFalse(s.update(quad(n * .006), n * 130L).ready)
    }

    @Test
    fun lostOrUncertainEdgesStopTheCountdown() {
        val s = ScanStability()
        for (n in 0..7) s.update(quad(), n * 130L)
        assertFalse(s.update(null, 1000).ready)
        assertEquals(0f, s.update(quad(), 1130).progress, .001f)
        assertFalse(s.update(quad().copy(confidence = .6), 2500).ready)
    }

    @Test
    fun oneLostFrameDoesNotDuplicateAPage() {
        val s = ScanStability()
        for (n in 0..8) s.update(quad(), n * 130L)
        s.didCapture(1100)
        s.update(null, 1500)
        s.restartCountdown()
        for (n in 12..40) assertFalse(s.update(quad(), n * 130L).ready)
        assertTrue(s.update(quad(), 5400).nextPage)
    }

    @Test
    fun removingThePageRearmsEvenAtTheSamePosition() {
        val s = ScanStability()
        s.update(quad(), 0)
        s.didCapture(1000)
        s.update(null, 2000)
        s.update(null, 2600)
        for (n in 0..8) s.update(quad(), 3000 + n * 130L)
        assertTrue(s.update(quad(), 4200).ready)
    }
}
