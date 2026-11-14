package at.flowzym.flex_device

import kotlin.math.*

/** Bounded luminance-only detector. No Android, service or network dependency. */
object DocumentEdges {
    data class Point(val x: Double, val y: Double)

    data class Quad(val points: List<Point>, val confidence: Double)

    private fun cross(a: Point, b: Point, c: Point) =
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

    private fun area(p: List<Point>) =
        abs(
            p.indices.sumOf { i ->
                val a = p[i]
                val b = p[(i + 1) % p.size]
                a.x * b.y - b.x * a.y
            }
        ) / 2

    private fun hull(input: List<Point>): List<Point> {
        val points = input.distinct().sortedWith(compareBy<Point> { it.x }.thenBy { it.y })
        if (points.size < 4) return emptyList()
        val lower = mutableListOf<Point>()
        val upper = mutableListOf<Point>()
        for (p in points) {
            while (lower.size >= 2 && cross(lower[lower.size - 2], lower.last(), p) <= 0) lower
                .removeAt(lower.lastIndex)
            lower.add(p)
        }
        for (p in points.asReversed()) {
            while (upper.size >= 2 && cross(upper[upper.size - 2], upper.last(), p) <= 0) upper
                .removeAt(upper.lastIndex)
            upper.add(p)
        }
        return lower.dropLast(1) + upper.dropLast(1)
    }

    fun detect(luma: IntArray, width: Int, height: Int): Quad? {
        require(width in 24..640 && height in 24..640 && luma.size == width * height)
        val histogram = IntArray(256)
        luma.forEach { histogram[it.coerceIn(0, 255)]++ }
        fun percentile(f: Double): Int {
            var n = 0
            for (i in histogram.indices) {
                n += histogram[i]
                if (n >= luma.size * f) return i
            }
            return 255
        }
        val low = percentile(0.15)
        val high = percentile(0.85)
        if (high - low < 18) return null
        val gradient = IntArray(luma.size)
        for (y in 1 until height - 1) for (x in 1 until width - 1) {
            val i = y * width + x
            val gx =
                luma[i - width + 1] + 2 * luma[i + 1] + luma[i + width + 1] -
                    luma[i - width - 1] -
                    2 * luma[i - 1] -
                    luma[i + width - 1]
            val gy =
                luma[i + width - 1] + 2 * luma[i + width] + luma[i + width + 1] -
                    luma[i - width - 1] -
                    2 * luma[i - width] -
                    luma[i - width + 1]
            gradient[i] = abs(gx) + abs(gy)
        }
        val edgeThreshold = max(50, (high - low) * 2)
        val edges = BooleanArray(luma.size)
        for (y in 2 until height - 2) for (x in 2 until width - 2) if (
            gradient[y * width + x] > edgeThreshold
        ) {
            for (dy in -1..1) for (dx in -1..1) edges[(y + dy) * width + x + dx] = true
        }
        val masks =
            listOf(
                edges,
                BooleanArray(luma.size) { luma[it] > (low + high) / 2 },
                BooleanArray(luma.size) { luma[it] < (low + high) / 2 },
            )
        var best: Quad? = null
        var bestScore = 0.0
        for (mask in masks) {
            val visited = BooleanArray(luma.size)
            val queue = IntArray(luma.size)
            for (seed in mask.indices) {
                if (!mask[seed] || visited[seed]) continue
                var read = 0
                var count = 1
                queue[0] = seed
                visited[seed] = true
                while (read < count) {
                    val index = queue[read++]
                    val x = index % width
                    val y = index / width
                    for (next in
                        intArrayOf(
                            if (x > 0) index - 1 else -1,
                            if (x < width - 1) index + 1 else -1,
                            if (y > 0) index - width else -1,
                            if (y < height - 1) index + width else -1,
                        )) {
                        if (next >= 0 && mask[next] && !visited[next]) {
                            visited[next] = true
                            queue[count++] = next
                        }
                    }
                }
                if (count < width + height || count > luma.size * 0.94) continue
                val boundary = mutableListOf<Point>()
                for (i in 0 until count) {
                    val at = queue[i]
                    val x = at % width
                    val y = at / width
                    if (
                        x == 0 ||
                            y == 0 ||
                            x == width - 1 ||
                            y == height - 1 ||
                            !mask[at - 1] ||
                            !mask[at + 1] ||
                            !mask[at - width] ||
                            !mask[at + width]
                    )
                        boundary.add(Point(x.toDouble(), y.toDouble()))
                }
                val original = hull(boundary)
                val polygon = original.toMutableList()
                if (polygon.size < 4) continue
                while (polygon.size > 4) {
                    val remove =
                        polygon.indices.minBy { i ->
                            abs(
                                cross(
                                    polygon[(i + polygon.size - 1) % polygon.size],
                                    polygon[i],
                                    polygon[(i + 1) % polygon.size],
                                )
                            )
                        }
                    polygon.removeAt(remove)
                }
                val a = area(polygon)
                val ratio = a / (width * height)
                if (ratio !in 0.13..0.92 || a / area(original) < 0.88) continue
                if (polygon.any { it.x < 3 || it.y < 3 || it.x > width - 4 || it.y > height - 4 })
                    continue
                var angleQuality = 1.0
                for (i in 0..3) {
                    val p = polygon[i]
                    val prev = polygon[(i + 3) % 4]
                    val next = polygon[(i + 1) % 4]
                    val ax = prev.x - p.x
                    val ay = prev.y - p.y
                    val bx = next.x - p.x
                    val by = next.y - p.y
                    val lengths = hypot(ax, ay) * hypot(bx, by)
                    if (lengths < width * height * 0.02) {
                        angleQuality = 0.0
                        break
                    }
                    val cosine = abs((ax * bx + ay * by) / lengths)
                    if (cosine > 0.78) {
                        angleQuality = 0.0
                        break
                    }
                    angleQuality = min(angleQuality, 1 - cosine)
                }
                if (angleQuality == 0.0) continue
                var hits = 0
                var samples = 0
                for (i in 0..3) {
                    val p = polygon[i]
                    val q = polygon[(i + 1) % 4]
                    for (step in 0..30) {
                        val x = (p.x + (q.x - p.x) * step / 30).roundToInt()
                        val y = (p.y + (q.y - p.y) * step / 30).roundToInt()
                        var hit = false
                        for (dy in -2..2) for (dx in -2..2) {
                            val nx = x + dx
                            val ny = y + dy
                            if (
                                nx in 1 until width - 1 &&
                                    ny in 1 until height - 1 &&
                                    gradient[ny * width + nx] > edgeThreshold
                            )
                                hit = true
                        }
                        if (hit) hits++
                        samples++
                    }
                }
                val support = hits.toDouble() / samples
                if (support < 0.55) continue
                val score = ratio * 0.5 + angleQuality * 0.2 + support * 0.3
                if (score > bestScore) {
                    val first =
                        polygon.indices.minBy { polygon[it].x / width + polygon[it].y / height }
                    val ordered =
                        (0..3)
                            .map { polygon[(first + it) % 4] }
                            .map { Point(it.x / (width - 1), it.y / (height - 1)) }
                    best = Quad(ordered, min(1.0, support * 0.75 + angleQuality * 0.25))
                    bestScore = score
                }
            }
        }
        return best
    }
}
