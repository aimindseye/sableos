package org.sableos.start.live

private fun checkTrue(value: Boolean, message: String) {
    if (!value) throw AssertionError(message)
}

private fun <T> checkEquals(expected: T, actual: T, message: String) {
    if (expected != actual) throw AssertionError("$message expected=$expected actual=$actual")
}

private inline fun checkThrows(message: String, block: () -> Unit) {
    try {
        block()
    } catch (_: IllegalArgumentException) {
        return
    }
    throw AssertionError(message)
}

fun main() {
    val tests =
        listOf<Pair<String, () -> Unit>>(
            "fresh at boundary" to {
                val s =
                    LiveSurfaceSnapshot(
                        dateText = "Sep 11, 2026",
                        timeText = "9:00 AM",
                        photos = LiveDatum("Photos", "1 photo", LiveAvailability.LIVE),
                        music = LiveDatum("Music", "empty", LiveAvailability.EMPTY),
                        calendar = LiveDatum("Calendar", "empty", LiveAvailability.EMPTY),
                        weather = LiveDatum("Weather", "provider not configured", LiveAvailability.UNAVAILABLE),
                        tasks = LiveDatum("Tasks", "provider not configured", LiveAvailability.UNAVAILABLE),
                        observedAtEpochMs = 1_000L,
                    )
                checkTrue(s.isFresh(61_000L, 60_000L), "snapshot must be fresh at boundary")
                checkTrue(!s.isFresh(61_001L, 60_000L), "snapshot must be stale after boundary")
            },
            "future timestamp is not fresh" to {
                val s =
                    LiveSurfaceSnapshot(
                        "d",
                        "t",
                        LiveDatum("Photos", "x", LiveAvailability.EMPTY),
                        LiveDatum("Music", "x", LiveAvailability.EMPTY),
                        LiveDatum("Calendar", "x", LiveAvailability.EMPTY),
                        LiveDatum("Weather", "x", LiveAvailability.UNAVAILABLE),
                        LiveDatum("Tasks", "x", LiveAvailability.UNAVAILABLE),
                        2_000L,
                    )
                checkTrue(!s.isFresh(1_000L, 60_000L), "future snapshot must not be fresh")
            },
            "negative timestamp rejected" to {
                checkThrows("negative timestamp must fail") {
                    LiveSurfaceSnapshot(
                        "d",
                        "t",
                        LiveDatum("Photos", "x", LiveAvailability.EMPTY),
                        LiveDatum("Music", "x", LiveAvailability.EMPTY),
                        LiveDatum("Calendar", "x", LiveAvailability.EMPTY),
                        LiveDatum("Weather", "x", LiveAvailability.UNAVAILABLE),
                        LiveDatum("Tasks", "x", LiveAvailability.UNAVAILABLE),
                        -1L,
                    )
                }
            },
            "loading state is explicit" to {
                val loading = LiveDatum("Photos", "loading local data", LiveAvailability.LOADING)
                checkEquals(LiveAvailability.LOADING, loading.availability, "loading state")
            },
            "unconfigured providers are explicit" to {
                val weather = LiveDatum("Weather", "provider not configured", LiveAvailability.UNAVAILABLE)
                val tasks = LiveDatum("Tasks", "provider not configured", LiveAvailability.UNAVAILABLE)
                checkEquals(LiveAvailability.UNAVAILABLE, weather.availability, "weather state")
                checkEquals(LiveAvailability.UNAVAILABLE, tasks.availability, "tasks state")
            },
        )

    var failures = 0
    tests.forEach { (name, test) ->
        try {
            test()
            println("PASS: $name")
        } catch (t: Throwable) {
            failures++
            println("FAIL: $name: ${t.message}")
        }
    }

    println("SABLE_METRO_R3_DELTA_UNIT_TEST_COUNT=${tests.size}")
    println("SABLE_METRO_R3_DELTA_UNIT_TEST_FAILURES=$failures")
    println("SABLE_METRO_R3_DELTA_UNIT_TESTS=" + if (failures == 0) "PASS" else "FAIL")
    if (failures != 0) error("$failures unit test(s) failed")
}
