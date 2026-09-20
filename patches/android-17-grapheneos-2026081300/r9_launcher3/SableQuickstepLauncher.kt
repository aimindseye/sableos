package com.android.launcher3.sable

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.android.launcher3.LauncherState
import com.android.launcher3.allapps.AllAppsStore
import com.android.launcher3.model.data.AppInfo
import com.android.launcher3.uioverrides.QuickstepLauncher
import com.android.launcher3.util.ComponentKey
import com.android.launcher3.util.PackageManagerHelper
import com.android.launcher3.views.BaseDragLayer
import org.sableos.design.SableAppearance
import org.sableos.design.applySableSystemBars
import org.sableos.design.resolveSableDarkAppearance
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LiveSurfaceRepository
import org.sableos.start.platform.StartStateRepository
import org.sableos.start.ui.SableStartScreen

/**
 * SableOS HOME presentation hosted by the upstream Launcher3/Quickstep activity.
 *
 * Launcher3 remains responsible for model loading, package/profile changes,
 * lifecycle, state restoration, app launching, widgets/shortcuts and Recents.
 * Sable owns the NORMAL-state presentation layered over that machinery.
 */
class SableQuickstepLauncher : QuickstepLauncher() {
    private val appsState = mutableStateOf<List<AppEntry>>(emptyList())
    private val appearanceState = mutableStateOf(SableAppearance())
    private val liveRefreshGeneration = mutableStateOf(0)
    private val homeGeneration = mutableStateOf(0)
    private val backGeneration = mutableStateOf(0)

    private lateinit var liveSurfaceRepository: LiveSurfaceRepository
    private lateinit var startStateRepository: StartStateRepository

    private var allAppsStore: AllAppsStore? = null
    private var sableView: ComposeView? = null
    private var canSableNavigateBack = false

    private val appsUpdateListener =
        AllAppsStore.OnUpdateListener {
            refreshAppsFromLauncherModel()
        }

    private val sableBackCallback =
        object : OnBackAnimationCallback {
            override fun onBackStarted(backEvent: BackEvent) = Unit

            override fun onBackProgressed(backEvent: BackEvent) = Unit

            override fun onBackCancelled() = Unit

            override fun onBackInvoked() {
                backGeneration.value += 1
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        liveSurfaceRepository = LiveSurfaceRepository(this)
        startStateRepository = StartStateRepository(this)
        appearanceState.value = startStateRepository.loadAppearance()

        allAppsStore =
            activityComponent.appsStore.also { store ->
                store.addUpdateListener(appsUpdateListener)
            }

        refreshAppsFromLauncherModel()
        installSableSurface()
        applyCurrentSystemBars()
        updateSableVisibility(isInState(LauncherState.NORMAL))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        if (intent.action == Intent.ACTION_MAIN) {
            homeGeneration.value += 1
        }
    }

    override fun onStateSetStart(state: LauncherState) {
        super.onStateSetStart(state)
        if (state != LauncherState.NORMAL) {
            updateSableVisibility(false)
        }
    }

    override fun onStateSetEnd(state: LauncherState) {
        super.onStateSetEnd(state)
        updateSableVisibility(state == LauncherState.NORMAL)
        if (state == LauncherState.NORMAL) {
            refreshAppsFromLauncherModel()
        }
    }

    protected override fun getOnBackAnimationCallback(): OnBackAnimationCallback =
        if (
            sableView?.visibility == View.VISIBLE &&
                canSableNavigateBack
        ) {
            sableBackCallback
        } else {
            super.getOnBackAnimationCallback()
        }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == LIVE_PERMISSION_REQUEST_CODE) {
            liveRefreshGeneration.value += 1
        }
    }

    override fun onDestroy() {
        allAppsStore?.removeUpdateListener(appsUpdateListener)
        allAppsStore = null

        sableView?.let { view ->
            dragLayer.removeView(view)
            view.disposeComposition()
        }
        sableView = null

        super.onDestroy()
    }

    private fun installSableSurface() {
        check(sableView == null) {
            "Sable launcher surface must be installed exactly once"
        }

        val view =
            ComposeView(this).apply {
                setViewCompositionStrategy(
                    ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
                )
                setContent {
                    SableStartScreen(
                        apps = appsState.value,
                        liveSurfaceRepository = liveSurfaceRepository,
                        appearance = appearanceState.value,
                        refreshGeneration = liveRefreshGeneration.value,
                        homeGeneration = homeGeneration.value,
                        backGeneration = backGeneration.value,
                        onCanNavigateBackChanged = { canNavigate ->
                            canSableNavigateBack = canNavigate
                        },
                        initialPinnedKeys = startStateRepository.loadPinnedKeys(),
                        onPinnedKeysChanged = startStateRepository::savePinnedKeys,
                        onAppearanceChanged = { appearance ->
                            appearanceState.value = appearance
                            startStateRepository.saveAppearance(appearance)
                            applyCurrentSystemBars()
                        },
                        onResetAppearance = {
                            appearanceState.value =
                                startStateRepository.resetAppearance()
                            applyCurrentSystemBars()
                        },
                        onLaunchApp = ::launchApp,
                        onOpenSettings = ::openSettings,
                        onOpenAppInfo = ::openAppDetails,
                        onRequestLivePermissions = ::requestLivePermissions,
                    )
                }
            }

        dragLayer.addView(
            view,
            BaseDragLayer.LayoutParams(MATCH_PARENT, MATCH_PARENT),
        )
        sableView = view
    }

    private fun updateSableVisibility(visible: Boolean) {
        val visibility =
            if (visible) {
                View.VISIBLE
            } else {
                View.GONE
            }

        sableView?.visibility = visibility

        val underlyingAccessibility =
            if (visible) {
                View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            } else {
                View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
            }

        workspace.importantForAccessibility = underlyingAccessibility
        hotseat.importantForAccessibility = underlyingAccessibility
        appsView.importantForAccessibility = underlyingAccessibility
    }

    private fun refreshAppsFromLauncherModel() {
        val store = allAppsStore ?: return

        appsState.value =
            store.apps
                .mapNotNull { info ->
                    val component = info.componentName ?: return@mapNotNull null
                    val label =
                        info.title
                            ?.toString()
                            ?.trim()
                            .orEmpty()

                    if (label.isEmpty()) {
                        null
                    } else {
                        AppEntry(
                            label = label,
                            component = component,
                            user = info.user,
                        )
                    }
                }
                .distinctBy { entry ->
                    ComponentKey(entry.component, entry.user)
                }
    }

    private fun findApp(entry: AppEntry): AppInfo? =
        allAppsStore?.getApp(
            ComponentKey(entry.component, entry.user),
        )

    private fun launchApp(entry: AppEntry): Boolean {
        val app = findApp(entry) ?: return false
        val intent = app.intent ?: return false

        return runCatching {
            startActivitySafely(
                sableView,
                Intent(intent),
                app,
            )
            true
        }.getOrDefault(false)
    }

    private fun openAppDetails(entry: AppEntry) {
        val app = findApp(entry) ?: return

        PackageManagerHelper.startDetailsActivityForInfo(
            this,
            app,
            null,
            null,
        )
    }

    private fun openSettings() {
        runCatching {
            startActivitySafely(
                sableView,
                Intent(Settings.ACTION_SETTINGS),
                null,
            )
        }
    }

    private fun applyCurrentSystemBars() {
        val activityWindow = window ?: return

        applySableSystemBars(
            window = activityWindow,
            darkTheme =
                resolveSableDarkAppearance(
                    context = this,
                    appearance = appearanceState.value,
                ),
        )
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
