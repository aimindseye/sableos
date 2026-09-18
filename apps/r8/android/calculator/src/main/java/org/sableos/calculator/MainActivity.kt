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
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.convert.ConverterScreen
import org.sableos.design.SableTheme

private enum class CalculatorMode(val label: String) {
    Regular("Regular"),
    Scientific("Scientific"),
    Converter("Convert"),
}

private data class ScientificChoice(
    val code: Int,
    val label: String,
)

private val operationLabels = listOf("+", "−", "×", "÷")

private val scientificChoices = listOf(
    ScientificChoice(0, "√x"),
    ScientificChoice(1, "x²"),
    ScientificChoice(2, "1/x"),
    ScientificChoice(3, "sin"),
    ScientificChoice(4, "cos"),
    ScientificChoice(5, "tan"),
    ScientificChoice(6, "ln"),
    ScientificChoice(7, "log₁₀"),
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val nativeQualification = NativeBridge.selfTest()
        check(nativeQualification.startsWith("PASS:")) { nativeQualification }

        setContent {
            SableTheme {
                var mode by remember { mutableStateOf(CalculatorMode.Regular) }

                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier =
                            Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                                .padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Text(
                            "Sable Calculator",
                            style = MaterialTheme.typography.headlineLarge,
                        )
                        Text(
                            "Regular arithmetic, scientific functions and offline conversion",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            CalculatorMode.entries.forEach { choice ->
                                Button(
                                    onClick = { mode = choice },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text(
                                        if (mode == choice) {
                                            "[${choice.label}]"
                                        } else {
                                            choice.label
                                        },
                                    )
                                }
                            }
                        }

                        when (mode) {
                            CalculatorMode.Regular -> RegularCalculatorScreen()
                            CalculatorMode.Scientific -> ScientificCalculatorScreen()
                            CalculatorMode.Converter -> ConverterScreen()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RegularCalculatorScreen() {
    var left by remember { mutableStateOf("0.1") }
    var right by remember { mutableStateOf("0.2") }
    var operation by remember { mutableIntStateOf(0) }
    var result by remember { mutableStateOf("Ready") }

    Column(
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            "Regular calculator",
            style = MaterialTheme.typography.headlineMedium,
        )

        OutlinedTextField(
            value = left,
            onValueChange = { left = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Left operand") },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            operationLabels.forEachIndexed { index, label ->
                Button(
                    onClick = { operation = index },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (operation == index) "[$label]" else label)
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
                result =
                    renderResult(
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
            "Result  $result",
            style = MaterialTheme.typography.headlineSmall,
        )

        Text(
            "Rust preserves exact decimal arithmetic for +, −, × and ÷. " +
                "The UI does not silently round exact rational results.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ScientificCalculatorScreen() {
    var input by remember { mutableStateOf("9") }
    var result by remember { mutableStateOf("Ready") }

    Column(
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            "Scientific calculator",
            style = MaterialTheme.typography.headlineMedium,
        )

        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Value") },
        )

        scientificChoices.chunked(4).forEach { rowChoices ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowChoices.forEach { choice ->
                    Button(
                        onClick = {
                            result =
                                renderResult(
                                    NativeBridge.applyScientific(
                                        input,
                                        choice.code,
                                    ),
                                )
                        },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(choice.label)
                    }
                }
            }
        }

        Text(
            "Result  $result",
            style = MaterialTheme.typography.headlineSmall,
        )

        Text(
            "Trigonometric functions use degrees. Square root, square, reciprocal, " +
                "sin/cos/tan, ln and log₁₀ execute in the Rust calculator domain.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun renderResult(protocol: String): String =
    when {
        protocol.startsWith("OK:") -> protocol.removePrefix("OK:")
        protocol.startsWith("ERR:") -> protocol.removePrefix("ERR:").replace('_', ' ')
        else -> "Native bridge failure"
    }
