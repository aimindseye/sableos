package org.sableos.convert

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.design.SableTheme

private data class UnitChoice(
    val code: Int,
    val label: String,
)

private val units = listOf(
    UnitChoice(0, "Millimeters"),
    UnitChoice(1, "Centimeters"),
    UnitChoice(2, "Meters"),
    UnitChoice(3, "Kilometers"),
    UnitChoice(4, "Inches"),
    UnitChoice(5, "Feet"),
    UnitChoice(6, "Miles"),
    UnitChoice(7, "Grams"),
    UnitChoice(8, "Kilograms"),
    UnitChoice(9, "Ounces"),
    UnitChoice(10, "Pounds"),
    UnitChoice(11, "Celsius"),
    UnitChoice(12, "Fahrenheit"),
    UnitChoice(13, "Kelvin"),
    UnitChoice(14, "Milliliters"),
    UnitChoice(15, "Liters"),
    UnitChoice(16, "Cups"),
    UnitChoice(17, "Gallons"),
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val nativeQualification = NativeBridge.selfTest()
        check(nativeQualification.startsWith("PASS:")) { nativeQualification }

        setContent {
            SableTheme {
                var valueMilli by remember { mutableStateOf("5000") }
                var fromIndex by remember { mutableStateOf(6) }
                var toIndex by remember { mutableStateOf(3) }
                var result by remember { mutableStateOf("Ready") }

                val from = units[fromIndex]
                val to = units[toIndex]

                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Text(
                            "Sable Convert",
                            style = MaterialTheme.typography.headlineLarge,
                        )

                        Text(
                            "Offline fixed-point conversion",
                            style = MaterialTheme.typography.titleMedium,
                        )

                        OutlinedTextField(
                            value = valueMilli,
                            onValueChange = { valueMilli = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("Value in thousandths") },
                        )

                        Button(
                            onClick = {
                                fromIndex = (fromIndex + 1) % units.size
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("From: ${from.label}")
                        }

                        Button(
                            onClick = {
                                toIndex = (toIndex + 1) % units.size
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("To: ${to.label}")
                        }

                        Button(
                            onClick = {
                                val value = valueMilli.toLongOrNull()
                                result = if (value == null) {
                                    "Enter a signed 64-bit integer"
                                } else {
                                    renderResult(
                                        NativeBridge.convertMilli(
                                            value,
                                            from.code,
                                            to.code,
                                        ),
                                    )
                                }
                            },
                        ) {
                            Text("Convert")
                        }

                        Text(
                            "Result: $result",
                            style = MaterialTheme.typography.titleLarge,
                        )

                        Text(
                            "Values use the fixed scale 1000. Unit conversion, " +
                                "temperature rules and range validation execute in Rust.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

private fun renderResult(protocol: String): String =
    when {
        protocol.startsWith("OK:") -> protocol.removePrefix("OK:")
        protocol.startsWith("ERR:") -> protocol.removePrefix("ERR:").replace('_', ' ')
        else -> "NATIVE BRIDGE FAILURE"
    }
