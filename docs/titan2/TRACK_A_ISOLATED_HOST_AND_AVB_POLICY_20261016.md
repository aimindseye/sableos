# Track A OEM Titan2: isolated host and AVB correction (2026-10-16)

## Correction: Q25 build driver is NOT the Titan2 build

The previous delivery ran `/srv/sable-build/workspaces/q25/zinwaq25-sableos/scripts/build-apps.sh` and required the Q25 HEAD `e9bed8cec9da387301dc6a0124b22b28615f5f31`. The owner correctly received `TRACK_A=HOLD_Q25_SOURCE_NOT_PINNED`. That is a **tooling design error** for a Titan2 deliverable. It stopped before any image build or device contact. **Do not rerun that Q25-script-based command** to produce Titan2 firmware.

Track A must be sourced from canonical `aimindseye/sableos` on PR343 or successor, with Q25 **portable source changes imported via review** and Titan2's own profile/product/ROM assembly driver. Neither `scripts/build-apps.sh` in the Q25 repo nor `build/sable.sh q25` is an approved Titan2 OEM image entrypoint.

## Host separation

- **Q25 (unchanged)**: `SABLE_BUILD_ROOT=/srv/sable-build/workspaces/q25`, `ANDROID_HOME=$SABLE_ANDROID_SDK`, `SABLE_JDK=$SABLE_JDK21`, `GRADLE_USER_HOME=$SABLE_GRADLE_USER_HOME`. Preserve the user's `~/.q25env` and existing Q25 build/out/caches. No change or sourcing of it in Titan2 commands.
- **Titan2 Track A**: `SABLE_BUILD_ROOT=/srv/sable-build/workspaces/titan2-track-a`; `SABLE_ANDROID_ROOT=$SABLE_BUILD_ROOT/android`; `SABLE_APPS_OUT=$SABLE_BUILD_ROOT/artifacts/apps`; `JAVA_HOME=$SABLE_JDK17` (existing Titan2 five-APK host success); `ANDROID_HOME=$SABLE_ANDROID_SDK`; `GRADLE_USER_HOME=$SABLE_BUILD_ROOT/gradle-home`. Use a **subshell** for exports and never source the Q25 environment.
- **Titan2 Elite**: independently scoped under `/srv/sable-build/workspaces/titan2-elite`, own device profile and firmware pins; no Titan2 flash parity inheritance.
- **Zinwa Q27**: independently scoped under `/srv/sable-build/workspaces/q27`, own device profile and firmware pins; no Q25 hardware proof inheritance.
- Shared canonical **host tooling** `/srv/data/sable-build/sableos/repo/build/config/host-tools.env` and read-only Android SDK/JDK installations are allowed. Device-specific Gradle/Android build outputs must be isolated. Do not clobber or alter Q25 environment, workspace, signing or cache settings.

## AVB / MediaTek restore safety

The owner supplied an internet recipe claiming that patching flags in a stock vbmeta, writing the same patched image to `vbmeta`, `vbmeta_system`, `vbmeta_vendor` with SP Flash Tool V6, and then `fastboot flash product` permanently disables AVB at the hardware level. **Not validated for Titan2; do not execute**.

Authoritative project facts:
- `docs/titan2/TITAN2_FLASH_REGRESSION_POLICY.md` proves the actual Titan 2 chain `vbmeta → vbmeta_system / vbmeta_vendor` and userspace fastbootd, and keeps the default successful system-only N1F write at `AVB_MUTATION=NO`.
- `docs/titan2/N1C_FIRST_WRITE_POSTMORTEM_20260930.md` records a successfully written hybrid `super` that failed to boot, recovery requiring matched stock super + boot/AVB chain and factory reset.
- Flash mode is explicit (Android ADB, bootloader fastboot, fastbootd, recovery); `is-userspace=yes` and exact device/slot/LP/snapshot guard apply. A product-partition write has NOT inherited the N1F system-only flash pass.
- An AVB flag edit changes signed metadata: it is **not permanently burned into hardware**, and no proof a modified stock vbmeta will be accepted on this device was supplied. AVB flags belong to the **top-level** signed vbmeta contract; chained vbmeta images are independently signed/keyed and must not be overwritten by copies of root vbmeta. Unlocked bootloader doesn't remove the need to verify exact bootloader, metadata, rollback and filesystem mount behavior.
- SP Flash Tool V6 isn't a guaranteed bypass for a specific MediaTek device; exact signed download agent/auth, partition XML, restore backing, slot/geometry and operator setup require confirmation. Never replace three vbmeta partitions or bootloader/preloader/NVRAM based on this generic web recipe.
- No factory reset, reboot, flash, boot-chain modification, network fetch, Q25 workspace write, or source mutation are authorized by this documentation.

## Image milestone status

PR343 source contains Sable Tools, updated Hub, shared design, and planned 13-app Titan2 product manifest. **No actual OEM product image has been built.** The previously delivered `oem_product_assembler.py` is a **host-only ext4/sparse-ext4, Q25-manifest-consuming prototype**, NOT a Titan2 build driver; it cannot ingest the complete canonical Titan2 app set until Reader v2, Mail/TextReader flavors, Sable Start/Recents and OEM-compatible integration are admitted. The script's 10 synthetic parser tests and a 96MiB streaming checksum do not prove a real ext4 image with metadata or AVB has been built. EROFS remains unsupported by the prototype; `product.img` format must be observed from actual pinned TEE14 bytes on ai-g732 rather than guessed.

**NEXT ONE CONSOLIDATED DELIVERABLE:** Canonical Titan2-specific Track A build system integrating all portable apps and OEM-compatible HOME/system UX, producing a real V01.00.14 stock-derived image with source hashes, filesystem/SELinux ownership, signed APK package identities, LP sizing and AVB acceptance constraints. One host build qualification; then one separately authorized device-flash boundary; one final full OEM functionality acceptance. **No micro-gates for each app or patch.** 
