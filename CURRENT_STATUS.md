# SableOS current status

Last updated: 2026-09-24

## Executive state

Pixel 7 / Panther R9 is temporarily reopened for one **bounded final
compatibility closure** before returning to frozen touch-first reference status.
The approved closure scope now includes the physically discovered communication
remediation required to freeze Panther cleanly: the pinned GrapheneOS App Store,
optional sandboxed Google Play, third-party Android interoperability, and Sable
Hub V1 over the proven Connected Apps notification/conversation foundation.

```text
R9_PANTHER_PREVIOUS_ACCEPTED_SOURCE=6f1d6d2f0f2525067874238c4b797ad58f2bcbc6
R9_PANTHER_PREVIOUS_ACCEPTED_TARGET_FILES_SHA256=08ef429c7f9eef17de7ddad4ce9baa81911950e8d34b6751b6e4588f66821502
R9_MODULE_QUALIFICATION=PASS
R9_LOCAL_FULL_CI=PASS
R9_FRESH_FULL_BUILD=PASS
R9_ARTIFACT_REGISTRATION=PASS
R9_STANDARD_PRESERVED_DATA_FLASH=PASS
R9_POSTFLASH_SMOKE=PASS_19_OF_19
R9_SYSTEM_IDENTITY_AUDIT=PASS_READ_ONLY
R9_PERMISSION_ALLOWLIST_RUNTIME=PASS_NO_NOTIFICATION
R9_LIGHT_DARK_PROPAGATION=PASS_PHYSICAL
R9_PANTHER_DEVELOPMENT=BOUNDED_FINAL_APPSTORE_THIRD_PARTY_CLOSURE
R9_APPSTORE_TESTED_SOURCE=86d0f67cd66f812c59e30a6fd28e455ae1dec6c1
R9_APPSTORE_TESTED_TARGET_FILES_SHA256=87b7347fbc388bfb9f121aa0bf9b19ec68b2ce3d2f0079f837b797692fd416a0
R9_APPSTORE_PRODUCT=PASS_PHYSICAL
R9_GOOGLE_PLAY_POLICY=OPTIONAL_USER_INSTALLED_NOT_PREINSTALLED
R9_SANDBOXED_GOOGLE_PLAY=PASS_PHYSICAL_GMS_WITHOUT_GSF
R9_THIRD_PARTY_PROVIDER_INSTALLATION=PASS_SIGNAL_WHATSAPP_TELEGRAM_LINKEDIN
R9_SIGNAL_CONNECTED_APP=PASS_CONVERSATION_REPLY
R9_WHATSAPP_CONNECTED_APP=REMEDIATION_PENDING_REPLY_HANDLE_SELECTION
R9_TELEGRAM_CONNECTED_APP=NOT_EVALUATED_PROVIDER_VERIFICATION_CHARGE
R9_LINKEDIN_CONNECTED_APP=PASS_NOTIFICATION_ONLY_OPEN_APP
R9_HUB_V1=SOURCE_IMPLEMENTED_QUALIFICATION_PENDING
R9_PANTHER_FINAL_COMPATIBILITY_FREEZE=PENDING_HUB_V1
```

The private repository `main` now contains the reconciled R9 lineage and the
Titan camera / sealed stock-firmware documentation. Later documentation or
multi-device tooling commits do not retroactively become Panther image
qualification sources.

## Active development

```text
PRIMARY_ACTIVE_WORK=PANTHER_FINAL_COMPATIBILITY_CLOSURE_THEN_KEYBOARD_FIRST
DEVICE_1=TITAN2
DEVICE_2=TITAN2_ELITE
FUTURE_DEVICE=Q27
PANTHER=BOUNDED_REOPEN_THEN_FROZEN_REFERENCE
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
1. Qualify the combined Sable Hub V1 closure in
   docs/adr/0011-sable-hub-v1.md: generic WhatsApp reply-handle retention,
   Enabled / Available Connected Apps, inline truthful reply handoff history,
   Priority / Messages / Email / People, and bounded Sable Mail snapshot access.
2. Build and physically verify one final source-bound Panther image.
3. Record the final Panther source + target-files seal and freeze Panther again.
4. Reconcile public sableos-project documentation with accepted R9 architecture.
5. Keep the canonical multi-device entry point and make artifact/flash strategy
   adapter-driven rather than Panther-target-files-specific.
6. Titan 2: finish T0/T1 read-only platform + camera + keyboard evidence.
7. Titan 2: qualify the first keyboard-first N0 SableOS image path.
8. Titan 2 Elite: run the same independent evidence sequence.
9. Implement common Sable Camera + Sable Keyboard/system input integration.
10. Q27 remains research until shipped hardware qualifies.
11. Return to production signing/OTA after repeatable multi-device development
   qualification.
```

Historical R5-R9 status details remain available in Git history and milestone
documents; this file is the current execution authority.
