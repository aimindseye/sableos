# Titan 2 N1B2 cellular / telephony evidence audit

Status: PR 207 audit contract
Date: 2026-09-29
Target: Titan 2 N1B2 cellular root-cause discovery

## Purpose

PR 207 creates the read-only evidence pipeline for the cellular issue observed on
Titan 2: cellular connects initially and then disconnects. The updated N1B2 plan
records that N1B1 and the N1B2 candidate share this failure, while stock
firmware is the only known-good reference.

PR 207 does **not** fix cellular. It gathers static and runtime evidence so PR
208 can make evidence-backed module, overlay, permission, sepolicy, or vendor
binding changes.

## Device mode

```text
ANDROID_MODE_REQUIRED=YES
ADB_USED=YES_FOR_RUNTIME_CAPTURE
FASTBOOT_REQUIRED=NO
FASTBOOTD_REQUIRED=NO
```

For PR 207, keep the phone booted in Android mode. Do not put it in fastboot or
fastbootd. Runtime capture is read-only and uses `adb shell` / `adb logcat`.

Fastboot or fastbootd may be relevant only for a later, separately approved
partition extraction, image build, or flash workflow. This PR does not approve
that work.

## Deliverables

```text
build/titan2/audit-n1b2-cellular-stack.sh
build/titan2/capture-n1b2-cellular-runtime.sh
build/gates/n1b2-cellular-stack-audit-contract.sh
docs/titan2/N1B2_CELLULAR_STACK_AUDIT.md
docs/titan2/N1B2_CELLULAR_ROOT_CAUSE.md
```

## Scope boundaries

```text
STATIC_AUDIT=YES
RUNTIME_CAPTURE=YES_READ_ONLY
SOURCE_MUTATION=NO
MODULE_CHANGES=NO
OVERLAY_CHANGES=NO
SEPOLICY_CHANGES=NO
PERMISSION_CHANGES=NO
PRODUCT_PACKAGE_CHANGES=NO
IMAGE_BUILD=NO
FLASH_ENABLEMENT=NO
RADIO_TOGGLE=NO
DEVICE_REBOOT=NO
FASTBOOT_USE=NO
FASTBOOTD_USE=NO
```

## Evidence roles

| Image/source | Role |
|---|---|
| Stock firmware | Known-good reference. Static capture always where extracted firmware is available; runtime only if a stock-running Titan 2 is available without reflashing. |
| N1B1 | Failing sample 1. Static and runtime capture. |
| N1B2 candidate | Failing sample 2. Static and runtime capture. |
| RestlessOS source/tree | Candidate module source. Static comparison only unless an image is already available. |
| AOSP / Treble GSI | Candidate module source and composition reference. Static comparison only. |

Primary diff:

```text
stock_known_good vs (N1B1 common failure ∩ N1B2 common failure)
```

Anything present in stock and missing or different in both failing samples is a
first-priority candidate cause, not a conclusion.

## Static evidence

The static script accepts optional roots via environment variables:

```text
STOCK_ROOT
N1B1_ROOT
N1B2_ROOT
RESTLESS_ROOT
AOSP_ROOT
```

It scans for:

```text
TeleService
Telecom
TelephonyProvider
CarrierConfig
CellBroadcast
Stk
Euicc / LPA
eSIM feature declarations
IMS / RCS / MBMS packages
MmsService
priv-app permissions
sysconfig files
overlays and telephony configuration
APN / carrier / MMS config
radio / RIL / IMS init services
radio / IMS / RIL vendor libraries
VINTF manifest / framework compatibility matrix files
```

Outputs:

```text
summary.tsv
cellular-candidate-files.tsv
common-failure-vs-stock-candidates.tsv
static-markers.txt
```

## Runtime evidence

Runtime capture is Android-mode adb only. Run on N1B1 and the N1B2 candidate. If
a stock-running Titan 2 is available without reflashing, capture stock too.

The runtime script captures:

```text
adb devices -l
adb get-state
getprop
service list
lshal
pm list packages filtered for telephony / phone / carrier / IMS / MMS / eSIM
dumpsys telephony.registry
dumpsys phone
dumpsys isub
dumpsys carrier_config
dumpsys connectivity
dumpsys telecom
dumpsys activity processes
settings get global mobile_data
settings get global airplane_mode_on
settings get global device_provisioned
dmesg radio / denial lines where permitted
logcat -b radio -b main -b system -b crash -b events
```

The script must be started at boot or immediately before the observed
connect-to-disconnect window when possible. It does not change any device state.

## Required root-cause classification

PR 207's root-cause report must classify any findings into one or more of:

```text
product package selection
privileged permission missing
framework overlay/config
CarrierConfig/APN
IMS/radio/vendor service
radio HAL / VINTF mismatch
SELinux denial
SIM state / carrier provisioning
Settings or Network Manager policy
Treble/AOSP composition gap
stock vendor dependency gap
```

For every candidate cause, the report must name the candidate source for the fix
(AOSP, RestlessOS, stock, or no-change) and cite the evidence supporting that
choice.

## PR 208 handoff

PR 208 may only add or replace modules, overlays, permissions, sepolicy, or
vendor bindings that cite a PR 207 finding. Speculative additions are blocked.

PR 208 runtime pass bar remains:

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
