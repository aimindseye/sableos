package org.sableos.games

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.sableos.design.SableActionButton
import org.sableos.design.SableSpacing
import org.sableos.design.SableValuePanel

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
        SableValuePanel(
            label = "puzzle",
            value = status,
            supportingText = "Tap an open cell, then choose a number.",
        )

        SudokuBoard(
            board = board,
            selectedRow = selectedRow,
            selectedCol = selectedCol,
            onSelect = { row, col ->
                selectedRow = row
                selectedCol = col
                status =
                    if (isGiven(row, col)) {
                        "Fixed clue"
                    } else {
                        "Row ${row + 1}, column ${col + 1}"
                    }
            },
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            (1..9).chunked(3).forEach { values ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                ) {
                    values.forEach { value ->
                        SudokuNumberKey(
                            value = value,
                            modifier = Modifier.weight(1f),
                            onClick = { setValue(value) },
                        )
                    }
                }
            }
        }

        SableActionButton(
            text = "New puzzle",
            modifier = Modifier.fillMaxWidth(),
            primary = false,
            onClick = ::reset,
        )
    }
}

@Composable
private fun SudokuBoard(
    board: String,
    selectedRow: Int,
    selectedCol: Int,
    onSelect: (Int, Int) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
    ) {
        (0 until 3).forEach { blockRow ->
            Row(
                modifier = Modifier.fillMaxWidth(),
            ) {
                (0 until 3).forEach { blockCol ->
                    Surface(
                        modifier = Modifier.weight(1f),
                        shape = RectangleShape,
                        color = MaterialTheme.colorScheme.surface,
                        border =
                            BorderStroke(
                                1.5.dp,
                                MaterialTheme.colorScheme.outline,
                            ),
                    ) {
                        Column {
                            (0 until 3).forEach { innerRow ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    (0 until 3).forEach { innerCol ->
                                        val row = blockRow * 3 + innerRow
                                        val col = blockCol * 3 + innerCol
                                        val index = row * 9 + col
                                        val cell = board[index]
                                        val selected =
                                            row == selectedRow &&
                                                col == selectedCol
                                        val peer =
                                            row == selectedRow ||
                                                col == selectedCol
                                        val given = isGiven(row, col)

                                        val container =
                                            when {
                                                selected ->
                                                    MaterialTheme.colorScheme.primary
                                                peer ->
                                                    MaterialTheme.colorScheme.surfaceVariant
                                                else ->
                                                    MaterialTheme.colorScheme.surface
                                            }
                                        val content =
                                            when {
                                                selected ->
                                                    MaterialTheme.colorScheme.onPrimary
                                                given ->
                                                    MaterialTheme.colorScheme.onSurface
                                                else ->
                                                    MaterialTheme.colorScheme.primary
                                            }

                                        Surface(
                                            onClick = { onSelect(row, col) },
                                            modifier =
                                                Modifier
                                                    .weight(1f)
                                                    .aspectRatio(1f),
                                            shape = RectangleShape,
                                            color = container,
                                            contentColor = content,
                                            border =
                                                BorderStroke(
                                                    0.5.dp,
                                                    MaterialTheme.colorScheme.outlineVariant,
                                                ),
                                            tonalElevation = 0.dp,
                                        ) {
                                            Box(
                                                contentAlignment = Alignment.Center,
                                            ) {
                                                Text(
                                                    text =
                                                        if (cell == '0') {
                                                            ""
                                                        } else {
                                                            cell.toString()
                                                        },
                                                    style = MaterialTheme.typography.titleMedium,
                                                    fontWeight =
                                                        if (given) {
                                                            FontWeight.Bold
                                                        } else {
                                                            FontWeight.Medium
                                                        },
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SudokuNumberKey(
    value: Int,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = modifier,
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        contentColor = MaterialTheme.colorScheme.onSurface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
        tonalElevation = 0.dp,
    ) {
        Box(
            modifier = Modifier.aspectRatio(2.05f),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = value.toString(),
                style = MaterialTheme.typography.titleLarge,
            )
        }
    }
}

private fun isGiven(
    row: Int,
    col: Int,
): Boolean = DEFAULT_SUDOKU[row * 9 + col] != '0'
