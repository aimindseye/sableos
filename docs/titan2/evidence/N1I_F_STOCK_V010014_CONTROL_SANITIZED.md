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

This is a single-SIM tray-1 control. It does not qualify tray 2 or two-SIM DSDS;
those remain mandatory product requirements because Titan 2 has two physical
SIM slots and no eSIM fallback.

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

## Engineering conclusions

1. The physical SIM, serving network, modem firmware and tray-1 hardware can
   provide stable full telephony on V01.00.14.
2. The GSI registration/data instability is system-environment-dependent rather
   than an unavoidable carrier/SIM/device failure.
3. Stock uses `fast.t-mobile.com` while the failing GSI used `pwg`; carrier/APN
   selection must be compared before another long GSI radio trial.
4. Voice is a separate delta: stock has the OEM API-36 MediaTek IMS closure and
   a validated IMS/MMTEL bearer. The generic TrebleDroid IMS APK did not reach
   the same state.
5. `mtkImsIndication == NULL` is observed in a fully working stock boot and is
   demoted from a root-cause signal.
6. Both physical SIM slots plus two-SIM DSDS remain required; this control only
   proves tray-1 single-SIM behavior.

## Next comparison

Before adding more IMS or radio recovery logic, compare stock against the
C3A/N1G system environment in two independent lanes:

```text
DATA/REGISTRATION:
  carrier identity + APN selection + carrier config + data profile
  stock fast.t-mobile.com vs GSI pwg

VOICE/IMS:
  OEM com.mediatek.ims closure + required MTK framework/native/policy pieces
  stock validated ccmni2 IMS/MMTEL vs GSI missing/non-registering provider
```

Do not reintroduce blind simswitch property holds, RadioEx shims, periodic RIL
restarts, airplane-mode healing or permissive SELinux as substitutes for these
identified deltas.
