# SableOS current status

Last updated: 2026-09-25

This file is the private integration repository's current execution authority.
Historical R5-R10 status files, issue bodies and PR descriptions remain evidence
for the milestone they described, but they do not override this file when they
conflict with the current merged state.

## Executive state

Pixel 7 / Panther R9 is closed again as the frozen touch-first reference after
the final Sable Hub V1 compatibility/remediation closure.

```text
PRIVATE_MAIN_HEAD=2624e1af
R10_KEYBOARD_FIRST_DESIGN_V1=MERGED
R10_KEYBOARD_FIRST_DESIGN_PR=108
R10_KEYBOARD_FIRST_DESIGN_MERGE_COMMIT=2624e1af
R10_KEYBOARD_FIRST_DESIGN_SOURCE=20da2daa

R9_PANTHER_HUB_V1_CLOSURE=MERGED
R9_PANTHER_HUB_V1_PR=110
R9_PANTHER_HUB_V1_MERGE_COMMIT=f175b00f
R9_PANTHER_ACCEPTED_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_STANDARD_PRESERVED_DATA_FLASH=PASS
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
R9_PANTHER_REFERENCE_STATE=FROZEN_TOUCH_FIRST_REFERENCE

THEME_PROPAGATION=DEFERRED_SEPARATE_PHYSICAL_APPEARANCE_GATE
CLEAN_BASELINE_APPSTORE=NOT_CLAIMED_ON_PRESERVED_DATA_DEVICE
PRODUCTION_SIGNING=DEFERRED
```

The final Panther image is source-bound to `edf62e5b` and target-files-bound to
`a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285`. Later
merged documentation, keyboard-first planning and repository-cleanup commits do
not become new Panther image qualification sources.

## Final R9 closure evidence

```text
R9_MESSAGES_FOCUSED_QUALIFICATION=PASS
R9_PHYSICAL_UX_MODULE_QUALIFICATION=PASS
R9_FRESH_FULL_BUILD=PASS
R9_FULL_BUILD_CAUSALITY=PASS_ABSENT_OUT_TO_FRESH_TARGET_FILES
SABLE_DEVICE_ARTIFACT_GATE=PASS
SABLE_ARTIFACT_REGISTER=PASS
SABLE_RELEASE_ARTIFACT_REGISTER=PASS
SABLE_STANDARD_FLASH=PASS
R9_SABLE_HOME_DEVICE_ACCEPTANCE=PASS
R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY
R9_PERMISSION_ALLOWLIST_RUNTIME=PASS_NO_NOTIFICATION
R9_APPSTORE_AUDIT=PASS_READ_ONLY_RUNTIME_STATE
MAIN_CONTAINS_SOURCE=PASS
```

The preserved-data physical device intentionally kept user-installed state. The
AppStore/Play read-only audit therefore proves the observed preserved runtime
state and sandboxed Play behavior, not a clean baseline factory image without
user-installed packages.

## Current product status

Sable Hub V1 is the accepted common communications surface:

```text
Priority | Messages | Email | People
```

Hub remains an aggregator/interaction surface. Sable Mail owns mail accounts,
protocols, MIME/storage/security behavior and credentials. Hub consumes bounded
local summaries and/or notification-derived state; it must not scrape private
mail/provider databases or manufacture delivery/read semantics.

Panther now serves as:

- frozen touch-first reference;
- regression/security/product-comparison baseline;
- known-good build/flash/evidence pattern;
- reference for common app semantics before Titan-family promotion.

Open polish/physical issues intentionally remain open until the Titan 2 SableOS
install path gives the next useful closure point. In particular, appearance,
Reader propagation, large-media-library performance, duplicate visible Messages,
production icons/launch timing, first-run crash evidence and All Apps permission
summaries are tracked as open follow-ups rather than blockers to the current
Panther freeze.

## Active development

```text
PRIMARY_ACTIVE_WORK=KEYBOARD_FIRST_TITAN_N0_SEQUENCE
PANTHER=FROZEN_TOUCH_FIRST_REFERENCE
DEVICE_1=TITAN2
DEVICE_2=TITAN2_ELITE
FUTURE_DEVICE=Q27
BRAMBLE=HISTORICAL_REFERENCE
```

Titan 2 and Titan 2 Elite are independent physical qualification targets even
when they consume the same common Sable applications and interaction semantics.
Titan 2 already has active sealed stock-firmware, camera and keyboard research.
Titan 2 Elite must receive its own read-only inventory and bootloader/recovery/
Treble/camera/telephony evidence when the device arrives.

## Canonical engineering interface

The operator contract is device/release neutral:

```text
bash build/sable.sh <device> <release> <function> [options]
```

Canonical device IDs:

```text
panther
titan2
titan2-elite
q27
```

The hardware serial is intentionally **not** part of build/image identity. It is
required only for device-contact operations such as flash and acceptance:

```bash
bash build/sable.sh titan2 R10 flash \
  --build-source <sha> \
  --serial <serial> \
  --preserve-data \
  --authorize
```

Titan 2, Titan 2 Elite and Q27 adapters remain fail-closed for build,
qualification and flash until each platform contract is proven.

## Repository direction

During the keyboard-first transition:

- `aimindseye/sableos` remains the private integration/release authority;
- `sableos-project` is the target canonical public home for reusable Sable
  product code, architecture and build contracts;
- do not publish the private monorepo wholesale;
- migrate reusable components one at a time after provenance, licensing,
  secret/private-path review and independent build/test closure;
- private host evidence, raw firmware, serials and unreviewed vendor diagnostics
  remain outside public Git.

Public documentation must now reflect that PR #110 and PR #108 are merged and
that Panther's current image authority is the `edf62e5b` / `a0b359...` R9 Hub
V1 closure, not the earlier `6f1d6d2f` / `08ef...` acceptance image.

## Next execution order

```text
1. Keep remaining open issues open until Titan 2 SableOS install closure.
2. Synchronize sableos-project public documentation with this current state.
3. Titan 2: finish T0/T1 read-only platform, keyboard, display, camera, radio
   and restore evidence.
4. Titan 2: qualify first keyboard-first N0 SableOS artifact/deployment path.
5. Close Panther/Titan-shared open polish issues only when the Titan 2 install
   proves or supersedes them.
6. Titan 2 Elite: run the same independent evidence sequence.
7. Implement common Sable Camera and Sable Keyboard/system-input integration.
8. Q27 remains research until shipped hardware qualifies.
9. Return to production signing/OTA after repeatable multi-device development
   qualification.
```

Historical R5-R10 details remain available in Git history, issues, PRs and
milestone documents; this file is the current execution authority.
