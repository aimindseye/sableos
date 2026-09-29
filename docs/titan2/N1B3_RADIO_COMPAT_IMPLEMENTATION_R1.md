# N1B3 Radio Compatibility Implementation R1

## Status

N1B3 is the first implementation-prep branch after PR209.

PR209 superseded PR208 and preserved the clean evidence path for Titan 2 radio compatibility work. This branch intentionally starts with source/static audit tooling before any runtime-affecting change.

## Contract markers

```text
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BASE_MAIN=e5267b928a53c8fc4861c5f8118b58e6a10d68b3
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_BUILDS_ON_PR209=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SUPERSEDES_PR208=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_STOCK_APK_IMPORT=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_MTK_JAR_SO_PAYLOAD=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_VENDOR_COPY=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_NO_FLASH=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_SOURCE_AUDIT_FIRST=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_MTK_INDICATION=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_IMS_BINDING=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_TARGETS_WWAN_DROP=YES
```

## Evidence basis

PR209 local evidence showed:

- LTE / WWAN service can come up on the N1B1 baseline.
- WWAN data can connect through `ccmni1`.
- The observed failure is a later WWAN disconnect with `ERROR_UNSPECIFIED`.
- MTK indication callbacks and IMS binding remain the high-signal suspects.
- Stock telephony APK payload import remains blocked and is not part of this path.

## Implementation-prep scope

This PR adds only:

- a N1B3 implementation handoff document;
- a bounded source/static audit script;
- a contract gate that blocks the old PR208 payload direction.

The source audit searches only explicit source roots and summarizes:

- MTK indication surfaces;
- IMS binding surfaces;
- PHH / MTK IMS overlay wiring;
- WWAN drop/data-call terms;
- QNS/IWLAN terms;
- SELinux radio service terms.

## Explicit non-goals

- No `MtkTeleService.apk`
- No `MtkTelephonyProvider.apk`
- No `MtkMmsService.apk`
- No `MtkTelecom.apk`
- No stock `ImsService.apk`
- No MTK framework jar payload import
- No native MTK `.so` payload import
- No vendor partition copy
- No full vendor copy
- No flash script mutation

## Validation

Static contract:

```bash
bash build/gates/n1b3-radio-compat-implementation-contract.sh
```

Expected marker:

```text
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT=PASS
```

Source audit:

```bash
bash build/titan2/audit-n1b3-radio-compat-source.sh \
  --android-src /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 \
  --evidence-dir /srv/data/sable-build/evidence/titan2/n1b3-radio-compat-implementation-r1/source-audit
```

Expected marker:

```text
N1B3_RADIO_COMPAT_SOURCE_AUDIT=PASS
```
