# SableOS

SableOS is an experimental privacy- and security-focused Android-compatible
mobile OS with narrow privilege boundaries, a Rust-first userspace direction,
and one common product core across hardware and interaction profiles.

> **Applications provide capabilities; Sable organizes people, attention and actions.**

## Current milestone

Pixel 7 / Panther R9 is closed as the frozen touch-first reference after the
final Sable Hub V1 compatibility/remediation closure.

Validated Panther release evidence is bound to the exact image source and
artifact, not to later documentation-only repository heads:

```text
PRIVATE_MAIN_HEAD=2624e1af
R9_PANTHER_HUB_V1_CLOSURE=MERGED
R9_PANTHER_HUB_V1_MERGE_COMMIT=f175b00f
R9_PANTHER_SOURCE=edf62e5bb08372a1395841d6cc5d78d3148a7695
R9_PANTHER_TARGET_FILES_SHA256=a0b359613c4f30e9a834fba212e0b044a97d63ed0537c59471c31b99b627d285
R9_PANTHER_PHYSICAL_ACCEPTANCE=PASS_WITH_PRESERVED_PLAY_STATE
R9_PANTHER_DEVELOPMENT=FROZEN_TOUCH_FIRST_REFERENCE
R10_KEYBOARD_FIRST_DESIGN_V1=MERGED
```

The final preserved-data physical device intentionally kept user-installed
state. Clean-baseline AppStore claims are therefore not made from that device.
Appearance/theme-propagation and polish issues remain open follow-ups and will
be closed with the Titan 2 SableOS install path where appropriate.

## Product direction

SableOS should not become a collection of unrelated device ROMs or a differently
branded Android launcher.

The intended product model is:

```text
Android / third-party applications
        provide capabilities, content and authorized actions
                         |
                         v
AOSP / Android platform services
        provide mature enforcement and device capability
                         |
                         v
Sable product surfaces
        organize people, attention, actions, privacy and intent
```

Core rules:

> One SableOS core, multiple hardware adapters, multiple interaction profiles.

> Preserve proven Android/vendor capability unless there is a demonstrated
> privacy, security, performance, maintainability or architectural reason to
> replace it.

> The shell may observe and request; privileged services decide and execute.

> Stable Sable semantic contracts should survive Android-version and device
> changes; substrate-specific behavior belongs behind bounded adapters.

## Sable Flow and Sable Hub

**Sable Flow** is the Sable-owned design language: information-first,
Metro-influenced, privacy-bounded and implemented under Sable identity rather
than as a clone of another shell.

**Sable Hub V1** is the accepted common people/communications surface:

```text
Priority | Messages | Email | People
```

Sable Hub is an aggregator and interaction surface, not the owner of every
source database or account. Sable Mail owns mail accounts, protocols, MIME,
storage, TLS/certificate handling and credentials. Hub consumes bounded local
summaries and/or notification-derived state and must not scrape private provider
databases or manufacture delivery/read semantics.

## Active device direction

Active product work now moves to the keyboard-first portability line:

```text
Titan 2
    -> active keyboard-first N0 SableOS/GSI integration target
    -> stock/firmware/camera/keyboard/display/restore evidence in progress

Titan 2 Elite
    -> independent stock/device baseline when hardware arrives
    -> second keyboard-first N0 target

Q27
    -> RESEARCH / future product candidate
    -> no device claims until shipped hardware/firmware qualifies
```

The common rule is unchanged: one Sable product core, multiple hardware adapters
and interaction profiles. See `docs/KEYBOARD_FIRST_MULTI_DEVICE_TRANSITION.md`.

## Canonical engineering interface

The operator-facing entry point is device/release neutral:

```text
bash build/sable.sh <device> <release> <function> [options]
```

Examples:

```bash
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 build --tmux
bash build/sable.sh panther R9 flash --build-source <sha> --serial <serial> --preserve-data --authorize
bash build/sable.sh panther R9 accept --serial <serial> --suite launcher
```

Canonical device IDs:

```text
panther
titan2
titan2-elite
q27
```

The hardware serial is not build/image identity. It is required only for
device-contact operations such as flash and acceptance. Titan 2, Titan 2 Elite
and Q27 adapters remain fail-closed until their restore, partition, AVB,
transport and acceptance contracts are proven.

## Repository direction

During the keyboard-first transition:

- `aimindseye/sableos` remains the private integration/release authority;
- `sableos-project` is the target canonical public home for reusable Sable
  product code, architecture and build contracts;
- the private monorepo is not published wholesale;
- reusable components migrate only after provenance, licensing, secret/private
  path review and independent build/test closure;
- private host evidence, raw firmware, serials and unreviewed vendor diagnostics
  stay outside public Git.

## CI execution

SableOS qualification runs directly on the controlled local build machine.
GitHub is used for source hosting, PR review, issues and documentation.

This is not a self-hosted GitHub Actions runner. Remote execution from GitHub
remains disabled, and the prior encryption requirement for any future Actions
runner remains intact.

## Historical reference target

Pixel 7 / Panther remains the frozen touch-first reference. Pixel 4a 5G /
Bramble is a historical architecture/regression reference only.

## Release signing

Production signing/OTA engineering is intentionally **paused and non-blocking**
while product features and multi-device qualification are developed.

```text
PRODUCTION_KEYS_GENERATED=NO
KEY_GENERATION_AUTHORIZED=NO
SIGNING_AUTHORIZED=NO
OTA_GENERATION_AUTHORIZED=NO
SIGNING_HOST_SELECTION=DEFERRED
```

Production signing returns to the critical path before release-candidate/OTA
distribution.

## Engineering discipline

Runtime milestones close on evidence, not compilation alone:

```text
source guards
 -> targeted tests
 -> affected build
 -> generated-artifact audit
 -> compiled policy audit
 -> full product build
 -> exact image proof
 -> AVB validation
 -> controlled device deployment
 -> runtime/physical proof
 -> fallback/recovery validation
```

## Documentation

Start with:

- `CURRENT_STATUS.md` — current validated state and active milestone.
- `docs/DOCUMENTATION_INDEX.md` — current/historical documentation index.
- `docs/adr/0010-keyboard-first-sableos-design-v1.md` — accepted keyboard-first design V1.
- `docs/adr/0011-sable-hub-v1.md` — accepted Sable Hub V1 communications model.
- `docs/KEYBOARD_FIRST_MULTI_DEVICE_TRANSITION.md` — Titan-family keyboard-first transition.
- `build/README.md` — canonical build/deploy/acceptance entry points.
