# Titan 2 N1I-F — sanitized V01.00.14 stock telephony control

Status: **PASS — factory-stock telephony control captured and functionally qualified**

Date: **2026-10-03 ET**

This record preserves the engineering-relevant state from a freshly factory-reset
Unihertz Titan 2 V01.00.14 control. The raw operator capture is intentionally
not committed because it contains subscriber identifiers, IP addresses, cell
location identifiers and raw modem payloads.

## Source evidence

```text
RAW_ARCHIVE_BASENAME=Titan2_V01.00.14.zip
RAW_ARCHIVE_SHA256=c3d49e62e71571750da5b9828fd0af0866d83bffc73eea100a1c9bf715a76cc1
RAW_ARCHIVE_BYTES=205167
RAW_ARCHIVE_COMMITTED_TO_GIT=NO_PRIVACY
SANITIZER=build/titan2/sanitize-n1i-stock-control.py
SANITIZATION_STATUS=PASS
```

The sanitizer removes or masks subscriber identifiers (IMEI/IMSI/ICCID/MEID/
MSISDN/EID), IP/MAC addresses, cell identifiers (CI/PCI/TAC), raw modem payloads
and SIM ATR values. Full raw evidence remains a host-side artifact only.

## Stock identity

```text
ro.build.fingerprint=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
ro.system.build.fingerprint=Unihertz/Titan_2/Titan_2:16/BP2A.250605.031.A3/V01.00.14:user/release-keys
ro.vendor.build.fingerprint=Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.14:user/release-keys
ro.build.version.release=16
ro.build.version.incremental=V01.00.14
ro.boot.slot_suffix=_a
ro.boot.verifiedbootstate=orange
```

The Android-14 `UP1A` vendor fingerprint is normal for this stock Android-16
system stack and must not be used by itself to identify the active system image.

## Physical SIM and radio state

The control was captured with one physical SIM in tray 1.

```text
gsm.sim.state=LOADED,ABSENT
gsm.sim.operator.numeric=310240
gsm.operator.numeric=310260,
gsm.network.type=LTE,Unknown

persist.vendor.radio.simswitch=1
persist.vendor.radio.c_capability_slot=1
persist.vendor.ims_support=1
persist.vendor.mims_support=2
persist.vendor.mtk.volte.enable=1
persist.vendor.vilte_support=1

mobile_data=1
data_roaming=0
```

This section is the single-SIM tray-1 control. A separate stock tray-2 control
below also passes. Two-SIM DSDS remains a mandatory pending product requirement
because Titan 2 has two physical SIM slots and no eSIM fallback.

## Registration and data

Stock remains HOME / NOT_ROAMING on serving PLMN 310260 with LTE band 66,
voice and packet service both IN_SERVICE, rejectCause=0, NR available and
EN-DC available.

The selected stock default Internet profile is:

```text
APN_NAME=T-Mobile US
APN=fast.t-mobile.com
SIM_OPERATOR=310240
SERVING_PLMN=310260
DATA_INTERFACE=ccmni1
DATA_NETWORK=CONNECTED
DATA_NETWORK_VALIDATED=YES
```

The captured stock window contains:

```text
ERROR_UNSPECIFIED_COUNT=0
REJECT_CAUSE_11_COUNT=0
REJECT_CAUSE_13_COUNT=0
REJECT_CAUSE_15_COUNT=0
```

This is a material delta from the GSI runs, where the selected default APN was
`pwg`, an initially established data call later tore down with
`ERROR_UNSPECIFIED`, and registration subsequently entered reject causes
11/13/15.

The APN difference is now a first-class investigation item. It is not yet
claimed to be the cause of NAS registration rejection.

## OEM IMS control

Stock provides the real MediaTek IMS package:

```text
IMS_PACKAGE=com.mediatek.ims
IMS_CODE_PATH=/system_ext/priv-app/ImsService
IMS_VERSION_CODE=36
IMS_VERSION_NAME=16
IMS_MIN_SDK=36
IMS_TARGET_SDK=36
IMS_SHARED_UID=android.uid.phone
IMS_FLAGS=SYSTEM,PERSISTENT,PRIVILEGED,SYSTEM_EXT
IMS_DEVICE_SERVICE_SLOT0=com.mediatek.ims
IMS_DEVICE_SERVICE_SLOT1=com.mediatek.ims
```

The stock IMS startup is asynchronous and briefly reports registration/setup
errors during boot. It subsequently reaches:

```text
+CIREGU:1,7
setImsRegistrationState registered=true
+CIREGU:1,f
```

Connectivity then exposes a separate cellular IMS bearer:

```text
IMS_INTERFACE=ccmni2
IMS_CAPABILITIES=IMS,MMTEL
IMS_NETWORK_CONNECTED=YES
IMS_NETWORK_VALIDATED=YES
```

Therefore an early `ImsService` setup error is not by itself a failure
criterion; successful end-state registration is what matters.

The stock log also emits `mtkImsIndication == NULL` during early startup and
still goes on to register IMS and pass real calls. That message is therefore
**not sufficient evidence for a required RadioEx/MTK indication shim**.

The legacy `dumpsys ims` command reports no service on this stock build even
though OEM IMS and real voice work. It must not be used as a standalone IMS
readiness gate on Titan 2.

## Functional qualification

Operator-validated on the freshly factory-reset stock control:

```text
STOCK_CELLULAR_DATA=PASS
STOCK_SMS_MMS_SEND_RECEIVE=PASS
STOCK_OUTGOING_VOICE=PASS
STOCK_INCOMING_VOICE=PASS
STOCK_TELEPHONY_CONTROL=PASS
```

## Stock tray-2 single-SIM control

The same physical SIM was moved to tray 2 under the unchanged factory-stock
V01.00.14 stack and the phone was power-cycled. Raw tray-2 logs are deliberately
kept off-repo and hash-pinned:

```text
TRAY2_TELEPHONY_RAW_SHA256=b77da3775575310401bbaaa5cc998cd9d2f31e828fde334c08b00aca51dc4a89
TRAY2_TELEPHONY_RAW_BYTES=149824
TRAY2_RADIO_RAW_SHA256=3e23000d91cd216a07cee55d90eab1d411c82baf26901547a4f3ed50bbdda76c
TRAY2_RADIO_RAW_BYTES=1476929
```

Observed stable end state:

```text
gsm.sim.state=ABSENT,LOADED
gsm.sim.operator.numeric=,310240
gsm.operator.numeric=,310260
gsm.network.type=Unknown,LTE

persist.vendor.radio.simswitch=1
persist.vendor.radio.c_capability_slot=1

mDefaultPhoneId=1
mDefaultSubId=1
mActiveDataSubId=1

DEFAULT_APN=fast.t-mobile.com
DATA_INTERFACE=ccmni1
IMS_INTERFACE=ccmni2
TRAY2_IMS_REGISTRATION=PASS
```

The key capability result is that stock does **not** require the two observed
vendor properties to numerically change when the active physical SIM moves from
tray 1 to tray 2. They remain `1` / `1`, while framework/default-subscription
state moves to phone 1 and the actual modem capability transaction runs.

The stock radio path contains:

```text
queryMainProtocol, main_sim:1
NW_SET_RADIO_CAPABILITY_REQ
MtkProxyController
SET_RADIO_CAPABILITY
EVENT_UNSOL_RADIO_CAPABILITY_CHANGED
DSSExt: Default data phoneid = 1
```

Therefore writing `persist.vendor.radio.simswitch` or
`persist.vendor.radio.c_capability_slot` is not the demonstrated mechanism for
a working tray-2 switch. A property-hold workaround remains rejected.

Stock also exposes modem/framework capability signals absent from the generic
GSI analysis:

```text
EDATASIM Supported
IA MD Preferred APN
MODE_SWITCH_BY_DATA
MtkProxyController
DSSExt
MtkGsmCdmaPhone
MediaTek service-state handling (MTKSST)
```

These are now first-class stock-vs-GSI comparison targets.

### Transient stock failure and successful recovery

During tray-2 boot, stock briefly attempts `fast.t-mobile.com`, receives
`ERROR_UNSPECIFIED`, and enters an emergency state with reject cause 27.
Unlike the failing GSI, stock recovers automatically within seconds:

```text
fast.t-mobile.com CONNECTING
 -> ERROR_UNSPECIFIED / DISCONNECTED
 -> rejectCause=27 / EMERGENCY
 -> HOME / IN_SERVICE
 -> fast.t-mobile.com CONNECTED on ccmni1
 -> ims CONNECTED on ccmni2
 -> +CIREGU:1,f
 -> setImsRegistrationState registered=true
```

This materially changes the diagnosis:

```text
ERROR_UNSPECIFIED_AS_SOLE_ROOT_CAUSE=NO
TRANSIENT_REGISTRATION_REJECT_CAN_RECOVER_ON_STOCK=YES
APN_ONLY_FIX_JUSTIFIED=NO
```

The stock-vs-GSI question is now **why the stock telephony environment
recovers/stabilizes and the GSI environment eventually does not**, rather than
whether an `ERROR_UNSPECIFIED` event can occur at all.

### Tray-2 functional qualification

Operator-validated with the same SIM in tray 2:

```text
TRAY2_CELLULAR_DATA=PASS
TRAY2_SMS_MMS_SEND_RECEIVE=PASS
TRAY2_OUTGOING_VOICE=PASS
TRAY2_INCOMING_VOICE=PASS
TRAY2_SINGLE_SIM_CONTROL=PASS
STOCK_BOTH_PHYSICAL_TRAYS_SINGLE_SIM=PASS
DUAL_SIM_DSDS_CONTROL=PENDING
```

## Engineering conclusions

1. The physical SIM, serving network and modem firmware can provide full
   telephony on V01.00.14 with the SIM alone in either physical tray.
2. The GSI registration/data instability is system-environment-dependent rather
   than an unavoidable carrier/SIM/device failure.
3. Stock uses `fast.t-mobile.com` while the failing GSI used `pwg`, but stock
   itself can transiently receive `ERROR_UNSPECIFIED` and recover. APN selection
   remains a material delta, but an APN-only fix is not justified.
4. Voice is a separate delta: stock has the OEM API-36 MediaTek IMS closure and
   a validated IMS/MMTEL bearer. The generic TrebleDroid IMS APK did not reach
   the same state.
5. `mtkImsIndication == NULL` is observed in a fully working stock boot and is
   demoted from a root-cause signal.
6. Single-SIM behavior now passes in both physical trays. Two-SIM DSDS remains
   unqualified and mandatory.

## Next comparison

Before adding more IMS or radio recovery logic, compare stock against the
C3A/N1G system environment in two independent lanes:

```text
DATA/REGISTRATION:
  stock MTK capability/recovery path + carrier/APN/data-profile handling
  MtkProxyController / DSSExt / MTKSST / EDATASIM / MODE_SWITCH_BY_DATA
  stock fast.t-mobile.com vs GSI pwg remains a delta, not a proven root cause

VOICE/IMS:
  OEM com.mediatek.ims closure + required MTK framework/native/policy pieces
  stock validated ccmni2 IMS/MMTEL vs GSI missing/non-registering provider
```

Do not reintroduce blind simswitch property holds, RadioEx shims, periodic RIL
restarts, airplane-mode healing or permissive SELinux as substitutes for these
identified deltas.
