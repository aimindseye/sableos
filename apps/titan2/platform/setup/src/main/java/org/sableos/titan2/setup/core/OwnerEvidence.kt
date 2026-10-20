package org.sableos.titan2.setup.core

/** Read-only interpretations; a visible activity does not imply installed-product or signing authority. */
object OwnerEvidence {
    fun browser(value: Observed): String = when (value) {
        is Observed.Value ->
            "Android resolves web links to: ${value.text}; default role and launch acceptance not verified."
        Observed.Absent -> "No user-facing HTTPS browser handler resolved; WebView alone is not a browser."
        Observed.Failed -> "Unable to query an HTTPS browser handler on this user/profile."
    }

    fun wizard(value: Observed): String = when (value) {
        is Observed.Value ->
            "Android advertises setup handler: ${value.text}; privileged ownership not verified."
        Observed.Absent -> "No enabled setup-wizard handler visible; it may be disabled after provisioning."
        Observed.Failed -> "Cannot identify an installed setup-wizard handler for this Android user."
    }

    fun provisioning(value: Observed): String = when (value) {
        is Observed.Value -> when (value.text) {
            "complete" -> "Android reports device provisioned and this user setup complete; wizard owner unknown."
            "pending" -> "Android first-boot provisioning is not yet complete; wizard owner unknown."
            else -> "Android provisioning flags are not conclusive; wizard owner unknown."
        }
        Observed.Absent -> "Android did not report usable provisioning flags; wizard owner unknown."
        Observed.Failed -> "Provisioning flags unavailable; privileged SetupWizard owner unverified."
    }
}
