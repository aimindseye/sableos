package org.sableos.hub.web

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.addCallback
import org.sableos.hub.HubProvider
import org.sableos.hub.HubProviderCatalog

abstract class ProviderCapsuleActivity : ComponentActivity() {
    protected abstract val providerId: String

    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        val provider =
            requireNotNull(HubProviderCatalog.byId(providerId)) {
                "Unknown Sable Hub provider."
            }

        WebView.setDataDirectorySuffix(provider.id)
        super.onCreate(savedInstanceState)

        title = provider.displayName + " · WEB"

        webView =
            WebView(this).apply {
                setBackgroundColor(Color.BLACK)
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.setSupportMultipleWindows(false)
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                settings.safeBrowsingEnabled = true

                CookieManager.getInstance().setAcceptCookie(true)
                CookieManager.getInstance().setAcceptThirdPartyCookies(
                    this,
                    false,
                )

                webViewClient =
                    ProviderWebViewClient(
                        context = this@ProviderCapsuleActivity,
                        provider = provider,
                    )
            }

        setContentView(webView)

        onBackPressedDispatcher.addCallback(this) {
            if (webView.canGoBack()) {
                webView.goBack()
            } else {
                finish()
            }
        }

        webView.loadUrl(provider.startUrl)
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.loadUrl("about:blank")
            webView.clearHistory()
            webView.removeAllViews()
            webView.destroy()
        }
        super.onDestroy()
    }
}

private class ProviderWebViewClient(
    private val context: Context,
    private val provider: HubProvider,
) : WebViewClient() {
    override fun shouldOverrideUrlLoading(
        view: WebView,
        request: WebResourceRequest,
    ): Boolean {
        val uri = request.url
        val scheme = uri.scheme?.lowercase()
        if (
            scheme in setOf("https", "http") &&
            provider.allowsHost(uri.host)
        ) {
            return false
        }

        if (scheme == "https" || scheme == "http") {
            val launched =
                runCatching {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, uri)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    true
                }.getOrDefault(false)

            if (!launched) {
                Toast.makeText(
                    context,
                    "No external browser is available.",
                    Toast.LENGTH_SHORT,
                ).show()
            }
        } else {
            Toast.makeText(
                context,
                "This provider link is outside the Sable WEB capsule.",
                Toast.LENGTH_SHORT,
            ).show()
        }

        return true
    }
}

class WhatsAppCapsuleActivity : ProviderCapsuleActivity() {
    override val providerId: String = "whatsapp"
}

class InstagramCapsuleActivity : ProviderCapsuleActivity() {
    override val providerId: String = "instagram"
}

class MessengerCapsuleActivity : ProviderCapsuleActivity() {
    override val providerId: String = "messenger"
}

class LinkedInCapsuleActivity : ProviderCapsuleActivity() {
    override val providerId: String = "linkedin"
}

object ProviderCapsuleLauncher {
    fun open(
        context: Context,
        providerId: String,
    ): Boolean {
        val activityClass =
            when (providerId) {
                "whatsapp" -> WhatsAppCapsuleActivity::class.java
                "instagram" -> InstagramCapsuleActivity::class.java
                "messenger" -> MessengerCapsuleActivity::class.java
                "linkedin" -> LinkedInCapsuleActivity::class.java
                else -> return false
            }

        return runCatching {
            context.startActivity(
                Intent(context, activityClass),
            )
            true
        }.getOrDefault(false)
    }
}
