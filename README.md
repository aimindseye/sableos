# SableOS

SableOS is an experimental privacy- and security-focused Android-compatible
mobile OS with narrow privilege boundaries and one common product core across
touch-first and keyboard-first hardware profiles.

> **Applications provide capabilities; Sable organizes people, attention and actions.**

## Current milestone

Pixel 7 / Panther R9 is the frozen touch-first reference.

```text
R9_PANTHER_ACCEPTED_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
```

Active development is Titan 2 **N1D/C3B runtime recovery**, not the earlier
N0/N1B execution sequence.

```text
TITAN2_ACTIVE_LANE=N1D_C3B_RUNTIME_RECOVERY
C3B_E1_SYSTEMIMAGE=PASS
C3B_E2_SOURCE_ADMISSION=PASS
C3B_E3_BUILD_SOURCE=caf98dde723d07a071d95aaa1ef27d578d3208d8
C3B_E3_STATUS=SEALED_PASS
N1D_PHYSICAL_RESULT=FAIL_REBOOT_LOOP
C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
COUNT_ZERO_STATUS=PRIMARY_SUSPECT_NOT_PROVEN_ROOT_CAUSE
N1B_V010014_CONTROL=PENDING
N1E_BUILD_AUTHORIZED=NO_PENDING_N1B_CONTROL
```

The first N1D physical attempt did not establish a boot-qualified baseline.
The next physical experiment is the exact sealed N1B system artifact on the
current V01.00.14 device state. If N1B boots, N1E is built as the exact N1B
product plus only the five C3B apps and must pass G0/G1/G2 before any flash.
If N1B fails, N1E stops and the firmware/boot-chain/current-device-state delta
is investigated. N1D/E6 remain frozen meanwhile.

See
[`docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md`](docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md)
for the active roadmap.

## Parallel product development

The product-source lane is `aimindseye/titan2-temp`.

While E3 builds, the developer may progress continuously through:

```text
P1  Launcher3-hosted Sable Start keyboard-first source/handoff
P2  Sable Keyboard first-boot/default-provisioning readiness
P3  GrapheneOS SetupWizard2 keyboard/square-display integration preparation
P4  Sable Weather city-management + keyboard-first closure
```

P1-P4 do not wait for ai-g732 between stages. Each stage is frozen separately;
after P4 the operator performs a batched exact-head ai-g732 qualification before
the train is merged/admitted.

P5 **Sable Reader v2** architecture is accepted as a separate sibling P5A-P5F implementation train: keyboard-first EPUB/PDF, local-first CBZ comics/manga/webtoons and audiobooks while Sable Text Reader remains separate. The 23-screen SableScreens catalog is an explicit design/reference baseline, not a shipping runtime.

## Product architecture

```text
common Sable applications + semantic contracts
        |
        +-- touch-first profile      -> Panther reference
        |
        +-- keyboard-first profile   -> Titan 2 / Titan 2 Elite / future Q27
        |
        v
bounded device adapters
        |
        v
Android framework + vendor HAL/BSP + hardware
```

Current first-party HOME ownership is Launcher3/Launcher3QuickStep hosting
Sable Start presentation/state. The retired standalone SableLauncher runtime is
not current architecture. Android user choice of another launcher or IME remains
supported.

## Canonical engineering interface

```text
bash build/sable.sh <device> <release> <function> [options]
```

Device serials are not image identity and are used only for explicitly
authorized device-contact operations.

## Repository direction

- `aimindseye/sableos` — private integration, build and release authority.
- `aimindseye/titan2-temp` — parallel Titan product-source candidate lane.
- `sableos-project` — public reusable architecture/source/build home.
- Restless/Treble material — compatibility/reference evidence, not SableOS
  runtime/security authority.

## Release status

```text
PRODUCTION_KEYS_GENERATED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
PUBLIC_TITAN_BUILD_IMAGE=NO
PUBLIC_TITAN_FLASH=NO
```

Production signing/OTA remains deferred until repeatable multi-device
development qualification reaches a release-candidate stage.

## Documentation

Start with:

- `CURRENT_STATUS.md` — current private execution state.
- `docs/titan2/N1D_C3B_CURRENT_PLAN_AND_ASSIGNMENTS.md` — active Titan 2 roadmap and assignments.
- `docs/titan2/N1D_RUNTIME_RECOVERY_AND_N1E_CONTROL_PLAN.md` — current N1B control / N1E isolation authority.
- `docs/SABLE_READER_V2_ARCHITECTURE.md` — accepted P5 Reader v2 architecture, UX, formats and dependencies.
- `docs/titan2/SABLESCREENS_REFERENCE_BASELINE.md` — 23-screen design/reference convergence baseline.
- `docs/DOCUMENTATION_INDEX.md` — current/historical documentation index.
- `docs/CURRENT_HOME_AND_C3B_INTEGRATION_AUTHORITY.md` — HOME/product authority.
- `docs/adr/0010-keyboard-first-sableos-design-v1.md` — keyboard-first architecture.
- `docs/adr/0011-sable-hub-v1.md` — Sable Hub V1.
- `build/README.md` — build/deploy entry points.

Historical N0/N1B/N1B2/N1B3/N1C documents are retained as evidence and
requirements history; they are not current execution authority.
