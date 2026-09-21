package org.sableos.calendar

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

class CalendarSnapshotProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val appContext = checkNotNull(context)
        val snapshot = CalendarRepository(appContext).snapshot()
        return MatrixCursor(COLUMNS).apply {
            addRow(
                arrayOf(
                    snapshot.title,
                    snapshot.detail,
                    snapshot.availability,
                    snapshot.observedAt,
                ),
            )
            setNotificationUri(appContext.contentResolver, SNAPSHOT_URI)
        }
    }

    override fun getType(uri: Uri): String =
        "vnd.android.cursor.item/vnd.org.sableos.calendar.snapshot"

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("Read-only provider")

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("Read-only provider")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("Read-only provider")

    companion object {
        val SNAPSHOT_URI: Uri =
            Uri.parse("content://org.sableos.calendar.snapshot/current")
        private val COLUMNS =
            arrayOf("title", "detail", "availability", "observed_at")
    }
}
