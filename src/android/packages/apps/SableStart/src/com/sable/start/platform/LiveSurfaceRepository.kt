package org.sableos.start.platform

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CalendarContract
import android.provider.MediaStore
import android.text.format.DateFormat
import org.sableos.start.live.LiveAvailability
import org.sableos.start.live.LiveDatum
import org.sableos.start.live.LiveSurfaceSnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Calendar
import java.util.Date

class LiveSurfaceRepository(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val resolver = appContext.contentResolver

    fun initialSnapshot(nowEpochMs: Long = System.currentTimeMillis()): LiveSurfaceSnapshot {
        val loading =
            LiveDatum(
                title = "Loading",
                detail = "loading local data",
                availability = LiveAvailability.LOADING,
            )
        return LiveSurfaceSnapshot(
            dateText = DateFormat.getMediumDateFormat(appContext).format(Date(nowEpochMs)),
            timeText = DateFormat.getTimeFormat(appContext).format(Date(nowEpochMs)),
            photos = loading.copy(title = "Photos"),
            music = loading.copy(title = "Music"),
            calendar = loading.copy(title = "Calendar"),
            weather =
                LiveDatum(
                    title = "Weather",
                    detail = "provider not configured",
                    availability = LiveAvailability.UNAVAILABLE,
                ),
            tasks =
                LiveDatum(
                    title = "Tasks",
                    detail = "provider not configured",
                    availability = LiveAvailability.UNAVAILABLE,
                ),
            observedAtEpochMs = nowEpochMs,
        )
    }

    suspend fun snapshot(
        nowEpochMs: Long = System.currentTimeMillis(),
    ): LiveSurfaceSnapshot =
        withContext(Dispatchers.IO) {
            LiveSurfaceSnapshot(
                dateText = DateFormat.getMediumDateFormat(appContext).format(Date(nowEpochMs)),
                timeText = DateFormat.getTimeFormat(appContext).format(Date(nowEpochMs)),
                photos = mediaCount(
                    permission =
                        if (Build.VERSION.SDK_INT >= 33) {
                            Manifest.permission.READ_MEDIA_IMAGES
                        } else {
                            Manifest.permission.READ_EXTERNAL_STORAGE
                        },
                    uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    title = "Photos",
                    noun = "photo",
                ),
                music = mediaCount(
                    permission =
                        if (Build.VERSION.SDK_INT >= 33) {
                            Manifest.permission.READ_MEDIA_AUDIO
                        } else {
                            Manifest.permission.READ_EXTERNAL_STORAGE
                        },
                    uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    title = "Music",
                    noun = "track",
                ),
                calendar = calendarToday(nowEpochMs),
                weather =
                    LiveDatum(
                        title = "Weather",
                        detail = "provider not configured",
                        availability = LiveAvailability.UNAVAILABLE,
                    ),
                tasks =
                    LiveDatum(
                        title = "Tasks",
                        detail = "provider not configured",
                        availability = LiveAvailability.UNAVAILABLE,
                    ),
                observedAtEpochMs = nowEpochMs,
            )
        }

    private fun mediaCount(
        permission: String,
        uri: android.net.Uri,
        title: String,
        noun: String,
    ): LiveDatum {
        if (appContext.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            return LiveDatum(
                title = title,
                detail = "permission required",
                availability = LiveAvailability.PERMISSION_REQUIRED,
            )
        }

        return try {
            val count =
                resolver
                    .query(
                        uri,
                        arrayOf(MediaStore.MediaColumns._ID),
                        null,
                        null,
                        null,
                    )
                    ?.use { cursor -> cursor.count }
                    ?: 0

            LiveDatum(
                title = title,
                detail =
                    if (count == 0) {
                        "no ${noun}s found"
                    } else {
                        "$count ${if (count == 1) noun else "${noun}s"}"
                    },
                availability =
                    if (count == 0) {
                        LiveAvailability.EMPTY
                    } else {
                        LiveAvailability.LIVE
                    },
            )
        } catch (_: SecurityException) {
            LiveDatum(
                title = title,
                detail = "permission required",
                availability = LiveAvailability.PERMISSION_REQUIRED,
            )
        } catch (_: RuntimeException) {
            LiveDatum(
                title = title,
                detail = "provider error",
                availability = LiveAvailability.ERROR,
            )
        }
    }

    private fun calendarToday(nowEpochMs: Long): LiveDatum {
        if (
            appContext.checkSelfPermission(Manifest.permission.READ_CALENDAR) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return LiveDatum(
                title = "Calendar",
                detail = "permission required",
                availability = LiveAvailability.PERMISSION_REQUIRED,
            )
        }

        val dayStart =
            Calendar.getInstance().apply {
                timeInMillis = nowEpochMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        val dayEnd =
            Calendar.getInstance().apply {
                timeInMillis = dayStart
                add(Calendar.DAY_OF_YEAR, 1)
            }.timeInMillis

        return try {
            val selection =
                "${CalendarContract.Events.DTSTART} < ? AND " +
                    "${CalendarContract.Events.DTEND} > ?"
            val args = arrayOf(dayEnd.toString(), dayStart.toString())
            val count =
                resolver
                    .query(
                        CalendarContract.Events.CONTENT_URI,
                        arrayOf(CalendarContract.Events._ID),
                        selection,
                        args,
                        null,
                    )
                    ?.use { cursor -> cursor.count }
                    ?: 0

            LiveDatum(
                title = "Calendar",
                detail =
                    if (count == 0) {
                        "no events today"
                    } else {
                        "$count ${if (count == 1) "event" else "events"} today"
                    },
                availability =
                    if (count == 0) {
                        LiveAvailability.EMPTY
                    } else {
                        LiveAvailability.LIVE
                    },
            )
        } catch (_: SecurityException) {
            LiveDatum(
                title = "Calendar",
                detail = "permission required",
                availability = LiveAvailability.PERMISSION_REQUIRED,
            )
        } catch (_: RuntimeException) {
            LiveDatum(
                title = "Calendar",
                detail = "provider error",
                availability = LiveAvailability.ERROR,
            )
        }
    }
}
