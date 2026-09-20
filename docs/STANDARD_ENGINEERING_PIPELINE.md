# SableOS standard engineering pipeline

Status: **active infrastructure contract**

Issue: `#76 INFRA: standardize multi-device CI/build/deploy/acceptance entry point`

## Goal

SableOS uses one operator-facing entry point for CI, release builds, artifact registration, flash-plan validation, device flashing and post-build/device acceptance:

```bash
bash build/sable.sh <device> <release> <function> [options]
```

The device and release select bounded adapters and evidence paths. They do not create new per-release or per-device top-level scripts.

Current adapters:

```text
panther       Pixel 7; build + preserved-data development flash qualified
titan2        fail-closed placeholder until physical mutation is qualified
titan2-elite  fail-closed placeholder until physical mutation is qualified
q27           fail-closed placeholder until physical mutation is qualified
```

Q25 is not an active SableOS target and has no device adapter.

## Canonical functions

```bash
bash build/sable.sh panther R9 ci core
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 ci release
bash build/sable.sh panther R9 build --tmux
bash build/sable.sh panther R9 register-artifact ...
bash build/sable.sh panther R9 show-artifact ...
bash build/sable.sh panther R9 flash-plan --build-source <sha>
bash build/sable.sh panther R9 flash --build-source <sha> --serial <serial> --preserve-data --authorize
bash build/sable.sh panther R9 accept --serial <serial> --suite launcher
```

## Build-source identity versus tooling identity

The source commit which produced target-files is independent from a later commit containing deployment tooling. Every deployment records:

```text
TOOL_SOURCE_COMMIT=
BUILD_SOURCE_COMMIT=
TARGET_FILES_SHA256=
```

This is deliberate. A proven build stays bound to the exact source that produced it even when later host-side tooling improves. Deployment tooling must never claim that its own HEAD built an older artifact.

## Artifact registry

Successful build artifacts are registered outside Git in:

```text
/srv/data/sable-build/release-registry/<device>/<release>/<build-source>.json
```

A record binds device, release, build-source commit, target-files path and SHA-256, android-info path and SHA-256, OUT_DIR when available, build evidence directory and registration time. Mutation commands require an exact build-source identity; they do not choose a loosely defined latest artifact.

Qualified Panther release builds started through `build/sable.sh ... build` automatically register their exact successful artifact. The manual `register-artifact` function exists for builds created before this contract (including the current R9 artifact) and for bounded recovery/import cases.

## Historical deployment lessons promoted to permanent gates

### One image source

Panther deployment previously exposed a product-out versus target-files image mismatch. Current deployment stages all flash image bytes solely from `<target-files.zip>!IMAGES/`. Product-out images are never mixed into the flash payload. `android-info.txt` is the only product-out metadata currently permitted and is separately SHA-bound.

### Parse packaged fastboot policy before mutation

`META/fastboot-info.txt` is the packaged flash task definition. The parser rejects unconditional erase, direct userdata/metadata flashing, `--slot-other`, unknown commands, unknown flash options and missing required `IMAGES/` members. Conditional `if-wipe erase userdata` / `metadata` directives are allowed, but preserved-data deployment never supplies `-w`.

### Fastboot enumeration is not readiness

Panther D4 demonstrated that `fastboot devices` can enumerate a device before read-only `getvar` requests are ready. The reusable readiness predicate is: requested serial present, successful `fastboot getvar product`, and product equals the selected device adapter. No write begins merely because `fastboot devices` prints a row.

### Child-process stdin is isolated

The historical R10R3 ART loop allowed an `adb` child to consume the parent's TSV stdin and only one of five expected ART files was checked. Current `sablectl` uses `stdin=DEVNULL`; standard shell deployment also redirects adb/fastboot stdin from `/dev/null`.

### Preserved data is a first-class gate

Before mutation, `sablectl baseline capture` records the user/package baseline. The bootloader must already be unlocked, CE data must be available, no unlock/lock operation is allowed, no wipe flag is allowed, userdata/metadata writes are forbidden, the current slot is captured and reasserted rather than switched, and inactive-slot flashing is forbidden in this development flow.

After boot, `sablectl smoke` revalidates exact packaged BuildManifest/ART identity, expected device/slot, boot completion, SELinux/core services, third-party package set, Android user count and CE-data availability.

### Bootloader/baseband requirements

Before writes, deployment reads the registered `android-info.txt` and verifies live fastboot bootloader/baseband requirements when declared. Required partitions declared by `partition-exists=` must be observable.

### Bounded failure and GitHub issue policy

Once `fastboot flashall` starts, a nonzero result suppresses automatic reboot and emits `SABLE_BLOCKER_ISSUE_REQUIRED=YES`. Evidence is preserved; do not reflexively retry with a changed procedure. A pre-write failure may use the already-authorized reboot back to Android.

A new blocking CI/build/artifact/deployment/physical-acceptance failure must be recorded as a GitHub issue before a materially different retry procedure is adopted. Record device, release, tool source, build source, artifact SHA-256, failing marker, evidence directory/seal, whether mutation began, recovery state and the proposed durable gate/fix.

## Current Panther R9 registration

```text
BUILD_SOURCE_COMMIT=20f6ed40b78e205b39bf2d657eaad29432a0016a
TARGET_FILES_SHA256=7a9b81c6f9f37c783bcf6d7bb8760a7bcf918dc56a1fc89bb6babc1d6e402e71
BUILD_EVIDENCE_DIR=/srv/data/sable-build/evidence/panther/r8-final-ui/20260920_154844
```

Register it once:

```bash
bash build/sable.sh panther R9 register-artifact \
  --build-source 20f6ed40b78e205b39bf2d657eaad29432a0016a \
  --target-files /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300/out_sable_r9_full_20f6ed40b78e/target/product/panther/obj/PACKAGING/target_files_intermediates/panther-target_files.zip \
  --sha256 7a9b81c6f9f37c783bcf6d7bb8760a7bcf918dc56a1fc89bb6babc1d6e402e71 \
  --android-info /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300/out_sable_r9_full_20f6ed40b78e/target/product/panther/android-info.txt \
  --out-dir /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300/out_sable_r9_full_20f6ed40b78e \
  --build-evidence-dir /srv/data/sable-build/evidence/panther/r8-final-ui/20260920_154844
```

Then flash through the same entry point:

```bash
bash build/sable.sh panther R9 flash \
  --build-source 20f6ed40b78e205b39bf2d657eaad29432a0016a \
  --serial <PIXEL_7_SERIAL> \
  --preserve-data \
  --authorize
```

No `-w`, bootloader unlock, slot switch or inactive-slot flash is performed.

After the post-flash smoke PASS:

```bash
bash build/sable.sh panther R9 accept --serial <PIXEL_7_SERIAL> --suite launcher
```

## Historical scripts

`tools/validation/**` remains a byte-preserved evidence/history surface. Historical scripts explain why contracts exist but are not normal operator entry points for new releases. Durable lessons must be absorbed into the standard pipeline before old scripts are retired from active use.
