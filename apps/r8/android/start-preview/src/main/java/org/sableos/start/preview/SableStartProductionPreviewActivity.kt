package org.sableos.start.preview

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.platform.LiveSurfaceRepository
import org.sableos.start.platform.StartStateRepository
import org.sableos.start.ui.SableStartScreen

/**
 * Android Studio/emulator adapter for the production Sable Start surface.
 *
 * This deliberately omits HOME intent resolution and the production JNI bridge.
 * The rendered Compose surface is the same SableStartScreen used by SableStartActivity.
 */
class SableStartProductionPreviewActivity : ComponentActivity() {
    private val launcherAppsRepository by lazy {
        LauncherAppsRepository(this)
    }

    private val liveSurfaceRepository by lazy {
        LiveSurfaceRepository(this)
    }

    private val startStateRepository by lazy {
        StartStateRepository(this)
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
                initialPinnedKeys = startStateRepository.loadPinnedKeys(),
                onPinnedKeysChanged = startStateRepository::savePinnedKeys,
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

    private companion object {
        const val LIVE_PERMISSION_REQUEST_CODE = 0x534D
    }
}
