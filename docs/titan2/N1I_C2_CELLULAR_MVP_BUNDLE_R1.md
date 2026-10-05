# Titan 2 N1I-C2 Cellular MVP Bundle R1

Status: **engineering admission proposal; no mutation/build/device/flash authorization**

## Product objective

The objective is not to discover the theoretical minimum set of Android 16,
RestlessOS and SableOS cellular modifications.

The objective is:

```text
get reliable Titan 2 cellular working quickly
freeze the cellular substrate
return to SableOS product development
```

N1I-C1/V6 work established enough authority to stop serial
"add one library / patch, rebuild, discover the next one" experimentation.

The next candidate shall be a **small coherent cellular subsystem**, not the
smallest possible delta.

## Why this is broader than the recent C1 admission

BE1 and BE2 both treated plain AOSP as a control rather than the Titan product.
Their common architecture was a TrebleDroid/Restless compatibility substrate
plus Sable/device integration. The physically qualified C3A control validates
that approach.

The C3A control itself carries the exact public Restless Android-16 patch
topology:

```text
trebledroid           198
trebledroid-staging   121
rom                     29
personal                17
release-builds           4
                       ---
                       369
```

That is already a compatibility-superset strategy. Cellular bring-up should not
reverse course and peel the known-good substrate down one method at a time.

## Findings now considered closed enough for MVP admission

### Existing Restless/Treble compatibility substrate

Already present in the C3A control and retained for the MVP:

- TrebleApp MTK radio detection and IMS startup behavior;
- MTK IMS telephony RRO targeting `com.mediatek.ims`;
- PHH signature trust compatibility;
- `ImsManager.updateImsServiceConfig(Context,int,boolean)` compatibility;
- restored `SubscriptionManager.getSimStateForSlotIndex`;
- Android-16 `TelephonyMetrics` compatibility stub;
- legacy incoming-call binder compatibility path;
- APN database integration;
- MTK RIL compatibility hooks;
- `mtk-sms-fwk-ready`;
- older MTK radio HIDL interface compatibility.

These are **not re-litigated for minimality** in this milestone.

### OEM IMS Java closure

The accepted V01.00.14 audit and V6 member qualification establish:

```text
OEM_IMS_PACKAGE=com.mediatek.ims
REQUIRED_JARS=
  /system_ext/framework/mediatek-common.jar
  /system_ext/framework/mediatek-ims-base.jar

MEDIATEK_COMMON_UNRESOLVED=0
MEDIATEK_IMS_BASE_UNRESOLVED=0
IMPORTED_BOOT_DUPLICATE_CLASS_COUNT=0
```

The two required MediaTek framework jars are therefore part of the MVP.

### Confirmed framework ABI delta

V6F proves one real old-MTK-to-Android-16 framework ABI gap:

```text
stock TelephonyMetrics.writeRilAnswer = (II)V
C3A/C1 TelephonyMetrics.writeRilAnswer = (IIII)V
ImsRILAdapter observed call            = (II)V
```

The reviewed two-argument no-op overload is admitted into the MVP proposal.
It extends an existing no-op compatibility class and imports no stock
framework implementation.

### AgentPremain findings

The remaining eight static resolver findings are confined to
`kotlinx.coroutines.debug.internal.AgentPremain*` references to desktop-JVM
instrumentation APIs, with zero direct inbound references from normal IMS code.

For MVP policy:

```text
KEEP_VISIBLE_IN_EVIDENCE=YES
BLOCK_CELLULAR_BUILD=NO
BROAD_RUNTIME_FAILURE_SUPPRESSION=NO
```

This is a deliberate product decision: dormant debug-agent code does not justify
blocking the cellular milestone indefinitely.

## Bundle R1

### 1. Keep the complete C3A compatibility substrate

Do not peel Restless/Treble compatibility patches for this milestone.

The release architecture remains Sable-owned, but cellular MVP inherits the
physically qualified C3A behavior and applies Sable deltas on top.

### 2. OEM MediaTek IMS island

Include the existing C1 admission:

- V01.00.14 `ImsService.apk`, platform-resigned under the reviewed shared-UID
  contract;
- `mediatek-common.jar`;
- `mediatek-ims-base.jar`;
- current required MediaTek privapp/sysconfig declarations;
- current bounded system_ext SELinux admission.

Do not copy an entire stock `system_ext`, `product` or `system`.

### 3. Native dependency policy: close once, not one library per build

Prefer the exact N1I-B2 stock-vs-C3A closure when a retained B2 run exists.

The post-merge host review established that **no B2 native run was ever retained
for the accepted OEM IMS APK**. That missing analysis artifact is not allowed to
turn into a new open-ended research milestone.

For the Cellular MVP only, the accepted N1I-A A4 result is therefore an
authorized bounded fallback when both B2 sides are absent. The fallback is the
exact 33-path system-side compatibility superset already frozen in
`product/titan2/n1i-c1/a4-native-superset.txt`, and is accepted only when:

```text
N1I_A_NATIVE_DEPENDENCY_CLOSURE=PASS
MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE == exact 33-path reference set
every referenced A4 row is side=system
every referenced A4 row is present_in_c3a=NO
A4 evidence is sealed and hashed
```

This intentionally favors **getting the complete MediaTek compatibility island
working** over proving the theoretical minimum native set first. The B2 resolver
remains a later pruning/validation tool and is still preferred automatically if
both exact stock and C3A B2 authorities exist.

Vendor/ODM components remain preserved from vendor and are never duplicated
through this fallback.

The implementation materializer must freeze the exact stock bytes/SHA-256 for
all admitted A4 paths before build authorization. We still do not add one
library at a time.

### 4. Framework compatibility bundle

Retain all existing Restless MTK compatibility surfaces and add:

1. the V6F-proven two-argument `TelephonyMetrics.writeRilAnswer` no-op;
2. enable the already-present Restless legacy incoming-call binder behavior for
   Titan 2 rather than leaving it inert behind its default;
3. verify the MTK MMTEL provider RRO is enabled and points to
   `com.mediatek.ims`.

Do not import stock `framework.jar`, `telephony-common.jar`,
`services.jar` or a general MediaTek framework fork.

### 5. Titan cellular integration package

Create one Sable-owned Titan cellular integration package. Architectural role is
similar to AtlasOS's Titan IMS integration package, but implementation and
policy are Sable-owned.

It shall contain:

- a boot/readiness probe;
- exact provider/MMTEL binding verification;
- vendor VoLTE-UA readiness observation;
- bounded one-shot IMS rearm support;
- state capture and evidence logging;
- a disabled-by-default healer;
- no unrelated product configuration.

The package shall not become a generic always-root shell loop.

### 6. Vendor-UA / service-order handling

The V01.00.14 audit found vendor VoLTE/RCS UA components in preserved vendor and
identified service-trigger dependencies.

For MVP, derive the exact service names and stock trigger relationship from the
accepted audit and make the integration package:

1. wait for services that stock normally starts before declaring IMS ready;
2. start a vendor service only if it is explicitly disabled in vendor init and
   the stock audit attributes its trigger to the OEM IMS side;
3. perform at most one bounded ImsService rearm if the first bind occurred
   before vendor-UA readiness.

No blind process-kill loop.

### 7. PHH MTK IMS-disable behavior

Restless's `phh-on-boot.sh` contains MTK behavior that can disable IMS/ePDG
support when `mtkmal` is present.

Before the MVP image is built, classify whether Titan 2 satisfies that branch.
If yes, Titan-gate that behavior for the OEM-IMS candidate so the compatibility
substrate does not deliberately disable the feature being brought up.

This check is **mandatory** for Bundle R1 because leaving an opposite-policy
startup hook active would create avoidable diagnostic churn.

### 8. Healer ships now, disabled by default

The image should contain the recovery mechanism from the first MVP build so a
reproducible runtime race does not require another rebuild.

Default:

```text
HEALER_ENABLED=NO
```

Permitted trigger classes:

- IMS provider exists but expected MMTEL feature is unbound;
- IMS was bound before a required stock-attributed vendor UA became ready;
- IMS feature transitions to a known failed state after registration.

Permitted bounded actions:

- ensure IMS feature is enabled;
- rebind/reset the affected IMS feature;
- one-shot rearm of the affected ImsService after UA readiness.

Required protections:

- slot-aware;
- cooldown/rate limit;
- idempotent;
- no action during active voice call;
- no action during emergency call;
- structured trigger/action/result log.

Explicitly rejected:

- periodic blind `simswitch` forcing;
- periodic property hold loops;
- generic RIL restart;
- repeated airplane-mode toggles;
- SELinux permissive fallback;
- reboot-as-healing.

### 9. AtlasOS disposition

AtlasOS is used as runtime-pattern evidence, not a patch allowlist.

Adapt:

- dedicated Titan IMS integration ownership;
- readiness diagnostics;
- bounded ImsService rearm concept;
- legacy incoming-call compatibility awareness;
- healer as an explicit subsystem.

Do not copy by default:

- broad property forcing;
- blind simswitch loops;
- carrier/APN forcing without Titan evidence;
- generic radio restart;
- permissive SELinux behavior;
- framework changes unrelated to the single-SIM MVP.

### 10. Radio/DSDS scope

Do not introduce a new `mtkradioex` client for MVP unless the normal Android
radio-capability path produces an observed blocker.

The single-SIM MVP does not wait for:

- tray 2 qualification;
- DSDS;
- default-data SIM switching;
- default-voice SIM switching;
- full RadioEx callback parity.

Those remain follow-on cellular work.

## MVP acceptance gate

Use one known-good physical SIM in tray 1.

Blocking requirements:

```text
BOOT_X3=PASS
REGISTRATION=PASS
LTE_OR_5G_DATA=PASS
DATA_STABLE_30_MIN=PASS
SMS_MO=PASS
SMS_MT=PASS
MMS_MO=PASS
MMS_MT=PASS
IMS_REGISTERED=PASS
VOICE_MO=PASS
VOICE_MT=PASS
REBOOT_REREGISTER=PASS
PHONE_IMS_CRASH_LOOP=ABSENT
```

First physical run uses:

```text
HEALER_ENABLED=NO
```

If a reproducible readiness/race failure is captured, the same image may enable
the pre-shipped bounded healer under a separate physical authorization and
repeat only the failed surfaces. This avoids an unnecessary source/build cycle.

## Explicitly deferred from the SableOS development blocker

These do not block returning to general SableOS development after MVP passes:

```text
TRAY2
DSDS
DEFAULT_DATA_SWITCH
DEFAULT_VOICE_SWITCH
VoWiFi / QNS / IWLAN
eSIM
ViLTE / VT
new MTK RadioEx client
perfect healer tuning
```

## Build authorization boundary

This document defines the target bundle only.

Before a build is authorized, engineering must produce one finite source
mutation manifest containing:

- exact OEM IMS artifacts/hashes;
- exact two JAR hashes;
- exact B2 native closure/hashes when retained, otherwise the accepted A4 33-path compatibility superset with hashes frozen by materialization;
- exact TelephonyMetrics patch;
- exact incoming-call compatibility activation;
- exact Titan integration package files;
- exact PHH MTK-IMS-disable disposition;
- exact healer default-off configuration.

Once that finite manifest passes host qualification, the next build should be
**one Cellular MVP candidate**, not another diagnostic micro-image.

Current authority:

```text
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```
