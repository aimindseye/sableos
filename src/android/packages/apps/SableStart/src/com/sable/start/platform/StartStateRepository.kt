package org.sableos.start.platform

import android.content.Context

/**
 * Stores only launcher presentation state. Recent activity intentionally stays
 * in-memory so Sable Start does not build a persistent app-usage history.
 */
class StartStateRepository(
    context: Context,
) {
    private val preferences =
        context.applicationContext.getSharedPreferences(
            PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )

    fun loadPinnedKeys(): Set<String> =
        preferences
            .getStringSet(KEY_PINNED_APPS, emptySet())
            .orEmpty()
            .toSet()

    fun savePinnedKeys(keys: Set<String>) {
        preferences
            .edit()
            .putStringSet(KEY_PINNED_APPS, keys.toSet())
            .apply()
    }

    private companion object {
        const val PREFERENCES_NAME = "sable_start_state"
        const val KEY_PINNED_APPS = "pinned_apps"
    }
}
