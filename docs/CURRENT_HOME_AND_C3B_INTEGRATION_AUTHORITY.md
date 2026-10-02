# Current HOME and Titan 2 C3B product-integration authority

Status: **current architecture authority**

Date: 2026-10-02

This document resolves conflicting historical SableOS launcher/product notes and
defines the source-of-truth boundary for Titan 2 N1D/C3B product integration.

When an older R8/R9 document, gate description, PR body or design note conflicts
with this file and the current source tree, this file plus the current source
tree wins.

## HOME ownership

The R9L8 cutover is authoritative:

```text
HOME_RUNTIME=packages/apps/Launcher3/Launcher3QuickStep
SABLESTART_ROLE=PRESENTATION_AND_STATE_SOURCE_HOSTED_IN_LAUNCHER3
STANDALONE_SABLELAUNCHER_RUNTIME=RETIRED
HOME_AUTHORITY_SCOPE=SABLE_FIRST_PARTY_CANONICAL
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
FORCE_SABLE_HOME_AFTER_USER_SELECTION=NO
```

Canonical source evidence:

```text
src/android/packages/apps/SableStart/PORTABILITY_STATUS.md
src/android/packages/apps/SableStart/Android.bp
apps/r8/android/sablestart-visual-review/
docs/BUILD_LAYOUT.md
```

The SableStart source directory no longer defines a standalone HOME application.
Reusable Sable presentation/state source is compiled into Launcher3/Quickstep.

This authority defines Sable's first-party HOME ownership, not a prohibition on
Android user choice. A user-installed launcher may be selected as the default
HOME through the normal Android role/default-app model. SableOS does not force
Sable Start back after an explicit user selection. Third-party launchers do not
automatically receive privileged Quickstep/SystemUI or Private Space integration.

Historical files that describe `org.sableos.launcher` / `SableLauncher` as
the current HOME architecture document an earlier R9 phase and must not be used
as authority for Titan 2 C3B work.

## Titan 2 N1D/C3B product authority

The R9L8 HOME decision is final, but the Android product identity has two
different phases that must not be conflated.

C3A used the generated control product:

```text
C3A_PRODUCT=treble_arm64_bvN
C3A_VARIANT=user
```

The earlier handcrafted `sable_titan2_n1d_arm64` implementation was retired
after live compilation proved that its direct
`generic_system_arm64 + gsi_release` graph was incompatible with the pinned
GrapheneOS source set.

C3B E1 uses a separate clean Graphene workspace, adds five pinned Treble
build-scaffold projects, applies 14 exact security/control reductions to the
pinned PHH `base.mk`, and keeps a generated engineering identity:

```text
RELEASE_TRACK=N1D
C3B_E1_PRODUCT=treble_arm64_bvN
C3B_E1_RELEASE_CONFIG=bp4a
C3B_E1_VARIANT=userdebug
C3B_E1_GOAL=systemimage
C3B_E1_PRODUCT_IDENTITY_STATUS=ENGINEERING_GENERATED_TREBLEDROID_PENDING_E2
```

C3B E2 owns the final Sable product identity, source-module admission and
partition/product inheritance model. Parallel product work must not create a
second `vendor/sable/titan2` authority or revive the retired handcrafted
product path.

Canonical source:

```text
build/titan2/n1d-c3b-transition.env
build/titan2/n1d-c3b-scaffold-add.xml
build/titan2/n1d-c3b-scaffold-decisions.tsv
build/titan2/apply-n1d-c3b-phh-base-hardening.py
build/titan2/n1d-c3b-engineering.mk
build/titan2/n1d-product-contract.env
docs/titan2/N1D_C3_PRODUCT_COMPOSITION_R1.md
docs/titan2/N1D_C3B_TRANSITION_R1.md
```

## Parallel product-development lane

`aimindseye/titan2-temp` is a parallel product-source lane, not a second
Android base.

It may provide:

- Sable-owned Android/Kotlin product modules;
- keyboard-first behavior;
- UI/product composition fragments;
- diagnostics UI;
- tests and qualification scripts;
- design/visual traceability;
- explicit platform-interface requests.

It must not independently own:

- the Android/Graphene/Treble base;
- HOME runtime ownership;
- radio/IMS/QNS/IWLAN fixes;
- SELinux relaxations;
- vendor/RIL/modem recovery behavior;
- product assurance values;
- release signing;
- production signing keys;
- repository-stored presigned product APKs.

Accepted product source is integrated into the canonical SableOS tree through a
reviewed C3B staging/integration path before canonical CI or image build.

## Development signing

For C3B source/application qualification:

```text
PRODUCTION_SIGNING_AUTHORIZED=NO
CHECKED_IN_PRIVATE_KEY=NO
CHECKED_IN_PRESIGNED_PRODUCT_APK=NO
STANDALONE_RELEASE_APK=UNSIGNED_ALLOWED
DEVELOPER_LOCAL_DEBUG_SIGNING=ALLOWED_NONCANONICAL
USERDEBUG_DEVELOPMENT_CERTIFICATES=CANONICAL_ANDROID_BUILD_OWNED
```

Any request for platform signing, shared UID or privileged permission is an
explicit security/interface decision owned by the canonical integration lane.

## Messages

The intended Sable product surface is the canonical Sable Messages source:

```text
apps/r8/android/messages/
```

Stock/AOSP Messaging may remain a temporary early radio-bring-up fallback but
must not silently become the integrated C3B product decision.

## CI/operator boundary

Canonical qualification is operator-owned on the controlled build host.

The authoritative command for Titan 2 C3B source integration is:

```bash
bash build/sable.sh titan2 N1D ci full
```

Parallel developers provide validated source, tests, dependency declarations,
PR-specific checkout/setup/build commands and fixes. They do not claim canonical
CI PASS.

An exact PR HEAD must be bound to operator evidence. Any later PR push invalidates
the prior PASS.

## Public design source

`sableos-project/platform_sable` remains the public source for reusable
architecture/design/capability contracts and visual-confirmation artifacts.

Its Sable Start design documents define product behavior and presentation, not a
separate Android HOME process. Runtime ownership is decided by the canonical
SableOS integration architecture above.

## Historical-document rule

Historical R8/R9/N0 evidence should normally be preserved rather than rewritten
to pretend that later architecture was always in effect.

However, documents advertised as current/normative must point here or be updated
when their current statements conflict with the R9L8/C3B authority.

Current priority for new Titan 2 work:

```text
CURRENT_HOME_AUTHORITY=LAUNCHER3_HOSTED_SABLE_START
CURRENT_HOME_AUTHORITY_SCOPE=SABLE_FIRST_PARTY_CANONICAL
THIRD_PARTY_HOME_SELECTION_ALLOWED=YES
CURRENT_TITAN2_PRODUCT_AUTHORITY=N1D_C3B
PARALLEL_PRODUCT_REPO=aimindseye/titan2-temp
PUBLIC_DESIGN_REPO=sableos-project/platform_sable
```
