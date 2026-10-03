# Sable Setup helper readiness hardening (D8)

Status: **source delivered; no device evidence**

The Setup module stays a **post-provisioning readiness helper**. It is not the Android Setup Wizard and claims no first-boot or
provisioning authority (KL-005, IR-003). It observes, opens screens the user confirms, and changes nothing itself.

## Source markers

Derived from the source by `build/titan2/qualify-c3b-product-source.sh`; source-level only.

~~~text
SABLE_SETUP_READINESS_MODEL=PASS
SABLE_SETUP_LAUNCH_SAFETY=PASS
SABLE_SETUP_WORDING=PASS
SABLE_SETUP_DEFAULT_APP_TRUTHFULNESS=PASS
SABLE_SETUP_PROFILE_UNKNOWN=PASS
SABLE_SETUP_SCOPE=PASS_EXCLUSIONS_ABSENT
~~~

## Contract statements

~~~text
D8_DEVICE_RUNTIME_VALIDATED=NO
D8_DEPENDENCY_DELTA=NONE
D8_SETUP_WIZARD_CLAIMED=NO
D8_SETTING_MUTATION=NO
D8_ROLE_MUTATION=NO
D8_NEW_PERMISSIONS=NONE
D8_HIDDEN_PROPERTY_EXPANSION=NO
IR_001_STATUS=OPEN_CANONICAL
IR_003_STATUS=OPEN_CANONICAL
IR_005_STATUS=OPEN_CANONICAL
KL_005_STATUS=OPEN_CANONICAL
~~~

## What changed

- **Readiness model.** `Done / Todo / Info` is replaced by `Satisfied`, `ActionRequired`, `Informational`, `Unavailable` and `Unknown`
  (`core/Readiness.kt`). A read is `Value`, `Absent` or `Failed`; a failed read is `Unknown` and is never shown as satisfied, failed or not configured.
  The summary names action-required, unavailable and unknown rows instead of dropping them, and "no action required" is shown only when none exist.
- **Radio wording.** The row reads "Read-only SIM and network diagnostics; IMS registration visibility requires canonical IR-007". The helper never
  implies that IMS registration is observed.
- **Launch safety.** Every destination (home settings, default-apps settings, network settings, DisplayCompat, RadioDiag, the keyboard picker) is
  resolved before its button is offered. A destination that is missing shows as `Unavailable` and gets no button; a destination whose availability
  cannot be verified also gets no button and keeps the row's evidence state with an explicit bounded "could not verify" note. A launch that still
  fails is classified (`ActivityNotFoundException`, `SecurityException`, other runtime failures) and shown as one bounded line; exception text is never shown.
- **Default apps.** The helper stays observational. HOME is informational and canonical-owned. The keyboard row tests the Sable keyboard package
  explicitly and only observes (IR-005 stays canonical). The Phone and Messages rows say only "A default app is configured" because only presence is
  tested; no package is called correct.
- **Profile identity.** The provisional `ro.sable.profile.id` read is unchanged. A blank or unreadable value is shown as an explicit unknown, an
  unrecognized id is shown as sanitized, length-bounded text, and no row or behaviour depends on it. It is not a security boundary and nothing
  branches on a device name (IR-001 stays open).
- **Manifest.** Only `<queries>` entries for the three settings actions were added so the resolve check works under package visibility. No permission.

## Not in D8

No Setup Wizard, provisioning-state ownership, SettingsProvider change, default-keyboard product configuration, HOME-role enforcement,
privileged permission, Settings/SystemUI/framework change, role or setting mutation, new hidden API, product-tree or admission change, device contact,
flash or signing. Evidence is pure JVM tests and the static gate; Android compile and device behaviour are not claimed (KL-033).
