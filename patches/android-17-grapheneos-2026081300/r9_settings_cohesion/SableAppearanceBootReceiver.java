package com.android.settings.sable;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class SableAppearanceBootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : null;
        if (Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
            SableAppearanceProvider.applyStoredMode(context);
        }
    }
}
