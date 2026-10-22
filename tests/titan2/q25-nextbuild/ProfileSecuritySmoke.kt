package org.sableos.start.platform

fun main() {
    var count = 0
    fun ok(v: Boolean) { check(v); count++ }
    val g = LauncherProfileSecurityGate
    ok(g.mayLaunch(true, true, false, false, true))
    ok(!g.mayLaunch(false, true, false, false, true))
    ok(!g.mayLaunch(true, true, false, false, false))
    ok(g.mayLaunch(true, false, true, false, true))
    ok(!g.mayLaunch(true, false, true, true, true))
    ok(!g.mayLaunch(true, false, false, false, true))
    ok(!g.mayLaunch(true, false, true, false, false))
    ok(!g.mayLaunch(false, false, true, false, true))
    ok(g.mayTogglePrivateSpace(true, true))
    ok(!g.mayTogglePrivateSpace(true, false))
    ok(!g.mayTogglePrivateSpace(false, true))
    ok(!g.mayTogglePrivateSpace(false, false))
    println("PROFILE_SECURITY_JVM_SMOKE=PASS_$count")
}
