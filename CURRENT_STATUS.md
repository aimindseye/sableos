# SableOS current status

Last updated: 2026-09-24

## Executive state

Pixel 7 / Panther R9 is closed for active feature development and retained as a
frozen touch-first reference / regression target.

```text
R9_PANTHER_SOURCE=6f1d6d2f0f2525067874238c4b797ad58f2bcbc6
R9_PANTHER_TARGET_FILES_SHA256=08ef429c7f9eef17de7ddad4ce9baa81911950e8d34b6751b6e4588f66821502
R9_MODULE_QUALIFICATION=PASS
R9_LOCAL_FULL_CI=PASS
R9_FRESH_FULL_BUILD=PASS
R9_ARTIFACT_REGISTRATION=PASS
R9_STANDARD_PRESERVED_DATA_FLASH=PASS
R9_POSTFLASH_SMOKE=PASS_19_OF_19
R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY
R9_PERMISSION_ALLOWLIST_RUNTIME=PASS_NO_NOTIFICATION
R9_LIGHT_DARK_PROPAGATION=PASS_PHYSICAL
R9_PANTHER_DEVELOPMENT=HOLD_REFERENCE_MAINTENANCE_ONLY
```

The private repository `main` now contains the reconciled R9 lineage and the
Titan camera / sealed stock-firmware documentation. Later documentation or
multi-device tooling commits do not retroactively become Panther image
qualification sources.

## Active development

```text
PRIMARY_ACTIVE_WORK=KEYBOARD_FIRST_COMMON_PRODUCT
DEVICE_1=TITAN2
DEVICE_2=TITAN2_ELITE
FUTURE_DEVICE=Q27
PANTHER=FROZEN_REFERENCE
BRAMBLE=HISTORICAL_REFERENCE
```

Titan 2 and Titan 2 Elite are independent physical qualification targets even
when they consume the same common Sable applications and interaction semantics.

Titan 2 already has a sealed stock firmware/OTA corpus and active camera
research. Titan 2 Elite must receive its own read-only inventory and
bootloader/recovery/Treble/camera evidence when the device arrives.

## Canonical engineering interface

The operator contract is already device/release neutral:

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

The hardware serial is intentionally **not** part of build/image identity.
It is required only for device-contact operations such as flash and acceptance:

```bash
bash build/sable.sh titan2 R10 flash \
  --build-source <sha> \
  --serial <serial> \
  --preserve-data \
  --authorize
```

Titan 2, Titan 2 Elite and Q27 adapters currently fail closed for build,
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

See `docs/KEYBOARD_FIRST_MULTI_DEVICE_TRANSITION.md`.

## Next execution order

```text
1. Freeze Panther feature development.
2. Reconcile public sableos-project documentation with accepted R9 architecture.
3. Keep the canonical multi-device entry point and make artifact/flash strategy
   adapter-driven rather than Panther-target-files-specific.
4. Titan 2: finish T0/T1 read-only platform + camera + keyboard evidence.
5. Titan 2: qualify the first keyboard-first N0 SableOS image path.
6. Titan 2 Elite: run the same independent evidence sequence.
7. Implement common Sable Camera + Sable Keyboard/system input integration.
8. Q27 remains research until shipped hardware qualifies.
9. Return to production signing/OTA after repeatable multi-device development
   qualification.
```

Historical R5-R9 status details remain available in Git history and milestone
documents; this file is the current execution authority.
