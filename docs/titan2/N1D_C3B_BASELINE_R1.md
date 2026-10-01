# Titan 2 N1D C3B minimal Sable baseline

Status: **C3A evidence prerequisite satisfied; C3B transition pending separate change**

Date: 2026-10-01

## Purpose

C3B is the actual SableOS N1D baseline.

It starts from the sealed GrapheneOS Android 16 source and may use the pinned
TrebleDroid scaffold as build/compatibility infrastructure, but it does not
inherit the complete C3A Restless patch stack.

## Admission rule

C3B uses a peeling model:

```text
C3A known control
      |
C3B minimal Graphene + pinned Treble scaffold
      |
build/runtime failure
      |
identify the C3A change that explains the failure
      |
review security/runtime impact
      |
admit the smallest required change or atomic patch pair
      |
rebuild and record evidence
```

No patch enters C3B merely because it existed in Restless.

```text
N1D_C3B_RESTLESS_FULL_PATCH_STACK_ALLOWED=NO
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_INITIAL_COUNT=0
N1D_C3B_PATCH_ADMISSION_MODE=FAILURE_EVIDENCE_THEN_REVIEW_THEN_ADMIT
```

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

## Security direction

C3B must not inherit PHH/Restless release-incompatible defaults such as:

- SELinux neverallow bypasses;
- `ro.adb.secure=0`;
- PHH root/securize tooling;
- PHH remote-debug behavior;
- vendor Magisk runtime inclusion;
- PHH OTA behavior.

These must be absent, replaced, or individually justified before release
qualification.

## Current authorization state

C3A has now produced sealed control evidence:

```text
N1D_C3A_CONTROL_EVIDENCE=PASS
N1D_C3B_TRANSITION_PREREQUISITE=SATISFIED_BY_C3A_CONTROL_EVIDENCE
```

PR231 intentionally leaves the existing C3B build block in place:

```text
N1D_C3B_BUILD_AUTHORIZED=NO_UNTIL_C3A_CONTROL_EVIDENCE
N1D_C3B_RELEASE_ELIGIBLE=NO
```

That preserves the exact policy state under which C3A was qualified. A separate
C3B transition change will consume
`build/titan2/n1d-c3a-control-evidence.env`, switch the active phase to the
minimal Sable baseline, and authorize only the C3B engineering build scope.
Release, signing, device contact, and flash remain separate later gates.
