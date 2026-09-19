package org.sableos.start

import android.Manifest
import android.content.Intent
import android.content.pm.LauncherApps
import android.os.Build
import android.os.Bundle
import android.os.UserHandle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import org.sableos.start.bridge.SableStartNative
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.platform.LiveSurfaceRepository
import org.sableos.start.platform.StartStateRepository
import org.sableos.start.ui.SableStartScreen

class SableStartActivity : ComponentActivity() {
    private var nativeHandle: Long = 0

    private lateinit var launcherAppsRepository: LauncherAppsRepository
    private lateinit var liveSurfaceRepository: LiveSurfaceRepository
    private lateinit var startStateRepository: StartStateRepository

    private val appsState =
        mutableStateOf<List<AppEntry>>(emptyList())

    private var liveRefreshGeneration by mutableStateOf(0)
    private var callbackRegistered = false

    private val launcherCallback =
        object : LauncherApps.Callback() {
            override fun onPackageRemoved(
                packageName: String,
                user: UserHandle,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackageAdded(
                packageName: String,
                user: UserHandle,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackageChanged(
                packageName: String,
                user: UserHandle,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackagesAvailable(
                vararg packageNames: String,
                user: UserHandle,
                replacing: Boolean,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackagesUnavailable(
                packageNames: Array<String>,
                user: UserHandle,
                replacing: Boolean,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackagesSuspended(
                vararg packageNames: String,
                user: UserHandle,
            ) {
                scheduleInventoryRefresh()
            }

            override fun onPackagesUnsuspended(
                vararg packageNames: String,
                user: UserHandle,
            ) {
                scheduleInventoryRefresh()
            }
        }

    override fun onCreate(
        savedInstanceState: Bundle?,
    ) {
        super.onCreate(savedInstanceState)

        nativeHandle =
            SableStartNative.nativeCreate()

        launcherAppsRepository =
            LauncherAppsRepository(this)

        liveSurfaceRepository =
            LiveSurfaceRepository(this)

        startStateRepository =
            StartStateRepository(this)

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

    override fun onStart() {
        super.onStart()

        if (!callbackRegistered) {
            launcherAppsRepository.registerCallback(launcherCallback)
            callbackRegistered = true
        }

        refreshInventory()
    }

    override fun onResume() {
        super.onResume()
        refreshInventory()
    }

    override fun onStop() {
        if (callbackRegistered) {
            launcherAppsRepository.unregisterCallback(launcherCallback)
            callbackRegistered = false
        }

        super.onStop()
    }

    override fun onDestroy() {
        if (callbackRegistered) {
            launcherAppsRepository.unregisterCallback(launcherCallback)
            callbackRegistered = false
        }

        if (nativeHandle != 0L) {
            SableStartNative.nativeDestroy(
                nativeHandle,
            )

            nativeHandle = 0
        }

        super.onDestroy()
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

    private fun scheduleInventoryRefresh() {
        runOnUiThread {
            refreshInventory()
        }
    }

    private fun refreshInventory() {
        appsState.value =
            launcherAppsRepository.loadApps()
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
