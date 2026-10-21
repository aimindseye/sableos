package org.sableos.calendar

import android.view.KeyEvent
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/** Five consecutive days anchored on the selected date; no infinite scroll or provider state. */
object CalendarWorkWindowPolicy {
    const val DAYS = 5

    fun dates(start: LocalDate): List<LocalDate> =
        (0 until DAYS).map { start.plusDays(it.toLong()) }

    /** Timed events use the device zone; all-day CalendarProvider instances use UTC dates. */
    fun onDay(
        events: List<CalendarEvent>,
        date: LocalDate,
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<CalendarEvent> {
        val begin = date.atStartOfDay(zone).toInstant().toEpochMilli()
        val end = date.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        val utcBegin = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val utcEnd = date.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        return events.filter { event ->
            if (event.allDay) event.startMillis < utcEnd && event.endMillis > utcBegin
            else event.startMillis < end && event.endMillis > begin
        }
    }

    /** Text search is confined to the loaded five-day provider result, never an unbounded account query. */
    fun search(events: List<CalendarEvent>, query: String): List<CalendarEvent> {
        val term = query.trim().take(80)
        if (term.isEmpty()) return events
        return events.filter {
            it.title.contains(term, ignoreCase = true) ||
                it.calendarName.contains(term, ignoreCase = true)
        }
    }

    /** Explicit four-hour pages; events spanning the page or all-day events remain visible. */
    fun inTimeBlock(
        event: CalendarEvent,
        date: LocalDate,
        startHour: Int,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        require(startHour in 0..20 && startHour % 4 == 0)
        if (event.allDay) return true
        val lower = date.atTime(startHour, 0).atZone(zone).toInstant().toEpochMilli()
        val upper = date.atTime(startHour + 4, 0).atZone(zone).toInstant().toEpochMilli()
        return event.startMillis < upper && event.endMillis > lower
    }

    fun nextEvent(events: List<CalendarEvent>, nowMillis: Long): CalendarEvent? =
        events.asSequence()
            .filter { it.endMillis > nowMillis }
            .minWithOrNull(compareBy<CalendarEvent> { maxOf(it.startMillis, nowMillis) }
                .thenBy { it.startMillis })
}

enum class CalendarBrowseAction {
    Create, Today, View, Next, Previous,
}

/** Only for browse screens: the composing activity must never invoke these from text-field modes. */
object CalendarBrowseKeys {
    fun action(keyCode: Int, modified: Boolean, repeating: Boolean): CalendarBrowseAction? {
        if (modified || repeating) return null
        return when (keyCode) {
            KeyEvent.KEYCODE_C -> CalendarBrowseAction.Create
            KeyEvent.KEYCODE_T -> CalendarBrowseAction.Today
            KeyEvent.KEYCODE_V -> CalendarBrowseAction.View
            KeyEvent.KEYCODE_J, KeyEvent.KEYCODE_N -> CalendarBrowseAction.Next
            KeyEvent.KEYCODE_K, KeyEvent.KEYCODE_P -> CalendarBrowseAction.Previous
            else -> null // R/RSVP cannot be claimed until a provider-safe response path exists
        }
    }
}
