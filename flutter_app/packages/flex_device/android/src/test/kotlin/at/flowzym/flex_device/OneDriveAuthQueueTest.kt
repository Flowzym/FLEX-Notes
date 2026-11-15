package at.flowzym.flex_device

import org.junit.Assert.*
import org.junit.Test

class OneDriveAuthQueueTest {
    @Test fun signOutWaitsForPendingCacheWrites() {
        val queue = OneDriveAuthQueue()
        var cache: String? = "old token"
        var completeRefresh: (() -> Unit)? = null
        queue.submit { done -> completeRefresh = { cache = "refreshed token"; done() } }
        queue.submit { done -> cache = null; done() }
        assertEquals("old token", cache)
        completeRefresh!!.invoke()
        assertNull(cache)
    }

    @Test fun duplicateCallbackCannotAdvanceOrSkipAnotherOperation() {
        val queue = OneDriveAuthQueue()
        var first: (() -> Unit)? = null
        var second: (() -> Unit)? = null
        val started = mutableListOf<Int>()
        queue.submit { done -> started.add(1); first = done }
        queue.submit { done -> started.add(2); second = done }
        queue.submit { done -> started.add(3); done() }
        val completeFirst = requireNotNull(first)
        completeFirst()
        completeFirst()
        assertEquals(listOf(1, 2), started)
        second!!.invoke()
        assertEquals(listOf(1, 2, 3), started)
    }
}
