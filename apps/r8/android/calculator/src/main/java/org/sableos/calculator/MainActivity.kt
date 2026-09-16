package org.sableos.calculator

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.design.SableTheme

/**
 * R8 compile/runtime shell. Final keypad/expression behavior remains gated by
 * the Calculator interaction-policy requirements. Arithmetic correctness lives
 * in the separately host-qualified Rust calculator core.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SableTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Text("Sable Calculator", style = MaterialTheme.typography.headlineLarge)
                        Text("R8 arithmetic foundation")
                        Text(
                            "Exact +, −, × and ÷ are host-qualified in Rust. " +
                                "Keypad semantics, precedence, percent, rounding and history " +
                                "remain intentionally unselected until the product contract is frozen.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}
