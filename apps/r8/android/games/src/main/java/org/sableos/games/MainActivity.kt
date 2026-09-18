package org.sableos.games

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import org.sableos.design.SablePageHeader
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val qualification = NativeBridge.selfTest()
        check(qualification.startsWith("PASS:")) { qualification }

        setContent {
            SableTheme {
                SableScrollableScreen {
                    when (BuildConfig.SABLE_GAME) {
                        "sudoku" -> {
                            SablePageHeader(
                                title = "Sudoku",
                                subtitle = "Sable Games",
                            )
                            SudokuScreen()
                        }

                        "minesweeper" -> {
                            SablePageHeader(
                                title = "Minesweeper",
                                subtitle = "Sable Games",
                            )
                            MinesweeperScreen()
                        }

                        "2048" -> {
                            SablePageHeader(
                                title = "2048",
                                subtitle = "Sable Games",
                            )
                            Game2048Screen()
                        }

                        else -> error("Unsupported Sable game flavor: ${BuildConfig.SABLE_GAME}")
                    }
                }
            }
        }
    }
}
