package org.sableos.games

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import org.sableos.design.SablePageHeader
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSpacing
import org.sableos.design.SableTheme
import org.sableos.design.SableTile

private enum class GameMode(val label: String) {
    Sudoku("Sudoku"),
    Minesweeper("Mines"),
    Game2048("2048"),
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val qualification = NativeBridge.selfTest()
        check(qualification.startsWith("PASS:")) { qualification }

        setContent {
            SableTheme {
                var game by remember { mutableStateOf(GameMode.Sudoku) }

                SableScrollableScreen {
                    SablePageHeader(
                        title = "Games",
                        subtitle = "Sudoku · Minesweeper · 2048",
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
                    ) {
                        GameMode.entries.forEach { choice ->
                            SableTile(
                                title = choice.label,
                                active = game == choice,
                                modifier = Modifier.weight(1f),
                                onClick = { game = choice },
                            )
                        }
                    }

                    when (game) {
                        GameMode.Sudoku -> SudokuScreen()
                        GameMode.Minesweeper -> MinesweeperScreen()
                        GameMode.Game2048 -> Game2048Screen()
                    }
                }
            }
        }
    }
}
