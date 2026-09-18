package org.sableos.start.platform

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.os.Process
import android.os.UserManager
import org.sableos.start.model.AppEntry
import java.util.Locale

class LauncherAppsRepository(
    context: Context,
) {
    private val appContext = context.applicationContext

    private val launcherApps =
        appContext.getSystemService(LauncherApps::class.java)

    private val userManager =
        appContext.getSystemService(UserManager::class.java)

    fun loadApps(): List<AppEntry> {
        val locale = Locale.getDefault()

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
                compareBy<AppEntry> {
                    it.label.lowercase(locale)
                }
                    .thenBy {
                        it.component.packageName
                    }
                    .thenBy {
                        it.component.className
                    }
                    .thenBy {
                        userManager.getSerialNumberForUser(it.user)
                    },
            )
    }

    fun launch(entry: AppEntry): Boolean {
        return try {
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

            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    fun registerCallback(callback: LauncherApps.Callback) {
        launcherApps.registerCallback(callback)
    }

    fun unregisterCallback(callback: LauncherApps.Callback) {
        launcherApps.unregisterCallback(callback)
    }
}
