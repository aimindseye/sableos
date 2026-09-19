package org.sableos.start.platform

import android.content.Context
import org.sableos.design.AccentPreset
import org.sableos.design.AppearanceMode
import org.sableos.design.SableAppearance
import org.sableos.design.SableDesignContract
import org.sableos.design.SableGlobalAppearanceContract

/**
 * Stores launcher presentation state only. Recent activity intentionally stays
 * in-memory so Sable Start does not build a persistent app-usage history.
 */
class StartStateRepository(
    context: Context,
) {
    private val appContext = context.applicationContext

    private val preferences =
        appContext.getSharedPreferences(
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

    fun loadAppearance(): SableAppearance =
        SableAppearance(
            mode =
                AppearanceMode.fromStableValue(
                    preferences.getString(
                        SableDesignContract.KEY_APPEARANCE_MODE,
                        null,
                    ),
                ),
            accent =
                AccentPreset.fromStableValue(
                    preferences.getString(
                        SableDesignContract.KEY_ACCENT,
                        null,
                    ),
                ),
        )

    fun saveAppearance(appearance: SableAppearance) {
        preferences
            .edit()
            .putString(
                SableDesignContract.KEY_APPEARANCE_MODE,
                appearance.mode.stableValue,
            )
            .putString(
                SableDesignContract.KEY_ACCENT,
                appearance.accent.stableValue,
            )
            .apply()

        notifyAppearanceChanged()
    }

    fun resetAppearance(): SableAppearance {
        val appearance = SableAppearance()
        preferences
            .edit()
            .remove(SableDesignContract.KEY_APPEARANCE_MODE)
            .remove(SableDesignContract.KEY_ACCENT)
            .apply()

        notifyAppearanceChanged()
        return appearance
    }

    private fun notifyAppearanceChanged() {
        appContext.contentResolver.notifyChange(
            SableGlobalAppearanceContract.CONTENT_URI,
            null,
        )
    }

    private companion object {
        const val PREFERENCES_NAME = "sable_start_state"
        const val KEY_PINNED_APPS = "pinned_apps"
    }
}
