package org.sableos.messages

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Bounded, read-only rows from Android's Telephony.Sms provider; never stores or sends SMS. */
data class ProviderSmsRow(
    val id: Long,
    val threadId: Long,
    val address: String,
    val body: String,
    val dateMillis: Long,
    val incoming: Boolean,
    val read: Boolean,
)

/** Pure mapping shared by the real provider reader and JVM tests. Android remains data owner. */
object ProviderSmsConversationMapper {
    const val MAX_MESSAGES = 500
    const val MAX_THREADS = 80
    const val MAX_PER_THREAD = 40
    private const val MAX_BODY_CHARS = 8_192
    private val clock = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")

    fun map(rows: List<ProviderSmsRow>): List<SableThread> {
        val newest =
            rows
                .asSequence()
                .filter { it.threadId > 0 && it.id >= 0 && it.dateMillis >= 0 }
                .sortedWith(compareByDescending<ProviderSmsRow> { it.dateMillis }.thenByDescending { it.id })
                .take(MAX_MESSAGES)
                .toList()
        val grouped = LinkedHashMap<Long, MutableList<ProviderSmsRow>>()
        for (row in newest) {
            if (!grouped.containsKey(row.threadId) && grouped.size >= MAX_THREADS) continue
            val bucket = grouped.getOrPut(row.threadId) { ArrayList(MAX_PER_THREAD) }
            if (bucket.size < MAX_PER_THREAD) bucket.add(row)
        }
        val count = grouped.size
        return grouped.values.mapIndexedNotNull { index, items ->
            val route =
                items
                    .firstOrNull { it.address.isNotBlank() }
                    ?.address
                    ?.trim()
                    .orEmpty()
            // Do not generate fake recipients or attempt a provider send when routing is missing.
            if (route.isBlank()) return@mapIndexedNotNull null
            val chronological = items.asReversed()
            SableThread(
                id = items[0].threadId.toString(),
                person = route,
                route = route,
                source = "Android SMS provider · read-only",
                priority = count - index,
                unreadCount = items.count { it.incoming && !it.read },
                messages =
                    chronological.map { row ->
                        SableMessage(
                            id = row.id.toString(),
                            sender = if (row.incoming) row.address.ifBlank { route } else "You",
                            body = row.body.take(MAX_BODY_CHARS),
                            time = Instant.ofEpochMilli(row.dateMillis).atZone(ZoneId.systemDefault()).format(clock),
                            incoming = row.incoming,
                            unread = row.incoming && !row.read,
                        )
                    },
            )
        }
    }
}
