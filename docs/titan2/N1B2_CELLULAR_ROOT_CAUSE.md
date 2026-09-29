# Titan 2 N1B2 cellular root-cause report

Status: PR 207 evidence report, N1B2 transition evidence captured
Date: 2026-09-29

PR 207 is read-only evidence collection. It does not fix cellular and does not
authorize module, overlay, sepolicy, permission, product package, image, or
flash changes.

## Current state

```text
ROOT_CAUSE_STATUS=PRELIMINARY_EVIDENCE_CAPTURED
N1B1_STATUS=FAILING_SAMPLE
N1B2_STATUS=FAILING_SAMPLE_RUNTIME_CAPTURED
STOCK_STATUS=KNOWN_GOOD_REFERENCE
PR207_FIXES_CELLULAR=NO
PR208_REQUIRED_FOR_FIX=YES
```

Known symptom from the approved N1B2 plan:

```text
N1B1 connects initially and then disconnects.
N1B2 candidate connects initially and then disconnects.
Stock firmware is the only known-good reference.
```

## Evidence inventory

| Evidence set | Required | Path | Status | Notes |
|---|---:|---|---|---|
| Static stock firmware tree | Yes, if extracted stock firmware is available | TBD | NOT_CAPTURED | Known-good static reference. |
| Static N1B1 tree | Yes | TBD | NOT_CAPTURED | Failing sample 1. |
| Static N1B2 candidate tree | Yes | TBD | NOT_CAPTURED | Failing sample 2. |
| Static RestlessOS tree | Yes, if available | TBD | NOT_CAPTURED | Candidate source. |
| Static AOSP/Treble tree | Yes, if available | TBD | NOT_CAPTURED | Candidate source. |
| Runtime N1B1 capture | Yes | TBD | NOT_CAPTURED | Android mode adb only. |
| Runtime N1B2 transition capture | Yes | `/tmp/SABLE_N1B2_CELLULAR_RUNTIME_n1b2_transition_20260929T124815Z` | CAPTURED | Manual reboot followed by Android-mode transition capture. |
| Runtime N1B2 transition archive | Yes | `SABLE_N1B2_CELLULAR_RUNTIME_n1b2_transition_20260929T124815Z.tar.gz` | CAPTURED | SHA-256 `14691bae50c1e10650d5e278ca4e35481a62094a6a8fe945b7a922602ab79170`, size 1,221,748 bytes. |
| Runtime stock capture | Optional | TBD | NOT_CAPTURED | Only if a stock-running Titan 2 is available without reflashing. |

## N1B2 transition evidence summary

The N1B2 transition capture proves a real post-boot transition rather than a
static already-failed state:

```text
CAPTURE_MODE=transition
MOBILE_DATA=1
AIRPLANE_MODE=0
DEVICE_PROVISIONED=1
```

Observed transition:

1. Android boots and adb returns in normal Android mode.
2. WWAN registration reaches LTE HOME after boot.
3. The same slot later drops to OUT_OF_SERVICE / NOT_REG_* while IWLAN remains HOME.
4. Framework service probes for `phone`, `isub`, and `carrier_config` fail in the final snapshot.
5. RIL/MTK logs repeatedly report null MTK network indication callbacks and IMS service unavailability.

Important negatives:

```text
FASTBOOT_USED=NO
FASTBOOTD_USED=NO
REBOOT_BY_SCRIPT=NO
RADIO_TOGGLE_BY_SCRIPT=NO
SETTINGS_MUTATION=NO
DYNAMIC_DMESG_RADIO_DENIALS_CAPTURED=NO
```

## Disconnect timeline

| Sample | Last good ServiceState/DataConnectionState | First bad state after last good | Evidence file | Notes |
|---|---|---|---|---|
| N1B1 | TBD | TBD | TBD | Still required for comparison. |
| N1B2 | 2026-09-29 08:49:52.150 local log time: LTE IN_SERVICE, WWAN HOME, channel 66736, bandwidth 20000, data RAT LTE. Earlier first LTE HOME observed at 08:48:21.292 with PS WWAN HOME and DATA/MMS. | 2026-09-29 08:49:52.151 local log time: OUT_OF_SERVICE, data RAT IWLAN, WWAN CS/PS NOT_REG_SEARCHING or NOT_REG_OR_SEARCHING, cell identity null. | `logcat/logcat-window-600s.txt` | This matches the known symptom: cellular comes up briefly after reboot and then falls back to no service. |
| Stock | TBD | TBD | TBD | Optional comparable window if available. |

## Runtime service / package signals

| Signal | Evidence | Interpretation |
|---|---|---|
| Radio HAL and MTK radio-extension services are registered | `service-list.txt` lists AIDL radio services for slot1/slot2 and MTK `mtkradioex` data/ims/network/sim/voice services. | Modem/radio service availability is not simply absent. |
| Mobile data is enabled | `settings-global-mobile-data.txt` is `1`. | User/network-manager mobile-data policy is not the primary observed blocker. |
| Airplane mode is off | `settings-global-airplane-mode.txt` is `0`. | Airplane mode is not the primary observed blocker. |
| `dumpsys phone` fails | `dumpsys-phone.txt`: `Can't find service: phone`. | Suspect framework telephony service registration/product composition gap. |
| `dumpsys isub` fails | `dumpsys-isub.txt`: `Can't find service: isub`. | Suspect subscription service registration/product composition gap. |
| `dumpsys carrier_config` fails | `dumpsys-carrier-config.txt`: `Can't find service: carrier_config`. | Suspect CarrierConfig package/service registration gap. |
| Telephony package grep is empty | `pm-telephony-packages.txt` is empty. | Suspect package selection gap, but PR 208 should capture full `pm list packages -f` before treating this as conclusive. |
| Dynamic dmesg radio denials file is empty | `dmesg-radio-denials.txt` is empty. | No runtime dmesg denial was captured by the targeted read, but logcat still contains early SELinux denials that require static review. |

## Static candidate differences

| Candidate | Category | Present in stock | Present in N1B1 | Present in N1B2 | Priority | Notes |
|---|---|---:|---:|---:|---|---|
| TeleService / phone service registration | product package selection | TBD | TBD | Failing runtime evidence | HIGH | `dumpsys phone` is unavailable in N1B2 runtime snapshot. |
| Subscription service registration | product package selection | TBD | TBD | Failing runtime evidence | HIGH | `dumpsys isub` is unavailable in N1B2 runtime snapshot. |
| CarrierConfig service/package | product package selection / CarrierConfig/APN | TBD | TBD | Failing runtime evidence | HIGH | `dumpsys carrier_config` is unavailable in N1B2 runtime snapshot. |
| MTK network indication bridge | IMS/radio/vendor service | TBD | TBD | Failing runtime evidence | HIGH | RILC repeatedly logs `radioNetworkServiceImpl[1]->mtkNetworkIndication == NULL`. |
| IMS service binding | IMS/radio/vendor service | TBD | TBD | Failing runtime evidence | MEDIUM_HIGH | Telephony repeatedly logs IMS service timeout / unavailable. |
| SELinux access to CCCI/gsm0710 devices | SELinux denial | TBD | TBD | Logcat evidence | MEDIUM | Early logcat includes denials for wrapper processes accessing CCCI/gsm0710 device nodes; needs stock comparison before PR 208 changes policy. |

## Root-cause classification

Mark every applicable class with evidence. Leave non-applicable classes as
`NO_EVIDENCE_YET`, not `NO`, until the evidence supports that conclusion.

| Class | Status | Evidence | Candidate source for fix |
|---|---|---|---|
| product package selection | SUSPECT_HIGH | Missing `phone`, `isub`, `carrier_config` dumpsys services; empty targeted telephony package listing. | Compare stock/N1B1/N1B2 package lists and product package selection before PR 208. |
| privileged permission missing | NO_EVIDENCE_YET | No specific missing privapp permission has been isolated yet. | Static privapp permission comparison required. |
| framework overlay/config | NO_EVIDENCE_YET | WWAN briefly registers, then deregisters; framework service registration gaps may hide deeper overlay/config issues. | Compare telephony/carrier overlays against stock/RestlessOS/AOSP. |
| CarrierConfig/APN | SUSPECT_HIGH | `carrier_config` service is unavailable in N1B2 runtime; carrier/subscription logs identify T-Mobile-derived carrier state but no stable cellular service. | Restore/prove CarrierConfig service/package and APN sources before changing APNs. |
| IMS/radio/vendor service | SUSPECT_HIGH | RILC reports null MTK network indication callbacks; IMS service is not up/available. | Compare MTK IMS/radio service packages, init services, VINTF, and permissions. |
| radio HAL / VINTF mismatch | POSSIBLE | AIDL radio and MTK radio-extension services are registered, but MTK indication callback is null. | Compare radio VINTF/init/service names against stock and RestlessOS. |
| SELinux denial | POSSIBLE | Targeted dmesg denial capture is empty; boot logcat contains CCCI/gsm0710 access denials that need stock comparison. | Do not add policy until the denied domains and stock policy are compared. |
| SIM state / carrier provisioning | POSSIBLE | SIM/subscription is visible in logs, but service state falls to No service. | Compare stock SIM/subscription behavior with same SIM/carrier if available. |
| Settings or Network Manager policy | LOWER_PROBABILITY | Runtime shows mobile data enabled and airplane mode off; PR 207 script made no settings changes. | Keep Network Manager duplication blocked unless PR 208 evidence proves policy involvement. |
| Treble/AOSP composition gap | SUSPECT_HIGH | Runtime product reports TrebleDroid/GSI identity, and framework telephony service probes fail. | Compare AOSP/Treble package set versus RestlessOS/stock known-good components. |
| stock vendor dependency gap | SUSPECT_HIGH | MTK vendor services are present but not enough for stable WWAN registration. | Compare stock vendor dependencies, MTK telephony packages, init, permissions, VINTF, and overlays. |

## PR 208 handoff checklist

Before PR 208 changes anything, this report must name:

```text
ROOT_CAUSE_CLASSIFICATION_COMPLETE=NO
CANDIDATE_SOURCE_SELECTED=NO
AOSP_SOURCE_NEEDED=TBD
RESTLESSOS_SOURCE_NEEDED=TBD
STOCK_SOURCE_NEEDED=TBD
NO_SPECULATIVE_MODULES=YES
NETWORK_MANAGER_DUPLICATION_BLOCKED=YES
```

PR 208 should not jump directly to APN-only or 5G-only fixes. The first fix
candidate must be selected from static stock/N1B1/N1B2/RestlessOS/AOSP evidence,
with special attention to framework telephony package/service registration,
CarrierConfig, MTK IMS/radio packages, VINTF/init bindings, and only then SELinux
policy if stock comparison supports it.

Every PR 208 module, overlay, permission, sepolicy, or vendor binding must cite a
row from this report.
