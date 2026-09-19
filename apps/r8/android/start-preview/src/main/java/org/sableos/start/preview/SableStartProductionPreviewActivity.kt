package org.sableos.start.preview

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.platform.LiveSurfaceRepository
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

    private val appsState =
        mutableStateOf<List<AppEntry>>(emptyList())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        refreshInventory()

        setContent {
            SableStartScreen(
                apps = appsState.value,
                liveSurfaceRepository = liveSurfaceRepository,
                onLaunchApp = { entry ->
                    if (!launcherAppsRepository.launch(entry)) {
                        refreshInventory()
                    }
                },
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
}
