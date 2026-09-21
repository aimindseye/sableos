package org.sableos.media

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

class MediaSnapshotProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val appContext = checkNotNull(context)
        val snapshot = MediaSnapshotStore.read(appContext)
        val hasMedia = snapshot.title.isNotBlank()
        val detail =
            if (!hasMedia) {
                "nothing playing"
            } else {
                buildString {
                    append(snapshot.title)
                    if (snapshot.artist.isNotBlank()) {
                        append(" · ")
                        append(snapshot.artist)
                    }
                    append(if (snapshot.playing) " · playing" else " · paused")
                }
            }

        return MatrixCursor(COLUMNS).apply {
            addRow(
                arrayOf(
                    "Media",
                    detail,
                    if (hasMedia) "LIVE" else "EMPTY",
                    snapshot.observedAt,
                ),
            )
            setNotificationUri(appContext.contentResolver, MediaSnapshotStore.SNAPSHOT_URI)
        }
    }

    override fun getType(uri: Uri): String =
        "vnd.android.cursor.item/vnd.org.sableos.media.snapshot"

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
        private val COLUMNS =
            arrayOf("title", "detail", "availability", "observed_at")
    }
}
