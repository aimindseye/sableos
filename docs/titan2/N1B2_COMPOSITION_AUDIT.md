# Titan2 N1B2 composition audit

```text
N1B2_COMPOSITION_AUDIT=YES
SCOPE=NO BUILD / NO DEVICE CONTACT / NO FLASH
DEVICE=titan2
RELEASE=N1B2
```

## Purpose

This audit is the stop point before any more Titan2 image building. It checks
whether the private `aimindseye/sableos` repository and the prepared Android
workspace actually compose the system implied by the public `platform_sable`
design docs.

It is intentionally different from a UX-readiness matrix. The UX matrix may say
`POLICY_PRESENT`; this audit asks whether code, product packages, target-files
markers, profile artifacts and device-adapter wiring exist.

## Safety boundary

```text
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
ADB_COMMANDS_RUN=NO
FASTBOOT_COMMANDS_RUN=NO
FLASH_AUTHORIZED=NO
FACTORY_RESET_AUTHORIZED=NO
PUBLIC_RELEASE=NO
PRODUCTION_SIGNING=NO
```

The audit must be run before a new N1B2 image-candidate build is accepted. It is
also the Panther-taint guard: Titan2/N1B2-specific code must not leak into common
app source or Panther build/test paths.

## Artifact classes under review

The audit is bound to the artifact classes described in `build/README.md`:

```text
target-files
full-device-images
gsi-system-image
system-product-bundle
boot-recovery-bundle
```

Current expectation:

```text
panther/R9 -> target-files, qualified/frozen reference
titan2/N1B2 -> gsi-system-image candidate only, still fail-closed until audited
```

## What the audit checks

### Canonical build and artifact interface

The audit checks that the repository still exposes the simple operator contract:

```text
bash build/sable.sh <device> <release> <function> [options]
```

and that the artifact class vocabulary remains visible in `build/README.md` and
`build/sable.sh`.

### Device adapters

The audit checks Panther and Titan2 adapters separately:

```text
PANTHER_ADAPTER_PRESENT
PANTHER_TARGET_FILES_ONLY
PANTHER_BUILD_SUPPORTED
TITAN2_ADAPTER_PRESENT
TITAN2_GSI_ARTIFACT_KIND
TITAN2_CANONICAL_BUILD_SUPPORTED
TITAN2_N1B2_RELEASE_GATE
```

A likely current failure is `TITAN2_N1B2_RELEASE_GATE`: the Titan2 adapter may
still allow only earlier N-series labels and may not explicitly register N1B2.
That is a build-process gap, not a reason to flash or build anyway.

### Private app/source composition

The audit checks current Gradle app scope under `apps/r8/android` and records
which expected common product surfaces are absent from the current app graph:

```text
design
calculator
games
media
hub
weather
calendar
mail
messages
people
reader
textreader
browser
settings
systemui
phone
contacts
```

Absence here is not automatically fatal for Panther R9, because Panther R9 is a
frozen accepted reference. It is fatal to any claim that N1B2 is a complete
Titan2 UX testbed image.

### Android workspace/product composition

The audit checks the prepared Android source tree, not only the private repo:

```text
vendor/sable/n1b2/sable_n1b2_product_profile.mk
vendor/sable/n1b2/product-closure.env
vendor/sable/n1b2/ux-testbed-readiness.env
vendor/sable/n1b2/profiles/titan2/*.env
packages/apps/SableStart/Android.bp
packages/apps/SableStart/AndroidManifest.xml
packages/apps/SableDesign/Android.bp
```

It then verifies that SableLauncher is present, selected, and marked as HOME,
while Quickstep remains Recents-only.

### Design-driven product surfaces

The audit does not treat policy docs as runtime proof. It probes for Soong/Make
modules and product-profile selection for these expected system-image surfaces:

```text
SableHub
SableMail
SableCalendar
SableWeather
SableMedia
SableMessages
SablePeople
SableReader
SableTextReader
SableCommand
SableSettings
SablePhone
SableContacts
```

Rows may report `NOT_PROVEN`. That is intentional. `NOT_PROVEN` means do not
make image-readiness, UX-readiness, or daily-driver claims from that surface yet.

### Panther taint

The Panther taint check greps common app/shared source and Panther build/test
paths for Titan2/N1B/N1B2-specific tokens. If it finds any, the audit fails by
default.

If Panther taint is found, the decision options are:

```text
1. move Titan2-specific logic behind device/profile adapters;
2. revert or isolate the tainted common change;
3. create a fork/branch/repo split only if common-code isolation is not practical.
```

A fork is a fallback, not the default product architecture. The default remains
one SableOS common core plus device profiles/adapters.

## Command

```bash
cd /srv/data/sable-build/sableos/repo

git fetch origin main
git switch main
git merge --ff-only origin/main

bash build/gates/n1b2-composition-audit-contract.sh

bash build/titan2/audit-n1b2-composition.sh \
  --android-root /srv/data/sable-build/workspaces/titan2-n0b-restless-native-android16-r7-seeded-public-skip-goodix-20260927_174816/treble_restlessos/src \
  --active-product-mk device/phh/treble/treble_arm64_bvN.mk \
  --platform-sable-root /srv/data/sable-build/platform_sable
```

If `platform_sable` is not checked out locally, omit `--platform-sable-root`.
The audit will record that docs were not checked locally, but it will still check
private repo and Android workspace composition.

## Decision rule after running

```text
N1B2_COMPOSITION_AUDIT=PASS
  -> proceed to fix remaining NOT_PROVEN rows or explicitly bound them before image build.

N1B2_COMPOSITION_AUDIT=PASS_WITH_WARNINGS
  -> do not image-build unless every warning is explained and bounded.

N1B2_COMPOSITION_AUDIT=FAIL
  -> no image build. Fix composition, adapter, or Panther-taint failures first.
```

Expected current outcome before the next implementation pass is likely `FAIL`,
because the purpose of this pass is to identify the actual missing composition
rather than stamp another readiness marker.
