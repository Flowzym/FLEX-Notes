package at.flowzym.flex_device

/** All MSAL cache operations run in order, including across Flutter engines.
 * Callers dispatch both submission and completion onto the Android main thread.
 * In particular sign-out must run after a pending refresh has written its cache.
 */
internal class OneDriveAuthQueue {
    private val jobs = ArrayDeque<((() -> Unit) -> Unit)>()

    fun submit(work: (() -> Unit) -> Unit) {
        jobs.addLast(work)
        if (jobs.size == 1) start()
    }

    private fun start() {
        var finished = false
        jobs.first().invoke {
            if (!finished) {
                finished = true
                jobs.removeFirst()
                if (jobs.isNotEmpty()) start()
            }
        }
    }
}
