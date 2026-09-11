package org.sableos.start.platform

import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.os.Process
import android.os.UserManager
import org.sableos.start.model.AppEntry

class LauncherAppsRepository(
    context: Context,
) {
    private val appContext = context.applicationContext

    private val launcherApps =
        appContext.getSystemService(LauncherApps::class.java)

    private val userManager =
        appContext.getSystemService(UserManager::class.java)

    fun loadApps(): List<AppEntry> {
        return userManager.userProfiles
            .flatMap { user ->
                launcherApps
                    .getActivityList(null, user)
                    .map { info ->
                        AppEntry(
                            label = info.label.toString(),
                            component = info.componentName,
                            user = user,
                        )
                    }
            }
            .sortedWith(
                compareBy(
                    String.CASE_INSENSITIVE_ORDER,
                ) {
                    it.label
                }
            )
    }

    fun launch(entry: AppEntry) {
        if (entry.user == Process.myUserHandle()) {
            val intent =
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER)
                    .setComponent(entry.component)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            appContext.startActivity(intent)
        } else {
            launcherApps.startMainActivity(
                entry.component,
                entry.user,
                null,
                null,
            )
        }
    }
}
