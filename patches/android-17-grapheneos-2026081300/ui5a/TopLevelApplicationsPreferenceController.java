/*
 * SableOS UI5A: top-level Applications preference summary.
 *
 * The count is derived from PackageManager for the current Settings user. The
 * controller does not cache installed-app inventory and does not expose it
 * outside Settings.
 */
package com.android.settings.applications;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;

import com.android.settings.R;
import com.android.settings.core.BasePreferenceController;

import java.util.List;

public final class TopLevelApplicationsPreferenceController extends BasePreferenceController {
    public TopLevelApplicationsPreferenceController(Context context, String preferenceKey) {
        super(context, preferenceKey);
    }

    @Override
    public int getAvailabilityStatus() {
        return AVAILABLE;
    }

    @Override
    public CharSequence getSummary() {
        final PackageManager pm = mContext.getPackageManager();
        final List<ApplicationInfo> apps =
                pm.getInstalledApplications(PackageManager.MATCH_DISABLED_COMPONENTS);

        int count = 0;
        for (ApplicationInfo info : apps) {
            if ((info.flags & ApplicationInfo.FLAG_INSTALLED) != 0) {
                count++;
            }
        }

        return mContext.getResources().getQuantityString(
                R.plurals.sable_installed_apps_summary,
                count,
                count);
    }
}
