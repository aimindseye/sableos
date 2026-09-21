package org.sableos.weather

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.sableos.design.SableGlobalTheme
import org.sableos.design.SableSpacing

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val nativeQualification = WeatherNative.selfTest()
        check(nativeQualification.startsWith("PASS:")) {
            nativeQualification
        }

        enableEdgeToEdge()

        setContent {
            SableGlobalTheme(window = window) {
                WeatherApp()
            }
        }
    }
}

@Composable
private fun WeatherApp() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val repository =
        remember(context) {
            WeatherRepository(context)
        }
    val scope = rememberCoroutineScope()

    var selectedLocation by remember {
        mutableStateOf(repository.loadLocation())
    }
    var state by remember(selectedLocation) {
        mutableStateOf(repository.load(selectedLocation))
    }
    var refreshing by remember {
        mutableStateOf(false)
    }

    fun refresh() {
        if (refreshing) return
        refreshing = true
        state =
            state.copy(
                availability = WeatherAvailability.Fetching,
                message = "Refreshing forecast…",
            )

        scope.launch {
            state =
                withContext(Dispatchers.IO) {
                    repository.refresh(selectedLocation)
                }
            refreshing = false
        }
    }

    LaunchedEffect(selectedLocation) {
        state = repository.load(selectedLocation)
        if (state.snapshot == null) {
            refresh()
        }
    }

    Column(
        modifier =
            Modifier
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.Xl,
                ),
    ) {
        Text(
            text = "weather",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = statusLine(state),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.height(SableSpacing.Xl))

        val snapshot = state.snapshot
        if (snapshot == null) {
            WeatherNotice(
                title =
                    when (state.availability) {
                        WeatherAvailability.Fetching -> "loading forecast"
                        WeatherAvailability.Failed -> "forecast unavailable"
                        else -> "weather ready"
                    },
                detail = state.message,
            )
        } else {
            CurrentConditions(snapshot)
            Spacer(Modifier.height(SableSpacing.Xl))
            MetricRow(snapshot)
            Spacer(Modifier.height(SableSpacing.Xl))
            HourlySection(snapshot.hourly)
            Spacer(Modifier.height(SableSpacing.Xl))
            DailySection(snapshot.daily)
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        SectionHeader("locations")

        DefaultWeatherLocations.forEach { location ->
            LocationRow(
                location = location,
                selected = location == selectedLocation,
                onClick = {
                    selectedLocation = location
                },
            )
        }

        Spacer(Modifier.height(SableSpacing.Xl))
        FlatAction(
            text =
                if (refreshing) {
                    "refreshing…"
                } else {
                    "refresh"
                },
            onClick = ::refresh,
        )

        Spacer(Modifier.height(SableSpacing.Md))
        Text(
            text =
                "Open-Meteo · HTTPS · cached locally · manual city by default · " +
                    "precise location is not required",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun CurrentConditions(snapshot: WeatherSnapshot) {
    val current = snapshot.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = current.temperature.toInt().toString() + "°",
                fontSize = 84.sp,
                lineHeight = 88.sp,
                fontWeight = FontWeight.Light,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text = conditionLabel(current.condition),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text =
                    "feels like " +
                        current.apparentTemperature.toInt().toString() +
                        "°",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Text(
            text = conditionMark(current.condition),
            fontSize = 42.sp,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(top = 24.dp),
        )
    }
}

@Composable
private fun MetricRow(snapshot: WeatherSnapshot) {
    val current = snapshot.current
    val nextRain =
        snapshot.hourly
            .firstOrNull()
            ?.precipitationProbability
            ?: 0

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Metric("rain", nextRain.toString() + "%", Modifier.weight(1f))
        Metric("humidity", current.humidity.toString() + "%", Modifier.weight(1f))
        Metric(
            "wind",
            windDirection(current.windDirectionDegrees) +
                " " +
                current.windSpeedMph.toInt().toString() +
                " mph",
            Modifier.weight(1f),
        )
    }
}

@Composable
private fun Metric(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
    }
}

@Composable
private fun HourlySection(hourly: List<HourWeather>) {
    SectionHeader("next hours")

    hourly.take(8).forEach { hour ->
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 9.dp),
        ) {
            Text(
                text = hourLabel(hour.time),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = conditionMark(hour.condition),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(0.6f),
                textAlign = TextAlign.Center,
            )
            Text(
                text = hour.temperature.toInt().toString() + "°",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(0.7f),
                textAlign = TextAlign.End,
            )
            Text(
                text = hour.precipitationProbability.toString() + "%",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(0.7f),
                textAlign = TextAlign.End,
            )
        }
        Hairline()
    }
}

@Composable
private fun DailySection(daily: List<DayWeather>) {
    SectionHeader("7 days")

    daily.take(7).forEach { day ->
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 10.dp),
        ) {
            Text(
                text = dayLabel(day.date),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(1.1f),
            )
            Text(
                text = conditionMark(day.condition),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(0.5f),
                textAlign = TextAlign.Center,
            )
            Text(
                text =
                    day.high.toInt().toString() +
                        "°  " +
                        day.low.toInt().toString() +
                        "°",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(0.9f),
                textAlign = TextAlign.End,
            )
            Text(
                text = day.precipitationProbability.toString() + "%",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(0.6f),
                textAlign = TextAlign.End,
            )
        }
        Hairline()
    }
}

@Composable
private fun LocationRow(
    location: WeatherLocation,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column {
            Text(
                text = location.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onBackground,
            )
            Text(
                text =
                    if (selected) {
                        "selected · manual location"
                    } else {
                        location.timezone
                    },
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
private fun WeatherNotice(
    title: String,
    detail: String,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(vertical = SableSpacing.Md),
    ) {
        Spacer(
            modifier =
                Modifier
                    .height(48.dp)
                    .padding(end = SableSpacing.Md)
                    .weight(0.02f)
                    .background(MaterialTheme.colorScheme.primary),
        )
        Column(modifier = Modifier.weight(0.98f)) {
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
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineMedium,
        color = MaterialTheme.colorScheme.onBackground,
    )
}

@Composable
private fun FlatAction(
    text: String,
    onClick: () -> Unit,
) {
    Text(
        text = text,
        modifier =
            Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.primary)
                .clickable(onClick = onClick)
                .padding(vertical = 14.dp),
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onPrimary,
        textAlign = TextAlign.Center,
    )
}

@Composable
private fun Hairline() {
    HorizontalDivider(
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}

private fun statusLine(state: WeatherUiState): String {
    val prefix = state.location.name
    return when (state.availability) {
        WeatherAvailability.Live -> prefix + " · live"
        WeatherAvailability.Stale -> prefix + " · cached"
        WeatherAvailability.Fetching -> prefix + " · fetching"
        WeatherAvailability.Failed -> prefix + " · unavailable"
        WeatherAvailability.Local -> prefix + " · local"
    }
}

private fun conditionLabel(condition: WeatherCondition): String =
    when (condition) {
        WeatherCondition.Clear -> "clear"
        WeatherCondition.PartlyCloudy -> "partly cloudy"
        WeatherCondition.Cloudy -> "cloudy"
        WeatherCondition.Fog -> "fog"
        WeatherCondition.Rain -> "rain"
        WeatherCondition.Snow -> "snow"
        WeatherCondition.Storm -> "storms"
        WeatherCondition.Unknown -> "conditions unavailable"
    }

private fun conditionMark(condition: WeatherCondition): String =
    when (condition) {
        WeatherCondition.Clear -> "○"
        WeatherCondition.PartlyCloudy -> "◒"
        WeatherCondition.Cloudy -> "≋"
        WeatherCondition.Fog -> "≈"
        WeatherCondition.Rain -> "///"
        WeatherCondition.Snow -> "✦"
        WeatherCondition.Storm -> "ϟ"
        WeatherCondition.Unknown -> "·"
    }

private fun windDirection(degrees: Int): String {
    val normalized = Math.floorMod(degrees, 360)
    val directions =
        listOf(
            "N",
            "NE",
            "E",
            "SE",
            "S",
            "SW",
            "W",
            "NW",
        )
    val index = ((normalized + 22) / 45) % directions.size
    return directions[index]
}

private fun hourLabel(value: String): String =
    value.substringAfter('T', value)

private fun dayLabel(value: String): String = value
