package org.sableos.start

import android.content.pm.LauncherApps
import android.os.Bundle
import android.os.UserHandle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import org.sableos.start.bridge.SableStartNative
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.ui.SableStartRoot

class SableStartActivity : ComponentActivity() {
    private var nativeHandle: Long = 0

    private lateinit var launcherAppsRepository: LauncherAppsRepository

    private val appsState =
        mutableStateOf<List<AppEntry>>(emptyList())

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

        refreshInventory()

        setContent {
            SableStartRoot(
                apps = appsState.value,
                onLaunchApp = { entry ->
                    if (!launcherAppsRepository.launch(entry)) {
                        refreshInventory()
                    }
                },
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

    private fun scheduleInventoryRefresh() {
        runOnUiThread {
            refreshInventory()
        }
    }

    private fun refreshInventory() {
        appsState.value =
            launcherAppsRepository.loadApps()
    }
}
