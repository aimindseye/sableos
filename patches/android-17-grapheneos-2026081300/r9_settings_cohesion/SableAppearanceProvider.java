package com.android.settings.sable;

import android.app.UiModeManager;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.Binder;
import android.os.Process;

import java.util.Arrays;

public final class SableAppearanceProvider extends ContentProvider {
    private static final String PREFS = "sable_system_appearance";
    private static final String KEY_MODE = "mode";
    private static final String KEY_ACCENT = "accent";
    private static final String KEY_NIGHT_MODE_BEFORE_OVERRIDE =
            "night_mode_before_sable_override";

    @Override
    public boolean onCreate() {
        Context context = getContext();
        if (context != null) {
            applyStoredMode(context);
        }
        return true;
    }

    private static SharedPreferences prefs(Context context) {
        Context deviceContext = context.createDeviceProtectedStorageContext();
        return deviceContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static String readMode(Context context) {
        return prefs(context).getString(
                KEY_MODE,
                SableAppearanceContract.DEFAULT_MODE);
    }

    public static String readAccent(Context context) {
        return prefs(context).getString(
                KEY_ACCENT,
                SableAppearanceContract.DEFAULT_ACCENT);
    }

    public static void applyStoredMode(Context context) {
        String mode = readMode(context);
        if (SableAppearanceContract.MODE_LIGHT.equals(mode)) {
            applyExplicitNightMode(context, UiModeManager.MODE_NIGHT_NO);
        } else if (SableAppearanceContract.MODE_DARK.equals(mode)) {
            applyExplicitNightMode(context, UiModeManager.MODE_NIGHT_YES);
        }
    }

    private static void applyExplicitNightMode(Context context, int targetMode) {
        UiModeManager manager = context.getSystemService(UiModeManager.class);
        if (manager == null) {
            return;
        }

        SharedPreferences preferences = prefs(context);
        if (!preferences.contains(KEY_NIGHT_MODE_BEFORE_OVERRIDE)) {
            preferences.edit()
                    .putInt(KEY_NIGHT_MODE_BEFORE_OVERRIDE, manager.getNightMode())
                    .apply();
        }
        manager.setNightMode(targetMode);
    }

    private static void restoreFollowSystem(Context context) {
        UiModeManager manager = context.getSystemService(UiModeManager.class);
        if (manager == null) {
            return;
        }

        SharedPreferences preferences = prefs(context);
        if (preferences.contains(KEY_NIGHT_MODE_BEFORE_OVERRIDE)) {
            int previous = preferences.getInt(
                    KEY_NIGHT_MODE_BEFORE_OVERRIDE,
                    UiModeManager.MODE_NIGHT_AUTO);
            manager.setNightMode(previous);
            preferences.edit().remove(KEY_NIGHT_MODE_BEFORE_OVERRIDE).apply();
        }
    }

    @Override
    public Cursor query(
            Uri uri,
            String[] projection,
            String selection,
            String[] selectionArgs,
            String sortOrder) {
        enforceUri(uri);
        Context context = requireProviderContext();

        MatrixCursor cursor = new MatrixCursor(
                new String[] {
                    SableAppearanceContract.COLUMN_MODE,
                    SableAppearanceContract.COLUMN_ACCENT,
                },
                1);
        cursor.addRow(new Object[] {
            readMode(context),
            readAccent(context),
        });
        cursor.setNotificationUri(
                context.getContentResolver(),
                SableAppearanceContract.CONTENT_URI);
        return cursor;
    }

    @Override
    public int update(
            Uri uri,
            ContentValues values,
            String selection,
            String[] selectionArgs) {
        enforceUri(uri);
        enforceWriter();

        Context context = requireProviderContext();
        SharedPreferences preferences = prefs(context);

        String currentMode = readMode(context);
        String currentAccent = readAccent(context);
        String mode = values != null
                ? values.getAsString(SableAppearanceContract.COLUMN_MODE)
                : null;
        String accent = values != null
                ? values.getAsString(SableAppearanceContract.COLUMN_ACCENT)
                : null;

        if (mode == null) {
            mode = currentMode;
        }
        if (accent == null) {
            accent = currentAccent;
        }

        if (!SableAppearanceContract.isValidMode(mode)) {
            throw new IllegalArgumentException("Invalid Sable appearance mode: " + mode);
        }
        if (!SableAppearanceContract.isValidAccent(accent)) {
            throw new IllegalArgumentException("Invalid Sable accent: " + accent);
        }

        preferences.edit()
                .putString(KEY_MODE, mode)
                .putString(KEY_ACCENT, accent)
                .apply();

        if (SableAppearanceContract.MODE_LIGHT.equals(mode)) {
            applyExplicitNightMode(context, UiModeManager.MODE_NIGHT_NO);
        } else if (SableAppearanceContract.MODE_DARK.equals(mode)) {
            applyExplicitNightMode(context, UiModeManager.MODE_NIGHT_YES);
        } else {
            restoreFollowSystem(context);
        }

        context.getContentResolver().notifyChange(
                SableAppearanceContract.CONTENT_URI,
                null);
        return 1;
    }

    @Override
    public String getType(Uri uri) {
        enforceUri(uri);
        return "vnd.android.cursor.item/vnd.org.sableos.appearance";
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        throw new UnsupportedOperationException("Use update for Sable appearance");
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("Sable appearance cannot be deleted");
    }

    private Context requireProviderContext() {
        Context context = getContext();
        if (context == null) {
            throw new IllegalStateException("Settings context unavailable");
        }
        return context;
    }

    private static void enforceUri(Uri uri) {
        if (!SableAppearanceContract.CONTENT_URI.equals(uri)) {
            throw new IllegalArgumentException("Unsupported Sable appearance URI: " + uri);
        }
    }

    private void enforceWriter() {
        int callingUid = Binder.getCallingUid();
        if (callingUid == Process.myUid()) {
            return;
        }

        PackageManager pm = requireProviderContext().getPackageManager();
        String[] packages = pm.getPackagesForUid(callingUid);
        if (packages != null && Arrays.asList(packages).contains("org.sableos.launcher")) {
            return;
        }

        throw new SecurityException(
                "Sable appearance writes are restricted to Settings and SableLauncher");
    }
}
