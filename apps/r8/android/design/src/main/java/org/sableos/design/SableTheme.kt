package org.sableos.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

enum class AppearanceMode(val stableValue: String) {
    FollowSystem("follow-system"),
    Light("light"),
    Dark("dark");

    companion object {
        fun fromStableValue(value: String?): AppearanceMode =
            entries.firstOrNull { it.stableValue == value } ?: FollowSystem
    }
}

enum class AccentPreset(
    val stableValue: String,
    val displayName: String,
    val color: Color,
    val onColor: Color,
) {
    Blue("blue", "Blue", Color(0xFF4D9CFF), Color.Black),
    Green("green", "Green", Color(0xFF35C66B), Color.Black),
    Purple("purple", "Purple", Color(0xFF7A42E8), Color.White),
    Orange("orange", "Orange", Color(0xFFF28C45), Color.Black),
    Slate("slate", "Slate", Color(0xFF64748B), Color.White);

    companion object {
        fun fromStableValue(value: String?): AccentPreset =
            entries.firstOrNull { it.stableValue == value } ?: Blue
    }
}

data class SableAppearance(
    val mode: AppearanceMode = AppearanceMode.FollowSystem,
    val accent: AccentPreset = AccentPreset.Blue,
)

object SableDesignContract {
    const val SCHEMA_VERSION = 1
    const val KEY_APPEARANCE_MODE = "sable.appearance.mode"
    const val KEY_ACCENT = "sable.appearance.accent"
}

@Composable
fun SableTheme(
    appearance: SableAppearance = SableAppearance(),
    content: @Composable () -> Unit,
) {
    val dark = when (appearance.mode) {
        AppearanceMode.FollowSystem -> isSystemInDarkTheme()
        AppearanceMode.Light -> false
        AppearanceMode.Dark -> true
    }
    val accent = appearance.accent
    val colors = if (dark) {
        darkColorScheme(
            primary = accent.color,
            onPrimary = accent.onColor,
            background = Color(0xFF08090B),
            onBackground = Color(0xFFF5F7FA),
            surface = Color(0xFF17191D),
            onSurface = Color(0xFFF5F7FA),
            surfaceVariant = Color(0xFF24272D),
            onSurfaceVariant = Color(0xFFBEC3CC),
            error = Color(0xFFFFB4AB),
            onError = Color(0xFF690005),
        )
    } else {
        lightColorScheme(
            primary = accent.color,
            onPrimary = accent.onColor,
            background = Color(0xFFF7F8FA),
            onBackground = Color(0xFF15171A),
            surface = Color.White,
            onSurface = Color(0xFF15171A),
            surfaceVariant = Color(0xFFE9ECF1),
            onSurfaceVariant = Color(0xFF4C535D),
            error = Color(0xFFBA1A1A),
            onError = Color.White,
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}
