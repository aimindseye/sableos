package org.sableos.messages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderSmsConversationMapperTest {
    private fun row(
        id: Long, thread: Long, date: Long, address: String = "+15550001111",
        body: String = "Hello", incoming: Boolean = true, read: Boolean = false,
    ) = ProviderSmsRow(id, thread, address, body, date, incoming, read)

    @Test fun producesLiveLatestFirstConversationAndChronologicalMessages() {
        val threads = ProviderSmsConversationMapper.map(
            listOf(
                row(1, 101, 100, body = "Old"),
                row(2, 101, 300, body = "New", incoming = false, read = true),
                row(3, 202, 200, address = "+15550002222", body = "Second"),
            ),
        )
        assertEquals(listOf("101", "202"), threads.map { it.id })
        assertEquals(listOf("Old", "New"), threads[0].messages.map { it.body })
        assertEquals(1, threads[0].unreadCount)
        assertFalse(threads[0].messages[1].incoming)
        assertEquals("+15550001111", threads[0].route)
        assertEquals("Android SMS provider · read-only", threads[0].source)
    }

    @Test fun refusesMissingRecipientAndInvalidThreadWithoutFakeData() {
        val rows = listOf(row(1, 0, 10), row(2, 1, 20, address = ""))
        assertTrue(ProviderSmsConversationMapper.map(rows).isEmpty())
    }

    @Test fun capsMessagesPerThreadThreadCountAndBody() {
        val rows = (1L..550L).map { i ->
            row(i, (i % 110) + 1, i, body = "x".repeat(10_000))
        }
        val threads = ProviderSmsConversationMapper.map(rows)
        assertTrue(threads.size <= ProviderSmsConversationMapper.MAX_THREADS)
        assertTrue(threads.sumOf { it.messages.size } <= ProviderSmsConversationMapper.MAX_MESSAGES)
        assertTrue(threads.all { it.messages.size <= ProviderSmsConversationMapper.MAX_PER_THREAD })
        assertTrue(threads.all { thread -> thread.messages.all { it.body.length <= 8192 } })
    }

    @Test fun pureMapperIsFastOnMaximumBound() {
        val rows = (1L..500L).map { i -> row(i, i % 60 + 1, i * 2) }
        val start = System.nanoTime()
        repeat(100) { ProviderSmsConversationMapper.map(rows) }
        val milliseconds = (System.nanoTime() - start) / 1_000_000L
        // Very generous host performance regression threshold, not a device runtime claim.
        assertTrue("100 × 500 rows took ${milliseconds}ms", milliseconds < 10_000L)
    }
}
