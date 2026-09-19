/*
 * SableOS UI5A: concise effective-sensitive-access summary for the normal
 * Settings application list.
 *
 * This deliberately reports only effective Android permission grants. It does
 * not infer runtime use, tracker behavior, network destinations, or component
 * risk. Deeper evidence belongs to UI5B Application Security & Privacy.
 */
package com.android.settings.applications.manageapplications;

import android.Manifest;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.UserHandle;

import com.android.settings.R;

import java.util.ArrayList;
import java.util.List;

final class SableSensitiveAccessSummary {
    private static final int MAX_VISIBLE_CAPABILITIES = 3;

    private SableSensitiveAccessSummary() {}

    static CharSequence getSummary(Context context, ApplicationInfo info) {
        if (info == null || info.packageName == null) {
            return context.getString(R.string.sable_no_sensitive_access_granted);
        }

        final Context userContext;
        try {
            userContext = context.createContextAsUser(
                    UserHandle.getUserHandleForUid(info.uid), 0);
        } catch (RuntimeException e) {
            return context.getString(R.string.sable_sensitive_access_unknown);
        }

        final PackageManager pm = userContext.getPackageManager();
        final List<String> capabilities = new ArrayList<>();

        addIfGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_camera,
                Manifest.permission.CAMERA);
        addIfGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_microphone,
                Manifest.permission.RECORD_AUDIO);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_location,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_contacts,
                Manifest.permission.READ_CONTACTS,
                Manifest.permission.WRITE_CONTACTS);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_calendar,
                Manifest.permission.READ_CALENDAR,
                Manifest.permission.WRITE_CALENDAR);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_phone,
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.CALL_PHONE,
                Manifest.permission.READ_CALL_LOG,
                Manifest.permission.WRITE_CALL_LOG);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_messages,
                Manifest.permission.READ_SMS,
                Manifest.permission.SEND_SMS,
                Manifest.permission.RECEIVE_SMS);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_nearby_devices,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_photos_videos,
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO);
        addIfGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_music_audio,
                Manifest.permission.READ_MEDIA_AUDIO);
        addIfAnyGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_sensors,
                Manifest.permission.BODY_SENSORS,
                Manifest.permission.BODY_SENSORS_BACKGROUND);
        addIfGranted(pm, info.packageName, capabilities,
                R.string.sable_sensitive_notifications,
                Manifest.permission.POST_NOTIFICATIONS);

        if (capabilities.isEmpty()) {
            return context.getString(R.string.sable_no_sensitive_access_granted);
        }

        final int visible = Math.min(capabilities.size(), MAX_VISIBLE_CAPABILITIES);
        final StringBuilder summary = new StringBuilder();
        for (int i = 0; i < visible; i++) {
            if (i > 0) {
                summary.append(" · ");
            }
            summary.append(capabilities.get(i));
        }

        final int remaining = capabilities.size() - visible;
        if (remaining > 0) {
            summary.append(" · ");
            summary.append(context.getResources().getQuantityString(
                    R.plurals.sable_sensitive_more_count,
                    remaining,
                    remaining));
        }

        return summary;
    }

    private static void addIfGranted(
            PackageManager pm,
            String packageName,
            List<String> out,
            int labelRes,
            String permission) {
        if (pm.checkPermission(permission, packageName)
                == PackageManager.PERMISSION_GRANTED) {
            out.add(pm.getResources().getString(labelRes));
        }
    }

    private static void addIfAnyGranted(
            PackageManager pm,
            String packageName,
            List<String> out,
            int labelRes,
            String... permissions) {
        for (String permission : permissions) {
            if (pm.checkPermission(permission, packageName)
                    == PackageManager.PERMISSION_GRANTED) {
                out.add(pm.getResources().getString(labelRes));
                return;
            }
        }
    }
}
