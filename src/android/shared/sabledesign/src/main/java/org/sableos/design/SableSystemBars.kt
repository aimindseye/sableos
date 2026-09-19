package org.sableos.design

import android.graphics.Color
import android.view.Window
import android.view.WindowInsetsController

fun applySableDarkSystemBars(window: Window) {
    window.statusBarColor = Color.BLACK
    window.navigationBarColor = Color.BLACK
    window.insetsController?.setSystemBarsAppearance(
        0,
        WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
            WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
    )
}
