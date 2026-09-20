package org.sableos.start.visualreview

import android.Manifest
import android.content.Intent
import android.content.pm.LauncherApps
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import org.sableos.design.SableAppearance
import org.sableos.start.model.AppEntry
import org.sableos.start.model.stableKey
import org.sableos.start.platform.LiveSurfaceRepository
import org.sableos.start.ui.SableStartScreen
import java.util.Locale

/**
 * Non-product Android Studio / Pixel 7 emulator host for the production R9
 * SableStartScreen.
 *
 * This APK deliberately has no HOME intent filter and is never part of the
 * Panther product. Launcher3QuickStep remains the only product HOME. The
 * activity exists solely to make the exact production presentation source
 * fast to review on the established Mac mini emulator workflow.
 */
class R9LauncherVisualReviewActivity : ComponentActivity() {
    private val appsState = mutableStateOf<List<AppEntry>>(emptyList())
    private val appearanceState = mutableStateOf(SableAppearance())
    private val refreshGeneration = mutableStateOf(0)

    private lateinit var launcherApps: LauncherApps
    private lateinit var liveSurfaceRepository: LiveSurfaceRepository

    private var pinnedKeys: Set<String> = emptySet()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enableEdgeToEdge()
        launcherApps = getSystemService(LauncherApps::class.java)
        liveSurfaceRepository = LiveSurfaceRepository(this)

        refreshInventory()
        pinnedKeys = defaultPinnedKeys(appsState.value)

        setContent {
            SableStartScreen(
                apps = appsState.value,
                liveSurfaceRepository = liveSurfaceRepository,
                appearance = appearanceState.value,
                refreshGeneration = refreshGeneration.value,
                initialPinnedKeys = pinnedKeys,
                onPinnedKeysChanged = { keys ->
                    pinnedKeys = keys
                },
                onAppearanceChanged = { appearance ->
                    appearanceState.value = appearance
                },
                onResetAppearance = {
                    appearanceState.value = SableAppearance()
                },
                onLaunchApp = ::launchApp,
                onOpenSettings = ::openSettings,
                onOpenAppInfo = ::openAppInfo,
                onRequestLivePermissions = ::requestLivePermissions,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        if (::launcherApps.isInitialized) {
            refreshInventory()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == LIVE_PERMISSION_REQUEST_CODE) {
            refreshGeneration.value += 1
        }
    }

    private fun refreshInventory() {
        val locale = Locale.getDefault()

        appsState.value =
            launcherApps.profiles
                .flatMap { user ->
                    launcherApps.getActivityList(null, user).mapNotNull { info ->
                        val label = info.label?.toString()?.trim().orEmpty()
                        if (label.isEmpty()) {
                            null
                        } else {
                            AppEntry(
                                label = label,
                                component = info.componentName,
                                user = info.user,
                            )
                        }
                    }
                }
                .distinctBy { entry -> entry.stableKey() }
                .sortedWith(
                    compareBy<AppEntry> { entry ->
                        entry.label.lowercase(locale)
                    }.thenBy { entry ->
                        entry.component.flattenToString()
                    }.thenBy { entry ->
                        entry.user.hashCode()
                    },
                )
    }

    private fun launchApp(entry: AppEntry): Boolean =
        runCatching {
            launcherApps.startMainActivity(
                entry.component,
                entry.user,
                null,
                null,
            )
            true
        }.getOrElse {
            false
        }

    private fun openSettings() {
        runCatching {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun openAppInfo(entry: AppEntry) {
        runCatching {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${entry.component.packageName}"),
                ),
            )
        }
    }

    private fun requestLivePermissions() {
        val permissions =
            buildList {
                add(Manifest.permission.READ_CALENDAR)
                if (Build.VERSION.SDK_INT >= 33) {
                    add(Manifest.permission.READ_MEDIA_IMAGES)
                    add(Manifest.permission.READ_MEDIA_AUDIO)
                } else {
                    add(Manifest.permission.READ_EXTERNAL_STORAGE)
                }
            }

        requestPermissions(
            permissions.toTypedArray(),
            LIVE_PERMISSION_REQUEST_CODE,
        )
    }

    private fun defaultPinnedKeys(apps: List<AppEntry>): Set<String> {
        val selected = linkedMapOf<String, AppEntry>()

        REVIEW_PIN_LABELS.forEach { preferred ->
            apps.firstOrNull { entry ->
                entry.label.equals(preferred, ignoreCase = true)
            }?.let { entry ->
                selected.putIfAbsent(entry.stableKey(), entry)
            }
        }

        apps.forEach { entry ->
            if (selected.size < REVIEW_PIN_COUNT) {
                selected.putIfAbsent(entry.stableKey(), entry)
            }
        }

        return selected.values
            .take(REVIEW_PIN_COUNT)
            .mapTo(linkedSetOf()) { entry -> entry.stableKey() }
    }

    private companion object {
        const val LIVE_PERMISSION_REQUEST_CODE = 0x5239
        const val REVIEW_PIN_COUNT = 3

        val REVIEW_PIN_LABELS =
            listOf(
                "Phone",
                "Calendar",
                "Calculator",
                "Files",
                "Camera",
            )
    }
}
