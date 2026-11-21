package at.flowzym.flex_device

import kotlin.math.hypot

/** Time-based capture gate. A single lost frame must never re-arm a batch. */
class ScanStability {
    data class Frame(
        val quad: DocumentEdges.Quad?,
        val progress: Float,
        val ready: Boolean,
        val nextPage: Boolean,
    )

    private var anchor: DocumentEdges.Quad? = null
    private var displayed: DocumentEdges.Quad? = null
    private var started = 0L
    private var samples = 0
    private var lastSeen = 0L
    private var captured: DocumentEdges.Quad? = null
    private var lastShot = -2000L
    private var movementSince: Long? = null
    private var missingSince: Long? = null

    private fun distance(a: DocumentEdges.Quad?, b: DocumentEdges.Quad?): Double =
        if (a == null || b == null) 1.0
        else a.points.zip(b.points).maxOf { (p, q) -> hypot(p.x - q.x, p.y - q.y) }

    fun restartCountdown() {
        anchor = null
        samples = 0
    }

    fun reset() {
        anchor = null
        displayed = null
        captured = null
        samples = 0
        movementSince = null
        missingSince = null
    }

    fun didCapture(now: Long) {
        captured = anchor ?: displayed
        lastShot = now
        samples = 0
        anchor = null
        movementSince = null
        missingSince = null
    }

    fun update(found: DocumentEdges.Quad?, now: Long): Frame {
        if (captured != null) {
            if (found == null) {
                if (missingSince == null) missingSince = now
                if (now - missingSince!! >= 500) captured = null
            } else {
                missingSince = null
                if (distance(captured, found) > .12) {
                    if (movementSince == null) movementSince = now
                    if (now - movementSince!! >= 350) captured = null
                } else movementSince = null
            }
        }
        if (found == null || found.confidence < .8) {
            anchor = null
            samples = 0
            if (found != null) {
                displayed = found
                lastSeen = now
            } else if (now - lastSeen > 250) displayed = null
            return Frame(displayed, 0f, false, captured != null)
        }
        lastSeen = now
        val old = displayed
        displayed =
            if (old == null || distance(old, found) > .08) found
            else
                DocumentEdges.Quad(
                    old.points.zip(found.points).map { (p, q) ->
                        DocumentEdges.Point(p.x * .6 + q.x * .4, p.y * .6 + q.y * .4)
                    },
                    found.confidence,
                )
        if (anchor == null || distance(anchor, found) > .018) {
            anchor = found
            started = now
            samples = 1
        } else samples++
        val progress =
            if (captured == null && now - lastShot >= 1800)
                ((now - started) / 1000f).coerceIn(0f, 1f)
            else 0f
        return Frame(displayed, progress, progress >= 1f && samples >= 6, captured != null)
    }
}
