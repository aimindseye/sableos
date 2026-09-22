package com.android.settings.sable;

import android.net.Uri;

public final class SableAppearanceContract {
    public static final String AUTHORITY = "org.sableos.appearance";
    public static final String PATH_APPEARANCE = "appearance";
    public static final Uri CONTENT_URI =
            Uri.parse("content://" + AUTHORITY + "/" + PATH_APPEARANCE);

    public static final String COLUMN_MODE = "mode";
    public static final String COLUMN_ACCENT = "accent";

    public static final String MODE_FOLLOW_SYSTEM = "follow-system";
    public static final String MODE_LIGHT = "light";
    public static final String MODE_DARK = "dark";

    public static final String ACCENT_BLUE = "blue";
    public static final String ACCENT_GREEN = "green";
    public static final String ACCENT_PURPLE = "purple";
    public static final String ACCENT_ORANGE = "orange";
    public static final String ACCENT_SLATE = "slate";

    public static final String DEFAULT_MODE = MODE_FOLLOW_SYSTEM;
    public static final String DEFAULT_ACCENT = ACCENT_BLUE;

    private SableAppearanceContract() {}

    public static boolean isValidMode(String value) {
        return MODE_FOLLOW_SYSTEM.equals(value)
                || MODE_LIGHT.equals(value)
                || MODE_DARK.equals(value);
    }

    public static boolean isValidAccent(String value) {
        return ACCENT_BLUE.equals(value)
                || ACCENT_GREEN.equals(value)
                || ACCENT_PURPLE.equals(value)
                || ACCENT_ORANGE.equals(value)
                || ACCENT_SLATE.equals(value);
    }
}
