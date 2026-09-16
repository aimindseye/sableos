package org.sableos.calculator

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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

private val operationLabels = listOf("+", "−", "×", "÷")

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val nativeQualification = NativeBridge.selfTest()
        check(nativeQualification.startsWith("PASS:")) { nativeQualification }

        setContent {
            SableTheme {
                var left by remember { mutableStateOf("0.1") }
                var right by remember { mutableStateOf("0.2") }
                var operation by remember { mutableStateOf(0) }
                var result by remember { mutableStateOf("Ready") }

                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Text(
                            "Sable Calculator",
                            style = MaterialTheme.typography.headlineLarge,
                        )

                        Text(
                            "Exact binary arithmetic",
                            style = MaterialTheme.typography.titleMedium,
                        )

                        OutlinedTextField(
                            value = left,
                            onValueChange = { left = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("Left operand") },
                        )

                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            operationLabels.forEachIndexed { index, label ->
                                Button(
                                    onClick = { operation = index },
                                ) {
                                    Text(
                                        if (operation == index) {
                                            "[$label]"
                                        } else {
                                            label
                                        },
                                    )
                                }
                            }
                        }

                        OutlinedTextField(
                            value = right,
                            onValueChange = { right = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("Right operand") },
                        )

                        Button(
                            onClick = {
                                result = renderResult(
                                    NativeBridge.applyBinary(
                                        left,
                                        operation,
                                        right,
                                    ),
                                )
                            },
                        ) {
                            Text("Calculate")
                        }

                        Text(
                            "Result: $result",
                            style = MaterialTheme.typography.titleLarge,
                        )

                        Text(
                            "Rust owns exact decimal parsing and checked +, −, × and ÷. " +
                                "Expression precedence, percent, rounding, history and " +
                                "handheld-keypad policy remain outside this binary contract.",
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
