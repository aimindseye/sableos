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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import org.sableos.design.SableActionButton
import org.sableos.design.SablePanel
import org.sableos.design.SableSpacing

private const val DEFAULT_SUDOKU =
    "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

@Composable
internal fun SudokuScreen() {
    var state by remember {
        mutableStateOf(requireOk(NativeBridge.sudokuStart(DEFAULT_SUDOKU)))
    }
    var board by remember {
        mutableStateOf(requireOk(NativeBridge.sudokuBoard(state)))
    }
    var selectedRow by remember { mutableIntStateOf(0) }
    var selectedCol by remember { mutableIntStateOf(2) }
    var status by remember { mutableStateOf("Choose a cell") }

    fun reset() {
        state = requireOk(NativeBridge.sudokuStart(DEFAULT_SUDOKU))
        board = requireOk(NativeBridge.sudokuBoard(state))
        selectedRow = 0
        selectedCol = 2
        status = "New puzzle"
    }

    fun setValue(value: Int) {
        val response =
            NativeBridge.sudokuSet(
                state,
                selectedRow,
                selectedCol,
                value,
            )

        if (response.startsWith("OK:")) {
            state = response.removePrefix("OK:")
            board = requireOk(NativeBridge.sudokuBoard(state))
            status =
                if (NativeBridge.sudokuSolved(state)) {
                    "Solved"
                } else {
                    "Move accepted"
                }
        } else {
            status = humanize(response)
        }
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {

        SablePanel {
            Text(
                status,
                style = MaterialTheme.typography.titleMedium,
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            board.chunked(9).forEachIndexed { rowIndex, row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
                ) {
                    row.forEachIndexed { colIndex, cell ->
                        val selected =
                            rowIndex == selectedRow &&
                                colIndex == selectedCol
                        val container =
                            if (selected) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            }
                        val content =
                            if (selected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            }

                        Surface(
                            onClick = {
                                selectedRow = rowIndex
                                selectedCol = colIndex
                                status = "Row ${rowIndex + 1}, column ${colIndex + 1}"
                            },
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f),
                            shape = MaterialTheme.shapes.extraSmall,
                            color = container,
                            contentColor = content,
                        ) {
                            Box(
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    if (cell == '0') "" else cell.toString(),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                            }
                        }
                    }
                }
            }
        }

        Column(
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            (1..9).chunked(3).forEach { values ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                ) {
                    values.forEach { value ->
                        SableActionButton(
                            text = value.toString(),
                            modifier = Modifier.weight(1f),
                            onClick = { setValue(value) },
                        )
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
