package org.sableos.weather.visualreview

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

internal enum class WeatherCondition {
    Clear,
    PartlyCloudy,
    Cloudy,
    Rain,
    Storm,
}

@Composable
internal fun WeatherGlyph(
    condition: WeatherCondition,
    modifier: Modifier = Modifier,
    accent: Color,
    muted: Color,
) {
    Canvas(modifier = modifier) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val unit = size.minDimension / 12f

        when (condition) {
            WeatherCondition.Clear -> {
                drawCircle(
                    color = accent,
                    radius = unit * 2.2f,
                    center = Offset(cx, cy),
                    style = Stroke(width = unit * 0.8f),
                )
                repeat(8) { index ->
                    val angle = Math.toRadians((index * 45.0))
                    val sx = cx + kotlin.math.cos(angle).toFloat() * unit * 3.2f
                    val sy = cy + kotlin.math.sin(angle).toFloat() * unit * 3.2f
                    val ex = cx + kotlin.math.cos(angle).toFloat() * unit * 4.5f
                    val ey = cy + kotlin.math.sin(angle).toFloat() * unit * 4.5f
                    drawLine(
                        color = accent,
                        start = Offset(sx, sy),
                        end = Offset(ex, ey),
                        strokeWidth = unit * 0.65f,
                        cap = StrokeCap.Round,
                    )
                }
            }

            WeatherCondition.PartlyCloudy -> {
                drawCircle(
                    color = accent,
                    radius = unit * 2.0f,
                    center = Offset(cx - unit * 1.8f, cy - unit * 1.8f),
                    style = Stroke(width = unit * 0.7f),
                )
                drawCloud(
                    color = muted,
                    center = Offset(cx + unit * 0.6f, cy + unit * 0.7f),
                    unit = unit,
                )
            }

            WeatherCondition.Cloudy -> {
                drawCloud(
                    color = muted,
                    center = Offset(cx, cy),
                    unit = unit,
                )
            }

            WeatherCondition.Rain -> {
                drawCloud(
                    color = muted,
                    center = Offset(cx, cy - unit),
                    unit = unit,
                )
                repeat(3) { index ->
                    val x = cx - unit * 2.2f + index * unit * 2.2f
                    drawLine(
                        color = accent,
                        start = Offset(x, cy + unit * 2.2f),
                        end = Offset(x - unit * 0.5f, cy + unit * 3.7f),
                        strokeWidth = unit * 0.65f,
                        cap = StrokeCap.Round,
                    )
                }
            }

            WeatherCondition.Storm -> {
                drawCloud(
                    color = muted,
                    center = Offset(cx, cy - unit),
                    unit = unit,
                )
                val path = androidx.compose.ui.graphics.Path().apply {
                    moveTo(cx + unit * 0.6f, cy + unit * 1.4f)
                    lineTo(cx - unit * 0.5f, cy + unit * 3.0f)
                    lineTo(cx + unit * 0.5f, cy + unit * 3.0f)
                    lineTo(cx - unit * 0.8f, cy + unit * 4.7f)
                }
                drawPath(
                    path = path,
                    color = accent,
                    style = Stroke(
                        width = unit * 0.8f,
                        cap = StrokeCap.Round,
                    ),
                )
            }
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawCloud(
    color: Color,
    center: Offset,
    unit: Float,
) {
    drawCircle(
        color = color,
        radius = unit * 1.8f,
        center = Offset(center.x - unit * 1.5f, center.y),
        style = Stroke(width = unit * 0.75f),
    )
    drawCircle(
        color = color,
        radius = unit * 2.3f,
        center = Offset(center.x + unit * 0.2f, center.y - unit * 0.8f),
        style = Stroke(width = unit * 0.75f),
    )
    drawCircle(
        color = color,
        radius = unit * 1.6f,
        center = Offset(center.x + unit * 2.0f, center.y + unit * 0.2f),
        style = Stroke(width = unit * 0.75f),
    )
    drawLine(
        color = color,
        start = Offset(center.x - unit * 3.0f, center.y + unit * 1.5f),
        end = Offset(center.x + unit * 3.2f, center.y + unit * 1.5f),
        strokeWidth = unit * 0.75f,
        cap = StrokeCap.Round,
    )
}
