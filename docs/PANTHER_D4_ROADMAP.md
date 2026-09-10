# Panther D4 roadmap — closed / handed off to R1

Date: 2026-09-08

Baseline: Pixel 7 (`panther`), Android 17 / GrapheneOS `2026081300` substrate, SableOS D4 B2 packaged population physically flashed and booted successfully on slot B with shared userdata preserved.

## Final D4 status

D4 is **CLOSED** for the current B2 development population.

```text
D4-R0 package/provenance + functional baseline        CLOSED
D4-R1 combined mutation scope                         CLOSED FOR CURRENT B2
D4-B1/B2 build + packaged target-files               PASS
R7R7 fs-verity named-input fidelity                   PASS / CLOSED
R8 ART residual classification                        PARTIAL / C2 HISTORICAL EVIDENCE UNAVAILABLE
R9 preserved-data flash preflight                     PASS
R10R3 exact packaged B2 flash                         PASS
R10R3 Android boot                                    PASS
R10R3 exact installed BuildManifest identity          PASS
R10R3 shell post-boot ART aggregate                   SUPERSEDED HARNESS DEFECT
sablectl exact post-boot BuildManifest                PASS
sablectl exact post-boot ART aggregate                PASS_5_OF_5
sablectl verify-boot                                  PASS_11_OF_11
sablectl smoke                                        PASS_16_OF_16
sablectl v0.3.1 full suite                            PASS_26_OF_26
D4 automated functional acceptance                    PASS
D4 release gate                                       PASS
D4 physical acceptance                                PASS
D4-R2 slot-success proof                              PASS
D4-R2 final closure                                   CLOSED
PANTHER_D4                                             CLOSED
```

Canonical packaged B2 target-files:

```text
panther-target_files.zip
sha256=b22c5ab5676b3a61304102cd508bf75a01bd4d0bc2a47ffceba8be153376bb78
```

Installed BuildManifest:

```text
/system/etc/security/fsverity/BuildManifest.apk
sha256=8a56fddab2ae42f40d522e96241b4b486bb2d702e11f9bb0b10e7527d32f8cec
```

## Closed evidence chain

```text
GrapheneOS 2026081300 source closure
    + bounded Sable delta
    -> B2 packaged target-files
    -> fs-verity named-input verification
    -> target-files sole-source flash payload
    -> physical slot B
    -> Android boot complete
    -> exact installed BuildManifest
    -> exact five ART residuals
    -> preserved shared data
    -> automated functional acceptance
    -> manual physical acceptance
    -> release-candidate gate
    -> bootloader current/bootable/successful slot proof
```

## D4-R2 target closure — final disposition

The D4-R2 target was:

```text
D4_GRAPHENE_USER_FACING_DEFAULTS=REMOVED_OR_EXPLICITLY_JUSTIFIED
D4_DEFAULT_APP_SET=DOCUMENTED
D4_FUNCTIONAL_ACCEPTANCE=PASS
D4_SLOT_B_BOOT=PASS
D4_SLOT_B_SUCCESSFUL=PASS
D4_SHARED_DATA_PRESERVED=PASS
D4_AUTOMATED_REGRESSION=PASS
```

Final disposition:

```text
D4_GRAPHENE_USER_FACING_DEFAULTS=REMOVED_OR_EXPLICITLY_JUSTIFIED
D4_DEFAULT_APP_SET=DOCUMENTED
D4_FUNCTIONAL_ACCEPTANCE=PASS
D4_SLOT_B_BOOT=PASS
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SLOT_B_CURRENT=PASS
D4_SHARED_DATA_PRESERVED=PASS
D4_AUTOMATED_REGRESSION=PASS
PANTHER_D4_R2=PASS
PANTHER_D4=CLOSED
```

The D4 release gate completed:

```text
PASS=56
FAIL=0
SKIP=8
MANUAL=0
ERROR=0
OVERALL=PASS
RELEASE_D4_RC=0
```

The bootloader-side R2 proof completed:

```text
FASTBOOT_PRODUCT=panther
FASTBOOT_CURRENT_SLOT=b
FASTBOOT_SLOT_COUNT=2
FASTBOOT_SLOT_SUCCESSFUL_b=yes
FASTBOOT_SLOT_UNBOOTABLE_b=no
FASTBOOT_SLOT_RETRY_COUNT_b=2
D4_SLOT_B_SUCCESSFUL=PASS
D4_SLOT_B_BOOTABLE=PASS
D4_SLOT_B_CURRENT=PASS
POST_SLOT_SUFFIX=_b
POST_BOOT_COMPLETED=1
POST_SLOT_PRESERVED=PASS
PANTHER_D4_R2_SLOT_SUCCESS_RESULT=PASS
R2_RC=0
```

Successful R2 evidence:

```text
EVIDENCE_DIR=/tmp/PANTHER_D4_R2_SLOT_SUCCESS_PROOF_20260908T215953Z_JS7omS
SCRIPT_SHA256=d3cdb1dc4cdca4289ff7d835a96d9c96aebfee05a4feaa4c967bbf033115ca71
LOG_SHA256=8aaf2bbaf195cd5f48acc0eafad64022c3dd6ca339a4b400a933752a49738dbc
```

The earlier R2 bounded failure is superseded as a host fastboot-readiness race and is not evidence of a slot defect.

## Functional acceptance

Automated validation covered exact packaged identity, security/runtime health, shared-data preservation, network/telephony/Bluetooth/USB/WebView/default-role checks and manual-evidence binding.

Physical validation passed:

```text
VOICE_OUT=PASS
VOICE_IN=PASS
SMS_OUT=PASS
SMS_IN=PASS
MMS_OUT=PASS
MMS_IN=PASS
HOTSPOT=PASS
BLUETOOTH_AUDIO=PASS
CAMERA=PASS
LOCATION=PASS
BIOMETRICS=PASS
CELLULAR_DATA=PASS
WIFI=PASS
```

NFC framework/service/HAL/enable/routing validation passed. RF tag read remains a non-blocking external-hardware gap:

```text
NFC_RF_TAG_READ=NOT_TESTED_NO_TEST_HARDWARE
NFC_DISPOSITION=DEFERRED_NON_BLOCKING_EXTERNAL_HARDWARE_VALIDATION
```

## Historical harness defects retained for evidence

Known superseded host-harness issues are retained rather than erased:

```text
R10R3 postboot ART shell-loop stdin consumption
sablectl v0.2 initial USB-property false failure
sablectl v0.3.0 bootctl rc=70 observability classification
R2 initial fastboot-enumeration readiness race
```

Each has a later successful proof or corrected harness result. None remains a D4 product defect.

## D4 operating rules that remain normative

The canonical Android/Pixel substrate remains GrapheneOS `2026081300`. Sable changes are bounded deltas on top.

```text
needed + clean on current base       -> PORT
needed + incompatible old design     -> REDESIGN
obsolete workaround                  -> DROP
independent Sable project            -> RETAIN / ADAPT / INTEGRATE
```

Do not globally rename GrapheneOS internal package/API identifiers. Do not relabel Graphene-operated services, URLs or infrastructure as Sable until Sable owns a truthful replacement.

```text
REMOVE_USER_FACING_GRAPHENE_DEFAULTS
!=
REMOVE_GRAPHENE_PLATFORM_DEPENDENCIES
```

The D4-R0 provenance model remains normative for future user-facing app/default changes even though the current D4 instance is closed.

## Handoff to R1 — Sable-owned release engineering

The active next milestone is R1:

```text
Sable signing keys and custody
Sable release/version identity
release/user build policy
signed target-files
OTA generation and signing
Sable-owned update metadata / Updater endpoint
A/B forward-update validation
rollback and rescue validation
factory/install artifact validation
sablectl release evidence integration
```

Current R1-R0 entrypoint:

```text
tools/validation/release-r1/SABLE_R1_R0R2_RELEASE_PREFLIGHT.py
```

R0R1 is retained only as a superseded recursion-defect artifact and must not be executed.

R1-R0 remains strictly read-only and does not authorize key generation, build, signing, OTA generation, device contact or deployment.

## Sequence

```text
D3  canonical GrapheneOS 2026081300 base
    + initial Sable identity
    + AVB/fs-verity closure
    + physical boot / A-B validation
    CLOSED

D4  identity/default-app work
    + packaged B2
    + exact target-files flash
    + exact postboot identity
    + functional acceptance
    + preserved data
    + release gate
    + slot-success proof
    CLOSED

R1  Sable-owned release engineering
    ACTIVE

F1  combined Sable functional feature batch
    AFTER R1 FOUNDATION

R2  production hardening / repeatable release validation
    LATER
```
