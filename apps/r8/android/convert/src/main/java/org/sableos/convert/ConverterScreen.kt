package org.sableos.convert

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.math.BigDecimal
import java.math.RoundingMode

private enum class UnitCategory(val label: String) {
    Length("Length"),
    Mass("Mass"),
    Temperature("Temp"),
    Volume("Volume"),
}

private data class UnitChoice(
    val code: Int,
    val label: String,
    val symbol: String,
    val category: UnitCategory,
)

private val units = listOf(
    UnitChoice(0, "Millimeters", "mm", UnitCategory.Length),
    UnitChoice(1, "Centimeters", "cm", UnitCategory.Length),
    UnitChoice(2, "Meters", "m", UnitCategory.Length),
    UnitChoice(3, "Kilometers", "km", UnitCategory.Length),
    UnitChoice(4, "Inches", "in", UnitCategory.Length),
    UnitChoice(5, "Feet", "ft", UnitCategory.Length),
    UnitChoice(6, "Miles", "mi", UnitCategory.Length),
    UnitChoice(7, "Grams", "g", UnitCategory.Mass),
    UnitChoice(8, "Kilograms", "kg", UnitCategory.Mass),
    UnitChoice(9, "Ounces", "oz", UnitCategory.Mass),
    UnitChoice(10, "Pounds", "lb", UnitCategory.Mass),
    UnitChoice(11, "Celsius", "°C", UnitCategory.Temperature),
    UnitChoice(12, "Fahrenheit", "°F", UnitCategory.Temperature),
    UnitChoice(13, "Kelvin", "K", UnitCategory.Temperature),
    UnitChoice(14, "Milliliters", "mL", UnitCategory.Volume),
    UnitChoice(15, "Liters", "L", UnitCategory.Volume),
    UnitChoice(16, "Cups", "cup", UnitCategory.Volume),
    UnitChoice(17, "Gallons", "gal", UnitCategory.Volume),
)

@Composable
fun ConverterScreen(
    modifier: Modifier = Modifier,
) {
    val nativeQualification = remember { NativeBridge.selfTest() }
    check(nativeQualification.startsWith("PASS:")) { nativeQualification }

    var category by remember { mutableStateOf(UnitCategory.Length) }
    var from by remember { mutableStateOf(units.first { it.code == 2 }) }
    var to by remember { mutableStateOf(units.first { it.code == 3 }) }
    var input by remember { mutableStateOf("1") }
    var result by remember { mutableStateOf("Ready") }

    Column(
        modifier = modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            "Unit converter",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(
            "Offline fixed-point conversion",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            UnitCategory.entries.forEach { choice ->
                Button(
                    onClick = {
                        category = choice
                        val available = units.filter { it.category == choice }
                        from = available.first()
                        to = available.getOrElse(1) { available.first() }
                        result = "Ready"
                    },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (category == choice) "[${choice.label}]" else choice.label)
                }
            }
        }

        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Value") },
        )

        val availableUnits = units.filter { it.category == category }

        Button(
            onClick = {
                from = cycleUnit(availableUnits, from)
                result = "Ready"
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("From  ${from.label} (${from.symbol})")
        }

        Button(
            onClick = {
                to = cycleUnit(availableUnits, to)
                result = "Ready"
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("To  ${to.label} (${to.symbol})")
        }

        Button(
            onClick = {
                val valueMilli = parseMilli(input)
                result = if (valueMilli == null) {
                    "Enter a number with up to three decimal places"
                } else {
                    renderResult(
                        NativeBridge.convertMilli(
                            valueMilli,
                            from.code,
                            to.code,
                        ),
                        to.symbol,
                    )
                }
            },
        ) {
            Text("Convert")
        }

        Text(
            result,
            style = MaterialTheme.typography.headlineSmall,
        )

        Text(
            "Length, mass, temperature and volume are local/offline. " +
                "The Rust domain owns unit compatibility, conversion rules and range checks.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun cycleUnit(
    available: List<UnitChoice>,
    current: UnitChoice,
): UnitChoice {
    val index = available.indexOfFirst { it.code == current.code }
    return available[(index + 1).mod(available.size)]
}

private fun parseMilli(text: String): Long? =
    try {
        BigDecimal(text.trim())
            .setScale(3, RoundingMode.HALF_UP)
            .movePointRight(3)
            .longValueExact()
    } catch (_: NumberFormatException) {
        null
    } catch (_: ArithmeticException) {
        null
    }

private fun renderResult(
    protocol: String,
    symbol: String,
): String =
    when {
        protocol.startsWith("OK:") -> {
            val milli = protocol.removePrefix("OK:").toLongOrNull()
            if (milli == null) {
                "Native bridge failure"
            } else {
                "${formatMilli(milli)} $symbol"
            }
        }
        protocol.startsWith("ERR:") -> protocol.removePrefix("ERR:").replace('_', ' ')
        else -> "Native bridge failure"
    }

private fun formatMilli(valueMilli: Long): String =
    BigDecimal.valueOf(valueMilli, 3)
        .stripTrailingZeros()
        .toPlainString()
