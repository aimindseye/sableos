# Titan 2 N1D C3B minimal Sable baseline

Status: **C3A evidence consumed; C3B Compatibility Peel R2 active on review branch**

Date: 2026-10-02

## Purpose

C3B is the actual SableOS N1D baseline.

It starts from a separate clean checkout of the same pinned GrapheneOS Android
16 source used to establish the sealed base. E1 adds five pinned Treble
build-scaffold projects, for 1,038 managed projects, and inherits none of the
C3A 54-project removal set or 369-patch Restless control stack.

The pinned PHH `base.mk` is not accepted wholesale as Sable runtime policy.
Before product generation, E1 applies 14 exact fail-closed security/control
reductions bound to the pinned PHH commit and `base.mk` blob.

## Admission rule

C3B uses a peeling model, refined by Compatibility Peel R2.

Runtime/device compatibility remains evidence-driven, but already-proven C3A
**build compatibility** is classified up front so C3B does not rediscover known
Graphene/Treble build failures one compile at a time.

```text
C3A known control
      |
audit repository-owned C3A compatibility fixes
      |
admit safe build-only/security-positive subset
      |
C3B minimal Graphene + pinned Treble scaffold
      |
new runtime/device failure only
      |
review -> bounded admission or rejection
```

No patch enters C3B merely because it existed in Restless. The full 369-patch
control stack remains excluded. The R2 decision ledger is
`build/titan2/n1d-c3b-compatibility-peel-r2.tsv`.

```text
N1D_C3B_RESTLESS_WHOLESALE_ADMISSION_ALLOWED=NO
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
N1D_C3B_BUILD_MAKE_COMPAT_PATCH_COUNT=2
```

The two R2 build/make patches are Sable-owned narrow deltas: one fixes the
Graphene/Treble GSI module graph and disables the irrelevant Cuttlefish-only
shared-system-image module; the other prevents the generic GSI
`ro.adb.secure=0` override. Restless APN removal, llkd removal, OPlus
`my_manifest` handling, and non-atomic VNDK-28 SELinux changes are not
admitted.

## Cellular/radio direction

The earlier Titan 2 evidence remains authoritative for C3B:

- keep the AOSP phone stack source-built;
- do not import stock telephony APKs which collide with platform identity;
- do not import MTK framework JAR/SO payloads speculatively;
- do not copy the full stock vendor tree into system;
- preserve the stock vendor/kernel/firmware compatibility strategy;
- preserve the proven LTE attach window as a regression condition;
- investigate MTK indication handling;
- investigate IMS/QNS/IWLAN compatibility;
- keep PHH MTK IMS enablement false until compatible IMS service behavior is
  proven;
- do not accept APN-only or LTE-only explanations without evidence.

```text
N1D_C3B_AOSP_PHONE_STACK=SOURCE_BUILT
N1D_C3B_STOCK_TELEPHONY_APK_IMPORT_ALLOWED=NO
N1D_C3B_STOCK_MTK_JAR_SO_IMPORT_ALLOWED=NO
N1D_C3B_FULL_VENDOR_COPY_ALLOWED=NO
N1D_C3B_STOCK_VENDOR_FIRMWARE_PRESERVE=YES
N1D_C3B_RADIO_COMPAT_MODE=EVIDENCE_DRIVEN
N1D_C3B_MTK_INDICATION_STATUS=INVESTIGATE
N1D_C3B_IMS_QNS_IWLAN_STATUS=INVESTIGATE
N1D_C3B_PHH_MTK_IMS_DEFAULT=false
N1D_C3B_APN_ONLY_FIX_ALLOWED=NO
N1D_C3B_LTE_ONLY_FIX_ALLOWED=NO
```

The detailed reference set, MediaTek/IMS prior art, healing-script constraints
and carry-forward mapping from the earlier N1B2 PR plan are recorded in:

```text
docs/titan2/N1D_C3B_REFERENCE_AND_SCOPE_R1.md
```

C3B is explicitly prepared to add a **bounded, evidence-gated cellular/IMS
healer** if runtime testing proves one is necessary. The healer is disabled by
default, must be state-triggered and rate-limited, must remain slot-aware and
call-safe, and must not use permissive SELinux, reboot loops, blind airplane
toggles or default RIL restarts. Partial OEM/MediaTek IMS compatibility may be
investigated when evidence points there; proprietary stock IMS payload import
remains a separate explicit admission decision.

## Security direction

C3B must not inherit PHH/Restless release-incompatible defaults such as:

- SELinux neverallow bypasses;
- `ro.adb.secure=0`;
- PHH root/securize tooling;
- PHH remote-debug behavior;
- vendor Magisk runtime inclusion;
- PHH OTA behavior.

E1 removes these highest-risk defaults before the first C3B engineering parse
or compile. Other PHH compatibility behavior remains provisional and can be
removed, retained or replaced only through evidence-driven C3B work.

The active E1 source graph is:

```text
GrapheneOS pinned base       1033
C3B Treble scaffold             5
Graphene removals               0
Restless patches                0
-------------------------------
managed projects             1038
```

## Current authorization state

C3A has produced sealed control evidence:

```text
N1D_C3A_CONTROL_EVIDENCE=PASS
N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE
```

The original split profile keeps the historical pre-transition block for audit,
but E1 moves current phase authority to:

```text
build/titan2/n1d-c3b-transition.env
```

E1 authorizes only a separate C3B engineering workspace, five-project scaffold
sync, exact PHH-base hardening, the reviewed R2 build-compatibility peel,
product parse, and `systemimage` compilation.
The first engineering target remains the generated Treble product
`treble_arm64_bvN-bp4a-userdebug`; final Sable product identity and
source-module admission are E2 work.

```text
N1D_C3_CURRENT_ACTIVE_PHASE=C3B_ENGINEERING
N1D_C3B_ENGINEERING_BUILD_AUTHORIZED=YES_SYSTEMIMAGE_ONLY_AFTER_STAGE_AND_PARSE
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO
N1D_C3B_FLASH_AUTHORIZED=NO
N1D_C3B_SIGNING_AUTHORIZED=NO
N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO
N1D_C3B_RELEASE_ELIGIBLE=NO
```

See `N1D_C3B_TRANSITION_R1.md`.
