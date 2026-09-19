/*
 * SableOS UI5C: About SableOS identity summary backed by live build/device properties.
 */
package com.android.settings.deviceinfo.aboutphone;

import android.content.Context;
import android.os.Build;

import com.android.settings.R;
import com.android.settings.core.BasePreferenceController;

public final class SableAboutPreferenceController extends BasePreferenceController {
    public SableAboutPreferenceController(Context context, String preferenceKey) {
        super(context, preferenceKey);
    }

    @Override
    public int getAvailabilityStatus() {
        return AVAILABLE;
    }

    @Override
    public CharSequence getSummary() {
        return mContext.getString(
                R.string.sable_about_summary_format,
                Build.MODEL,
                Build.DEVICE,
                Build.VERSION.RELEASE,
                Build.DISPLAY);
    }
}
