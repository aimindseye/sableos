package org.sableos.games

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.design.SableTheme

private const val DEFAULT_SUDOKU =
    "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val qualification = NativeBridge.selfTest()
        check(qualification.startsWith("PASS:")) { qualification }

        val sudokuState = requireOk(
            NativeBridge.sudokuStart(DEFAULT_SUDOKU),
        )
        val sudokuBoard = requireOk(
            NativeBridge.sudokuBoard(sudokuState),
        )

        val mineState = requireOk(
            NativeBridge.minesweeperStart(
                9,
                9,
                10,
                1803L,
            ),
        )
        val mineView = requireOk(
            NativeBridge.minesweeperView(mineState),
        )

        setContent {
            SableTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Text(
                            "Sable Games",
                            style = MaterialTheme.typography.headlineLarge,
                        )

                        SudokuCard(
                            initialState = sudokuState,
                            initialBoard = sudokuBoard,
                        )

                        MinesweeperCard(
                            initialState = mineState,
                            initialView = mineView,
                        )

                        Game2048Card()

                        Text(
                            "Rust owns all game rules and deterministic state transitions. " +
                                "Android owns rendering, input and lifecycle.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SudokuCard(
    initialState: String,
    initialBoard: String,
) {
    var state by remember { mutableStateOf(initialState) }
    var board by remember { mutableStateOf(initialBoard) }

    var row by remember { mutableStateOf("0") }
    var col by remember { mutableStateOf("2") }
    var value by remember { mutableStateOf("4") }
    var status by remember { mutableStateOf("Ready") }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "Sudoku",
                style = MaterialTheme.typography.titleLarge,
            )

            Text(formatGrid(board, 9))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = row,
                    onValueChange = { row = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Row") },
                )

                OutlinedTextField(
                    value = col,
                    onValueChange = { col = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Col") },
                )

                OutlinedTextField(
                    value = value,
                    onValueChange = { value = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Value") },
                )
            }

            Button(
                onClick = {
                    val parsedRow = row.toIntOrNull()
                    val parsedCol = col.toIntOrNull()
                    val parsedValue = value.toIntOrNull()

                    if (
                        parsedRow == null ||
                        parsedCol == null ||
                        parsedValue == null
                    ) {
                        status = "Enter integer row, col and value"
                    } else {
                        val response = NativeBridge.sudokuSet(
                            state,
                            parsedRow,
                            parsedCol,
                            parsedValue,
                        )

                        if (response.startsWith("OK:")) {
                            state = response.removePrefix("OK:")
                            board = requireOk(
                                NativeBridge.sudokuBoard(state),
                            )

                            status = if (
                                NativeBridge.sudokuSolved(state)
                            ) {
                                "Solved"
                            } else {
                                "Move accepted"
                            }
                        } else {
                            status = humanize(response)
                        }
                    }
                },
            ) {
                Text("Set cell")
            }

            Text(status)
        }
    }
}

@Composable
private fun MinesweeperCard(
    initialState: String,
    initialView: String,
) {
    var state by remember { mutableStateOf(initialState) }
    var view by remember { mutableStateOf(initialView) }

    var x by remember { mutableStateOf("4") }
    var y by remember { mutableStateOf("4") }
    var status by remember { mutableStateOf("Ready") }

    fun applyResponse(response: String) {
        val fields = response.split('|')

        if (fields.size >= 3 && fields[0] == "OK") {
            state = fields[1]
            view = requireOk(
                NativeBridge.minesweeperView(state),
            )
            status = fields.drop(2).joinToString(" ")
        } else {
            status = humanize(response)
        }
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "Minesweeper",
                style = MaterialTheme.typography.titleLarge,
            )

            Text(formatGrid(view, 9))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = x,
                    onValueChange = { x = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("X") },
                )

                OutlinedTextField(
                    value = y,
                    onValueChange = { y = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Y") },
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = {
                        val parsedX = x.toIntOrNull()
                        val parsedY = y.toIntOrNull()

                        if (parsedX == null || parsedY == null) {
                            status = "Enter integer coordinates"
                        } else {
                            applyResponse(
                                NativeBridge.minesweeperReveal(
                                    state,
                                    parsedX,
                                    parsedY,
                                ),
                            )
                        }
                    },
                ) {
                    Text("Reveal")
                }

                Button(
                    onClick = {
                        val parsedX = x.toIntOrNull()
                        val parsedY = y.toIntOrNull()

                        if (parsedX == null || parsedY == null) {
                            status = "Enter integer coordinates"
                        } else {
                            applyResponse(
                                NativeBridge.minesweeperToggleFlag(
                                    state,
                                    parsedX,
                                    parsedY,
                                ),
                            )
                        }
                    },
                ) {
                    Text("Flag")
                }
            }

            Text(status)
        }
    }
}

@Composable
private fun Game2048Card() {
    var board by remember {
        mutableStateOf(
            intArrayOf(
                2, 2, 4, 4,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
            ),
        )
    }

    var score by remember { mutableStateOf(0L) }

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

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "2048",
                style = MaterialTheme.typography.titleLarge,
            )

            Text(format2048(board))
            Text("Score: $score")

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { slide(0) }) { Text("Left") }
                Button(onClick = { slide(1) }) { Text("Right") }
                Button(onClick = { slide(2) }) { Text("Up") }
                Button(onClick = { slide(3) }) { Text("Down") }
            }
        }
    }
}

private fun requireOk(protocol: String): String {
    check(protocol.startsWith("OK:")) { protocol }
    return protocol.removePrefix("OK:")
}

private fun humanize(protocol: String): String =
    protocol
        .removePrefix("ERR:")
        .replace('_', ' ')

private fun formatGrid(
    cells: String,
    width: Int,
): String =
    cells
        .chunked(width)
        .joinToString("\n") { row ->
            row.toCharArray().joinToString(" ")
        }

private fun format2048(board: IntArray): String =
    board
        .toList()
        .chunked(4)
        .joinToString("\n") { row ->
            row.joinToString(" ") { value ->
                value.toString().padStart(4)
            }
        }
