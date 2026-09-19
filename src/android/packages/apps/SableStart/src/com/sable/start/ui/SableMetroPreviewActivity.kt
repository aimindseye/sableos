package org.sableos.start.ui

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.platform.LiveSurfaceRepository

/**
 * Development-only UI-A navigator.
 *
 * This Activity does not participate in HOME resolution. It renders the same
 * production SableStartScreen used by the launcher, with a small development
 * navigator for reviewing Start, Apps, Search, Pinned/Recent, and Live.
 */
class SableMetroPreviewActivity : ComponentActivity() {
    private val launcherAppsRepository by lazy {
        LauncherAppsRepository(this)
    }

    private val liveSurfaceRepository by lazy {
        LiveSurfaceRepository(this)
    }

    private val appsState =
        mutableStateOf<List<AppEntry>>(emptyList())

    private var liveRefreshGeneration by mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        refreshInventory()

        setContent {
            SableStartScreen(
                apps = appsState.value,
                liveSurfaceRepository = liveSurfaceRepository,
                refreshGeneration = liveRefreshGeneration,
                showDevelopmentNavigator = true,
                onLaunchApp = { entry ->
                    val launched = launcherAppsRepository.launch(entry)
                    if (!launched) {
                        refreshInventory()
                    }
                    launched
                },
                onOpenSettings = ::openSettings,
                onOpenAppInfo = { entry ->
                    launcherAppsRepository.openAppDetails(entry)
                },
                onRequestLivePermissions = ::requestLivePermissions,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        refreshInventory()
    }

    private fun refreshInventory() {
        appsState.value = launcherAppsRepository.loadApps()
    }

    private fun openSettings() {
        runCatching {
            startActivity(Intent(Settings.ACTION_SETTINGS))
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )

        if (requestCode == LIVE_PERMISSION_REQUEST_CODE) {
            liveRefreshGeneration += 1
        }
    }

    private companion object {
        const val LIVE_PERMISSION_REQUEST_CODE = 0x534D
    }
}
