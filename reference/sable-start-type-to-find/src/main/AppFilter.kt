package org.sableos.reference.typetofind

data class AppEntry(val label: String, val pkg: String, val cls: String)

/** Type-to-find ranking for All Apps: label prefix, then word prefix, then substring. Case-insensitive, stable by label. */
object AppFilter {
    fun filter(apps: List<AppEntry>, query: String): List<AppEntry> {
        val q = query.trim().lowercase()
        val sorted = apps.sortedBy { it.label.lowercase() }
        if (q.isEmpty()) return sorted
        fun rank(a: AppEntry): Int {
            val l = a.label.lowercase()
            return when {
                l.startsWith(q) -> 0
                l.split(' ', '-', '_', '.').any { it.startsWith(q) } -> 1
                l.contains(q) -> 2
                else -> -1
            }
        }
        return sorted.map { it to rank(it) }.filter { it.second >= 0 }.sortedBy { it.second }.map { it.first }
    }

    /** The app the Enter key launches: the first match, or null when nothing matches. */
    fun firstMatch(apps: List<AppEntry>, query: String): AppEntry? = if (query.isBlank()) null else filter(apps, query).firstOrNull()
}
