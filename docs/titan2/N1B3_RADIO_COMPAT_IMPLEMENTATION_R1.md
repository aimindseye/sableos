# N1B3 Radio Compatibility Implementation R1

## Status

N1B3 is the first implementation branch after PR209 and PR210.

PR209 superseded PR208 and preserved the clean evidence path for Titan 2 radio compatibility work. PR210 added source/static audit tooling. This branch adds the first small build-integrated radio-compatibility product delta.

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
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_PRODUCT_DELTA=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_MTK_IMS_DEFAULT_DISABLED=YES
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_APPLIES_TO_N1B2_PRODUCT_PROFILE=YES
```

## Evidence basis

PR209 local evidence showed:

- LTE / WWAN service can come up on the N1B1 baseline.
- WWAN data can connect through `ccmni1`.
- The observed failure is a later WWAN disconnect with `ERROR_UNSPECIFIED`.
- MTK indication callbacks and IMS binding remain the high-signal suspects.
- Stock telephony APK payload import remains blocked and is not part of this path.

The targeted runtime hypothesis for this branch is narrow:

```text
LTE_TELEPHONY_COMPATIBILITY=KEEP_ENABLED
MTK_IMS_PHHSYSTEM_PROPERTY=persist.sys.phh.ims.mtk
MTK_IMS_PHHSYSTEM_PROPERTY_DEFAULT=false
MTK_IMS_OVERLAY_POLICY=DISABLE_DEFAULT_UNTIL_IMS_SERVICE_PRESENT
IMS_BINDING_POLICY=AOSP_DEFAULT_UNTIL_COM_MEDIATEK_IMS_VALIDATED
```

## Implementation scope

This PR adds:

- `build/titan2/apply-n1b3-radio-compat-product-delta.sh`
- `build/gates/n1b3-radio-compat-product-delta-contract.sh`
- an update to the N1B3 implementation contract so the product delta is gated

The apply script is intentionally idempotent. It patches the generated N1B2 product profile after `prepare-n1b2-product-profile.sh` has prepared `vendor/sable/n1b2/sable_n1b2_product_profile.mk`.

The generated delta adds:

```text
PRODUCT_COPY_FILES += \
    vendor/sable/n1b2/profiles/titan2/radio-compat.env:system/etc/sableos/profiles/titan2/radio-compat.env

PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.phh.ims.mtk=false \
    ro.sableos.radio_compat.profile=n1b3_r1 \
    ro.sableos.radio_compat.mtk_ims_default=disabled_until_service_present \
    ro.sableos.radio_compat.no_stock_telephony_payload=true \
    ro.sableos.radio_compat.wwan_drop_regression_gate=required
```

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

Static contracts:

```bash
bash build/gates/n1b3-radio-compat-product-delta-contract.sh
bash build/gates/n1b3-radio-compat-implementation-contract.sh
```

Expected markers:

```text
N1B3_RADIO_COMPAT_PRODUCT_DELTA_CONTRACT=PASS
N1B3_RADIO_COMPAT_IMPLEMENTATION_R1_CONTRACT=PASS
```

## Operator flow after PR checkout

Prepare the existing N1B2 product profile first:

```bash
bash build/titan2/prepare-n1b2-product-profile.sh \
  --android-root /srv/data/sable-build/workspaces/titan2-n0b-restless-native-android16-r7-seeded-public-skip-goodix-20260927_174816/treble_restlessos/src \
  --active-product-mk device/phh/treble/treble_arm64_bvN.mk \
  --patch-active-product
```

Then apply the targeted radio-compat product delta:

```bash
bash build/titan2/apply-n1b3-radio-compat-product-delta.sh \
  --android-root /srv/data/sable-build/workspaces/titan2-n0b-restless-native-android16-r7-seeded-public-skip-goodix-20260927_174816/treble_restlessos/src
```

Then run Titan 2 local CI and only proceed to an N1B2 image build if CI passes.

## Source audit

```bash
bash build/titan2/audit-n1b3-radio-compat-source.sh \
  --android-src /srv/data/sable-build/workspaces/r8-a4-panther-base-2026081300 \
  --evidence-dir /srv/data/sable-build/evidence/titan2/n1b3-radio-compat-implementation-r1/source-audit
```

Expected marker:

```text
N1B3_RADIO_COMPAT_SOURCE_AUDIT=PASS
```
