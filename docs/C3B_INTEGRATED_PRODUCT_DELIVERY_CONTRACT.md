# C3B integrated-product lane delivery contract

Status: **canonical E2 source admitted; thin-wrapper product composition defined, build/runtime qualification pending**

Date: 2026-10-01

Audience: developer working in `aimindseye/titan2-temp`, and the SableOS
maintainer integrating that work into the canonical Titan 2 C3B image.

## Purpose

This document defines exactly what the `titan2-temp` parallel-development lane
should deliver, when it should deliver it, what it must not change, and how its
work will be integrated into the canonical SableOS Titan 2 C3B workflow.

The goal is to let product/UI/device-application work proceed in parallel with
the lower-level C3B engineering image without creating a second Android base,
second telephony architecture, or second security policy.

The two lanes have different responsibilities:

```text
CANONICAL C3B ENGINEERING LANE
    Graphene/AOSP/Treble source graph
    build system
    system/vendor compatibility
    SELinux / privileged services
    telephony / radio / IMS / QNS / IWLAN
    evidence-driven compatibility patch admission
    image build
    physical runtime qualification

PARALLEL C3B INTEGRATED-PRODUCT LANE (this repo)
    Sable product apps and user-facing modules
    keyboard-first UX
    device capability/profile consumers
    UI/product composition
    buildable application modules
    UX / VC / artifact traceability
    product-specific gates
    explicit platform-interface requests
    handoff package ready for canonical C3B integration
```

The parallel lane may prepare an integrated-product **source candidate**.
It must not claim that it has produced the canonical integrated C3B product
candidate until its source has been composed on top of the canonical C3B base,
built there, and passed the required runtime gates.

## Current source snapshots

At the time this contract was written:

```text
titan2-temp main
  bb3b59d6de7c4460141a7f8c3d22eaa49c3eb9d4

titan2-temp eleven-surface composition commit
  fd90307877aaa395bfee882e6e9f3abe32b1c5ae

platform_sable design/document source
  de9d4362f6779ddd0108fbd5804ebb25bdf4dc4c
```

These are reference points, not permanent pins. Every future handoff must record
the exact `titan2-temp` source head and exact `platform_sable` head used.


## Resolved decisions from the 2026-10-01 developer review

These decisions supersede earlier ambiguous wording in this contract.

### HOME

```text
C3B_HOME_OWNER=Launcher3QuickStep
C3B_STANDALONE_HOME_APP=RETIRED
C3B_TITAN2_TEMP_HOME_MODULE=REMOVE_FROM_PRODUCT_COMPOSITION
```

The R9L8 cutover made `packages/apps/Launcher3` / `Launcher3QuickStep` the
sole **Sable-owned canonical first-party HOME**. The remaining SableStart source
is presentation/state source compiled into Launcher3. This does not revoke
Android's user-selectable HOME model: an installed third-party launcher may be
selected by the user as the default HOME. SableOS must not force Sable Start
back after an explicit user choice.

Canonical evidence:

```text
aimindseye/sableos
src/android/packages/apps/SableStart/PORTABILITY_STATUS.md
docs/BUILD_LAYOUT.md
```

Some older SableOS architecture/R9 documents still describe standalone
`SableLauncher` ownership. Those are stale relative to the R9L8 cutover and
must be reconciled by the canonical lane; they are not authority for new C3B
work.

The `titan2-temp/home` application must therefore stop advertising HOME and
must not be included as a product HOME candidate. Reusable pure type-to-find /
filtering logic and tests may be preserved and proposed for Launcher3-hosted
Sable Start, but no second HOME activity/process is admitted.

### User-selectable HOME and IME policy

The first-party owner and the user's selected default are distinct concepts.

~~~text
SABLE_FIRST_PARTY_HOME_OWNER=Launcher3QuickStep
SABLE_FACTORY_DEFAULT_HOME=SableStart
USER_SELECTABLE_THIRD_PARTY_HOME=YES
FORCE_SABLE_HOME_AFTER_USER_SELECTION=NO

SABLE_FIRST_PARTY_IME=SableKeyboard
SABLE_FACTORY_DEFAULT_IME=SableKeyboard_PENDING_IR005
USER_SELECTABLE_THIRD_PARTY_IME=YES
FORCE_SABLE_IME_AFTER_USER_SELECTION=NO
~~~

The canonical lane must preserve Android's normal role/input-method selection
surfaces. Third-party launchers and IMEs do not automatically inherit Sable's
privileged/system integration or release qualification.

For HOME, Sable Start/Launcher3QuickStep remains the fully-supported Quickstep,
Recents and Private-Space-capable first-party implementation. A third-party
launcher that does not implement the relevant Android hidden-profile/private
space contract may provide reduced integration; SableOS must not weaken Private
Space to compensate.

For IME, Sable Keyboard remains the known first-party direct-boot/critical-entry
path. A third-party IME may be installed, enabled and selected by the user, but
Sable cannot claim that IME satisfies Sable's pre-unlock/Titan physical-keyboard
acceptance unless it independently proves those capabilities.

### Camera Control Deck and Pastiera 0.86 roadmap additions

The 2026-10-02 product review adds two accepted roadmap inputs:

~~~text
docs/SABLE_CAMERA_CONTROL_DECK.md
docs/PASTIERA_086_REFERENCE_INTAKE.md
~~~

Camera direction:

- Sable-owned Camera2 source is the keyboard-device product direction;
- portrait stays supported;
- landscape gains a viewfinder-first physical-keyboard Camera Control Deck;
- physical controls cover shutter, focus, exposure, Pro parameters, zoom and
  mode navigation;
- AF/AE lock and keyboard focus-point movement are roadmap requirements;
- parameter UI should be transient rather than permanent viewfinder chrome;
- touch remains a complete fallback;
- the app must not globally force landscape.

Pastiera 0.86 direction:

- reviewed release is v0.86 / commit
  `e7d8f27ecc7253e61690b5d34f110b25dc68bb16`, GPL-3.0;
- Sable Keyboard remains independently Sable-owned;
- no Pastiera/Plektra source import is authorized;
- D6 backlog adopts behavior-level ideas: compact input strip, configurable
  SYM/emoji/snippets, local dictionary improvements and better settings/deep
  links;
- QuickLauncher/global command ownership stays with Launcher3-hosted Sable
  Start/platform semantics, not the IME;
- Shizuku-dependent input and persistent clipboard history by default are not
  adopted.

These D6 items are non-blocking and must not delay D2 quality work, D3
critical-text-entry hardening, D5 icons or canonical C3B bring-up.

### Product model

```text
C3B_PRODUCT_NAME=sable_titan2
C3B_BASE_PRODUCT=device/phh/treble/treble_arm64_bvN.mk
C3B_STAGE_TARGET=vendor/sable/titan2
C3B_PRODUCT_WRAPPER=THIN_INHERIT_PROVEN_E1_GENERATED_PRODUCT
C3B_PRODUCT_SOURCE_MODEL=SOURCE_OWNED
C3B_GENERATED_APK_MODEL=UNSIGNED_SOURCE_BUILD_THEN_ANDROID_DEFAULT_DEV_CERT
C3B_REPOSITORY_PRESIGNED_APKS=FORBIDDEN
C3B_PRODUCT_ASSURANCE_PROPERTIES_OWNER=CANONICAL_C3B
```

During parallel development, `vendor/sable/titan2` was forbidden as a second
product authority. Canonical E2 now owns that Android-workspace staging path and
uses it only as a thin wrapper over the proven generated E1 Treble product.
The parallel lane remains source/test/interface input only and does not define
release/product-assurance properties or ship repository-stored presigned APKs.

The canonical lane decides the exact Soong/generated-artifact packaging
mechanism after source qualification. In every case the source is authoritative
and any packaged APK is generated from the accepted source; a checked-in
presigned binary is not the product model.

### Development signing

```text
C3B_PRODUCT_PRIVATE_SIGNING_KEYS_IN_TITAN2_TEMP=FORBIDDEN
C3B_PRODUCT_PRESIGNED_APKS=FORBIDDEN
C3B_PRODUCTION_SIGNING_AUTHORIZED=NO
C3B_USERDEBUG_DEVELOPMENT_KEYS=CANONICAL_BUILD_OWNED
```

The parallel repository must not require or contain a "Sable key".

For standalone source qualification:

- an unsigned release APK is acceptable;
- normal Android debug signing may be used only for developer-local/debug APK
  execution when needed;
- no debug/private keystore is committed;
- no signature result is a production-security claim.

For the canonical C3B `userdebug` image, development/test signing is owned by
the Android/SableOS build system. A module requiring platform/shared-UID
signature treatment must declare that requirement; the canonical lane decides
whether it is justified and which development certificate applies.

Production signing remains separately gated and unauthorized.

### Local stray sableos branch

The unpushed local branch:

```text
titan2/sablescreens-n0
commit 2342134
```

is superseded by this parallel-lane contract and should be deleted locally.
It must not be pushed as a review branch.


After confirming that branch is not checked out:

```bash
git branch -D titan2/sablescreens-n0
```

No GitHub deletion is needed because the branch was never pushed.


---

# 1. Project background

## 1.1 Why C3A existed

The earlier Titan 2 Android 16 work became blocked by uncertainty in the source
and product graph while cellular debugging was also incomplete.

C3A was created as a **known build-control**:

- sealed GrapheneOS Android 16 base;
- exact public Restless/TrebleDroid functional source topology;
- 991 managed projects;
- 369 Restless control patches;
- pinned TrebleDroid/PHH companion projects;
- generated Treble product;
- one `make systemimage`;
- no device contact;
- no flash;
- no release packaging;
- no production signing.

C3A answered one narrow question:

> Can we reproduce the public functional Android 16 Restless/TrebleDroid build
> topology successfully?

The answer is **yes**.

The canonical build completed on 2026-10-01:

```text
N1D_C3A_CONTROL_EVIDENCE=PASS
N1D_C3A_TREBLEDROID_SYSTEMIMAGE=PASS

SYSTEM_SHA256=
4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16

SYSTEM_BYTES=3146977280
N1D_C3A_POSTBUILD_PACKAGING_ARTIFACTS=PASS_ABSENT
N1D_C3_RELEASE_ELIGIBLE=NO
```

C3A is **not** the SableOS product baseline and will not be flashed as the
development target. The full Restless/PHH runtime stack was useful as a control,
not as SableOS security policy.

## 1.2 What C3B is

C3B is the actual SableOS Titan 2 Android 16 baseline.

Its starting rule is:

```text
C3B minimal Graphene/AOSP + pinned Treble build scaffold
Restless runtime patch allowlist initial count = 0
```

Compatibility changes enter C3B only after evidence:

```text
REPRODUCE FAILURE
    -> IDENTIFY CAUSE
    -> REVIEW SMALLEST COMPATIBILITY CHANGE
    -> ADMIT EXPLICITLY
    -> REBUILD
    -> COLLECT RUNTIME EVIDENCE
```

C3B therefore does **not** inherit all 369 Restless patches simply because C3A
built successfully.

## 1.3 C3B cellular / MediaTek direction

The canonical C3B lane owns radio and IMS integration.

Current rules include:

```text
AOSP phone stack = source-built
stock telephony APK import = NO by default
stock MTK framework JAR/SO import = NO by default
full stock vendor copy into system = NO
stock vendor/kernel/firmware compatibility = PRESERVE
PHH MTK IMS default = disabled until compatible behavior is proven
APN-only explanation = insufficient without evidence
LTE-only workaround = insufficient without evidence
```

The C3B radio investigation includes:

- MediaTek indication handling;
- IMS service compatibility;
- QNS / IWLAN behavior;
- incoming-call behavior;
- dual-SIM / SIM-switch behavior;
- carrier configuration;
- eSIM where supported;
- VoLTE / IMS registration;
- possible framework/API compatibility shims;
- a bounded healing mechanism **only if runtime evidence proves it is needed**.

Reference work from AtlasOS and other GSI projects shows that Titan 2-class MTK
systems may need partial OEM IMS compatibility and state-aware recovery.
However, the canonical C3B lane decides whether such changes are admitted.

The parallel product lane must not independently add:

- MTK IMS framework patches;
- proprietary IMS APK/JAR/SO payloads;
- RIL restart loops;
- radio property mutation scripts;
- CarrierConfig/APN fixes;
- SELinux relaxations;
- modem restart logic;
- healing scripts;
- Restless patches.

If a product module discovers that it needs a platform or telephony capability,
it must declare that requirement as an interface request instead of implementing
a private workaround.

---

# 2. Role of titan2-temp

## 2.1 What this repository is for

`titan2-temp` is the parallel **integrated-product source lane**.

Its job is to make the user-facing SableOS product implementation ready to
consume the canonical C3B base as soon as that base becomes available.

Useful work already present includes:

- SableScreens design catalog;
- Sable Home;
- Sable Setup helper;
- Sable Keyboard;
- Sable Camera;
- Display Compatibility;
- read-only Radio Diagnostics;
- Titan 2 / Titan 2 Elite profile separation;
- product composition files;
- APK staging;
- static source audit;
- image-composition audit;
- UX/design artifact references.

This work should continue.

## 2.2 What this repository is not

This repository must not become:

- a second C3B Android source tree;
- a second Treble/Graphene product baseline;
- an independent radio compatibility branch;
- a place to import Restless patches;
- a place to carry proprietary stock telephony payloads;
- a place to weaken SELinux or Android permission policy;
- a flash-authorized lane;
- a release-signing lane.

## 2.3 Terminology

Until canonical integration occurs, use:

```text
C3B_INTEGRATED_PRODUCT_SOURCE_CANDIDATE
```

Do **not** use:

```text
C3B_INTEGRATED_PRODUCT_CANDIDATE=PASS
```

A real integrated C3B product candidate exists only after the source candidate
is composed onto the canonical C3B Android base and the canonical image build
passes.

---

# 3. Review of the current eleven-surface composition

The current composition is a useful engineering starting point, but its
individual surfaces have different maturity.

## 3.1 Product identity / profile

Current state:

- per-device profile files exist;
- Titan 2 and Titan 2 Elite remain independent;
- `ro.sable.profile.validated=false` is correctly retained.

Direction:

- keep profile separation;
- never infer Titan 2 Elite PASS from Titan 2 evidence;
- never use profile properties as a security boundary;
- canonical C3B will supply the final product-assurance value.

## 3.2 HOME / Launcher3-hosted Sable Start

Current state:

- `titan2-temp/home` is a standalone HOME candidate;
- it contains useful type-to-find/filtering behavior;
- its runtime ownership conflicts with the R9L8 canonical HOME architecture.

Direction:

- remove `home` from product composition;
- retire its HOME manifest/activity role;
- do not request default-HOME provisioning for this module;
- preserve only reusable pure type-to-find/filter/search logic and tests if they
  add value;
- express the required keyboard-first behavior as a Launcher3/SableStart
  platform-interface request;
- canonical production implementation belongs in the Launcher3-hosted Sable
  Start presentation/runtime path.

The first C3B engineering image may use the current canonical Launcher3-hosted
Sable presentation and later consume the accepted keyboard-first logic. A
second launcher process is not admitted.

## 3.3 Sable Setup

Current state:

- first-run helper/checklist;
- not Android Setup Wizard.

Direction:

- keep this distinction explicit;
- Sable Setup may remain a post-provisioning readiness/configuration helper;
- it must not be counted as completion of the real Setup Wizard surface;
- the canonical C3B integrated product eventually needs the planned first-boot
  Setup Wizard UX or an explicitly approved bounded substitute.

## 3.4 SystemUI / lockscreen

Current state:

- stock AOSP SystemUI / lockscreen is named in composition;
- SableScreens contains UI prototypes.

Direction:

- stock AOSP is acceptable for the first minimal C3B engineering image;
- a SableScreens mock is not a SystemUI/Keyguard implementation;
- integrated-product completion requires either:
  - production changes in the real SystemUI/Keyguard path, or
  - an explicit project decision that stock AOSP remains the intended product
    behavior for that release.

Do not package a standalone mock and count it as SystemUI completion.

## 3.5 Settings / network / SIM

Current state:

- stock AOSP Settings / TelephonyProvider / CarrierConfig;
- Sable Setup links to system settings;
- SableScreens has a Settings prototype.

Direction:

- stock Settings is acceptable for the first engineering image;
- integrated-product completion should implement the planned Sable
  Settings/Search/Mobile Manager UX where the platform supports it;
- enforcement belongs in canonical platform code, not in fake UI controls.

## 3.6 Phone / Telecom

Current state:

- stock AOSP Phone/Telecom surfaces are named.

Direction:

- this is correct for early C3B radio testing;
- do not replace telephony framework components in this lane;
- eventual Sable Phone UI work may proceed independently, but must consume the
  canonical Telecom/Telephony stack.

## 3.7 Contacts

Current state:

- stock Contacts.

Direction:

- acceptable for first engineering image;
- eventual Sable product UX may replace/skin it after build and provider
  behavior are proven.

## 3.8 Messages

Current state:

- current `titan2-temp` composition names stock AOSP Messaging/MmsService.

Important project history:

- the earlier N1B2 plan already treated Sable Messages as an implemented and
  validated baseline product surface.

Direction:

- stock Messaging is acceptable only for the minimal radio-focused engineering
  image when Sable Messages has not yet been integrated;
- PR 4 must reconcile against canonical
  `aimindseye/sableos/apps/r8/android/messages`;
- the integrated C3B product candidate must not silently regress to stock
  Messaging as the product decision.

## 3.9 Critical text entry / Sable Keyboard

Current state:

- substantial Sable-owned IME implementation;
- JVM-tested core;
- default-IME overlay exists;
- Android/device behavior is not yet proven.

Direction:

This module is worth continuing, but acceptance requires Android build and
runtime evidence.

The critical text-entry gates must eventually cover at least:

```text
Bluetooth pairing text entry
Alt entry in system dialog
Sym entry in system dialog
software keyboard fallback
Setup Wizard text entry
lockscreen text entry
Wi-Fi password text entry
account sign-in text entry
```

Feature expansion should now take lower priority than compiling, integrating and
proving these fundamental paths.


`directBootAware=true` alone is not sufficient. Any state required before first
unlock must use device-protected storage (for example via
`createDeviceProtectedStorageContext()`) or be derivable without
credential-protected state.

Alt/Sym behavior that depends on physical scan-code normalization or platform
key policy is not solely an IME responsibility. If the app cannot prove the
behavior through public IME APIs, PR 3 must create a platform-interface request
for the canonical EventHub/InputReader/Keyboard Policy path rather than adding a
device-private workaround.

## 3.10 Titan 2 keyboard / display profile

Current state:

- profile-driven behavior;
- captured Titan 2 Mini-mode size;
- DisplayCompat backend remains gated.

Direction:

- keep Mini Mode non-blocking/deferred for C3B unless the project reopens it;
- captured Mini-mode evidence may remain in the repository;
- do not let Mini Mode become required for the first C3B integrated candidate;
- per-app display compatibility must remain reversible and safely gated.

## 3.11 Radio / IMS diagnostics

Current state:

- unprivileged read-only app;
- `READ_PHONE_STATE` only;
- identifiers masked;
- separate adb capture script.

Direction:

The UI application is useful and should remain read-only.

The canonical radio/IMS evidence collector belongs to the C3B engineering lane.
Do not let this repository fork the radio-debug contract.

The existing script can remain as reference/test tooling, but before integration
it must either:

1. be reconciled with the canonical C3B capture implementation, or
2. be explicitly marked `REFERENCE_ONLY_NOT_CANONICAL_CAPTURE`.

No product diagnostic app may mutate radio, IMS, SIM, APN, network mode or
CarrierConfig state.

---

# 4. Concrete workspace topology

The parallel product lane and canonical C3B engineering lane must not share one
mutable checkout. The controlled build host should use three independent source
trees plus the existing Android workspace.

Canonical paths:

```text
CANONICAL_SABLEOS_REPO=
  /srv/sable-build/sableos/repo

PARALLEL_PRODUCT_REPO=
  /srv/sable-build/workspaces/titan2-c3b-product/titan2-temp

CANONICAL_C3B_ANDROID_ROOT=
  /srv/sable-build/workspaces/titan2-n1d/android

PRODUCT_CI_WORKTREE_ROOT=
  /srv/sable-build/workspaces/titan2-c3b-product-ci
```

Roles:

```text
/srv/sable-build/sableos/repo
    canonical SableOS engineering repository
    our active C3B base/radio/system work
    DO NOT copy titan2-temp into this checkout while parallel work is active

/srv/sable-build/workspaces/titan2-c3b-product/titan2-temp
    independent clone of aimindseye/titan2-temp
    other developer's product-source lane
    Android module builds + repository-local pre-handoff checks happen here

/srv/sable-build/workspaces/titan2-n1d/android
    canonical Android 16 source workspace used by C3B
    staged product/system integration target
    not the developer's application-authoring checkout

/srv/sable-build/workspaces/titan2-c3b-product-ci/<product-sha>
    separate git worktree of aimindseye/sableos
    created from the exact canonical C3B base SHA
    accepted titan2-temp source is ported here
    canonical SableOS local CI runs here
```

## 4.1 Clone the parallel product repository

On the controlled build host:

```bash
mkdir -p /srv/sable-build/workspaces/titan2-c3b-product

git clone git@github.com:aimindseye/titan2-temp.git \
  /srv/sable-build/workspaces/titan2-c3b-product/titan2-temp
```

If the clone already exists, update it normally with `git fetch` and the
developer's intended branch. Do not place it under
`/srv/sable-build/sableos/repo` and do not symlink its app directories into
the canonical repository.

The developer may use a different local path on a different workstation.
The path above is the **canonical build-host location** used for handoff and
qualification.

## 4.2 Repository-local pre-handoff qualification

While code exists only in `titan2-temp`, run its own build/test/audit entry
points there.

Example using the canonical host SDK/JDK/Gradle cache without moving
the product source into the canonical repository:

```bash
CANONICAL_REPO=/srv/sable-build/sableos/repo
PRODUCT_REPO=/srv/sable-build/workspaces/titan2-c3b-product/titan2-temp

# Reuse the qualified host toolchain, not the canonical app-source directory.
source "$CANONICAL_REPO/build/config/host-tools.env"

export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export JAVA_HOME="$SABLE_JDK17"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$PRODUCT_REPO"

test -z "$(git status --porcelain)" || {
    echo "C3B_PRODUCT_PREHANDOFF=FAIL_DIRTY_SOURCE"
    git status --short
    exit 1
}

(
    cd apps/titan2/platform
    ./gradlew \
      assembleRelease \
      test \
      lint \
      --stacktrace \
      --console=plain \
      --no-daemon
)

(
    cd apps/titan2/screens
    ./gradlew \
      assembleRelease \
      test \
      lint \
      --stacktrace \
      --console=plain \
      --no-daemon
)

bash build/titan2/audit-sablescreens-source.sh
bash build/titan2/audit-sable-image.sh

# Required by this contract once implemented:
bash build/titan2/qualify-c3b-product-source.sh
```

Do not add `clean` merely to qualify a source change. Normal Gradle
incrementality should be preserved unless a specific build failure proves that
cleaning an output is necessary and separately authorized.

If dependencies are not already present in the canonical Gradle cache, the
developer must record the required network/bootstrap step separately. A network
fetch is not evidence that canonical CI passed.

These checks are intentionally independent from
`/srv/sable-build/sableos/repo/apps/r8/android`.

Do **not** try to make the existing canonical
`build/local-ci/run.sh` discover modules directly from the separate
`titan2-temp` directory. Canonical CI is source-bound to one SableOS commit
and must continue to qualify source inside that exact repository tree.

## 4.3 Create an isolated canonical CI integration worktree

When a `titan2-temp` source head is ready for canonical integration, the
canonical C3B lane first publishes:

```text
C3B_BASE_SHA=<40-char commit in aimindseye/sableos>
C3B_RELEASE=N1D
```

Then create a new worktree without disturbing the active engineering checkout:

```bash
CANONICAL_REPO=/srv/sable-build/sableos/repo
PRODUCT_REPO=/srv/sable-build/workspaces/titan2-c3b-product/titan2-temp
CI_ROOT=/srv/sable-build/workspaces/titan2-c3b-product-ci

C3B_BASE_SHA=<published-c3b-base-sha>
PRODUCT_SHA="$(git -C "$PRODUCT_REPO" rev-parse HEAD)"
SHORT_PRODUCT_SHA="${PRODUCT_SHA:0:12}"
CI_TREE="$CI_ROOT/$SHORT_PRODUCT_SHA"
CI_BRANCH="c3b/product-ci-$SHORT_PRODUCT_SHA"

mkdir -p "$CI_ROOT"

git -C "$CANONICAL_REPO" fetch origin

git -C "$CANONICAL_REPO" worktree add \
  -b "$CI_BRANCH" \
  "$CI_TREE" \
  "$C3B_BASE_SHA"
```

The active canonical checkout remains untouched.

Accepted product modules are then ported/cherry-picked/copied into **this
worktree** under their approved canonical paths, reviewed, committed, and only
then sent through canonical CI.

Do not run canonical CI against uncommitted copied files. The CI runner refuses
dirty source by design.

## 4.4 Canonical source locations the product developer must know

The SableOS repository is not just an orchestration shell. Existing shared
implementation lives there and must be referenced rather than re-created.

Current canonical source map:

```text
aimindseye/sableos

apps/r8/android/
    maintained first-party Android application workspace
    includes existing Messages and other Sable app modules

apps/r8/android/messages/
    existing Sable Messages implementation

apps/r8/rust/
    canonical shared Rust workspace

src/android/packages/apps/SableStart/
    canonical Sable Launcher / HOME platform source

build/titan2/n1d-c3-product/
    repository-owned N1D/C3 product composition bundle

build/titan2/n1d-c3-composition.env
    N1D/C3 product/staging identity

build/titan2/n1d-product-contract.env
    N1D product contract

build/gates/
    canonical static/architecture/CI gates
```

The Android workspace receives the N1D product bundle under:

```text
/srv/sable-build/workspaces/titan2-n1d/android/vendor/sable/n1d/
```

but that staged Android-tree copy is **not** the authoring source of truth.

## 4.5 Rust ownership and integration

`titan2-temp` currently contains no Rust or JNI source. That is intentional.

Canonical Rust remains in:

```text
aimindseye/sableos/apps/r8/rust/
```

Current workspace members include shared/domain/JNI crates such as:

```text
calculator-core
convert-core
games-core
media-domain
weather-core
calculator-jni
convert-jni
games-jni
weather-jni
```

Rules:

1. Do not copy the canonical Rust workspace into `titan2-temp`.
2. Do not create a second copy of an existing Sable Rust/domain crate just so a
   parallel Android module can compile.
3. If the parallel product app is pure Kotlin/Java, it may remain so unless the
   product architecture explicitly requires existing Rust logic.
4. If a product module needs an existing Rust capability, record it in
   `C3B_PLATFORM_INTERFACE_REQUESTS.tsv` and identify the canonical crate.
5. If new or modified shared Rust is actually required, make that change in a
   separate branch/worktree of `aimindseye/sableos`, not in
   `titan2-temp`.
6. The Rust change must pass the canonical Rust CI path
   (`cargo fmt --check`, Clippy with warnings denied, tests, dependency and
   security checks) through the normal SableOS CI profile.
7. JNI/package wiring is integrated only after both the product-source change
   and canonical Rust change have explicit commit identities.

The handoff ledger should therefore distinguish:

```text
RUST_DEPENDENCY=NONE
```

or:

```text
RUST_DEPENDENCY=CANONICAL
RUST_REPO=aimindseye/sableos
RUST_PATH=apps/r8/rust/<crate>
RUST_REQUIRED_COMMIT=<sha>
```

No Rust dependency may be implicit.

---

# 5. Delivery schedule

This work is deliberately split into phases so product development can continue
without waiting for radio debugging.

## Phase P0 — now, before the canonical C3B base is published

Goal: make the product lane **buildable, traceable and integration-ready**.

### Required deliverables

#### P0.1 Stop broad feature expansion

Until the core modules build and pass integration gates:

- no additional keyboard language families;
- no new non-blocking Camera modes;
- no new decorative surfaces;
- no Q27 implementation;
- no Titan 2 Elite claims without Elite evidence.

Bug fixes, build fixes and work needed for integration remain allowed.

#### P0.2 Compile the Android modules for real

Run a real Android/Gradle build for every module intended for handoff.

Required minimum:

```text
home
setup
radiodiag
keyboard
displaycompat
camera
screens
```

For each applicable Gradle project:

```text
assembleRelease = PASS
unit tests = PASS
lint = PASS if configured
```

If lint is not configured, record that fact; do not report lint PASS.

JVM-only core tests remain useful but are not a substitute for Android compile.

#### P0.3 Produce a surface implementation matrix

Add:

```text
docs/C3B_PRODUCT_SURFACE_MATRIX.tsv
```

Required columns:

```text
surface_id
provider
module_or_platform_path
status
ux_doc
visual_confirmation_doc
artifact
platform_dependency
privilege_requirement
runtime_evidence_required
c3b_first_engineering_required
c3b_integrated_candidate_blocking
notes
```

Allowed status values:

```text
PRODUCTION_MODULE_SOURCE
AOSP_UNMODIFIED_TEMPORARY
PROTOTYPE_ONLY
PLATFORM_CHANGE_REQUIRED
DEFERRED_NON_BLOCKING
EVIDENCE_REQUIRED
BLOCKED
```

No generic `DONE` value.

#### P0.4 Bind every production surface to platform_sable

For every source candidate intended to become product code, record:

- exact `platform_sable` commit SHA;
- UX document(s);
- visual-confirmation document;
- artifact SVG where one exists;
- any requirement intentionally not implemented yet.

Do not silently reinterpret the design source.

#### P0.5 Produce platform-interface requests

Add:

```text
docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv
```

Use this whenever product code needs something the app cannot safely own.

Required columns:

```text
request_id
consumer_module
capability
reason
current_fallback
privileged_api_needed
system_component_owner
security_impact
blocking
status
```

Examples:

- supported default-HOME provisioning;
- display-compat enforcement API;
- keyboard-backlight service;
- programmable-key adapter;
- SubScreen bridge;
- privileged diagnostics access;
- SystemUI hook.

Do **not** solve these by hidden API reflection, broad privapp grants or SELinux
relaxation unless the canonical C3B lane explicitly accepts that interface.

#### P0.6 Strengthen static audit

The product lane should fail closed on at least:

- device-name branching in common code;
- unexpected permissions;
- platform signing claims;
- privileged app claims;
- HOME role claims not backed by the approved mechanism;
- radio/network state mutation;
- `setprop` in product apps;
- direct RIL/modem control;
- SELinux mutation;
- proprietary telephony payload inclusion;
- Restless/PHH runtime patch import.

#### P0.7 Match canonical Kotlin quality policy

For Kotlin/Android modules, align with the current canonical SableOS quality
tooling:

```text
Detekt Gradle plugin = 1.23.8
Ktlint Gradle plugin = 14.2.0
Detekt config source = aimindseye/sableos/apps/r8/android/config/detekt.yml
```

The `titan2-temp` copy of the Detekt configuration must record the exact
SableOS source commit used. Canonical integration ultimately uses the canonical
configuration; the parallel copy exists only to expose issues earlier.

Dependency verification metadata is required for the parallel Gradle graph
before the corresponding deliverable is accepted. Do not copy the canonical
verification file wholesale because the dependency graphs differ.

If verification metadata cannot be generated in the developer environment, the
PR must state:

```text
DEPENDENCY_VERIFICATION_METADATA=OPERATOR_BOOTSTRAP_REQUIRED
```

The operator may authorize a bounded network/bootstrap run on `ai-g732`.
Generated metadata is reviewed and then committed by the developer to the same
PR before final acceptance.

#### P0.8 Pinyin dictionary provenance and performance

The existing `pinyin_zh.tsv` may remain only with explicit provenance and
license material for every upstream used to create it, including the exact
jieba and pypinyin source/version/commit inputs.

Required evidence:

```text
PINYIN_DICTIONARY_PROVENANCE=PASS
PINYIN_DICTIONARY_LICENSES=PASS
PINYIN_DICTIONARY_SIZE_BOUNDED=PASS
PINYIN_DICTIONARY_JVM_LOAD_BENCHMARK=PASS_EVIDENCE_CAPTURED
PINYIN_DICTIONARY_MAIN_THREAD_LOAD=FORBIDDEN
PINYIN_DICTIONARY_PER_KEYSTROKE_FULL_REPARSE=FORBIDDEN
```

PR 3 should establish the first accepted `ai-g732` JVM benchmark baseline
(load time and memory/entry-count evidence). Do not invent a device-performance
claim from that host result. On-device keyboard latency remains a later physical
runtime gate.

### P0 exit markers

The developer should provide a handoff summary containing:

```text
C3B_PRODUCT_DEVELOPER_ANDROID_COMPILE=PASS_OR_NOT_RUN_TOOLCHAIN_UNAVAILABLE
C3B_PRODUCT_SOURCE_UNIT_TESTS=PASS
C3B_PRODUCT_SOURCE_STATIC_AUDIT=PASS
C3B_PRODUCT_SURFACE_MATRIX=PASS
C3B_PRODUCT_PLATFORM_INTERFACE_LEDGER=PASS
C3B_PRODUCT_PLATFORM_SABLE_BINDING=PASS
C3B_PRODUCT_DEVICE_RUNTIME_VALIDATED=NO
C3B_PRODUCT_IMAGE_BUILT=NO
```

---

## Phase P1 — when the canonical C3B engineering baseline is published

The canonical lane will publish an exact baseline contract.

Expected inputs from the canonical lane:

```text
C3B_BASE_REPO
C3B_BASE_SHA
C3B_ANDROID_SOURCE_BINDING
C3B_PRODUCT_TARGET
C3B_ALLOWED_RUNTIME_PATCH_LIST
C3B_DEVICE_PROFILE_CONTRACT
C3B_PLATFORM_INTERFACE_DECISIONS
C3B_RADIO_POLICY_VERSION
```

The parallel developer must consume those exact values.

### Required P1 work

#### P1.1 Reconcile package/module names against the real tree

Run the equivalent of:

```text
audit-sable-image.sh --aosp <canonical-c3b-tree>
```

Do not assume:

```text
Dialer
Contacts
Messaging
MmsService
TeleService
TelephonyProvider
CarrierConfig
Settings
SystemUI
```

until the canonical Android tree proves the exact module names.

#### P1.2 Reconcile product files

The product lane may supply product fragments, but the canonical C3B build
decides where they are inherited.

Requirements:

- Titan 2 fragments integrate through the canonical E2 thin-wrapper product
  `sable_titan2`, which inherits the proven generated E1
  `device/phh/treble/treble_arm64_bvN.mk` graph;
- canonical Android-workspace staging authority is `vendor/sable/titan2`,
  populated only by the canonical E2 staging driver;
- the retired `sable_titan2_n1d_arm64` / `vendor/sable/n1d` direct
  handcrafted product must not be revived;
- the parallel product lane must not create a second `vendor/sable/titan2`
  authority;
- no repository-stored presigned APKs;
- no product assurance properties owned by the parallel lane;
- one Titan 2 fragment;
- one Titan 2 Elite fragment;
- no cross-device evidence inheritance;
- no duplicate product authority;
- no C3B base patching from this repository;
- no target-files/OTA/release logic in the product lane.

#### P1.3 Resolve default HOME correctly

The current user-selection fallback is acceptable for source development.

For canonical integration:

- identify the supported Android 16 HOME/default-role mechanism;
- implement through canonical platform/product configuration;
- retain a safe fallback if role assignment fails;
- prove resolved HOME after first boot.

Do not invent an undocumented resource overlay.

#### P1.4 Reconcile Messages

Import or adapt the already-developed Sable Messages implementation from the
canonical SableOS source rather than selecting stock Messaging as the final
product implementation.

#### P1.5 Reconcile real system surfaces

For SystemUI, Keyguard, Settings and Setup Wizard:

- prototypes may remain as visual/interaction references;
- production changes must land in the actual platform/system module;
- any change proposed by this developer should be supplied as a focused,
  reviewable patch/commit against the canonical C3B source binding.

---

# 6. Required handoff package

Before the canonical lane will integrate the product source candidate, the
parallel lane should provide all of the following.

## 6.1 Source manifest

Add:

```text
docs/C3B_PRODUCT_HANDOFF.env
```

This tracked file must **not** attempt to contain the commit SHA of the commit
that contains itself.

Required fields:

```text
C3B_PRODUCT_HANDOFF_VERSION=1
C3B_PRODUCT_SOURCE_REPO=aimindseye/titan2-temp
C3B_PRODUCT_SOURCE_IDENTITY_MODE=RUNTIME_GIT_HEAD
C3B_PLATFORM_SABLE_HEAD=<40-char sha>
C3B_EXPECTED_BASE_HEAD=<40-char sha or UNBOUND_PRE_BASE>
C3B_PRODUCT_ANDROID_RELEASE=16
C3B_PRODUCT_COMPILE_SDK=36
C3B_PRODUCT_DEVICE=titan2
C3B_PRODUCT_RELEASE_ELIGIBLE=NO
C3B_PRODUCT_FLASH_AUTHORIZED=NO
C3B_PRODUCT_PRODUCTION_SIGNING_AUTHORIZED=NO
C3B_PRODUCT_RUST_DEPENDENCY=NONE_OR_CANONICAL
C3B_PRODUCT_RUST_REQUIRED_COMMIT=<sha-or-NONE>
```

The exact product commit is resolved at qualification time with:

```bash
git rev-parse HEAD
```

and is written to the PR body/operator evidence, not back into the tracked
handoff file.

The same rule applies to `C3B_PRODUCT_BUILD_EVIDENCE.md`: it records commands,
toolchain/dependency information and expected evidence format, while the exact
tested PR HEAD is bound by runtime/operator evidence.

Do not use a parent-commit workaround. The source identity is the exact PR HEAD
that the operator fetched and tested.


## 6.2 Product surface matrix

Required:

```text
docs/C3B_PRODUCT_SURFACE_MATRIX.tsv
```

Every C3B product surface must be represented.

## 6.3 Platform interface ledger

Required:

```text
docs/C3B_PLATFORM_INTERFACE_REQUESTS.tsv
```

No hidden unresolved privilege dependency.

## 6.4 Build evidence

Required:

```text
docs/C3B_PRODUCT_BUILD_EVIDENCE.md
```

Record:

- exact source head;
- Java version;
- Gradle version;
- AGP/Kotlin version;
- build commands;
- unit-test commands;
- lint command or `NOT_CONFIGURED`;
- APK output paths;
- APK SHA-256 values;
- audit results;
- known warnings;
- anything skipped.

## 6.5 Known limitations

Required:

```text
docs/C3B_PRODUCT_KNOWN_LIMITATIONS.md
```

Do not bury incomplete features inside README prose.

Each limitation should include:

```text
id
surface
description
blocking yes/no
fallback
owner
required evidence
```

## 6.6 Integration gate

Add a single fail-closed entrypoint, for example:

```text
build/titan2/qualify-c3b-product-source.sh
```

It should run all source/product checks that are valid without building the
canonical Android image.

It must print one terminal marker only on full PASS:

```text
C3B_PRODUCT_SOURCE_QUALIFICATION=PASS
```

Canonical CI cannot be claimed by this pre-handoff gate.

The gate must not contact a device.

---

# 7. Canonical SableOS CI requirement

## 7.0 CI operator ownership

The parallel developer does **not** run canonical SableOS CI.

The required responsibility split is:

```text
DEVELOPER
    writes one bounded deliverable
    validates syntax / local tests / relevant performance properties
    opens one PR in aimindseye/titan2-temp
    documents exact source head and dependency delta
    provides exact ai-g732 fetch/setup/validation commands
    updates the same PR when validation finds defects

SABLEOS OPERATOR ON ai-g732
    fetches the exact open PR head
    runs any reviewed initialization/staging command
    builds the deliverable
    runs canonical SableOS CI
    records PASS/FAIL against that exact PR head
    merges only after acceptance

CANONICAL CI COMMAND
    bash build/sable.sh titan2 N1D ci full
```

The developer may run equivalent tests in their own environment, but those
results are supporting evidence only. They are never a substitute for the
operator-run `ai-g732` qualification.

A PR is not merge-eligible until the operator has validated the exact current PR
head. Any push to the PR after a PASS invalidates that PASS and requires another
operator validation run.


CI is a mandatory integration gate. A module build, JVM test, source audit or
successful Android compile in `titan2-temp` is **not sufficient** for admission
into the canonical C3B branch.

## 7.1 Current canonical CI model

As of the SableOS mainline reviewed for this contract, canonical CI runs
directly on the controlled SableOS build machine.

```text
GITHUB_ACTIONS_EXECUTION=DISABLED
SELF_HOSTED_ACTIONS_RUNNER=DISABLED
LOCAL_DIRECT_EXECUTION=YES
```

GitHub is used for source hosting, PR review, issues and documentation. GitHub
Actions is not the SableOS qualification path and must not be treated as a
substitute for canonical CI.

The canonical operator interface is:

```text
build/sable.sh <device> <release> ci <core|full|release>
```

The implementation-level interface is:

```text
SABLEOS_DEVICE=<device>
SABLEOS_RELEASE_VERSION=<release>
bash build/local-ci/run.sh <core|full|release>
```

The C3B release identifier is fixed by this contract:

```text
C3B_RELEASE=N1D
```

C3A and C3B are both part of the Titan 2 N1D Android 16 engineering track.
`build/sable.sh` accepts this release identity for CI today. Image/artifact
registration remains separately gated and is not implied by using `N1D` for
source qualification.

## 7.2 Clean-source requirement

Canonical local CI is source-bound and refuses a dirty checkout.

Before CI:

```text
git status --porcelain
```

must be empty.

The CI run records the exact source commit and writes evidence bound to that
commit. A successful `full` or `release` run also creates the local
source-bound attestation used by the governed pre-push workflow.

Therefore:

```text
CI_PASS_ON_COMMIT_A
+ additional code changes
!= CI_PASS_ON_NEW_COMMIT
```

Any code change after a passing CI run requires fresh qualification.

## 7.3 What canonical CI covers

The current canonical CI profiles are:

### `core`

Includes the maintained repository qualification path, including:

- repository policy and layout;
- canonical host-tool verification;
- shell syntax;
- Python syntax;
- applicator self-tests;
- static product/build-driver contracts;
- `build/gates/sable-pipeline-contract.sh`;
- Rust formatting, Clippy and tests;
- Android compile/unit-test/lint tasks;
- APK sealing;
- quality checks including Detekt/Ktlint/coverage where configured;
- deterministic supply-chain evidence.

The STATIC stage aggregates contract failures rather than hiding later failures
behind the first error.

### `full`

Runs everything in `core` and additionally includes the current security and
independent product qualification stages, including:

- Rust dependency/security policy;
- Gitleaks;
- MobSFScan;
- Text Reader qualification;
- Reader qualification;
- Mail qualification.

`full` is the canonical **pre-image source/build/security CI profile**.

### `release`

Runs `full` plus source-bound visual/release-candidate requirements.

The current generic release path contains Panther-specific release execution.
Therefore the parallel Titan 2 developer must **not** run or claim Titan 2
`release` qualification unless the canonical C3B lane explicitly enables and
documents a Titan 2 release path.

For C3B source integration, the required profile is `full` unless the
canonical C3B contract explicitly raises the requirement.

## 7.4 Developer validation before requesting operator CI

Before requesting an `ai-g732` validation run, the developer must validate the
deliverable to the extent possible in the authoring environment.

Required developer evidence:

```text
changed shell syntax = PASS
changed Python syntax = PASS where applicable
Android/Java/Kotlin compile = PASS or NOT_RUN_TOOLCHAIN_UNAVAILABLE
unit tests = PASS
lint/static analysis = PASS where configured
Rust fmt/clippy/tests = PASS for any developer-owned Rust change
repository-local source audits = PASS
relevant performance/complexity check = PASS or NOT_APPLICABLE_WITH_REASON
```

The developer must not claim canonical CI PASS.

Before operator validation, the PR must state:

```text
C3B_PRODUCT_DEVELOPER_VALIDATION=PASS
C3B_PRODUCT_AI_G732_CI=NOT_RUN
```

These results show that the PR is ready to be tested by the SableOS operator.

## 7.5 Per-deliverable ai-g732 validation loop

Every deliverable is one PR in `aimindseye/titan2-temp`.

The PR stays open while it is being validated.

### Required PR description fields

```text
DELIVERABLE_ID=<short stable name>
PRODUCT_REPO=aimindseye/titan2-temp
PRODUCT_PR=<number>
PRODUCT_HEAD=<40-char sha>
PLATFORM_SABLE_HEAD=<40-char sha>
SCOPE=<bounded description>

DEVELOPER_SYNTAX_VALIDATION=PASS
DEVELOPER_TEST_VALIDATION=PASS
DEVELOPER_PERFORMANCE_VALIDATION=PASS_OR_NOT_APPLICABLE_WITH_REASON

DEPENDENCY_DELTA=NONE
or
DEPENDENCY_DELTA=<exact dependency/library/tool changes>

HOST_PACKAGE_INSTALL_REQUIRED=NO_OR_EXPLICIT_LIST
NETWORK_FETCH_REQUIRED=NO_OR_EXPLICIT_LIST
NEW_MAVEN_DEPENDENCIES=NONE_OR_EXPLICIT_LIST
NEW_RUST_CRATES=NONE_OR_EXPLICIT_LIST
NEW_NATIVE_LIBRARIES=NONE_OR_EXPLICIT_LIST

AI_G732_CI_REQUIRED=YES
AI_G732_CI_STATUS=NOT_RUN
```

No dependency may be added implicitly.

If an additional library, Maven artifact, Rust crate, native dependency, SDK
component or host tool is required, the developer documents:

- exact name;
- exact version;
- upstream/source;
- license;
- why existing SableOS dependencies are insufficient;
- lockfile or verification-metadata changes;
- whether network access is required;
- whether the canonical host-tool profile must change.

The developer must **not** install packages or mutate the canonical host from an
initialization script. The SableOS maintainer decides whether and how a new
dependency enters the canonical toolchain.

### Fetch the open PR on ai-g732

Use a dedicated product-review worktree so neither the canonical SableOS checkout
nor another product PR is disturbed.

```bash
set -euo pipefail

PR=<titan2-temp-pr-number>

PRODUCT_REPO=/srv/sable-build/workspaces/titan2-c3b-product/titan2-temp
PRODUCT_REVIEW_ROOT=/srv/sable-build/workspaces/titan2-c3b-product-review
PRODUCT_REVIEW_TREE="$PRODUCT_REVIEW_ROOT/pr-$PR"

test -d "$PRODUCT_REPO/.git" || {
    mkdir -p "$(dirname "$PRODUCT_REPO")"
    git clone git@github.com:aimindseye/titan2-temp.git "$PRODUCT_REPO"
}

git -C "$PRODUCT_REPO" fetch origin
git -C "$PRODUCT_REPO" fetch origin \
  "pull/$PR/head:refs/heads/review/pr-$PR"

mkdir -p "$PRODUCT_REVIEW_ROOT"

if [[ -e "$PRODUCT_REVIEW_TREE" ]]; then
    echo "PRODUCT_REVIEW_TREE_ALREADY_EXISTS=$PRODUCT_REVIEW_TREE"
    exit 1
fi

git -C "$PRODUCT_REPO" worktree add \
  --detach \
  "$PRODUCT_REVIEW_TREE" \
  "review/pr-$PR"

echo "PRODUCT_PR_HEAD=$(git -C "$PRODUCT_REVIEW_TREE" rev-parse HEAD)"
git -C "$PRODUCT_REVIEW_TREE" status --short
```

The printed SHA must equal the PR's declared `PRODUCT_HEAD`.

### Developer-provided initialization command

Each PR must provide exact commands for any repository-local preparation needed
before build/test.

Preferred interface when initialization is necessary:

```text
build/titan2/prepare-c3b-product-deliverable.sh
```

Required properties:

```text
idempotent
syntax-checked
bounded to the product review tree or explicit output directory
no sudo
no apt/dnf/pacman/brew
no host-tool installation
no hidden network fetch
no device contact
no adb/fastboot
no signing-key access
no canonical Android-tree mutation
```

If no initialization is necessary, the PR must explicitly say:

```text
INITIALIZATION_REQUIRED=NO
```

### Operator build and repository-local validation

The developer supplies the exact commands appropriate for the changed modules.
The operator runs them on `ai-g732` against the fetched PR head.

The existing canonical host-tool profile may be sourced for SDK/JDK/tool paths:

```bash
CANONICAL_REPO=/srv/sable-build/sableos/repo
PRODUCT_REVIEW_TREE=/srv/sable-build/workspaces/titan2-c3b-product-review/pr-<PR>

source "$CANONICAL_REPO/build/config/host-tools.env"

export ANDROID_HOME="$SABLE_ANDROID_SDK"
export ANDROID_SDK_ROOT="$SABLE_ANDROID_SDK"
export JAVA_HOME="$SABLE_JDK17"
export GRADLE_USER_HOME="$SABLE_GRADLE_USER_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$PRODUCT_REVIEW_TREE"
```

The operator then runs the PR's declared compile/test/lint/audit commands.

### Canonical C3B product-review staging adapter

Before the first Java/Kotlin/Rust product PR is submitted for operator CI, the
**canonical C3B engineering lane** must provide the SableOS-owned review staging
adapter. This is our responsibility, not the parallel developer's.

Planned canonical interface:

```text
aimindseye/sableos
build/titan2/stage-c3b-product-review.sh
```

Required behavior:

```text
input:
  --product-source <titan2-temp PR review worktree>
  --product-head <exact 40-char PR head>
  --stage
  --authorize-source-mutation

target:
  current isolated SableOS C3B integration worktree only

must:
  verify exact product head
  consume a declared handoff/path manifest
  reject undeclared files
  reject path collisions with canonical ownership
  preserve provenance
  stage only accepted product-lane source/docs/gates
  produce deterministic staged-file inventory
  record product PR/head in integration evidence
  leave active /srv/sable-build/sableos/repo untouched

must not:
  modify /srv/sable-build/workspaces/titan2-n1d/android directly
  run adb/fastboot
  flash
  install host packages
  fetch undeclared dependencies
  access signing keys
  merge the developer PR
```

The developer may describe what needs to be imported, but they do not own this
adapter and must not bypass it with arbitrary copies into the canonical repo.

Until this adapter exists and passes its own canonical contracts:

```text
C3B_PRODUCT_AI_G732_CI=BLOCKED_CANONICAL_STAGING_ADAPTER_NOT_READY
```

That is a canonical-lane prerequisite, not a defect in the developer's PR.

### Canonical CI is operator-owned

For any Java/Kotlin/Rust deliverable, the operator also validates the candidate
through the SableOS canonical CI flow.

The product source is first staged into an **isolated SableOS C3B integration
worktree** using the canonical C3B staging/integration adapter owned by
`aimindseye/sableos`. The developer does not own or modify that CI harness.

The integration worktree must be clean and committed before CI.

The operator then runs, from that isolated SableOS worktree:

```bash
bash build/sable.sh titan2 N1D ci full
```

Required result:

```text
SABLE_LOCAL_CI=PASS
PROFILE=full
SOURCE_COMMIT=<exact-local-integration-commit>
```

The validation record must also bind the tested product PR:

```text
C3B_PRODUCT_PR=<number>
C3B_PRODUCT_PR_HEAD=<exact-sha>
C3B_PRODUCT_AI_G732_CI=PASS
```

### PASS / FAIL loop

If build or CI fails:

```text
DO NOT MERGE
preserve failure evidence
developer updates the SAME PR
new PRODUCT_HEAD is recorded
operator fetches the new PR head
all affected validation is rerun
previous PASS is invalid
```

If all required build/test/audit/CI checks pass:

```text
C3B_PRODUCT_DELIVERABLE_ACCEPTED=YES
```

Only then may the `titan2-temp` PR be merged.

Later, when accepted deliverables are assembled into the actual canonical C3B
product branch, the combined canonical commit runs `N1D ci full` again. The
per-deliverable PASS does not replace final integrated-candidate CI.

## 7.6 Development-signing rule

Developer deliverables do not require a Sable private signing key.

```text
STANDALONE_RELEASE_APK=UNSIGNED_ALLOWED
DEVELOPER_DEBUG_APK=STANDARD_DEBUG_SIGNING_ALLOWED_LOCAL_ONLY
CHECKED_IN_KEYSTORE=FORBIDDEN
PRESIGNED_PRODUCT_APK=FORBIDDEN
PRODUCTION_SIGNING=NO
```

When accepted source is integrated into the canonical C3B `userdebug` image,
the canonical Android/SableOS build owns development/test certificate
assignment. A request for platform signing, shared UID or privileged permission
must be explicit and security-reviewed; it is not inherited from the parallel
repository.

Production signing is a later release-stage decision and remains unauthorized.

## 7.7 Product modules must be wired into CI, not merely run manually

When a `titan2-temp` module becomes maintained canonical SableOS source, the
integration PR must update the relevant CI/gate configuration so future
`build/local-ci/run.sh full` runs continue to qualify it automatically.

Depending on the module, that may include:

- Android assemble/compile task;
- Android unit-test task;
- Android lint;
- Detekt/Ktlint;
- coverage where applicable;
- source/architecture contract;
- APK identity/hash verification;
- supply-chain lock/verification metadata;
- no-stale-product-code checks;
- product-composition gate.

A one-time manual successful Gradle command is not sufficient.

Required rule:

```text
MAINTAINED_C3B_PRODUCT_CODE_NOT_WIRED_TO_CANONICAL_CI=FAIL
```

## 7.8 CI failure policy

If canonical CI fails:

1. preserve the evidence directory and failure log;
2. identify the exact failing stage/contract;
3. fix the source or gate cause;
4. do not bypass, suppress or delete the failing check merely to obtain PASS;
5. rerun the required CI profile on the new exact commit.

No image build proceeds from a CI-failing product integration commit.

## 7.9 CI validation evidence

For each accepted `titan2-temp` PR, the SableOS operator records:

```text
C3B_PRODUCT_PR=<number>
C3B_PRODUCT_PR_HEAD=<sha>
C3B_PRODUCT_AI_G732_CI_PROFILE=full
C3B_PRODUCT_AI_G732_CI_RELEASE=N1D
C3B_PRODUCT_AI_G732_INTEGRATION_COMMIT=<local-sableos-integration-sha>
C3B_PRODUCT_AI_G732_CI_EVIDENCE_DIR=<path>
C3B_PRODUCT_AI_G732_CI=PASS
```

Before the operator runs CI, the developer may only state:

```text
C3B_PRODUCT_AI_G732_CI=NOT_RUN
```

The developer must never manufacture or pre-fill a PASS value.

The final combined C3B product integration will have its own separate
source-bound canonical CI evidence.

---

# 8. Per-deliverable PR contract

Every independently reviewable product change is delivered through one PR in:

```text
aimindseye/titan2-temp
```


PR 1 must add a deterministic, non-networked PR-body renderer:

```text
build/titan2/render-c3b-deliverable-pr.sh
```

It must derive the current `git rev-parse HEAD`, fail on unexpected dirty
source, render the declared dependency delta and validation status, and default:

```text
AI_G732_CI_STATUS=NOT_RUN
```

The generated body may be pasted/used with GitHub tooling, but the script must
not open/merge a PR or claim operator PASS by itself.

Examples of bounded deliverables:

```text
Home build/role readiness
Keyboard critical text-entry closure
Radio Diagnostics hardening
Camera compile/HAL-facing cleanup
DisplayCompat source qualification
Sable Messages reconciliation
product composition
surface traceability
SystemUI prototype-to-platform patch proposal
```

Do not combine unrelated features merely to reduce PR count.

Each PR must provide:

1. bounded scope and explicit non-goals;
2. exact source SHA;
3. files/modules changed;
4. syntax/static validation performed by the developer;
5. tests performed by the developer;
6. relevant performance validation or a reason it does not apply;
7. exact `ai-g732` fetch commands;
8. exact initialization command, or `INITIALIZATION_REQUIRED=NO`;
9. exact build/test/lint/audit commands for the operator;
10. complete dependency delta;
11. known limitations;
12. expected PASS markers;
13. no merge request until operator validation succeeds.

A developer PR is an **input to operator qualification**, not self-approval.

---

# 9. Handoff format to the canonical SableOS repository

When P0/P1 is complete, do not ask the canonical lane to merge the entire
unrelated-history repository blindly.

Preferred handoff:

1. one integration branch based on the canonical `aimindseye/sableos` C3B
   head;
2. copy/cherry-pick only the accepted product modules and contracts;
3. preserve commit provenance in the PR description;
4. separate platform changes from ordinary app changes where practical;
5. no generated APK binaries committed unless the canonical product model
   explicitly requires prebuilts;
6. no private signing key material;
7. no proprietary stock payloads.

The handoff PR should identify each source commit from `titan2-temp` that was
ported.

---

# 10. What the canonical C3B lane will do after handoff

The canonical lane will own:

- final Android workspace integration;
- exact product inheritance;
- full Soong/ninja build;
- system image generation;
- SELinux integration;
- privileged permission review;
- radio/IMS integration;
- runtime-patch admission;
- device-contact authorization;
- flash authorization;
- physical qualification;
- release/signing decisions.

The product developer should not block on those tasks unless their module needs
a specific canonical interface.

---

# 11. First canonical integration target

The first C3B engineering image remains intentionally small.

Minimum target:

```text
Sable product identity/profile
Sable HOME
bounded setup/provisioning path
SystemUI + lockscreen
Settings + network/SIM settings
Phone / Telecom
Contacts
Messages
critical text-entry path
Titan 2 keyboard/display/device profile
read-only radio/IMS diagnostics
```

For this first image:

- AOSP SystemUI/Keyguard is acceptable;
- AOSP Settings is acceptable;
- AOSP Phone/Contacts may be acceptable;
- Sable Messages should be preferred once its existing implementation is
  reconciled;
- Sable Home / Keyboard / Radio Diagnostics are valuable candidates;
- Camera and DisplayCompat may be included if they build cleanly but must not
  block radio/boot diagnosis;
- the 23-screen catalog remains a design/test application, not proof that the
  platform surfaces are implemented.

---

# 12. Integrated C3B product-candidate target

The later integrated product candidate carries forward the earlier N1B2
non-deferred product scope.

Expected product areas include:

- Sable Start / All Apps;
- Command Search;
- Settings / Settings Search / Mobile Manager;
- privacy/profile surfaces;
- Sable Hub;
- Media / Gallery;
- Phone / Contacts;
- Messages;
- Mail / Calendar;
- Browser / WebView / Files;
- real SystemUI / shade / lockscreen / Setup Wizard product changes;
- Camera, gated by HAL evidence;
- connectivity features, hardware-gated;
- Toolbox / IR, hardware-gated;
- Display Compatibility;
- Weather;
- Reader;
- SubScreen, evidence-gated.

Current planned deferrals remain unless reopened:

```text
keyboard shortcut base
Mini Mode as a release blocker
Calculator
Games
SubScreen shortcut/PTT portions
FM radio unless proven
per-app cellular/Wi-Fi enforcement unless platform support is proven
```

---

# 13. Panther icon-system carry-forward

C3B must reuse the approved Panther R9 Sable first-party icon language for the
same product identities rather than inventing a Titan-specific icon family.

Canonical Panther icon contract:

```text
build/gates/r9-first-party-app-icon-contract.py
```

Its source language is based on Phosphor Icons regular geometry pinned to:

```text
repository: https://github.com/phosphor-icons/core
commit:     2b75f3ad12b420c9504ef05df8d2564a28f8500e
license:    MIT
```

Sable adapts those glyphs into its own first-party icon system with:

```text
256x256 vector viewport
Sable tonal background treatment
light foreground glyph
stable per-app identity accent
bottom identity rail
consistent optical scale
same identity across launcher / Settings / Recents
```

Existing Panther assets for the same apps should be reused directly or ported
without visual drift.

Current `titan2-temp` status at this contract revision:

```text
Home            android:icon not declared
Setup           android:icon not declared
RadioDiag       android:icon not declared
Keyboard        android:icon not declared
Camera          android:icon not declared
DisplayCompat   android:icon not declared
SableScreens    separate @mipmap/ic_launcher prototype icon
```

Therefore:

```text
C3B_PANTHER_ICON_LANGUAGE_REQUIRED=YES
C3B_TITAN_SPECIFIC_REPLACEMENT_ICON_FAMILY_ALLOWED=NO
C3B_PRODUCT_ICON_CONTRACT_STATUS=NEEDS_INTEGRATION
```

For a new Titan-only utility with no Panther counterpart (for example Radio
Diagnostics or Display Compatibility), the developer should create a new icon
**in the same approved Sable/Phosphor language**, document the glyph source and
license provenance, and add it to the C3B icon contract.

Prototype/catalog icons do not become product icons automatically.

Icon work is subject to the same operator-validation loop and must be wired into
canonical CI so missing/incorrect manifest icon references fail qualification.

---

# 14. Runtime acceptance after integration

Product work is not complete merely because APKs compile or appear in a system
image.

The combined C3B candidate will eventually require runtime evidence for:

## Core product

- resolved Sable HOME;
- first-boot/provisioning path;
- keyboard-first navigation;
- critical text entry;
- no focus traps;
- global appearance propagation;
- Phone / Contacts / Messages provider handoffs;
- Settings network/SIM access;
- lockscreen secure entry;
- notification/privacy behavior;
- app-display behavior where enabled.

## Cellular

The canonical radio lane retains the acceptance bar:

```text
CELLULAR_REGISTERED_AFTER_BOOT=PASS
CELLULAR_DATA_STABLE_30_MIN=PASS
CELLULAR_SURVIVES_REBOOT_X3=PASS
CELLULAR_SURVIVES_AIRPLANE_TOGGLE=PASS
CELLULAR_LTE_DATA=PASS
CELLULAR_5G_DATA=PASS_OR_NETWORK_GATED_WITH_REASON
CELLULAR_VOICE_CALL_MO_MT=PASS
CELLULAR_SMS_MO_MT=PASS
CELLULAR_MMS_MO_MT=PASS
NO_COM_ANDROID_PHONE_CRASH=PASS
NO_RADIO_SELINUX_DENIAL=PASS
DUAL_SIM=PASS_OR_CARRIER_GATED_WITH_REASON
ESIM=PASS_OR_CARRIER_GATED_WITH_REASON
VOLTE_IMS=PASS_OR_CARRIER_GATED_WITH_REASON
```

If a healer is eventually admitted, the canonical lane will additionally
measure healer interventions and missed-call behavior.

The product lane's Radio Diagnostics app may display/read relevant state, but
it must not decide the radio PASS result.

---

# 15. Immediate next work for the titan2-temp developer

Priority order:

```text
1. use one bounded titan2-temp PR per deliverable
2. include exact ai-g732 fetch/setup/build commands in every PR
3. declare all dependency/library/tool changes before operator validation
4. build every existing Android module for real where the developer has a toolchain
5. fix all known compile failures before requesting operator validation
6. run unit tests
7. run lint/static analysis where configured
8. stop broad feature expansion until the current integration-critical modules qualify
9. create C3B_PRODUCT_SURFACE_MATRIX.tsv
10. create C3B_PLATFORM_INTERFACE_REQUESTS.tsv
11. bind all production surfaces to exact platform_sable docs/artifacts
12. strengthen source/image audits
13. make Sable Home / Keyboard / Radio Diagnostics handoff-ready
14. reconcile Sable Messages
15. keep SystemUI/Keyguard/Settings/Setup prototypes clearly separated from
    real platform implementation
16. prepare the handoff env/build-evidence/known-limitations files
17. wait for the canonical C3B base SHA before final product-fragment reconciliation
```

Camera, language expansion, Q27 work and other non-blocking feature growth should
not outrun this integration work.

---

# 16. Acceptance criteria for the parallel lane

Acceptance happens at two levels.

## 16.1 Individual titan2-temp PR acceptance

A developer PR is ready for **operator validation** when its applicable
developer-side markers are true:

```text
C3B_PRODUCT_DEVELOPER_VALIDATION=PASS
C3B_PRODUCT_DEVELOPER_ANDROID_COMPILE=PASS_OR_NOT_RUN_TOOLCHAIN_UNAVAILABLE
C3B_PRODUCT_SOURCE_UNIT_TESTS=PASS
C3B_PRODUCT_SOURCE_STATIC_AUDIT=PASS
C3B_PRODUCT_SOURCE_QUALIFICATION=PASS
C3B_PRODUCT_DEPENDENCY_DELTA=DECLARED
C3B_PRODUCT_AI_G732_CI=NOT_RUN
```

The PR is **not mergeable yet**.

It becomes accepted and merge-eligible only after the operator validates the
same exact PR head on `ai-g732` and records:

```text
C3B_PRODUCT_PR=<number>
C3B_PRODUCT_PR_HEAD=<exact-current-pr-head>
C3B_PRODUCT_AI_G732_ANDROID_COMPILE=PASS
C3B_PRODUCT_AI_G732_CI_PROFILE=full
C3B_PRODUCT_AI_G732_CI_RELEASE=N1D
C3B_PRODUCT_AI_G732_INTEGRATION_COMMIT=<exact-integration-sha>
C3B_PRODUCT_AI_G732_CI=PASS
C3B_PRODUCT_DELIVERABLE_ACCEPTED=YES
```

Any developer push after that result changes `PRODUCT_HEAD`, invalidates the
PASS and returns the PR to operator-validation-required state.

## 16.2 Integrated product-lane acceptance

When multiple individually accepted PRs are assembled into the canonical C3B
product source, the combined source must additionally satisfy the cross-surface
handoff markers:

```text
C3B_PRODUCT_SURFACE_MATRIX=PASS
C3B_PRODUCT_PLATFORM_INTERFACE_LEDGER=PASS
C3B_PRODUCT_PLATFORM_SABLE_BINDING=PASS
C3B_PRODUCT_HANDOFF_MANIFEST=PASS
C3B_PRODUCT_BUILD_EVIDENCE=PASS
C3B_PRODUCT_KNOWN_LIMITATIONS=PASS
```

The actual combined SableOS integration commit then runs
`bash build/sable.sh titan2 N1D ci full` again. Per-PR CI results are inputs to,
not replacements for, final integrated CI.

And all of these remain:

```text
C3B_PRODUCT_DEVICE_RUNTIME_VALIDATED=NO_UNTIL_CANONICAL_INTEGRATION
C3B_PRODUCT_IMAGE_BUILT=NO_UNTIL_CANONICAL_INTEGRATION
C3B_PRODUCT_FLASH_AUTHORIZED=NO
C3B_PRODUCT_RELEASE_ELIGIBLE=NO
C3B_PRODUCT_PRODUCTION_SIGNING_AUTHORIZED=NO
```

After that handoff, the canonical C3B lane can integrate the product source
without rediscovering which requirements are real, which surfaces are
prototypes, or which privileged/platform dependencies remain unresolved.
