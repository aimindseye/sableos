package org.sableos.start.platform

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import org.sableos.design.SableGlobalAppearanceContract

class SableAppearanceProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        require(uri == SableGlobalAppearanceContract.CONTENT_URI) {
            "Unsupported Sable appearance URI: $uri"
        }

        val appContext =
            requireNotNull(context) {
                "Sable appearance provider context is unavailable"
            }.applicationContext

        val appearance =
            StartStateRepository(appContext).loadAppearance()

        return MatrixCursor(
            arrayOf(
                SableGlobalAppearanceContract.COLUMN_MODE,
                SableGlobalAppearanceContract.COLUMN_ACCENT,
            ),
            1,
        ).apply {
            addRow(
                arrayOf(
                    appearance.mode.stableValue,
                    appearance.accent.stableValue,
                ),
            )
        }
    }

    override fun getType(uri: Uri): String? =
        if (uri == SableGlobalAppearanceContract.CONTENT_URI) {
            "vnd.android.cursor.item/vnd.org.sableos.appearance"
        } else {
            null
        }

    override fun insert(
        uri: Uri,
        values: ContentValues?,
    ): Uri? =
        throw UnsupportedOperationException(
            "Sable appearance provider is read-only",
        )

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int =
        throw UnsupportedOperationException(
            "Sable appearance provider is read-only",
        )

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int =
        throw UnsupportedOperationException(
            "Sable appearance provider is read-only",
        )
}
