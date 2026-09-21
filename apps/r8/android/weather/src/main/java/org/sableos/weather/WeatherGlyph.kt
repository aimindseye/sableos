package org.sableos.weather

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * Production Sable Weather condition glyphs.
 *
 * These are intentionally drawn from Compose primitives rather than font
 * characters so the condition language is stable across devices, fonts and
 * locales. The geometry is derived from the approved R9 Weather visual review.
 */
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
                drawSun(
                    color = accent,
                    center = Offset(cx, cy),
                    unit = unit,
                )
            }

            WeatherCondition.PartlyCloudy -> {
                drawSun(
                    color = accent,
                    center = Offset(cx - unit * 1.8f, cy - unit * 1.8f),
                    unit = unit * 0.9f,
                    includeRays = false,
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

            WeatherCondition.Fog -> {
                drawCloud(
                    color = muted,
                    center = Offset(cx, cy - unit * 1.2f),
                    unit = unit * 0.9f,
                )
                repeat(2) { index ->
                    val y = cy + unit * (2.2f + index * 1.4f)
                    drawLine(
                        color = muted,
                        start = Offset(cx - unit * 3.0f, y),
                        end = Offset(cx + unit * 3.0f, y),
                        strokeWidth = unit * 0.65f,
                        cap = StrokeCap.Round,
                    )
                }
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

            WeatherCondition.Snow -> {
                drawCloud(
                    color = muted,
                    center = Offset(cx, cy - unit),
                    unit = unit,
                )
                repeat(3) { index ->
                    val x = cx - unit * 2.2f + index * unit * 2.2f
                    val y = cy + unit * 3.0f
                    drawLine(
                        color = accent,
                        start = Offset(x - unit * 0.55f, y),
                        end = Offset(x + unit * 0.55f, y),
                        strokeWidth = unit * 0.55f,
                        cap = StrokeCap.Round,
                    )
                    drawLine(
                        color = accent,
                        start = Offset(x, y - unit * 0.55f),
                        end = Offset(x, y + unit * 0.55f),
                        strokeWidth = unit * 0.55f,
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
                val path =
                    Path().apply {
                        moveTo(cx + unit * 0.6f, cy + unit * 1.4f)
                        lineTo(cx - unit * 0.5f, cy + unit * 3.0f)
                        lineTo(cx + unit * 0.5f, cy + unit * 3.0f)
                        lineTo(cx - unit * 0.8f, cy + unit * 4.7f)
                    }
                drawPath(
                    path = path,
                    color = accent,
                    style =
                        Stroke(
                            width = unit * 0.8f,
                            cap = StrokeCap.Round,
                        ),
                )
            }

            WeatherCondition.Unknown -> {
                drawCircle(
                    color = muted,
                    radius = unit * 3.0f,
                    center = Offset(cx, cy),
                    style = Stroke(width = unit * 0.65f),
                )
                drawLine(
                    color = muted,
                    start = Offset(cx - unit * 1.2f, cy - unit * 1.2f),
                    end = Offset(cx + unit * 1.2f, cy + unit * 1.2f),
                    strokeWidth = unit * 0.65f,
                    cap = StrokeCap.Round,
                )
            }
        }
    }
}

private fun DrawScope.drawSun(
    color: Color,
    center: Offset,
    unit: Float,
    includeRays: Boolean = true,
) {
    drawCircle(
        color = color,
        radius = unit * 2.2f,
        center = center,
        style = Stroke(width = unit * 0.8f),
    )
    if (!includeRays) {
        return
    }

    repeat(8) { index ->
        val angle = Math.toRadians(index * 45.0)
        val sx = center.x + kotlin.math.cos(angle).toFloat() * unit * 3.2f
        val sy = center.y + kotlin.math.sin(angle).toFloat() * unit * 3.2f
        val ex = center.x + kotlin.math.cos(angle).toFloat() * unit * 4.5f
        val ey = center.y + kotlin.math.sin(angle).toFloat() * unit * 4.5f
        drawLine(
            color = color,
            start = Offset(sx, sy),
            end = Offset(ex, ey),
            strokeWidth = unit * 0.65f,
            cap = StrokeCap.Round,
        )
    }
}

private fun DrawScope.drawCloud(
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
