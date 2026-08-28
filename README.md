# SableOS

SableOS is an experimental privacy-focused mobile OS with a Rust-first userspace architecture, narrow privilege boundaries, and a goal of sharing one common core across different hardware and interaction profiles.

The project is not intended to become a collection of unrelated device ROMs. Hardware-specific behavior belongs in adapters; form-factor-specific behavior belongs in interaction profiles; common application and service semantics should remain shared wherever practical.

## Current reference target

- Device: Google Pixel 4a 5G G025E
- AOSP device codename: `bramble`
- SoC: Qualcomm Snapdragon 765G / SM7250
- GPU: Adreno 620
- Base: Android 12.1 / `android-12.1.0_r11`
- Build ID: `SQ3A.220705.003.A1`
- Build variant: `userdebug`

## Current milestone: B1.1 — in progress

### B0 — physical baseline passed

Vanilla AOSP B0 has been physically validated on the G025E.

Validated cellular/hardware behavior includes:

- cellular Internet
- outbound/inbound voice calling
- earpiece, microphone and speakerphone
- SMS send/receive
- MMS
- LTE registration
- 5G/NR observation

The retained Google/Qualcomm radio and IMS stack remains the hardware compatibility baseline.

### B1 — physical Rust validation passed

B1 is the first SableOS derivative build on `bramble`.

It keeps the known-good Google/Qualcomm hardware and radio stack intact and adds one native Rust executable:

```text
/system_ext/bin/oxynoded
```

The frozen B1 executable is:

```text
753cd2e2b4e915848a72f289d6bc764cd34edf1bbde0b0b4d023d06ae88d0e45  oxynoded
```

B1 has been physically validated on the G025E. `oxynoded --probe` runs successfully on-device and B1 retains cellular data, voice and SMS parity with B0.

The local B1 gold master is frozen and checksum-verified at:

```text
/srv/data/aosp_gold_master_bramble/B1-oxynoded-SQ3A.220705.003.A1
```

### B1.1 — init + dedicated SELinux domain

B1.1 is the current development milestone.

Its intended delta is deliberately small:

- start `oxynoded` through Android init
- run it as a non-root system service
- use a dedicated `oxynoded` SELinux domain
- keep SELinux enforcing
- add no radio, Binder, network, device, socket or capability privileges yet

The pre-full-build SELinux gates have passed:

- `system_ext_sepolicy.cil`
- `system_ext_file_contexts`
- `system_ext_file_contexts_test`
- `sepolicy_neverallows`
- combined `sepolicy`
- `sepolicy_tests`
- hand-written broad privilege audit: none

The full B1.1 image build and physical validation remain pending.

## Architecture

SableOS follows this rule:

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

The common architecture includes Rust services, security boundaries, application/service semantics, notifications, search, settings/storage, and eventual common telephony APIs.

Hardware differences are isolated below those APIs. The supported vendor modem/radio stack is preserved rather than reimplemented.

See `docs/ARCHITECTURE.md`.

## Interaction profiles

SableOS does not require radically different form factors to use one slab-phone UI.

### Touch-first

The Pixel reference experience is touch-first with a Metro-inspired design direction: strong typography, simple geometry, glanceable information, low chrome and fast gesture navigation.

### Keyboard-first

Physical-QWERTY devices use a keyboard-first profile built around focus navigation, shortcuts, type-to-search, command routing, dense information presentation, and touch/keyboard coexistence.

Source and API naming should remain generic rather than naming the interaction model after another commercial OS.

See `docs/INTERACTION_PROFILES.md`.

## Device roadmap

### Google Pixel 4a 5G G025E (`bramble`)

Status: **reference / physically validated**.

- Qualcomm SM7250
- B0 physical baseline: passed
- B1 Rust validation: passed
- B1.1: in progress

### Zinwa Q25

Status: **planned port / not yet supported**.

The current LineageOS Q25 device tree provides a promising MediaTek substrate with arm64, MT6789, kernel source dependency, A/B updates, dynamic partitions, AVB, MediaTek vendor policy/hardware support, and Android/MediaTek radio interfaces.

Q25 is intended to validate:

- a second SoC/vendor family
- the common Sable Rust/service architecture on MediaTek
- vendor-RIL preservation outside Qualcomm
- the keyboard-first interaction profile

See `docs/Q25_PORT_PLAN.md`.

### Zinwa Q27

Status: **exploratory/watch target**.

Q27 is of interest as a future physical-QWERTY platform, but SableOS will not assume Q25 compatibility or claim support until public developer sources, unlock/flash documentation, vendor interfaces and physical hardware can be reviewed.

If suitable, it should reuse the common Sable core and keyboard-first interaction framework rather than become a separate OS fork.

## Telephony rule

SableOS preserves the supported vendor modem path.

On Qualcomm this means retaining the Google/Qualcomm Radio HAL, QCRIL, IMS and modem firmware stack. On MediaTek targets it means retaining Android Radio HIDL/AIDL plus the supported MediaTek vendor RIL/IMS stack.

A future Rust telephony broker must use narrow supported Android/vendor interfaces. It must not talk directly to raw modem sockets or implement a replacement modem protocol.

## Repository layout

```text
device/sable/bramble/        SableOS bramble product and oxynoded source
patches/                     Minimal AOSP patches required by pinned bases
docs/                        Architecture, build, validation and porting notes
```

Generated Android images, proprietary vendor archives, firmware blobs and target-files ZIPs are intentionally not committed to this repository.

## Documentation

- `docs/ARCHITECTURE.md` — common-core, hardware-adapter, security and telephony architecture
- `docs/INTERACTION_PROFILES.md` — touch-first and keyboard-first UI/input design
- `docs/Q25_PORT_PLAN.md` — planned MediaTek/QWERTY port methodology
- `docs/BUILDING_B1.md` — reproduce the B1 build
- `docs/B1_VALIDATION.md` — B1 build and image validation record
- `docs/B1_GOLD_MASTER.md` — immutable B1 archive/freeze record
- `docs/G025E_HARDWARE_ACCEPTANCE.md` — factory-state, unlock, safe-flash and B0/B1 acceptance runbook
- `docs/CARRIER_COMPATIBILITY.md` — carrier compatibility goals and qualification rules

## Next gate

Complete the full B1.1 build, audit the B1-to-B1.1 partition delta, create a safe flash package only after that audit passes, then physically validate automatic `oxynoded` startup, the dedicated SELinux domain, enforcing policy, absence of unexpected AVCs, and telephony parity on the G025E.