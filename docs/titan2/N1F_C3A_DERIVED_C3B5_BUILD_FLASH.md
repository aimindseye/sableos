# Titan 2 N1F — C3A-derived C3B5 combined build and flash

Status: **next operator execution**

Date: **2026-10-03**

C3A is physically boot-qualified on Titan 2 V01.00.14:

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

The radio transient is tracked separately. An airplane-mode cycle restored
310260 HOME LTE registration with NR availability / EN-DC availability and
NR_NSA display state.

N1F keeps the exact booting C3A compatibility substrate and changes only the
five already-admitted Sable product apps:

```text
SableTitan2Keyboard
SableTitan2Camera
SableTitan2DisplayCompat
SableTitan2Setup
SableTitan2RadioDiag
```

There is no compatibility-patch delta.

## Single operator runner

```text
build/titan2/run-n1f-c3a-derived-c3b5.sh
```

The runner first preserves the exact C3A system image and evidence, then builds
the five APKs offline, stages only Android.bp + apps.mk + five APKs, adds one
inherit line to C3A rom.mk, incrementally rebuilds systemimage, verifies all
five signed APKs in system/product/app, preserves the derived image, restores
the C3A source tree, then flashes system_a once and observes one reboot.

The C3A history is a checksummed artifact directory with a reflinked/sparse
system.img, pinned repo manifest and sealed evidence rather than another
compressed 3+ GB copy.

Not authorized or performed: factory reset, COW deletion, slot switch,
vbmeta/boot/vendor_boot write, whole-super write, automatic flash retry,
target-files build, OTA build or production signing.

## Operator command

```bash
cd /srv/sable-build/sableos/repo

bash build/titan2/run-n1f-c3a-derived-c3b5.sh selfcheck

bash build/titan2/run-n1f-c3a-derived-c3b5.sh run \
  --authorize-build \
  --authorize-flash
```

Success markers:

```text
C3A_HISTORY=PASS
N1F_SOURCE_DELTA=PASS_7_FILES_PLUS_1_INHERIT
N1F_BUILD=PASS ...
N1F_ARTIFACT=PASS ...
N1F_SOURCE_RESTORE=PASS
N1F_PREFLASH=PASS ...
N1F_SYSTEM_A_FLASH=PASS
N1F_REBOOT=PASS_ONCE
N1F_RUNTIME_PACKAGES=PASS count=5
N1F_BOOT_RESULT=PASS_ANDROID_BOOT_COMPLETED
N1F_COMBINED=PASS
```

If fastboot returns, stop. If Android visibly boots but ADB cannot prove
sys.boot_completed, report the manual-UI result; do not reset or reflash.
