/*
 * SableOS UI5B: entry point from Android App info into the read-only
 * Application Security & Privacy evidence surface.
 */
package com.android.settings.applications.appinfo;

import android.content.Context;

import com.android.settings.SettingsPreferenceFragment;

public final class SableAppSecurityPrivacyPreferenceController
        extends AppInfoPreferenceControllerBase {

    public SableAppSecurityPrivacyPreferenceController(
            Context context, String preferenceKey) {
        super(context, preferenceKey);
    }

    @Override
    protected Class<? extends SettingsPreferenceFragment> getDetailFragmentClass() {
        return SableAppSecurityPrivacyFragment.class;
    }
}
