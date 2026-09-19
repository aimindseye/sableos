/*
 * SableOS UI5B: read-only Application Security & Privacy evidence surface.
 *
 * Trust model:
 *  - package metadata is read from PackageManager for the target user;
 *  - current permission grants and AppOps are read from Android enforcement state;
 *  - component exposure is derived from PackageManager's parsed component metadata;
 *  - packaged native-library signals are derived locally from APK ZIP entries;
 *  - unsupported evidence is shown as UNKNOWN rather than inferred as safe.
 *
 * This fragment deliberately performs no package/component mutation.
 */
package com.android.settings.applications.appinfo;

import android.Manifest;
import android.app.AppOpsManager;
import android.app.settings.SettingsEnums;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.InstallSourceInfo;
import android.content.pm.InstrumentationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ProviderInfo;
import android.content.pm.ServiceInfo;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.os.Bundle;
import android.os.PowerManager;
import android.os.UserHandle;
import android.text.TextUtils;

import androidx.annotation.Nullable;
import androidx.preference.Preference;
import androidx.preference.PreferenceCategory;

import com.android.settings.R;
import com.android.settings.SettingsPreferenceFragment;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TreeSet;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public final class SableAppSecurityPrivacyFragment extends SettingsPreferenceFragment {
    private static final String KEY_IDENTITY = "sable_identity_category";
    private static final String KEY_AUTHORITY = "sable_authority_category";
    private static final String KEY_COMPONENTS = "sable_components_category";
    private static final String KEY_CODE = "sable_code_category";
    private static final String KEY_NETWORK_BACKGROUND = "sable_network_background_category";
    private static final String KEY_HISTORY = "sable_history_category";

    private static final String PERMISSION_BIND_ACCESSIBILITY =
            "android.permission.BIND_ACCESSIBILITY_SERVICE";
    private static final String PERMISSION_BIND_NOTIFICATION_LISTENER =
            "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE";
    private static final String PERMISSION_BIND_VPN =
            "android.permission.BIND_VPN_SERVICE";
    private static final String PERMISSION_BIND_INPUT_METHOD =
            "android.permission.BIND_INPUT_METHOD";
    private static final String PERMISSION_BIND_AUTOFILL =
            "android.permission.BIND_AUTOFILL_SERVICE";
    private static final String PERMISSION_BIND_DEVICE_ADMIN =
            "android.permission.BIND_DEVICE_ADMIN";

    private Context mUserContext;
    private PackageManager mPm;
    private PackageInfo mPackageInfo;
    private ApplicationInfo mApplicationInfo;
    private String mPackageName;
    private int mUid;

    private static final class Capability {
        final int labelRes;
        final String[] permissions;

        Capability(int labelRes, String... permissions) {
            this.labelRes = labelRes;
            this.permissions = permissions;
        }
    }

    private static final class NativeCodeEvidence {
        boolean scanSucceeded;
        final Set<String> abis = new TreeSet<>();
        final Set<String> libraries = new TreeSet<>();
    }

    private static final class ComponentSummary {
        int total;
        int enabled;
        int exported;
        int exportedWithoutPermission;
        final List<String> exportedNames = new ArrayList<>();
    }

    @Override
    public int getMetricsCategory() {
        return SettingsEnums.APPLICATIONS_INSTALLED_APP_DETAILS;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        addPreferencesFromResource(R.xml.sable_app_security_privacy);
        getActivity().setTitle(R.string.sable_app_security_privacy_title);

        if (!loadPackage()) {
            getActivity().finish();
            return;
        }

        populateIdentity();
        populateAuthority();
        populateComponents();
        populateCodeAndLibraries();
        populateNetworkAndBackground();
        populateHistory();
    }

    private boolean loadPackage() {
        final Bundle args = getArguments();
        if (args == null) {
            return false;
        }

        mPackageName = args.getString(AppInfoDashboardFragment.ARG_PACKAGE_NAME);
        mUid = args.getInt(AppInfoDashboardFragment.ARG_PACKAGE_UID, -1);
        if (TextUtils.isEmpty(mPackageName) || mUid < 0) {
            return false;
        }

        final int userId = UserHandle.getUserId(mUid);
        try {
            mUserContext = getContext().createContextAsUser(UserHandle.of(userId), 0);
            mPm = mUserContext.getPackageManager();
            final long flags =
                    PackageManager.GET_ACTIVITIES
                            | PackageManager.GET_SERVICES
                            | PackageManager.GET_RECEIVERS
                            | PackageManager.GET_PROVIDERS
                            | PackageManager.GET_INSTRUMENTATION
                            | PackageManager.GET_PERMISSIONS
                            | PackageManager.GET_SIGNING_CERTIFICATES
                            | PackageManager.MATCH_DISABLED_COMPONENTS;
            mPackageInfo = mPm.getPackageInfo(
                    mPackageName,
                    PackageManager.PackageInfoFlags.of(flags));
            mApplicationInfo = mPackageInfo.applicationInfo;
            return mApplicationInfo != null;
        } catch (PackageManager.NameNotFoundException | RuntimeException e) {
            return false;
        }
    }

    private void populateIdentity() {
        final PreferenceCategory category = findPreference(KEY_IDENTITY);
        if (category == null) {
            return;
        }

        addRow(
                category,
                R.string.sable_package_name,
                evidence(R.string.sable_evidence_declared, mPackageName));

        final String versionName = TextUtils.isEmpty(mPackageInfo.versionName)
                ? getString(R.string.sable_unavailable)
                : mPackageInfo.versionName;
        addRow(
                category,
                R.string.sable_version,
                evidence(
                        R.string.sable_evidence_declared,
                        getString(
                                R.string.sable_identity_version_format,
                                versionName,
                                mPackageInfo.getLongVersionCode())));

        addRow(
                category,
                R.string.sable_sdk,
                evidence(
                        R.string.sable_evidence_declared,
                        getString(
                                R.string.sable_sdk_format,
                                mApplicationInfo.minSdkVersion,
                                mApplicationInfo.targetSdkVersion)));

        addRow(
                category,
                R.string.sable_installer,
                evidence(R.string.sable_evidence_observed, getInstallerSummary()));

        final SigningInfo signingInfo = mPackageInfo.signingInfo;
        final Signature[] currentSigners = signingInfo == null
                ? null
                : signingInfo.getApkContentsSigners();
        final String signerDigest = firstSignerDigest(currentSigners);
        addRow(
                category,
                R.string.sable_signing,
                evidence(R.string.sable_evidence_declared, signerDigest));

        int lineageCount = currentSigners == null ? 0 : currentSigners.length;
        String lineageState = getString(R.string.sable_no);
        if (signingInfo != null && signingInfo.hasPastSigningCertificates()) {
            final Signature[] history = signingInfo.getSigningCertificateHistory();
            lineageCount = history == null ? lineageCount : history.length;
            lineageState = getString(R.string.sable_yes);
        }
        addRow(
                category,
                R.string.sable_signing_lineage,
                evidence(
                        R.string.sable_evidence_declared,
                        getString(
                                R.string.sable_signing_lineage_format,
                                lineageState,
                                lineageCount)));

        final String installClass;
        if ((mApplicationInfo.flags & ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0) {
            installClass = getString(R.string.sable_updated_system_app);
        } else if ((mApplicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0) {
            installClass = getString(R.string.sable_system_image);
        } else {
            installClass = getString(R.string.sable_user_installed);
        }
        addRow(
                category,
                R.string.sable_install_class,
                evidence(R.string.sable_evidence_declared, installClass));

        final List<String> buildFlags = new ArrayList<>();
        if ((mApplicationInfo.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            buildFlags.add(getString(R.string.sable_debuggable));
        }
        if ((mApplicationInfo.flags & ApplicationInfo.FLAG_TEST_ONLY) != 0) {
            buildFlags.add(getString(R.string.sable_test_only));
        }
        if (buildFlags.isEmpty()) {
            buildFlags.add(getString(R.string.sable_release_build));
        }
        addRow(
                category,
                R.string.sable_build_flags,
                evidence(
                        R.string.sable_evidence_declared,
                        TextUtils.join(" · ", buildFlags)));
    }

    private void populateAuthority() {
        final PreferenceCategory category = findPreference(KEY_AUTHORITY);
        if (category == null) {
            return;
        }

        final Set<String> requested = new HashSet<>();
        if (mPackageInfo.requestedPermissions != null) {
            requested.addAll(Arrays.asList(mPackageInfo.requestedPermissions));
        }

        final Capability[] capabilities = new Capability[] {
            new Capability(R.string.sable_capability_camera, Manifest.permission.CAMERA),
            new Capability(
                    R.string.sable_capability_microphone,
                    Manifest.permission.RECORD_AUDIO),
            new Capability(
                    R.string.sable_capability_location,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            new Capability(
                    R.string.sable_capability_contacts,
                    Manifest.permission.READ_CONTACTS,
                    Manifest.permission.WRITE_CONTACTS),
            new Capability(
                    R.string.sable_capability_calendar,
                    Manifest.permission.READ_CALENDAR,
                    Manifest.permission.WRITE_CALENDAR),
            new Capability(
                    R.string.sable_capability_phone,
                    Manifest.permission.READ_PHONE_STATE,
                    Manifest.permission.READ_PHONE_NUMBERS,
                    Manifest.permission.CALL_PHONE,
                    Manifest.permission.READ_CALL_LOG,
                    Manifest.permission.WRITE_CALL_LOG),
            new Capability(
                    R.string.sable_capability_messages,
                    Manifest.permission.READ_SMS,
                    Manifest.permission.SEND_SMS,
                    Manifest.permission.RECEIVE_SMS),
            new Capability(
                    R.string.sable_capability_nearby,
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.NEARBY_WIFI_DEVICES),
            new Capability(
                    R.string.sable_capability_media,
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_AUDIO),
            new Capability(
                    R.string.sable_capability_sensors,
                    Manifest.permission.BODY_SENSORS,
                    Manifest.permission.BODY_SENSORS_BACKGROUND),
            new Capability(
                    R.string.sable_capability_notifications,
                    Manifest.permission.POST_NOTIFICATIONS),
        };

        int rows = 0;
        for (Capability capability : capabilities) {
            boolean declared = false;
            boolean granted = false;
            final LinkedHashSet<String> appOpModes = new LinkedHashSet<>();

            for (String permission : capability.permissions) {
                if (!requested.contains(permission)) {
                    continue;
                }
                declared = true;
                if (mPm.checkPermission(permission, mPackageName)
                        == PackageManager.PERMISSION_GRANTED) {
                    granted = true;
                }

                final String appOp = AppOpsManager.permissionToOp(permission);
                if (!TextUtils.isEmpty(appOp)) {
                    appOpModes.add(readAppOpMode(appOp));
                }
            }

            if (!declared) {
                continue;
            }

            rows++;
            final String appOpSummary = appOpModes.isEmpty()
                    ? getString(R.string.sable_not_applicable)
                    : TextUtils.join(", ", appOpModes);
            final String evidenceClass =
                    getString(R.string.sable_evidence_declared)
                            + " / "
                            + getString(R.string.sable_evidence_enforced);
            addRow(
                    category,
                    capability.labelRes,
                    getString(
                            R.string.sable_authority_format,
                            evidenceClass,
                            yesNo(declared),
                            yesNo(granted),
                            appOpSummary));
        }

        if (rows == 0) {
            addRow(
                    category,
                    getString(R.string.sable_no_sensitive_authority_title),
                    evidence(
                            R.string.sable_evidence_enforced,
                            getString(R.string.sable_no_sensitive_authority_summary)));
        }
    }

    private void populateComponents() {
        final PreferenceCategory category = findPreference(KEY_COMPONENTS);
        if (category == null) {
            return;
        }

        final ComponentSummary activities = summarizeActivities(mPackageInfo.activities);
        final ComponentSummary services = summarizeServices(mPackageInfo.services);
        final ComponentSummary receivers = summarizeActivities(mPackageInfo.receivers);
        final ComponentSummary providers = summarizeProviders(mPackageInfo.providers);

        addComponentRow(category, R.string.sable_activities, activities);
        addComponentRow(category, R.string.sable_services, services);
        addComponentRow(category, R.string.sable_receivers, receivers);
        addComponentRow(category, R.string.sable_providers, providers);

        final int instrumentationCount =
                mPackageInfo.instrumentation == null ? 0 : mPackageInfo.instrumentation.length;
        addRow(
                category,
                R.string.sable_instrumentation,
                evidence(
                        R.string.sable_evidence_declared,
                        Integer.toString(instrumentationCount)));

        final LinkedHashSet<String> elevated = new LinkedHashSet<>();
        if (mPackageInfo.services != null) {
            for (ServiceInfo service : mPackageInfo.services) {
                final String permission = service.permission;
                if (PERMISSION_BIND_ACCESSIBILITY.equals(permission)) {
                    elevated.add(getString(R.string.sable_elevated_accessibility));
                } else if (PERMISSION_BIND_NOTIFICATION_LISTENER.equals(permission)) {
                    elevated.add(getString(R.string.sable_elevated_notification_listener));
                } else if (PERMISSION_BIND_VPN.equals(permission)) {
                    elevated.add(getString(R.string.sable_elevated_vpn));
                } else if (PERMISSION_BIND_INPUT_METHOD.equals(permission)) {
                    elevated.add(getString(R.string.sable_elevated_input_method));
                } else if (PERMISSION_BIND_AUTOFILL.equals(permission)) {
                    elevated.add(getString(R.string.sable_elevated_autofill));
                }
            }
        }
        if (mPackageInfo.receivers != null) {
            for (ActivityInfo receiver : mPackageInfo.receivers) {
                if (PERMISSION_BIND_DEVICE_ADMIN.equals(receiver.permission)) {
                    elevated.add(getString(R.string.sable_elevated_device_admin));
                }
            }
        }

        if (elevated.isEmpty()) {
            addRow(
                    category,
                    R.string.sable_elevated_components,
                    getString(
                            R.string.sable_elevated_components_none,
                            getString(R.string.sable_evidence_declared)));
        } else {
            addRow(
                    category,
                    R.string.sable_elevated_components,
                    getString(
                            R.string.sable_elevated_components_format,
                            getString(R.string.sable_evidence_declared),
                            TextUtils.join(" · ", elevated)));
        }
    }

    private void populateCodeAndLibraries() {
        final PreferenceCategory category = findPreference(KEY_CODE);
        if (category == null) {
            return;
        }

        final NativeCodeEvidence nativeCode = scanNativeCode();
        if (!nativeCode.scanSucceeded) {
            addRow(
                    category,
                    R.string.sable_native_code,
                    evidence(
                            R.string.sable_evidence_unknown,
                            getString(R.string.sable_unavailable)));
        } else {
            final String abiSummary = nativeCode.abis.isEmpty()
                    ? getString(R.string.sable_none)
                    : TextUtils.join(", ", nativeCode.abis);
            addRow(
                    category,
                    R.string.sable_native_code,
                    getString(
                            R.string.sable_native_summary_format,
                            getString(R.string.sable_evidence_inferred),
                            nativeCode.libraries.size(),
                            abiSummary));
        }

        final String[] sharedLibraryFiles = mApplicationInfo.sharedLibraryFiles;
        final int sharedCount = sharedLibraryFiles == null ? 0 : sharedLibraryFiles.length;
        addRow(
                category,
                R.string.sable_shared_libraries,
                getString(
                        R.string.sable_shared_libraries_format,
                        getString(R.string.sable_evidence_declared),
                        sharedCount));

        addRow(
                category,
                R.string.sable_tracker_signals,
                getString(
                        R.string.sable_unknown_tracker_summary,
                        getString(R.string.sable_evidence_unknown)));
    }

    private void populateNetworkAndBackground() {
        final PreferenceCategory category = findPreference(KEY_NETWORK_BACKGROUND);
        if (category == null) {
            return;
        }

        final boolean internetDeclared = isPermissionRequested(Manifest.permission.INTERNET);
        final boolean internetGranted =
                mPm.checkPermission(Manifest.permission.INTERNET, mPackageName)
                        == PackageManager.PERMISSION_GRANTED;
        final String networkEvidence =
                getString(R.string.sable_evidence_declared)
                        + " / "
                        + getString(R.string.sable_evidence_enforced);
        addRow(
                category,
                R.string.sable_network_authority,
                getString(
                        R.string.sable_network_authority_format,
                        networkEvidence,
                        yesNo(internetDeclared),
                        yesNo(internetGranted)));

        addRow(
                category,
                R.string.sable_network_usage,
                getString(
                        R.string.sable_unknown_network_usage_summary,
                        getString(R.string.sable_evidence_unknown)));

        final PowerManager powerManager = mUserContext.getSystemService(PowerManager.class);
        final String backgroundSummary;
        try {
            backgroundSummary =
                    powerManager != null
                            && powerManager.isIgnoringBatteryOptimizations(mPackageName)
                    ? getString(R.string.sable_battery_unrestricted)
                    : getString(R.string.sable_battery_managed);
        } catch (RuntimeException e) {
            addRow(
                    category,
                    R.string.sable_background_policy,
                    evidence(
                            R.string.sable_evidence_unknown,
                            getString(R.string.sable_unavailable)));
            addStoppedState(category);
            return;
        }

        addRow(
                category,
                R.string.sable_background_policy,
                evidence(R.string.sable_evidence_enforced, backgroundSummary));
        addStoppedState(category);
    }

    private void addStoppedState(PreferenceCategory category) {
        final boolean stopped =
                (mApplicationInfo.flags & ApplicationInfo.FLAG_STOPPED) != 0;
        addRow(
                category,
                R.string.sable_package_stopped_state,
                evidence(
                        R.string.sable_evidence_enforced,
                        stopped
                                ? getString(R.string.sable_stopped)
                                : getString(R.string.sable_not_stopped)));
    }

    private void populateHistory() {
        final PreferenceCategory category = findPreference(KEY_HISTORY);
        if (category == null) {
            return;
        }

        addRow(
                category,
                R.string.sable_first_install,
                evidence(
                        R.string.sable_evidence_observed,
                        formatTimestamp(mPackageInfo.firstInstallTime)));
        addRow(
                category,
                R.string.sable_last_update,
                evidence(
                        R.string.sable_evidence_observed,
                        formatTimestamp(mPackageInfo.lastUpdateTime)));
        addRow(
                category,
                R.string.sable_change_history,
                getString(
                        R.string.sable_unknown_history_summary,
                        getString(R.string.sable_evidence_unknown)));
    }

    private String getInstallerSummary() {
        try {
            final InstallSourceInfo source = mPm.getInstallSourceInfo(mPackageName);
            final List<String> values = new ArrayList<>();
            if (!TextUtils.isEmpty(source.getInstallingPackageName())) {
                values.add(source.getInstallingPackageName());
            }
            if (!TextUtils.isEmpty(source.getInitiatingPackageName())
                    && !values.contains(source.getInitiatingPackageName())) {
                values.add(source.getInitiatingPackageName());
            }
            if (!TextUtils.isEmpty(source.getOriginatingPackageName())
                    && !values.contains(source.getOriginatingPackageName())) {
                values.add(source.getOriginatingPackageName());
            }
            return values.isEmpty()
                    ? getString(R.string.sable_unavailable)
                    : TextUtils.join(" · ", values);
        } catch (PackageManager.NameNotFoundException | RuntimeException e) {
            return getString(R.string.sable_unavailable);
        }
    }

    private String firstSignerDigest(Signature[] signatures) {
        if (signatures == null || signatures.length == 0) {
            return getString(R.string.sable_unavailable);
        }
        try {
            final byte[] digest =
                    MessageDigest.getInstance("SHA-256")
                            .digest(signatures[0].toByteArray());
            final StringBuilder out = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                out.append(String.format(Locale.ROOT, "%02X", value & 0xff));
            }
            return "SHA-256 " + out;
        } catch (NoSuchAlgorithmException e) {
            return getString(R.string.sable_unavailable);
        }
    }

    private String readAppOpMode(String op) {
        try {
            final AppOpsManager appOps = mUserContext.getSystemService(AppOpsManager.class);
            if (appOps == null) {
                return getString(R.string.sable_unavailable);
            }
            final int mode = appOps.unsafeCheckOpNoThrow(op, mUid, mPackageName);
            switch (mode) {
                case AppOpsManager.MODE_ALLOWED:
                    return getString(R.string.sable_allowed);
                case AppOpsManager.MODE_FOREGROUND:
                    return getString(R.string.sable_foreground_only);
                case AppOpsManager.MODE_IGNORED:
                    return getString(R.string.sable_ignored);
                case AppOpsManager.MODE_ERRORED:
                    return getString(R.string.sable_denied);
                case AppOpsManager.MODE_DEFAULT:
                    return getString(R.string.sable_default);
                default:
                    return getString(R.string.sable_appop_mode_format, mode);
            }
        } catch (RuntimeException e) {
            return getString(R.string.sable_unavailable);
        }
    }

    private boolean isPermissionRequested(String permission) {
        if (mPackageInfo.requestedPermissions == null) {
            return false;
        }
        for (String requested : mPackageInfo.requestedPermissions) {
            if (TextUtils.equals(permission, requested)) {
                return true;
            }
        }
        return false;
    }

    private NativeCodeEvidence scanNativeCode() {
        final NativeCodeEvidence evidence = new NativeCodeEvidence();
        final List<String> apkPaths = new ArrayList<>();
        if (!TextUtils.isEmpty(mApplicationInfo.sourceDir)) {
            apkPaths.add(mApplicationInfo.sourceDir);
        }
        if (mApplicationInfo.splitSourceDirs != null) {
            apkPaths.addAll(Arrays.asList(mApplicationInfo.splitSourceDirs));
        }

        for (String path : apkPaths) {
            try (ZipFile zip = new ZipFile(path)) {
                evidence.scanSucceeded = true;
                final Enumeration<? extends ZipEntry> entries = zip.entries();
                while (entries.hasMoreElements()) {
                    final String name = entries.nextElement().getName();
                    if (!name.startsWith("lib/") || !name.endsWith(".so")) {
                        continue;
                    }
                    final String[] parts = name.split("/");
                    if (parts.length >= 3) {
                        evidence.abis.add(parts[1]);
                        evidence.libraries.add(parts[parts.length - 1]);
                    }
                }
            } catch (IOException | RuntimeException ignored) {
                // UNKNOWN is surfaced only when no APK could be scanned.
            }
        }

        return evidence;
    }

    private ComponentSummary summarizeActivities(ActivityInfo[] infos) {
        final ComponentSummary summary = new ComponentSummary();
        if (infos == null) {
            return summary;
        }
        for (ActivityInfo info : infos) {
            summary.total++;
            if (info.enabled) {
                summary.enabled++;
            }
            if (info.exported) {
                summary.exported++;
                addExposedName(summary, info.name);
                if (TextUtils.isEmpty(info.permission)) {
                    summary.exportedWithoutPermission++;
                }
            }
        }
        return summary;
    }

    private ComponentSummary summarizeServices(ServiceInfo[] infos) {
        final ComponentSummary summary = new ComponentSummary();
        if (infos == null) {
            return summary;
        }
        for (ServiceInfo info : infos) {
            summary.total++;
            if (info.enabled) {
                summary.enabled++;
            }
            if (info.exported) {
                summary.exported++;
                addExposedName(summary, info.name);
                if (TextUtils.isEmpty(info.permission)) {
                    summary.exportedWithoutPermission++;
                }
            }
        }
        return summary;
    }

    private ComponentSummary summarizeProviders(ProviderInfo[] infos) {
        final ComponentSummary summary = new ComponentSummary();
        if (infos == null) {
            return summary;
        }
        for (ProviderInfo info : infos) {
            summary.total++;
            if (info.enabled) {
                summary.enabled++;
            }
            if (info.exported) {
                summary.exported++;
                addExposedName(summary, info.name);
                if (TextUtils.isEmpty(info.readPermission)
                        && TextUtils.isEmpty(info.writePermission)) {
                    summary.exportedWithoutPermission++;
                }
            }
        }
        return summary;
    }

    private void addExposedName(ComponentSummary summary, String name) {
        if (summary.exportedNames.size() >= 4 || TextUtils.isEmpty(name)) {
            return;
        }
        final int separator = name.lastIndexOf('.');
        summary.exportedNames.add(separator >= 0 ? name.substring(separator + 1) : name);
    }

    private void addComponentRow(
            PreferenceCategory category,
            int titleRes,
            ComponentSummary summary) {
        final String evidenceClass = getString(R.string.sable_evidence_declared);
        final String detail;
        if (summary.exportedNames.isEmpty()) {
            detail = getString(
                    R.string.sable_component_summary_format,
                    evidenceClass,
                    summary.total,
                    summary.enabled,
                    summary.exported,
                    summary.exportedWithoutPermission);
        } else {
            detail = getString(
                    R.string.sable_component_summary_with_names_format,
                    evidenceClass,
                    summary.total,
                    summary.enabled,
                    summary.exported,
                    summary.exportedWithoutPermission,
                    TextUtils.join(", ", summary.exportedNames));
        }
        addRow(category, titleRes, detail);
    }

    private String formatTimestamp(long millis) {
        if (millis <= 0) {
            return getString(R.string.sable_unavailable);
        }
        return DateFormat.getDateTimeInstance(
                        DateFormat.MEDIUM,
                        DateFormat.SHORT)
                .format(new Date(millis));
    }

    private String yesNo(boolean value) {
        return getString(value ? R.string.sable_yes : R.string.sable_no);
    }

    private String evidence(int evidenceRes, String detail) {
        return getString(evidenceRes) + " · " + detail;
    }

    private void addRow(
            PreferenceCategory category,
            int titleRes,
            CharSequence summary) {
        addRow(category, getString(titleRes), summary);
    }

    private void addRow(
            PreferenceCategory category,
            CharSequence title,
            CharSequence summary) {
        final Preference preference = new Preference(getPrefContext());
        preference.setTitle(title);
        preference.setSummary(summary);
        preference.setSelectable(false);
        category.addPreference(preference);
    }
}
