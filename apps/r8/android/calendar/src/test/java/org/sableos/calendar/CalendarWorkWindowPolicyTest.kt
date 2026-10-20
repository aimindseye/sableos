package org.sableos.calendar

import android.view.KeyEvent
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CalendarWorkWindowPolicyTest {
    @Test fun fiveDaysCrossMonthAndYear() {
        val dates = CalendarWorkWindowPolicy.dates(LocalDate.of(2026, 12, 30))
        assertEquals(5, dates.size)
        assertEquals(LocalDate.of(2027, 1, 3), dates.last())
    }

    @Test fun timedEventsIncludeOverlappingDaysAndDST() {
        val zone = ZoneId.of("America/New_York")
        val start = LocalDate.of(2026, 11, 1).atTime(23, 30).atZone(zone).toInstant().toEpochMilli()
        val ev = event(1, start, start + 60 * 60 * 1000L)
        assertTrue(ev in CalendarWorkWindowPolicy.onDay(listOf(ev), LocalDate.of(2026, 11, 1), zone))
        assertTrue(ev in CalendarWorkWindowPolicy.onDay(listOf(ev), LocalDate.of(2026, 11, 2), zone))
        assertTrue(CalendarWorkWindowPolicy.onDay(listOf(ev), LocalDate.of(2026, 11, 3), zone).isEmpty())
    }

    @Test fun allDayUTCDateNeverShiftsToPriorLocalDay() {
        val utc = LocalDate.of(2026, 10, 20).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val ev = event(2, utc, utc + 86_400_000L, allDay = true)
        val zone = ZoneId.of("America/Los_Angeles")
        assertEquals(listOf(ev), CalendarWorkWindowPolicy.onDay(listOf(ev), LocalDate.of(2026, 10, 20), zone))
        assertTrue(CalendarWorkWindowPolicy.onDay(listOf(ev), LocalDate.of(2026, 10, 19), zone).isEmpty())
    }

    @Test fun nextEventSkipsExpiredAndSelectsCurrentBeforeFuture() {
        val events = listOf(event(1, 0, 99), event(2, 90, 150), event(3, 200, 250))
        assertEquals(2L, CalendarWorkWindowPolicy.nextEvent(events, 100L)?.id)
        assertEquals(3L, CalendarWorkWindowPolicy.nextEvent(events, 180L)?.id)
        assertNull(CalendarWorkWindowPolicy.nextEvent(events, 260L))
    }

    @Test fun browseKeysAreGuardedAndDoNotInventRSVP() {
        assertEquals(CalendarBrowseAction.Create, CalendarBrowseKeys.action(KeyEvent.KEYCODE_C, false, false))
        assertEquals(CalendarBrowseAction.Today, CalendarBrowseKeys.action(KeyEvent.KEYCODE_T, false, false))
        assertEquals(CalendarBrowseAction.View, CalendarBrowseKeys.action(KeyEvent.KEYCODE_V, false, false))
        assertEquals(CalendarBrowseAction.Next, CalendarBrowseKeys.action(KeyEvent.KEYCODE_J, false, false))
        assertEquals(CalendarBrowseAction.Next, CalendarBrowseKeys.action(KeyEvent.KEYCODE_N, false, false))
        assertEquals(CalendarBrowseAction.Previous, CalendarBrowseKeys.action(KeyEvent.KEYCODE_K, false, false))
        assertEquals(CalendarBrowseAction.Previous, CalendarBrowseKeys.action(KeyEvent.KEYCODE_P, false, false))
        assertNull(CalendarBrowseKeys.action(KeyEvent.KEYCODE_R, false, false))
        assertNull(CalendarBrowseKeys.action(KeyEvent.KEYCODE_C, true, false))
        assertNull(CalendarBrowseKeys.action(KeyEvent.KEYCODE_C, false, true))
        assertNull(CalendarBrowseKeys.action(KeyEvent.KEYCODE_ENTER, false, false))
    }

    @Test fun performance10kEventsBoundedToFiveColumns() {
        val day = LocalDate.of(2026, 10, 20)
        val first = day.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        val items = (0 until 10_000).map { i -> event(i.toLong(), first + i * 1000L, first + i * 1000L + 60000L) }
        val dates = CalendarWorkWindowPolicy.dates(day)
        assertEquals(5, dates.size)
        assertEquals(10_000, CalendarWorkWindowPolicy.onDay(items, day, ZoneOffset.UTC).size)
        assertTrue(CalendarWorkWindowPolicy.nextEvent(items, first) != null)
        assertFalse(dates.any { it.isBefore(day) })
    }

    private fun event(id: Long, start: Long, end: Long, allDay: Boolean = false) =
        CalendarEvent(id, "event-$id", start, end, allDay, "local")
}
