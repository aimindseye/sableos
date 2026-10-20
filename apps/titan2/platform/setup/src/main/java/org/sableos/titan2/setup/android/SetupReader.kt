package org.sableos.titan2.setup.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import org.sableos.titan2.setup.core.Observed
import org.sableos.titan2.setup.core.Snapshot

/** Reads the current defaults through public APIs only. A failed read is [Observed.Failed], never "none". */
class SetupReader(private val context: Context) {
    fun snapshot(): Snapshot = Snapshot(
        home(), keyboard(), dialer(), sms(), messagesSmsRead(),
        browserHandler(), provisioningState(), wizardHandler()
    )

    private fun home(): Observed = observe {
        context.packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            0
        )?.activityInfo?.packageName
    }

    private fun keyboard(): Observed = observe {
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
    }

    private fun dialer(): Observed {
        val telecom = context.getSystemService(TelecomManager::class.java) ?: return Observed.Failed
        return observe { telecom.defaultDialerPackage }
    }

    private fun sms(): Observed = observe { Telephony.Sms.getDefaultSmsPackage(context) }

    /** Resolves a real browser activity for the current profile, never a WebView library APK. */
    private fun browserHandler(): Observed = observe {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        val resolved = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val info = resolved?.activityInfo
        if (info == null || info.packageName == "android" ||
            info.name?.contains("ResolverActivity") == true ||
            info.name?.contains("ChooserActivity") == true
        ) null else info.packageName + "/" + info.name
    }

    /** Visibility-bounded enabled SETUP_WIZARD intent handler, if unique. This does not check privileges. */
    private fun wizardHandler(): Observed = observe {
        val intent = Intent(Intent.ACTION_MAIN).addCategory("android.intent.category.SETUP_WIZARD")
        val candidates = context.packageManager.queryIntentActivities(intent, 0)
            .mapNotNull { it.activityInfo }
            .map { "${it.packageName}/${it.name}" }.distinct()
        candidates.singleOrNull()
    }

    /** Read-only Android setup flags; does not guess the owner of first-boot SetupWizard. */
    private fun provisioningState(): Observed = try {
        val device = Settings.Global.getInt(
            context.contentResolver, Settings.Global.DEVICE_PROVISIONED, -1)
        val user = Settings.Secure.getInt(
            context.contentResolver, Settings.Secure.USER_SETUP_COMPLETE, -1)
        when {
            device == 1 && user == 1 -> Observed.Value("complete")
            device == 0 || user == 0 -> Observed.Value("pending")
            else -> Observed.Failed
        }
    } catch (_: SecurityException) {
        Observed.Failed
    } catch (_: RuntimeException) {
        Observed.Failed
    }

    /** Explicit package-permission observation; uninstalled/denied never produces a success. */
    private fun messagesSmsRead(): Observed = try {
        val result = context.packageManager.checkPermission(
            android.Manifest.permission.READ_SMS,
            "org.sableos.messages",
        )
        if (result == PackageManager.PERMISSION_GRANTED) {
            Observed.Value("granted")
        } else {
            Observed.Value("denied")
        }
    } catch (_: SecurityException) {
        Observed.Failed
    } catch (_: RuntimeException) {
        Observed.Failed
    }

    private fun observe(read: () -> String?): Observed = try {
        val v = read()
        if (v.isNullOrBlank()) Observed.Absent else Observed.Value(v)
    } catch (_: SecurityException) {
        Observed.Failed
    } catch (_: RuntimeException) {
        Observed.Failed
    }
}
