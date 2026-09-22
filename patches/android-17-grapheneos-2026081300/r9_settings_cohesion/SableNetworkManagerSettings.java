package com.android.settings.sable;

import android.Manifest;
import android.app.settings.SettingsEnums;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.UserHandle;
import android.permission.PermissionManager;
import android.util.Log;

import androidx.preference.Preference;
import androidx.preference.PreferenceCategory;
import androidx.preference.SwitchPreferenceCompat;

import com.android.settings.R;
import com.android.settings.SettingsPreferenceFragment;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * SableOS view over GrapheneOS' runtime Network permission.
 *
 * GrapheneOS makes android.permission.INTERNET a user-revocable dangerous
 * permission and enforces it beyond a packet firewall. This screen delegates
 * directly to that existing permission implementation; it does not maintain a
 * second Sable firewall or duplicate policy database.
 */
public final class SableNetworkManagerSettings extends SettingsPreferenceFragment
        implements Preference.OnPreferenceChangeListener {
    private static final String TAG = "SableNetworkManager";
    private static final String KEY_PREFIX = "sable_network_app:";

    private PackageManager mPackageManager;
    private PermissionManager mPermissionManager;
    private UserHandle mUser;
    private PreferenceCategory mApps;

    @Override
    public int getMetricsCategory() {
        return SettingsEnums.MANAGE_APPLICATIONS;
    }

    @Override
    public void onCreate(Bundle icicle) {
        super.onCreate(icicle);
        addPreferencesFromResource(R.xml.sable_network_manager_settings);
        requireActivity().setTitle(R.string.sable_network_manager_title);

        mPackageManager = requireContext().getPackageManager();
        mPermissionManager = requireContext().getSystemService(PermissionManager.class);
        mUser = requireContext().getUser();
        mApps = findPreference("sable_network_apps");

        if (mPermissionManager == null || mApps == null) {
            throw new IllegalStateException("Sable Network Manager dependencies unavailable");
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        rebuildAppList();
    }

    private void rebuildAppList() {
        mApps.removeAll();

        List<NetworkApp> apps = new ArrayList<>();
        List<PackageInfo> packages =
                mPackageManager.getInstalledPackages(
                        PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS));

        for (PackageInfo packageInfo : packages) {
            if (!requestsNetwork(packageInfo) || packageInfo.applicationInfo == null) {
                continue;
            }

            ApplicationInfo applicationInfo = packageInfo.applicationInfo;
            CharSequence label = applicationInfo.loadLabel(mPackageManager);
            apps.add(
                    new NetworkApp(
                            packageInfo.packageName,
                            label != null ? label.toString() : packageInfo.packageName,
                            applicationInfo));
        }

        Collator collator = Collator.getInstance();
        apps.sort((left, right) -> collator.compare(left.label, right.label));

        for (NetworkApp app : apps) {
            SwitchPreferenceCompat preference = new SwitchPreferenceCompat(requireContext());
            preference.setKey(KEY_PREFIX + app.packageName);
            preference.setTitle(app.label);
            preference.setIcon(app.applicationInfo.loadIcon(mPackageManager));
            preference.setPersistent(false);
            preference.setChecked(hasNetworkAccess(app.packageName));

            if (isPermissionFixed(app.packageName)) {
                preference.setEnabled(false);
                preference.setSummary(R.string.sable_network_manager_fixed_summary);
            } else {
                preference.setSummary(R.string.sable_network_manager_app_summary);
                preference.setOnPreferenceChangeListener(this);
            }

            mApps.addPreference(preference);
        }
    }

    private static boolean requestsNetwork(PackageInfo packageInfo) {
        if (packageInfo.requestedPermissions == null) {
            return false;
        }

        return Arrays.asList(packageInfo.requestedPermissions)
                .contains(Manifest.permission.INTERNET);
    }

    private boolean hasNetworkAccess(String packageName) {
        return mPackageManager.checkPermission(
                        Manifest.permission.INTERNET,
                        packageName)
                == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isPermissionFixed(String packageName) {
        int flags =
                mPermissionManager.getPermissionFlags(
                        packageName,
                        Manifest.permission.INTERNET,
                        mUser);
        int fixedMask =
                PackageManager.FLAG_PERMISSION_SYSTEM_FIXED
                        | PackageManager.FLAG_PERMISSION_POLICY_FIXED;
        return (flags & fixedMask) != 0;
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        String key = preference.getKey();
        if (key == null || !key.startsWith(KEY_PREFIX) || !(newValue instanceof Boolean)) {
            return false;
        }

        String packageName = key.substring(KEY_PREFIX.length());
        boolean allow = (Boolean) newValue;

        try {
            if (allow) {
                mPermissionManager.grantRuntimePermission(
                        packageName,
                        Manifest.permission.INTERNET,
                        mUser);
            } else {
                mPermissionManager.revokeRuntimePermission(
                        packageName,
                        Manifest.permission.INTERNET,
                        mUser,
                        "Sable Network Manager");
            }
        } catch (IllegalArgumentException | SecurityException exception) {
            Log.e(TAG, "Unable to change Network permission for " + packageName, exception);
            return false;
        }

        return hasNetworkAccess(packageName) == allow;
    }

    private static final class NetworkApp {
        final String packageName;
        final String label;
        final ApplicationInfo applicationInfo;

        NetworkApp(String packageName, String label, ApplicationInfo applicationInfo) {
            this.packageName = packageName;
            this.label = label;
            this.applicationInfo = applicationInfo;
        }
    }
}
