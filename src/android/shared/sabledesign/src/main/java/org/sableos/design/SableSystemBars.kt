package org.sableos.design

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.view.Window
import android.view.WindowInsetsController

fun resolveSableDarkAppearance(
    context: Context,
    appearance: SableAppearance,
): Boolean =
    when (appearance.mode) {
        AppearanceMode.FollowSystem ->
            (
                context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK
            ) == Configuration.UI_MODE_NIGHT_YES
        AppearanceMode.Light -> false
        AppearanceMode.Dark -> true
    }

fun applySableSystemBars(
    window: Window,
    darkTheme: Boolean,
) {
    val barColor =
        if (darkTheme) {
            Color.rgb(5, 7, 10)
        } else {
            Color.rgb(245, 247, 249)
        }
    window.statusBarColor = barColor
    window.navigationBarColor = barColor

    val lightAppearance =
        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
            WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS

    // PhoneWindow.insetsController dereferences its DecorView internally.
    // SableStart applies system bars during Activity.onCreate(), before the
    // framework is guaranteed to have installed that DecorView. Resolve the
    // view explicitly so early startup is safe and defer icon appearance until
    // attachment if the controller is not ready yet.
    val decorView = window.decorView
    val applyAppearance = {
        decorView.windowInsetsController?.setSystemBarsAppearance(
            if (darkTheme) 0 else lightAppearance,
            lightAppearance,
        )
    }

    if (decorView.isAttachedToWindow) {
        applyAppearance()
    } else {
        decorView.post(applyAppearance)
    }
}

fun applySableDarkSystemBars(window: Window) {
    applySableSystemBars(
        window = window,
        darkTheme = true,
    )
}
