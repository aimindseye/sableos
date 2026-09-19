package org.sableos.hub

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import org.sableos.design.SableAppearance
import org.sableos.design.SableTheme
import org.sableos.design.applySableSystemBars
import org.sableos.design.resolveSableDarkAppearance
import org.sableos.hub.ui.HubScreen
import org.sableos.hub.web.ProviderCapsuleLauncher

class MainActivity : ComponentActivity() {
    private lateinit var repository: HubRepository
    private var refreshGeneration by mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        repository = HubRepository(applicationContext)
        applySableSystemBars(
            window = window,
            darkTheme =
                resolveSableDarkAppearance(
                    context = this,
                    appearance = SableAppearance(),
                ),
        )

        setContent {
            val permissionLauncher =
                rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions(),
                ) {
                    refreshGeneration += 1
                }

            val snapshot =
                remember(refreshGeneration) {
                    repository.snapshot()
                }

            SableTheme {
                HubScreen(
                    snapshot = snapshot,
                    providers = HubProviderCatalog.providers,
                    onRefresh = {
                        refreshGeneration += 1
                    },
                    onRequestAccess = {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.READ_SMS,
                                Manifest.permission.SEND_SMS,
                                Manifest.permission.READ_CONTACTS,
                            ),
                        )
                    },
                    onSendSms = { recipient, body ->
                        runCatching {
                            repository.sendSms(
                                recipient = recipient,
                                body = body,
                            )
                        }.fold(
                            onSuccess = {
                                refreshGeneration += 1
                                HubSendResult(
                                    success = true,
                                    message = "Message handed to Android telephony.",
                                )
                            },
                            onFailure = { error ->
                                HubSendResult(
                                    success = false,
                                    message =
                                        error.message
                                            ?: "SMS send capability is unavailable.",
                                )
                            },
                        )
                    },
                    onOpenAndroidMessaging = { recipient, body ->
                        repository.openAndroidMessaging(
                            recipient = recipient,
                            body = body,
                        )
                    },
                    onOpenProvider = { providerId ->
                        ProviderCapsuleLauncher.open(
                            context = this,
                            providerId = providerId,
                        )
                    },
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (::repository.isInitialized) {
            refreshGeneration += 1
        }
    }
}
