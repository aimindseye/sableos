# Titan 2 N1D C3B reference set and scope carry-forward

Status: **planning/reference input for C3B; not code admission**

Date: 2026-10-01

## Purpose

This document records external Titan 2 / Treble / MediaTek references and the
scope that C3B inherits from the earlier N1B2 product plan.

A reference being listed here does **not** authorize copying its code, patches,
properties, proprietary payloads, security posture, or runtime behavior into
SableOS. C3B remains evidence-driven:

```text
REPRODUCE_FAILURE
  -> IDENTIFY_CAUSE
  -> REVIEW_SMALLEST_COMPATIBILITY_CHANGE
  -> ADMIT_EXPLICITLY
  -> REBUILD
  -> COLLECT_RUNTIME_EVIDENCE
```

The C3B Restless runtime-patch allowlist starts at zero.

## External MediaTek / IMS references

### AtlasOS

Repository:

```text
https://github.com/Abyss-c0re/atlasos
reference branch: main
reviewed head: 9e78ad78897c63c4db91e28d9b327effc784390f
```

AtlasOS is a Titan 2-specific hybrid GSI project using stock vendor / boot with
a LineageOS GSI plus its own patches. Its current public tree contains explicit
Titan 2 IMS recovery and SIM-switch machinery, including:

```text
packages/gsi_product/prebuilt_sysbin/titan2-ims-heal.sh
packages/titan_ims/bin/titan2-ims-rearm.sh
packages/titan_ims/bin/titan2-ims-setup.sh
packages/titan_ims/bin/titan2-ims-simswitch-early.sh
packages/titan_ims/bin/titan2-ims-simswitch-hold.sh
packages/titan_ims/init/titan2-ims.rc
patches/gsi_source/0096-telephony-ims-follows-settings-calls-sim.patch
patches/gsi_source/0210-telephony-incoming-binder-thread-both-phones.patch
```

Developer feedback supplied to the SableOS project reports that AtlasOS needed
a partial OEM IMS port plus healing scripts to make incoming calls substantially
more reliable. The report also says missed calls can still occur, a subsequent
call often succeeds after healing, and SIM-slot switching remains an edge case.

This is high-value failure-model evidence for C3B, but not evidence that the
AtlasOS implementation is suitable for direct adoption. In particular, AtlasOS
contains lab/product choices that conflict with SableOS release policy, so C3B
must not inherit them blindly.

Useful design lessons to test independently:

- MediaTek IMS service compatibility may require framework/API shims rather
  than APN-only changes.
- the selected voice SIM and vendor IMS capability tray may need explicit,
  slot-aware alignment;
- IMS binding/re-registration may need to be re-armed after a specific failed
  state;
- incoming-call behavior may depend on framework-side binder/IMS behavior;
- a generic RIL restart is not automatically safe: AtlasOS itself documents
  that restarting the MTK RIL can make UICC/SIM state worse on this device;
- SIM-switch handling must be treated as a first-class runtime state transition.

### Unihertz Titan 2 LineageOS customizations

Repository:

```text
https://github.com/agreenbhm/Unihertz-Titan-2-LineageOS
reference branch: main
reviewed head: 1dba3d4ed7a3b79537814b4926202c55fdf8f209
```

This repository is explicitly a Titan 2 GSI customization layer. Its
`LineageOS/system/bin/phh-on-boot.sh` contains MediaTek-specific handling
around `/vendor/bin/mtkmal`, `persist.mtk_ims_support`, and
`persist.mtk_epdg_support`.

C3B reference role: device-specific evidence that the Titan 2 vendor stack has
MediaTek IMS/ePDG behavior requiring deliberate system/vendor coordination.
The script is a reference only; its property mutations and reboot behavior are
not automatically admissible SableOS policy.

### MisterZtr LineageOS GSI

Repository:

```text
https://github.com/MisterZtr/LineageOS_gsi
reference branch: lineage-23.2
reviewed head: 7bf212f449d1aa253ebc97b1ab3c4924be88effa
```

This is a TrebleDroid-based Android 16 LineageOS GSI patch set. Relevant current
patches include a compatibility `TelephonyMetrics` stub for MediaTek IMS
vendor code and legacy MediaTek IMS API compatibility in
`frameworks/opt/net/ims`.

C3B reference role: generic Android-16/Treble compatibility prior art. The
repository also incorporates Restless/Treble patches, so its patch stack is not
an allowlist for C3B. Individual changes require reproduced Titan 2 evidence and
normal C3B admission review.

### PeterGSI / Angry.Im

Reference:

```text
https://gitea.angry.im/PeterGSI
```

Historical PeterGSI device/GSI work contains MediaTek-specific compatibility
patterns, including an MTK RIL watchdog that conditionally restarts
`vendor.ril-daemon-mtk` after a crash and only after the service has previously
started successfully.

C3B reference role: historical GSI prior art for state-triggered recovery and
MediaTek quirks. This reference is not currently pinned here to an immutable
PeterGSI commit; any code considered for admission must first be pinned and
reviewed.

## C3B partial OEM IMS policy

The AtlasOS developer feedback materially changes what C3B must be prepared to
test, but it does not change the default security boundary.

C3B should distinguish:

```text
OEM/VENDOR IMS COMPATIBILITY
    framework/API shims, service binding, carrier/config integration
    -> allowed to investigate when failure evidence points there

PROPRIETARY OEM IMS PAYLOAD IMPORT
    APK/JAR/SO copied from stock system/product/system_ext
    -> NOT allowed by default; requires separate provenance, licensing,
       signature/shared-UID, security and architecture review
```

Existing policy remains:

```text
AOSP phone stack = source-built
stock telephony APK import = NO
stock MTK framework JAR/SO import = NO
full stock vendor copy into system = NO
stock vendor/kernel/firmware compatibility = PRESERVE
```

If C3B evidence proves that an OEM IMS component is indispensable, that is a
new explicit admission decision; it must not be smuggled into a generic
"cellular fix".

## C3B healing-script readiness

C3B **may implement a healing mechanism if runtime evidence proves it is
needed**. It is not enabled merely because another ROM uses one.

Required design constraints:

```text
HEALING_DEFAULT=DISABLED_UNTIL_FAILURE_EVIDENCE
HEALING_TRIGGER=OBSERVED_STATE_FAILURE_NOT_PERIODIC_BLIND_LOOP
HEALING_ACTION=SMALLEST_IDEMPOTENT_RECOVERY
HEALING_RATE_LIMIT=REQUIRED
HEALING_SLOT_AWARE=REQUIRED
HEALING_ACTIVE_CALL_SAFE=REQUIRED
HEALING_EMERGENCY_CALL_SAFE=REQUIRED
HEALING_EVIDENCE_LOG=REQUIRED
HEALING_ROOT_CAUSE_MASKING=FORBIDDEN
RIL_RESTART_DEFAULT=FORBIDDEN
AIRPLANE_TOGGLE_LOOP=FORBIDDEN
SELINUX_PERMISSIVE_RECOVERY=FORBIDDEN
REBOOT_AS_HEALING=FORBIDDEN
```

Preferred recovery order, only when supported by evidence:

```text
1. observe and classify IMS/radio/subscription state
2. re-apply a lost bounded configuration only if it drifted
3. re-enable/re-register the affected IMS feature/service
4. rebind only the affected IMS slot if proven necessary
5. restart a narrowly scoped IMS/vendor service only if proven safe
6. modem/RIL restart only under a separately reviewed exception
```

A healer must never be used to turn an unexplained failure into a superficial
PASS. Runtime evidence must record both raw failures and healer interventions,
including trigger reason, slot/subscription, action, result, cooldown and
recurrence count.

## Cellular acceptance bar carried into C3B

The earlier N1B2 product plan's cellular requirements remain useful and should
be carried forward to the C3B runtime gate:

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

For healing-enabled builds, add:

```text
CELLULAR_HEALER_DISABLED_CONTROL_CAPTURE=REQUIRED
CELLULAR_HEALER_TRIGGER_EVIDENCE=REQUIRED_IF_USED
CELLULAR_HEALER_SECOND_CALL_RECOVERY=MEASURE_NOT_ASSUME
CELLULAR_HEALER_MISSED_CALL_RATE=MEASURE
CELLULAR_HEALER_SIM_SWITCH_STABILITY=REQUIRED
CELLULAR_HEALER_REBOOT_STABILITY=REQUIRED
```

## Carry-forward of the earlier N1B2 PR plan

The 2026-09-29 N1B2 PR plan remains a product-scope reference, but its PR
numbers are historical logical work packages rather than reserved future PR
numbers. N1D/C3 work has since reused parts of that number range.

C3B should carry the work forward in these groups:

| Earlier logical PRs | C3B role | First minimal C3B image? |
|---|---|---|
| 206, 209, 210, 211 | product scope/capability ledger, design-surface matrix, Titan 2 profile, critical text-entry gates | Yes, foundation |
| 207, 208 | cellular evidence + restoration | Yes, highest-priority runtime track |
| 212–221 | Start/All Apps, Search, Settings, privacy/profile surfaces, Hub, Media, Phone/Contacts, Mail/Calendar, Browser/Files, SystemUI/Lockscreen/Setup | Carry forward; only essential boot/radio surfaces required for first engineering image, all blocking surfaces required for the later C3B product candidate |
| 222–228 | Camera, connectivity/HAL features, Toolbox/IR, display compatibility, Weather, Reader, SubScreen | Carry forward with the same HAL/evidence/deferred rules |
| 229, 230 | image assembly dry-run and first integrated candidate | Replaced by C3B-specific assembly/candidate qualification after the new baseline and radio track pass |

The first C3B **engineering** image is intentionally smaller than the old N1B2
integrated-candidate bar. Its job is to boot the Sable-owned baseline and make
cellular diagnosis fast and attributable.

Recommended first-image minimum:

```text
Sable product identity/profile
Sable launcher / HOME
Setup Wizard or bounded provisioning path
SystemUI + lockscreen
Settings + network/SIM settings
Phone / Telecom framework surface
Contacts
Messages
critical text-entry path
Titan 2 keyboard/display/device profile
read-only radio/IMS diagnostics
```

The later C3B **product candidate** should restore the old plan's non-deferred
blocking product scope before it is considered a successor to the planned N1B2
candidate.

Still-deferred items remain deferred unless separately reopened:

```text
keyboard shortcut base
Mini Mode
Calculator
Games
SubScreen shortcut/PTT portions
FM radio unless hardware path is proven
per-app cellular/Wi-Fi enforcement unless platform enforcement is proven
```

## Relationship to C3A

C3A proved that the pinned public Restless/TrebleDroid control graph builds.
It is not a source of automatic C3B runtime policy.

C3B uses C3A, AtlasOS, Titan 2 LineageOS, MisterZtr and PeterGSI as comparison
evidence. The smallest evidence-supported change wins; reference-project
behavior never overrides SableOS security, privacy or release requirements.
