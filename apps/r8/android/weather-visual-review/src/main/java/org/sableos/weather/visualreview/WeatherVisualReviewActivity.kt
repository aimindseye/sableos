package org.sableos.weather.visualreview

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import org.sableos.design.AppearanceMode
import org.sableos.design.SableAppearance
import org.sableos.design.SableTheme
import org.sableos.design.applySableSystemBars

class WeatherVisualReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enableEdgeToEdge()

        val surface = intent.getStringExtra("surface") ?: "current"
        val dark = intent.getBooleanExtra("dark", false)
        val appearance =
            SableAppearance(
                mode = if (dark) AppearanceMode.Dark else AppearanceMode.Light,
            )

        applySableSystemBars(window = window, darkTheme = dark)

        setContent {
            SableTheme(appearance = appearance) {
                WeatherPreview(surface = surface)
            }
        }
    }
}
