package org.sableos.calculator

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import org.sableos.convert.ConverterScreen
import org.sableos.design.SableActionButton
import org.sableos.design.SablePageHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.design.SableTile

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

                SableScrollableScreen {
                    SablePageHeader(
                        title = "Calculator",
                        subtitle = "Regular · Scientific · Convert",
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                    ) {
                        CalculatorMode.entries.forEach { choice ->
                            SableTile(
                                title = choice.label,
                                active = mode == choice,
                                modifier = Modifier.weight(1f),
                                onClick = { mode = choice },
                            )
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

@Composable
private fun RegularCalculatorScreen() {
    var left by remember { mutableStateOf("0.1") }
    var right by remember { mutableStateOf("0.2") }
    var operation by remember { mutableIntStateOf(0) }
    var result by remember { mutableStateOf("Ready") }

    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        SableSectionHeader("Regular")

        OutlinedTextField(
            value = left,
            onValueChange = { left = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Left operand") },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            operationLabels.forEachIndexed { index, label ->
                SableTile(
                    title = label,
                    active = operation == index,
                    modifier = Modifier.weight(1f),
                    onClick = { operation = index },
                )
            }
        }

        OutlinedTextField(
            value = right,
            onValueChange = { right = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Right operand") },
        )

        SableActionButton(
            text = "Calculate",
            modifier = Modifier.fillMaxWidth(),
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
        )

        ResultPanel(result)

        Text(
            "Exact decimal arithmetic stays in the Rust domain; rational results are not silently rounded.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ScientificCalculatorScreen() {
    var input by remember { mutableStateOf("9") }
    var result by remember { mutableStateOf("Ready") }

    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        SableSectionHeader("Scientific")

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
                horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
            ) {
                rowChoices.forEach { choice ->
                    SableTile(
                        title = choice.label,
                        modifier = Modifier.weight(1f),
                        onClick = {
                            result =
                                renderResult(
                                    NativeBridge.applyScientific(
                                        input,
                                        choice.code,
                                    ),
                                )
                        },
                    )
                }
            }
        }

        ResultPanel(result)

        Text(
            "Trigonometric functions use degrees. Scientific operations execute in the Rust calculator domain.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ResultPanel(result: String) {
    SablePanel {
        Text(
            "Result",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            result,
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

private fun renderResult(protocol: String): String =
    when {
        protocol.startsWith("OK:") -> protocol.removePrefix("OK:")
        protocol.startsWith("ERR:") -> protocol.removePrefix("ERR:").replace('_', ' ')
        else -> "Native bridge failure"
    }
