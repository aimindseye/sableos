# Titan 2 N1I-C2 Cellular MVP Mutation Manifest R1

Status: **host-side authority resolution only; no source mutation, build, device
contact, reboot or flash authorization**

## Purpose

Convert the approved Cellular MVP Bundle R1 into one finite implementation
manifest before any Android-source mutation is authorized.

This is deliberately not another diagnostic micro-image. The resolver produces
one reviewable set covering:

- the already-admitted V01.00.14 OEM `com.mediatek.ims` provider;
- the two qualified MediaTek boot JARs;
- the exact N1I-B2 system-side native stock-only dependency closure;
- the V6F-proven `TelephonyMetrics.writeRilAnswer(II)V` compatibility patch;
- the already-present Restless incoming-call compatibility path;
- the PHH `mtkmal` branch that can disable MTK IMS/ePDG;
- stock-attributed vendor IMS/VoLTE UA service readiness;
- one Sable-owned Titan cellular integration package;
- a bounded healer shipped disabled by default.

## Why this is the next gate

The merged post-consolidation host qualification established that build
regression memory, flash regression memory, the Cellular MVP contract, the
central Titan guard and runtime-linkage regression all pass on canonical
`main`.

The product decision is therefore no longer "what is the smallest next patch?"
It is "what exact finite mutation set will be used for the one Cellular MVP
candidate?"

## Tool

```text
build/titan2/prepare-n1i-c2-cellular-mvp-mutation-manifest.py
```

The tool is read-only. It does not run ADB, fastboot, a build, a network fetch,
a reboot or a flash.

Default authorities:

```text
ANDROID_ROOT=/srv/sable-build/workspaces/titan2-n1d/android
N1I_A=/srv/sable-build/evidence/titan2/n1i-a-oem-ims/20261005T002256Z
EVIDENCE_ROOT=/srv/sable-build/evidence/titan2
```

The B2 stock/C3A native directories may be auto-resolved only when exactly one
matching authority for the OEM IMS APK is discoverable by role. Otherwise the
operator must pass the two exact retained evidence directories explicitly.

## Native admission rule

The old N1I-A 33-file list remains reference-only.

The resolver consumes `NATIVE_SUMMARY.env` and `NATIVE_CLOSURE.tsv` from the
retained N1I-B2 stock and C3A runs. A native is proposed only when all of these
hold:

```text
stock status = FOUND
stock partition = system | system_ext | product | system_dlkm
stock namespace visibility = EXPLICIT
C3A status = NOT_FOUND (or not analysed)
stock SHA-256 = valid exact hash
```

Vendor/ODM libraries are preserved from vendor and are not duplicated into the
system image.

A C3A `FILE_PRESENT_NAMESPACE_UNPROVEN` or wrong-ABI result is a blocker, not
automatic stock-import authority. This prevents "adding more libraries" from
masking a linker-namespace problem.

The result is written to:

```text
CELLULAR_MVP_NATIVE_CLOSURE.tsv
```

## Telephony compatibility authority

The exact Android source target is:

```text
frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java
```

Accepted source states:

```text
BASE_BLOB=27638e5be9c008101c2f9b8f1e7a9af49d94f838
POST_BLOB=9d5108e0ddb8d4960d21cda021813b53dbbf4da8
PATCH_BLOB=ee353caded6dd07318991eb52d66687e06034c30
```

The mutation manifest proposes the two-argument no-op overload when the exact
base blob is present, or records the target as already patched when the exact
post blob is present. Any third state fails closed.

## Incoming-call compatibility authority

Restless already carries the legacy incoming-call behavior in
`ImsPhoneCallTracker`, gated by:

```text
ro.telephony.block_binder_thread_on_incoming_calls
```

The current Restless path is inert by default because its default is true. The
MVP mutation set therefore proposes a **Titan product property** selecting the
existing compatibility behavior rather than importing another telephony fork.

The source file and Git blob are recorded in
`CELLULAR_MVP_SOURCE_AUTHORITY.tsv`.

## PHH `mtkmal` disposition

The resolver requires the current
`device/phh/treble/phh-on-boot.sh` branch containing:

```text
/vendor/bin/mtkmal
persist.mtk_ims_support
persist.mtk_epdg_support
```

Because the Cellular MVP intentionally supplies OEM MediaTek IMS, the final
implementation must Titan-gate that generic PHH behavior rather than allow it
to disable the subsystem being brought up.

The exact source context is captured in:

```text
CELLULAR_MVP_PHH_MTKMAL_CONTEXT.tsv
```

## Vendor UA/service readiness

The accepted N1I-A A5 inventory remains the stock authority.

The resolver consumes:

```text
a5-init-services.tsv
a5-trigger-property-setters.tsv
```

Vendor/ODM IMS, VoLTE, clientapi, IMCB and UA services are recorded in:

```text
CELLULAR_MVP_VENDOR_UA.tsv
```

Default disposition:

```text
class-start / vendor-driven service -> OBSERVE_READINESS
disabled service whose trigger is attributed to SYSTEM_SIDE_OEM_IMS_CODE
    -> ALLOW_BOUNDED_START_IF_NOT_READY
```

This is the allowlist for the future integration package. The package must not
invent service names or start every IMS-keyword vendor daemon.

## Integration package and healer

The manifest always contains a proposed Sable-owned integration package:

```text
ADD_SABLE_TITAN_CELLULAR_INTEGRATION_PACKAGE
```

Its implementation scope is bounded to:

- provider/MMTEL binding verification;
- vendor-UA readiness;
- diagnostics/evidence;
- one-shot bounded rearm;
- state-triggered healer logic.

The healer is present in the image but:

```text
HEALER_ENABLED=NO
```

for the first physical MVP run.

Blind simswitch/property loops, generic RIL restart, repeated airplane toggles,
SELinux permissive fallback and reboot-as-healing remain rejected.

## Outputs

A successful run creates one fresh evidence directory with:

```text
CELLULAR_MVP_MUTATION_MANIFEST.tsv
CELLULAR_MVP_NATIVE_CLOSURE.tsv
CELLULAR_MVP_VENDOR_UA.tsv
CELLULAR_MVP_PHH_MTKMAL_CONTEXT.tsv
CELLULAR_MVP_SOURCE_AUTHORITY.tsv
CELLULAR_MVP_SUMMARY.env
SHA256SUMS.txt
```

Expected final markers:

```text
N1I_C2_MANIFEST_NATIVE_CLOSURE=PASS_FINITE
N1I_C2_MANIFEST_PHH_MTKMAL_BRANCH=PASS_PRESENT_REQUIRES_TITAN_GUARD
N1I_C2_MANIFEST_MUTATION_SET=PASS_FINITE_REVIEWABLE
N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST=PASS
```

## Authorization boundary

This gate **does not** authorize implementation.

```text
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
NETWORK_FETCH_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

After the exact generated manifest is reviewed, the next transition may
authorize one Android-source mutation set and one Cellular MVP build. The
implementation must correspond exactly to the sealed manifest; new discovered
requirements go through a manifest revision rather than being silently added
during the build.
