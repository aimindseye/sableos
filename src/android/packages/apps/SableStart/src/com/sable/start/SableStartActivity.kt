package org.sableos.start

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import org.sableos.start.bridge.SableStartNative
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.ui.SableStartRoot

class SableStartActivity : ComponentActivity() {
    private var nativeHandle: Long = 0

    private lateinit var launcherAppsRepository: LauncherAppsRepository

    override fun onCreate(
        savedInstanceState: Bundle?,
    ) {
        super.onCreate(savedInstanceState)

        nativeHandle =
            SableStartNative.nativeCreate()

        launcherAppsRepository =
            LauncherAppsRepository(this)

        setContent {
            SableStartRoot(
                repository = launcherAppsRepository,
            )
        }
    }

    override fun onDestroy() {
        if (nativeHandle != 0L) {
            SableStartNative.nativeDestroy(
                nativeHandle,
            )

            nativeHandle = 0
        }

        super.onDestroy()
    }
}
