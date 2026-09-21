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

    fun loadFavoriteKeys(): Set<String> {
        val explicit =
            preferences.getStringSet(
                KEY_FAVORITE_APPS,
                null,
            )
        if (explicit != null) {
            return explicit.toSet()
        }

        return preferences
            .getStringSet(
                KEY_PINNED_APPS_LEGACY,
                emptySet(),
            )
            .orEmpty()
            .toSet()
    }

    fun saveFavoriteKeys(keys: Set<String>) {
        preferences
            .edit()
            .putStringSet(
                KEY_FAVORITE_APPS,
                keys.toSet(),
            )
            .remove(KEY_PINNED_APPS_LEGACY)
            .apply()
    }

    /**
     * Null means the user has never customized Start tiles and the production
     * UI should resolve the current preferred/default set from installed apps.
     * An empty set is an explicit user choice to keep Start tile-free.
     */
    fun loadStartTileKeys(): Set<String>? {
        if (!preferences.contains(KEY_START_TILES)) {
            return null
        }

        return preferences
            .getStringSet(
                KEY_START_TILES,
                emptySet(),
            )
            .orEmpty()
            .toSet()
    }

    fun saveStartTileKeys(keys: Set<String>) {
        preferences
            .edit()
            .putStringSet(
                KEY_START_TILES,
                keys.toSet(),
            )
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
        const val KEY_FAVORITE_APPS = "favorite_apps"
        const val KEY_START_TILES = "start_tiles"
        const val KEY_PINNED_APPS_LEGACY = "pinned_apps"
        const val KEY_SYSTEM_NIGHT_MODE_BEFORE_OVERRIDE =
            "system_night_mode_before_sable_override"
    }
}
