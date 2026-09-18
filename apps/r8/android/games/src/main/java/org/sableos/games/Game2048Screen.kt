package org.sableos.games

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SablePanel
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing

@Composable
internal fun Game2048Screen() {
    var board by remember { mutableStateOf(initial2048Board()) }
    var score by remember { mutableLongStateOf(0L) }

    fun slide(direction: Int) {
        val result = NativeBridge.game2048Slide(
            board,
            direction,
        )

        check(result.size == 17)

        board = IntArray(16) { index ->
            result[index].toInt()
        }
        score += result[16]
    }

    fun reset() {
        board = initial2048Board()
        score = 0L
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        SableSectionHeader("2048")

        SablePanel {
            Text(
                "Score",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                score.toString(),
                style = MaterialTheme.typography.headlineMedium,
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            board.toList().chunked(4).forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                ) {
                    row.forEach { value ->
                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f),
                            shape = MaterialTheme.shapes.medium,
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            contentColor = MaterialTheme.colorScheme.onSurface,
                            tonalElevation = androidx.compose.ui.unit.Dp.Hairline,
                        ) {
                            Box(
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    if (value == 0) "" else value.toString(),
                                    style = MaterialTheme.typography.titleLarge,
                                )
                            }
                        }
                    }
                }
            }
        }

        SableActionButton(
            text = "Up",
            modifier = Modifier.fillMaxWidth(),
            onClick = { slide(2) },
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableActionButton(
                text = "Left",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = { slide(0) },
            )
            SableActionButton(
                text = "Down",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = { slide(3) },
            )
            SableActionButton(
                text = "Right",
                primary = false,
                modifier = Modifier.weight(1f),
                onClick = { slide(1) },
            )
        }

        SableActionButton(
            text = "New game",
            modifier = Modifier.fillMaxWidth(),
            primary = false,
            onClick = ::reset,
        )
    }
}

private fun initial2048Board(): IntArray =
    intArrayOf(
        2, 2, 4, 4,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    )
