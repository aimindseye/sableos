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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SablePanel
import org.sableos.design.SableSectionHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTile

@Composable
internal fun MinesweeperScreen() {
    var state by remember {
        mutableStateOf(
            requireOk(
                NativeBridge.minesweeperStart(
                    9,
                    9,
                    10,
                    1803L,
                ),
            ),
        )
    }
    var view by remember {
        mutableStateOf(requireOk(NativeBridge.minesweeperView(state)))
    }
    var flagMode by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("Clear the field") }

    fun reset() {
        state =
            requireOk(
                NativeBridge.minesweeperStart(
                    9,
                    9,
                    10,
                    1803L,
                ),
            )
        view = requireOk(NativeBridge.minesweeperView(state))
        flagMode = false
        status = "New field"
    }

    fun applyResponse(response: String) {
        val fields = response.split('|')

        if (fields.size >= 3 && fields[0] == "OK") {
            state = fields[1]
            view = requireOk(NativeBridge.minesweeperView(state))
            status = fields.drop(2).joinToString(" ")
        } else {
            status = humanize(response)
        }
    }

    fun selectCell(x: Int, y: Int) {
        applyResponse(
            if (flagMode) {
                NativeBridge.minesweeperToggleFlag(
                    state,
                    x,
                    y,
                )
            } else {
                NativeBridge.minesweeperReveal(
                    state,
                    x,
                    y,
                )
            },
        )
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        SableSectionHeader("Minesweeper")

        SablePanel {
            Text(
                status,
                style = MaterialTheme.typography.titleMedium,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            SableTile(
                title = "Reveal",
                active = !flagMode,
                modifier = Modifier.weight(1f),
                onClick = { flagMode = false },
            )
            SableTile(
                title = "Flag",
                active = flagMode,
                modifier = Modifier.weight(1f),
                onClick = { flagMode = true },
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            view.chunked(9).forEachIndexed { y, row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
                ) {
                    row.forEachIndexed { x, cell ->
                        Surface(
                            onClick = { selectCell(x, y) },
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f),
                            shape = MaterialTheme.shapes.extraSmall,
                            color =
                                if (cell == 'F') {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.surfaceVariant
                                },
                            contentColor =
                                if (cell == 'F') {
                                    MaterialTheme.colorScheme.onPrimary
                                } else {
                                    MaterialTheme.colorScheme.onSurface
                                },
                        ) {
                            Box(
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    cellLabel(cell),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                            }
                        }
                    }
                }
            }
        }

        SableActionButton(
            text = "New game",
            modifier = Modifier.fillMaxWidth(),
            primary = false,
            onClick = ::reset,
        )
    }
}

private fun cellLabel(cell: Char): String =
    when (cell) {
        '#', '0' -> ""
        'F' -> "⚑"
        else -> cell.toString()
    }
