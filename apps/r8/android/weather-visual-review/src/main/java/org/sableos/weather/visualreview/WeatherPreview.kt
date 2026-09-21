package org.sableos.weather.visualreview

import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.sableos.design.SableSpacing

private data class HourForecast(
    val time: String,
    val temperature: String,
    val condition: WeatherCondition,
    val precipitation: Int,
)

private data class DayForecast(
    val day: String,
    val condition: WeatherCondition,
    val summary: String,
    val high: String,
    val low: String,
    val precipitation: Int,
)

private val hourlyForecast =
    listOf(
        HourForecast("now", "72°", WeatherCondition.PartlyCloudy, 12),
        HourForecast("10 AM", "73°", WeatherCondition.PartlyCloudy, 14),
        HourForecast("12 PM", "76°", WeatherCondition.Clear, 8),
        HourForecast("2 PM", "78°", WeatherCondition.Clear, 6),
        HourForecast("4 PM", "77°", WeatherCondition.PartlyCloudy, 11),
        HourForecast("6 PM", "74°", WeatherCondition.Cloudy, 18),
        HourForecast("8 PM", "71°", WeatherCondition.Cloudy, 22),
    )

private val dailyForecast =
    listOf(
        DayForecast("today", WeatherCondition.PartlyCloudy, "partly cloudy", "78°", "64°", 18),
        DayForecast("monday", WeatherCondition.Clear, "clear", "80°", "65°", 5),
        DayForecast("tuesday", WeatherCondition.Rain, "showers", "73°", "62°", 62),
        DayForecast("wednesday", WeatherCondition.Rain, "rain", "70°", "60°", 71),
        DayForecast("thursday", WeatherCondition.PartlyCloudy, "partly cloudy", "74°", "61°", 20),
        DayForecast("friday", WeatherCondition.Clear, "clear", "77°", "63°", 8),
        DayForecast("saturday", WeatherCondition.Storm, "storms possible", "75°", "64°", 48),
    )

@Composable
internal fun WeatherPreview(surface: String) {
    when (surface) {
        "hourly" -> HourlyScreen()
        "daily" -> DailyScreen()
        "locations" -> LocationsScreen()
        "privacy" -> PrivacySetupScreen()
        "stale" -> CurrentWeatherScreen(stale = true)
        else -> CurrentWeatherScreen(stale = false)
    }
}

@Composable
private fun WeatherPage(
    title: String,
    subtitle: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.Lg,
                ),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(SableSpacing.Xs))
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(SableSpacing.Xl))
        content()
    }
}

@Composable
private fun AccentHeader(
    title: String,
    detail: String,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = SableSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .width(4.dp)
                    .height(48.dp)
                    .background(MaterialTheme.colorScheme.primary),
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Hairline() {
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}

@Composable
private fun FlatAction(
    text: String,
    primary: Boolean = false,
) {
    Box(
        modifier =
            Modifier
                .fillMaxWidth()
                .background(
                    if (primary) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    },
                )
                .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            color =
                if (primary) {
                    MaterialTheme.colorScheme.onPrimary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
        )
    }
}

@Composable
private fun CurrentWeatherScreen(stale: Boolean) {
    WeatherPage(
        title = "weather",
        subtitle =
            if (stale) {
                "Jersey City · cached · last live 47 min ago"
            } else {
                "Jersey City · live · updated 8:34 AM"
            },
    ) {
        if (stale) {
            AccentHeader(
                title = "offline forecast",
                detail = "showing last known weather · refresh when connected",
            )
            Spacer(Modifier.height(SableSpacing.Md))
        }

        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(top = SableSpacing.Sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "72°",
                    fontSize = 84.sp,
                    lineHeight = 88.sp,
                    fontWeight = FontWeight.Light,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Text(
                    text = "partly cloudy",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Text(
                    text = "feels like 72° · high 78° · low 64°",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            WeatherGlyph(
                condition = WeatherCondition.PartlyCloudy,
                modifier = Modifier.size(104.dp),
                accent = MaterialTheme.colorScheme.primary,
                muted = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        WeatherMetricRow(
            entries =
                listOf(
                    "rain" to "18%",
                    "humidity" to "58%",
                    "wind" to "NW 8 mph",
                ),
        )

        Spacer(Modifier.height(SableSpacing.Xl))
        SectionTitle(
            title = "next hours",
            trailing = "hourly ›",
        )
        Spacer(Modifier.height(SableSpacing.Md))
        CompactHourlyStrip()

        Spacer(Modifier.height(SableSpacing.Xl))
        SectionTitle(
            title = "week",
            trailing = "7 days ›",
        )
        Spacer(Modifier.height(SableSpacing.Sm))
        dailyForecast.take(3).forEach { day ->
            CompactDayRow(day)
        }

        Spacer(Modifier.weight(1f))
        Hairline()
        Text(
            text =
                if (stale) {
                    "cached locally · Open-Meteo · no background refresh"
                } else {
                    "Open-Meteo · cached locally · manual location"
                },
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(vertical = SableSpacing.Md),
        )
        if (stale) {
            FlatAction(
                text = "refresh",
                primary = true,
            )
        }
    }
}

@Composable
private fun WeatherMetricRow(entries: List<Pair<String, String>>) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        entries.forEach { (label, value) ->
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(SableSpacing.Xs))
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onBackground,
                )
            }
        }
    }
}

@Composable
private fun SectionTitle(
    title: String,
    trailing: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = trailing,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun CompactHourlyStrip() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        hourlyForecast.take(4).forEachIndexed { index, hour ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = hour.time,
                    style = MaterialTheme.typography.labelLarge,
                    color =
                        if (index == 0) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                )
                Spacer(Modifier.height(SableSpacing.Sm))
                WeatherGlyph(
                    condition = hour.condition,
                    modifier = Modifier.size(34.dp),
                    accent = MaterialTheme.colorScheme.primary,
                    muted = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(SableSpacing.Sm))
                Text(
                    text = hour.temperature,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                )
            }
        }
    }
}

@Composable
private fun CompactDayRow(day: DayForecast) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = day.day,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.weight(1.2f),
        )
        WeatherGlyph(
            condition = day.condition,
            modifier = Modifier.size(30.dp),
            accent = MaterialTheme.colorScheme.primary,
            muted = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Text(
            text = "${day.high}  ${day.low}",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
        )
    }
    Hairline()
}

@Composable
private fun HourlyScreen() {
    WeatherPage(
        title = "hourly",
        subtitle = "Jersey City · Sunday",
    ) {
        AccentHeader(
            title = "rain chance",
            detail = "highest chance 22% around 8 PM",
        )
        Spacer(Modifier.height(SableSpacing.Lg))

        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
        ) {
            hourlyForecast.forEach { hour ->
                HourRow(hour)
            }
        }

        FlatAction(text = "back to weather")
    }
}

@Composable
private fun HourRow(hour: HourForecast) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = hour.time,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.weight(1f),
        )
        WeatherGlyph(
            condition = hour.condition,
            modifier = Modifier.size(36.dp),
            accent = MaterialTheme.colorScheme.primary,
            muted = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Text(
            text = hour.temperature,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.width(54.dp),
            textAlign = TextAlign.End,
        )
        Spacer(Modifier.width(SableSpacing.Lg))
        PrecipitationBar(
            percent = hour.precipitation,
            modifier = Modifier.width(92.dp),
        )
        Spacer(Modifier.width(SableSpacing.Sm))
        Text(
            text = "${hour.precipitation}%",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(38.dp),
            textAlign = TextAlign.End,
        )
    }
    Hairline()
}

@Composable
private fun PrecipitationBar(
    percent: Int,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier =
            modifier
                .height(4.dp)
                .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxWidth((percent.coerceIn(0, 100)) / 100f)
                    .height(4.dp)
                    .background(MaterialTheme.colorScheme.primary),
        )
    }
}

@Composable
private fun DailyScreen() {
    WeatherPage(
        title = "7 days",
        subtitle = "Jersey City · forecast",
    ) {
        Column(
            modifier =
                Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
        ) {
            dailyForecast.forEach { day ->
                DayRow(day)
            }
        }
        FlatAction(text = "back to weather")
    }
}

@Composable
private fun DayRow(day: DayForecast) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = day.day,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.weight(1f),
        )
        WeatherGlyph(
            condition = day.condition,
            modifier = Modifier.size(38.dp),
            accent = MaterialTheme.colorScheme.primary,
            muted = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Column(modifier = Modifier.weight(1.1f)) {
            Text(
                text = day.summary,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "rain ${day.precipitation}%",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        Text(
            text = "${day.high}  ${day.low}",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.width(92.dp),
            textAlign = TextAlign.End,
        )
    }
    Hairline()
}

@Composable
private fun LocationsScreen() {
    val locations =
        listOf(
            "Jersey City" to "selected · America/New_York",
            "New York" to "saved · America/New_York",
            "Edison" to "saved · America/New_York",
            "Mumbai" to "saved · Asia/Kolkata",
        )

    WeatherPage(
        title = "locations",
        subtitle = "manual cities + optional device location",
    ) {
        AccentHeader(
            title = "Jersey City",
            detail = "selected · manual location · no location permission",
        )
        Spacer(Modifier.height(SableSpacing.Xl))

        locations.forEachIndexed { index, (name, detail) ->
            LocationRow(
                name = name,
                detail = detail,
                selected = index == 0,
            )
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        FlatAction(
            text = "add city",
            primary = true,
        )
        Spacer(Modifier.height(SableSpacing.Sm))
        FlatAction(text = "use approximate device location")

        Spacer(Modifier.weight(1f))
        Text(
            text = "precise location is never required for weather",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun LocationRow(
    name: String,
    detail: String,
    selected: Boolean,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .width(4.dp)
                    .height(44.dp)
                    .background(
                        if (selected) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            Color.Transparent
                        },
                    ),
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = if (selected) "current" else "›",
            style = MaterialTheme.typography.labelLarge,
            color =
                if (selected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
        )
    }
    Hairline()
}

@Composable
private fun PrivacySetupScreen() {
    WeatherPage(
        title = "weather setup",
        subtitle = "choose how Weather learns your location",
    ) {
        AccentHeader(
            title = "manual city",
            detail = "recommended · no Android location permission",
        )

        Spacer(Modifier.height(SableSpacing.Lg))
        PrivacyChoice(
            title = "search for a city",
            detail = "save one or more places · switch anytime",
            selected = true,
        )
        PrivacyChoice(
            title = "approximate device location",
            detail = "optional · Android approximate location only",
            selected = false,
        )
        PrivacyChoice(
            title = "precise device location",
            detail = "not required · Weather does not ask by default",
            selected = false,
        )

        Spacer(Modifier.height(SableSpacing.Xl))
        Hairline()
        Spacer(Modifier.height(SableSpacing.Lg))

        Text(
            text = "forecast privacy",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text =
                "Weather stores the last forecast locally so Start can show weather without making its own network request.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.weight(1f))
        FlatAction(
            text = "continue with manual city",
            primary = true,
        )
    }
}

@Composable
private fun PrivacyChoice(
    title: String,
    detail: String,
    selected: Boolean,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (selected) "●" else "○",
            style = MaterialTheme.typography.titleMedium,
            color =
                if (selected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
        )
        Spacer(Modifier.width(SableSpacing.Md))
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
    Hairline()
}
