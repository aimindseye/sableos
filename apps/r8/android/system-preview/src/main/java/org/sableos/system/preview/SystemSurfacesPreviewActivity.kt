package org.sableos.system.preview

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import org.sableos.design.SableTheme
import org.sableos.design.applySableDarkSystemBars

class SystemSurfacesPreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applySableDarkSystemBars(window)

        setContent {
            SableTheme {
                SystemSurfacesPreviewScreen()
            }
        }
    }
}
