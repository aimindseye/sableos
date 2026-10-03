# Titan 2 N1F — C3A-derived C3B5 build and flash

Status: **next operator execution**

Date: **2026-10-03**

## Decision

The C3A public-functional Restless/TrebleDroid control is now physically
boot-qualified on Titan 2 stock vendor/firmware V01.00.14.

Observed control result:

```text
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
C3A_SYSTEM_BYTES=3146977280
C3A_CONTROL_PATCH_COUNT=369

C3A_V010014_SYSTEM_FLASH=PASS
C3A_V010014_ANDROID_BOOT=PASS
C3A_V010014_VOICE_REGISTRATION=PASS
C3A_V010014_DATA_REGISTRATION=PASS
C3A_V010014_NR_NSA_CAPABILITY=PASS
C3A_V010014_RADIO_POSTBOOT_STABILITY=ISSUE_RECOVERABLE_BY_RADIO_CYCLE
C3A_V010014_COMPATIBILITY_BASELINE=PASS
```

An airplane-mode radio cycle restored home registration on 310260 with LTE,
NR availability / EN-DC availability and NR_NSA display state. The radio
stability issue is therefore tracked separately and does not block the boot
isolation experiment.

The previous plain C3B image is not the next physical test. N1F instead keeps
the exact booting C3A compatibility substrate and adds only the five already
admitted Sable product apps:

```text
SableTitan2Keyboard
SableTitan2Camera
SableTitan2DisplayCompat
SableTitan2Setup
SableTitan2RadioDiag
```

No Restless/TrebleDroid compatibility patch is added or removed.

## One combined operator deliverable

The single runner is:

```text
build/titan2/run-n1f-c3a-derived-c3b5.sh
```

It performs, in order:

1. archives the exact boot-qualified C3A `system.img`, build evidence,
   control/preflight evidence, physical-control log if present, and a pinned
   Android repo manifest under
   `/srv/sable-build/artifacts/titan2/c3a-boot-qualified/<timestamp>/`;
2. builds the five admitted application APKs from the pinned E2 source snapshot
   with Gradle offline;
3. stages exactly seven files into the C3A Android source:
   `Android.bp`, `sable-titan2-apps.mk`, and five APKs;
4. adds one product-inherit line to C3A `device/phh/treble/rom.mk`;
5. incrementally rebuilds the existing C3A `systemimage` output;
6. proves all five APKs are signed and present under `system/product/app`;
7. preserves the derived image under
   `/srv/sable-build/artifacts/titan2/n1f-c3a-derived-c3b5/<timestamp>/`;
8. restores the C3A Android source tree before device contact;
9. transitions the Titan 2 to userspace fastbootd if needed;
10. flashes `system_a` exactly once, reboots exactly once, and observes boot.

The runner does **not** perform a factory reset, COW cleanup, slot switch,
vbmeta/boot/vendor_boot write, whole-super write, automatic retry, OTA build or
target-files build.

## Operator command

Start with the integration repository on the merged main commit and a clean
worktree:

```bash
cd /srv/sable-build/sableos/repo

bash build/titan2/run-n1f-c3a-derived-c3b5.sh selfcheck

bash build/titan2/run-n1f-c3a-derived-c3b5.sh run \
  --authorize-build \
  --authorize-flash
```

The C3A archive completes before source mutation or device write. A failure in
archive, app build, product membership, image qualification, source restoration,
fastboot identity, slot, snapshot or COW state stops the run before the flash
where applicable.

## Decision after the run

```text
N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED
```

means the booting C3A compatibility baseline tolerates the five-app Sable
product delta. That becomes the Titan 2 SableOS engineering foundation.

```text
N1F_BOOT_RESULT=FAIL_FASTBOOT_RETURNED
```

means one or more of the five-app/product-composition deltas is implicated.
Do not return to broad N1B reconstruction. Isolate the five-app delta directly.

```text
N1F_BOOT_RESULT=MANUAL_UI_CHECK_REQUIRED
```

means fastboot did not return but ADB was insufficient to prove completion;
inspect the device UI before taking another action.

Factory reset remains a separate decision and is not part of this experiment.
