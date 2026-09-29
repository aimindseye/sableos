# Titan 2 N1B2 image scope, doc binding, and capability ledger

Status: PR 206 planning contract
Date: 2026-09-29
Target: Titan 2 N1B2 initial image planning and implementation
Platform source: sableos-project/platform_sable main @ de9d4362f6779ddd0108fbd5804ebb25bdf4dc4c

## Purpose

This document is the controlling N1B2 image-scope contract. It replaces app-inventory-driven promotion with source-bound, evidence-driven promotion.

N1B2 is a good initial Titan 2 image target, not a public production release. Flash, public release, production signing, and unqualified artifact registration remain fail-closed until later qualification.

## Governing rule

```text
Existing APK builds != N1B2 image-ready
N1B2 image-ready = UX doc + visual confirmation doc + artifact binding + implementation + gate + build/runtime evidence
```

No user-facing app, platform surface, hardware surface, or vendor capability may enter N1B2 image membership solely because it builds.

## PR 206 scope

PR 206 is documentation and gate only.

Allowed:

```text
DOCS_CHANGED=YES
GATE_CHANGED=YES
APP_CODE_CHANGED=NO
BUILD_CODE_CHANGED=NO
DEVICE_CODE_CHANGED=NO
IMAGE_BUILD=NO
FLASH_ENABLEMENT=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

Deliverables:

```text
docs/titan2/N1B2_IMAGE_PLAN.md
docs/titan2/N1B2_PLATFORM_SABLE_DOC_BINDING.tsv
docs/titan2/N1B2_CAPABILITY_LEDGER.tsv
docs/titan2/N1B2_DEFERRED_LEDGER.tsv
build/gates/n1b2-image-plan-contract.sh
```

## Source inputs

The binding ledger is taken from `sableos-project/platform_sable` branch `main` at commit:

```text
PLATFORM_SABLE_MAIN_SHA=de9d4362f6779ddd0108fbd5804ebb25bdf4dc4c
TOP_LEVEL_DOCS=17
DESIGN_DOCS=52
DESIGN_ARTIFACTS_SVG=23
DEVICE_CAPABILITY_DOCS_IN_SCOPE=1
```

The gate fails if the local `platform_sable` checkout changes these source file counts or SHA without updating the binding TSV.

## Product composition rule

Before any user-facing surface enters N1B2 image membership:

```text
UX_DOC_BOUND=YES
VISUAL_CONFIRMATION_DOC_BOUND=YES
ARTIFACT_BOUND=YES
IMPLEMENTATION_PRESENT=YES
GATE_PRESENT=YES
GATE_PASS=YES
BUILD_PASS=YES_IF_APP_OR_MODULE
RUNTIME_EVIDENCE=YES_IF_PLATFORM_OR_HARDWARE_SURFACE
```

Each included surface must be one of:

```text
IMPLEMENTED_AND_VALIDATED
EXPLICITLY_DEFERRED_NOT_N1B2_BLOCKING
PLATFORM_SYSTEM_SURFACE_WITH_GATE
VENDOR_HAL_GATED_WITH_SAFE_FALLBACK
```

## Sequencing contract

PR 206 creates the ledger base. It does not promote product packages.

Required follow-up sequence:

```text
PR 207  Cellular / telephony evidence audit (static + runtime)
PR 208  Cellular restoration
PR 209  N1B2 design-surface matrix and blocker ledger
PR 210  Titan 2 base profile, capability flags and design system
PR 211  Critical text entry gates
PR 212  Sable Start + All Apps
PR 213  Command Search
PR 214  Settings + Settings Search + Mobile Manager / App Controls
PR 215  Private Space / Secure Vault / Dual Apps / App Lock / Work Profile
PR 216  Sable Hub
PR 217  Media / Gallery
PR 218  Phone + Contacts / People + Call Recorder + Dialer Codes
PR 219  Mail + Calendar
PR 220  Browser / WebView + Files / Documents
PR 221  Quick Settings + Notification Shade + Lockscreen + Setup Wizard
PR 222  Camera
PR 223  Connectivity
PR 224  Toolbox + IR Remote + Utilities / Notes / Recorder
PR 225  App Display Compatibility Profiles
PR 226  Weather
PR 227  Reader + Text Reader accessibility
PR 228  SubScreen / attention surfaces
PR 229  N1B2 image assembly dry-run
PR 230  N1B2 first image candidate
```

Ordering constraints:

```text
206 -> 207 -> 209 -> 210 -> 211 are sequential foundations.
208 follows 207 and can run in parallel with 209-227.
212-228 can proceed in parallel after 210 and 211 land.
229 requires 208 and every n1b2_blocking=YES matrix row.
230 requires 229.
```

## Cellular posture

Cellular is an N1B2 blocker. PR 207 must identify the common N1B1/N1B2 failure against stock-known-good evidence before PR 208 changes modules, overlays, permissions, sepolicy, or vendor bindings.

PR 208 runtime pass bar:

```text
CELLULAR_REGISTERED_AFTER_BOOT=PASS
CELLULAR_DATA_STABLE_30_MIN=PASS
CELLULAR_SURVIVES_REBOOT_X3=PASS
CELLULAR_SURVIVES_AIRPLANE_TOGGLE=PASS
CELLULAR_LTE_DATA=PASS
CELLULAR_5G_DATA=PASS_OR_NETWORK_GATED_WITH_REASON
CELLULAR_VOICE_CALL_MO_MT=PASS
CELLULAR_SMS_MO_MT=PASS
CELLULAR_MMS_MO_MT=PASS
NO_COM_ANDROID_PHONE_CRASH=PASS
NO_RADIO_SELINUX_DENIAL=PASS
DUAL_SIM=PASS_OR_CARRIER_GATED_WITH_REASON
ESIM=PASS_OR_CARRIER_GATED_WITH_REASON
VOLTE_IMS=PASS_OR_CARRIER_GATED_WITH_REASON
```

## Deferred posture

Deferred features are explicit. A deferral is valid only when recorded in `N1B2_DEFERRED_LEDGER.tsv` and proven absent or safely disabled by the owning gate.

Initial deferred items:

```text
keyboard shortcut base
Mini Mode
SubScreen shortcut keyboard / PTT
Calculator
Games
AOD
per-app cellular / Wi-Fi toggles
FM radio
```

## Fail-closed boundaries

```text
PUBLIC_RELEASE=NO
FLASH_ENABLEMENT=NO
PRODUCTION_SIGNING=NO
UNVALIDATED_HAL_CLAIMS=NO
UNVALIDATED_CELLULAR_FIX=NO
APP_PROMOTION_BY_BUILD_ONLY=NO
COMMON_APP_DEVICE_FORKS=NO
```
