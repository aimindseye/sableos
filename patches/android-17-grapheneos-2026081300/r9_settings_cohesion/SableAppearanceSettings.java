package com.android.settings.sable;

import android.app.settings.SettingsEnums;
import android.content.ContentValues;
import android.database.Cursor;
import android.os.Bundle;

import androidx.preference.ListPreference;
import androidx.preference.Preference;

import com.android.settings.R;
import com.android.settings.SettingsPreferenceFragment;

public final class SableAppearanceSettings extends SettingsPreferenceFragment
        implements Preference.OnPreferenceChangeListener {
    private ListPreference mMode;
    private ListPreference mAccent;

    @Override
    public int getMetricsCategory() {
        return SettingsEnums.DISPLAY;
    }

    @Override
    public void onCreate(Bundle icicle) {
        super.onCreate(icicle);
        addPreferencesFromResource(R.xml.sable_appearance_settings);
        requireActivity().setTitle(R.string.sable_appearance_title);

        mMode = findPreference("sable_appearance_mode");
        mAccent = findPreference("sable_appearance_accent");

        if (mMode == null || mAccent == null) {
            throw new IllegalStateException("Sable appearance preferences missing");
        }

        mMode.setOnPreferenceChangeListener(this);
        mAccent.setOnPreferenceChangeListener(this);
        mMode.setSummaryProvider(ListPreference.SimpleSummaryProvider.getInstance());
        mAccent.setSummaryProvider(ListPreference.SimpleSummaryProvider.getInstance());
    }

    @Override
    public void onResume() {
        super.onResume();
        refresh();
    }

    private void refresh() {
        try (Cursor cursor = requireContext().getContentResolver().query(
                SableAppearanceContract.CONTENT_URI,
                new String[] {
                    SableAppearanceContract.COLUMN_MODE,
                    SableAppearanceContract.COLUMN_ACCENT,
                },
                null,
                null,
                null)) {
            if (cursor == null || !cursor.moveToFirst()) {
                return;
            }

            String mode = cursor.getString(
                    cursor.getColumnIndexOrThrow(SableAppearanceContract.COLUMN_MODE));
            String accent = cursor.getString(
                    cursor.getColumnIndexOrThrow(SableAppearanceContract.COLUMN_ACCENT));
            mMode.setValue(mode);
            mAccent.setValue(accent);
        }
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        ContentValues values = new ContentValues();
        if (preference == mMode) {
            values.put(
                    SableAppearanceContract.COLUMN_MODE,
                    String.valueOf(newValue));
        } else if (preference == mAccent) {
            values.put(
                    SableAppearanceContract.COLUMN_ACCENT,
                    String.valueOf(newValue));
        } else {
            return false;
        }

        int updated = requireContext().getContentResolver().update(
                SableAppearanceContract.CONTENT_URI,
                values,
                null,
                null);
        return updated == 1;
    }
}
