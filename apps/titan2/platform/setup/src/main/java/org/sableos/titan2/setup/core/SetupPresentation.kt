package org.sableos.titan2.setup.core

/** Read-only checklist progress, not first-boot provisioning state. */
object SetupPresentation {
    fun stepLabel(index: Int, total: Int): String {
        require(total > 0 && index in 0 until total)
        return "Review ${index + 1} of $total"
    }

    const val WIFI_HELP =
        "Check that the network appears in Android Wi-Fi Settings, select it, " +
            "and enter its password using the physical keyboard or on-screen keyboard. " +
            "This checklist does not configure Wi-Fi or bypass Android provisioning."
}
