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

    fun loadSystemNightModeBeforeOverride(): Int? =
        if (preferences.contains(KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE)) {
            preferences.getInt(
                KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE,
                0,
            )
        } else {
            null
        }

    fun rememberSystemNightModeBeforeOverride(mode: Int) {
        if (preferences.contains(KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE)) {
            return
        }
        preferences
            .edit()
            .putInt(KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE, mode)
            .apply()
    }

    fun clearSystemNightModeBeforeOverride() {
        preferences
            .edit()
            .remove(KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE)
            .apply()
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
        const val KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE =
            "system_night_mode_before_sable_override"
    }
}
