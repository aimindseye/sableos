package com.android.launcher3.sable

import android.Manifest
import android.app.UiModeManager
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.os.UserHandle
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
import org.sableos.design.AppearanceMode
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

    override fun onResume() {
        super.onResume()

        // Permission state can change while Android App info is in front of
        // HOME without changing Launcher3's app inventory. Re-read the
        // lightweight privacy summary whenever HOME resumes so All Apps never
        // relies on a stale permission snapshot.
        if (allAppsStore != null) {
            refreshAppsFromLauncherModel()
        }
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
            applyCurrentSystemBars()
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
                            applyAppearanceToSystem(appearance)
                            applyCurrentSystemBars()
                        },
                        onResetAppearance = {
                            appearanceState.value =
                                startStateRepository.resetAppearance()
                            applyAppearanceToSystem(appearanceState.value)
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
                    if (component.packageName == GRAPHENE_MESSAGING_PACKAGE) {
                        return@mapNotNull null
                    }
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
                            privacySummary =
                                buildPrivacyPermissionSummary(
                                    packageName = component.packageName,
                                    user = info.user,
                                ),
                        )
                    }
                }
                .distinctBy { entry ->
                    ComponentKey(entry.component, entry.user)
                }
    }

    private fun buildPrivacyPermissionSummary(
        packageName: String,
        user: UserHandle,
    ): String {
        val profileContext =
            runCatching {
                createContextAsUser(user, 0)
            }.getOrElse {
                this
            }

        val packageInfo =
            runCatching {
                profileContext.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(
                        PackageManager.GET_PERMISSIONS.toLong(),
                    ),
                )
            }.getOrNull() ?: return "permissions · unavailable"

        val requested = packageInfo.requestedPermissions.orEmpty()
        val flags = packageInfo.requestedPermissionsFlags.orEmpty()

        val granted =
            buildSet {
                requested.forEachIndexed { index, permission ->
                    val permissionFlags = flags.getOrNull(index) ?: 0
                    if (
                        permissionFlags and
                            PackageInfo.REQUESTED_PERMISSION_GRANTED != 0
                    ) {
                        add(permission)
                    }
                }
            }

        val labels =
            PRIVACY_PERMISSION_GROUPS.mapNotNull { group ->
                group.label.takeIf { _ ->
                    group.permissions.any(granted::contains)
                }
            }

        return if (labels.isEmpty()) {
            "permissions · none sensitive"
        } else {
            "permissions · " + labels.joinToString(" · ")
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

    private fun applyAppearanceToSystem(
        appearance: SableAppearance,
    ) {
        val uiModeManager =
            getSystemService(UiModeManager::class.java)
                ?: return

        runCatching {
            when (appearance.mode) {
                AppearanceMode.FollowSystem -> {
                    startStateRepository
                        .loadSystemNightModeBeforeOverride()
                        ?.let { previousMode ->
                            uiModeManager.setNightMode(previousMode)
                            startStateRepository
                                .clearSystemNightModeBeforeOverride()
                        }
                }

                AppearanceMode.Light,
                AppearanceMode.Dark,
                -> {
                    startStateRepository
                        .rememberSystemNightModeBeforeOverride(
                            uiModeManager.nightMode,
                        )

                    uiModeManager.setNightMode(
                        if (appearance.mode == AppearanceMode.Dark) {
                            UiModeManager.MODE_NIGHT_YES
                        } else {
                            UiModeManager.MODE_NIGHT_NO
                        },
                    )
                }
            }
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

    private data class PrivacyPermissionGroup(
        val label: String,
        val permissions: Set<String>,
    )

    private companion object {
        const val GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"
        const val LIVE_PERMISSION_REQUEST_CODE = 0x534D

        val PRIVACY_PERMISSION_GROUPS =
            listOf(
                PrivacyPermissionGroup(
                    label = "location",
                    permissions =
                        setOf(
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "camera",
                    permissions = setOf(Manifest.permission.CAMERA),
                ),
                PrivacyPermissionGroup(
                    label = "microphone",
                    permissions = setOf(Manifest.permission.RECORD_AUDIO),
                ),
                PrivacyPermissionGroup(
                    label = "contacts",
                    permissions =
                        setOf(
                            Manifest.permission.READ_CONTACTS,
                            Manifest.permission.WRITE_CONTACTS,
                            Manifest.permission.GET_ACCOUNTS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "phone",
                    permissions =
                        setOf(
                            Manifest.permission.READ_PHONE_STATE,
                            Manifest.permission.READ_PHONE_NUMBERS,
                            Manifest.permission.CALL_PHONE,
                            Manifest.permission.ANSWER_PHONE_CALLS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "messages",
                    permissions =
                        setOf(
                            Manifest.permission.READ_SMS,
                            Manifest.permission.RECEIVE_SMS,
                            Manifest.permission.SEND_SMS,
                            Manifest.permission.RECEIVE_MMS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "calendar",
                    permissions =
                        setOf(
                            Manifest.permission.READ_CALENDAR,
                            Manifest.permission.WRITE_CALENDAR,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "photos",
                    permissions =
                        setOf(
                            Manifest.permission.READ_MEDIA_IMAGES,
                            Manifest.permission.READ_MEDIA_VIDEO,
                            Manifest.permission.READ_EXTERNAL_STORAGE,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "audio",
                    permissions = setOf(Manifest.permission.READ_MEDIA_AUDIO),
                ),
                PrivacyPermissionGroup(
                    label = "nearby",
                    permissions =
                        setOf(
                            Manifest.permission.BLUETOOTH_SCAN,
                            Manifest.permission.BLUETOOTH_CONNECT,
                            Manifest.permission.NEARBY_WIFI_DEVICES,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "notifications",
                    permissions = setOf(Manifest.permission.POST_NOTIFICATIONS),
                ),
            )
    }
}
