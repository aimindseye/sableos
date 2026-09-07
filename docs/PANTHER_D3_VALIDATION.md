# Panther D3 branding / physical validation — PASS

Date: 2026-09-07

Device: Google Pixel 7 (`panther`)

Android baseline: Android 17 / SDK 37

Canonical substrate: signed GrapheneOS `2026081300`

Build identity:

```text
BUILD_ID=CP2A.260705.006
BUILD_NUMBER=2026090500
variant=userdebug
tags=test-keys
```

This record closes the D3 visible Sable branding deployment and bootloader-authoritative A/B success checks. It is a development/test-key validation record and is not a production-release security claim.

## Source delta

D3 contains the previously validated D2 SetupWizard/Settings branding plus one framework boot-logo change.

SetupWizard/Settings delta:

```text
Welcome to GrapheneOS -> Welcome to SableOS
GrapheneOS icon -> SableOS icon
welcome/finish drawable -> @drawable/sableos_icon
backup restore wording -> neutral compatible-backup wording
GrapheneOS exploit protections -> SableOS exploit protections
GrapheneOS will remain installed. -> SableOS will remain installed.
```

The following remain intentionally unchanged unless/until Sable owns a truthful replacement:

```text
app.grapheneos.setupwizard package/internal identifiers
GrapheneOS provider/service ownership claims
GrapheneOS network/geocoder service wording
GrapheneOS OEM-unlock URL
Play Integrity explanatory claims
BootAnimation.cpp
android-logo-shine.png
```

Boot fallback mutation:

```text
frameworks/base/core/res/assets/images/android-logo-mask.png
old SHA-256: 75efac98abbc429c9aaa4c1aea918014aaead364b802ecec493c70c2d000df41
new SHA-256: dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

The image is an opaque 448x605 Sable fallback mask. The unchanged shine asset remains:

```text
73c2cb640b053c29ec8be308892759a33cd6ed5aa85283cca2a456d208ccd4fb
```

## Build / warning closure

D3 target-files build completed successfully. Full build-log review classified the warning families rather than failing on raw text matches. Final result:

```text
D3_RELEVANT_WARNING_COUNT=0
UNRESOLVED_BUILD_CORRECTNESS_RISK_COUNT=0
BUILD_WARNING_AUDIT=PASS_FULLY_CLASSIFIED
```

The warning evidence retained non-D3 API-37 compiler warnings, R8 classfile/missing-class warnings, resource warnings and packaging probes for future toolchain cleanup.

## PRODUCT residual closure

The unexpected D3 `product.img` delta was traced to exactly one PRODUCT payload file:

```text
PRODUCT/overlay/framework-res__nosdcard__auto_generated_characteristics_rro.apk
```

D2/control:

```text
bytes=608345
sha256=90d87fb07ca36d803556a6c2c667faa2abbf88e047d902330c7ef66660d026f0
```

D3:

```text
bytes=813146
sha256=ffe8678bb5c8a009ee5d029138102ea0d39fa5ea781e0404e310f25b5f256306
```

The RRO was proven auto-generated for `framework-res`; its resource semantics, manifest semantics and signing certificate were equal. PRODUCT filesystem config and SELinux file contexts remained exact. The ext4 block-count increase was downstream of the regenerated RRO/repack.

## SYSTEM / fs-verity closure

Exactly six SYSTEM payload files differed from the control:

```text
SYSTEM/etc/apexd/empty_erofs.img
SYSTEM/etc/bpf/dmabuf/dmabufIter.bpf
SYSTEM/etc/security/fsverity/BuildManifest.apk
SYSTEM/etc/security/fsverity/BuildManifest.apk.idsig
SYSTEM/framework/framework-res.apk
SYSTEM/framework/framework-res.apk.fsv_meta
```

Classification:

```text
empty_erofs.img
  KNOWN_BUILD_ENV_IDENTITY_METADATA_RESIDUAL

dmabufIter.bpf
  KNOWN_NORMALIZED_BTF_ENCODING_ONLY_RESIDUAL

framework-res.apk
  D3_INTENTIONAL_SABLE_BOOT_MASK

framework-res.apk.fsv_meta
  PROVEN_DOWNSTREAM_FSVERITY_METADATA

BuildManifest.apk
  PROVEN_DOWNSTREAM_FSVERITY_BUILD_MANIFEST

BuildManifest.apk.idsig
  PROVEN_DOWNSTREAM_V4_SIGNATURE_OF_BUILD_MANIFEST
```

The D2 and D3 BuildManifest package manifest and signing certificate remained identical. The D3 `framework-res.apk` fs-verity digest changed as expected and was directly referenced by BuildManifest.

## AVB closure

D3 vbmeta contains matching hashtree descriptors for D3 SYSTEM, PRODUCT and SYSTEM_EXT:

```text
system root:
81f693e2ce54a37f476dd298ccbf4fd0ad92c97afe27ce740ae043f8c891577f

product root:
631858e3e9efe9bbf98aea650e53e4844349895416614f74ccd8355c0e8dec0c

system_ext root:
4e4bd4974838429bde21560095e5eb9e98cc43c0e7f56c3ac0822637804698ca
```

The old D2 PRODUCT root was different:

```text
6a370cb1b7987e4b515bc6dc4bba5fd24954aba3c337ba904e3390ccae5b2521
```

Therefore the minimal coherent D3 physical deployment set was proven to be:

```text
system_b
product_b
vbmeta_b
```

with `vbmeta_b` written last.

## D3-R2B physical deployment — PASS

Exact flashed input images:

```text
system.img
19656bad995fbdcacdb8cf283396dc69d636072bd6a88e4fb38da99aff9934af

product.img
711727133467b3b9eacae142a1af04b99907cf7c18f11892b625e0619e714c1b

vbmeta.img
cc284d3841c243a91d6a43efcf6aea81dc0cfa95d4107426c9c4112d0808a789
```

The flash ledger proved exactly three successful targets in this order:

```text
system_b,product_b,vbmeta_b
```

Slot-A logical partitions remained unchanged after each dynamic-partition write, and the Graphene control rollback anchor `vendor_boot_a` remained exact:

```text
84fb46744cbe67e9a2dd67e67551fa2ebaa27d046ee587e58dd063a9bb9758a6
```

After `set_active b`, slot B was re-armed (`successful=no`, retry count 3), then booted successfully.

Runtime identity:

```text
sys.boot_completed=1
ro.boot.slot_suffix=_b
ro.build.id=CP2A.260705.006
ro.build.version.incremental=2026090500
ro.build.fingerprint=google/panther/panther:17/CP2A.260705.006/2026090500:userdebug/test-keys
ro.crypto.state=encrypted
ro.boot.verifiedbootstate=orange
```

`orange` is expected for this unlocked development device.

Live artifact proof:

```text
SetupWizard2.apk
341850ebc00aa605a4b22e17659d6438401d70d061a8bae843be8d64da943548

Settings.apk
04ea22f0b10bf02446463a8bb0a8ec4f7c4c12537f3794f45ed65445be648ef4

PRODUCT auto-generated RRO
ffe8678bb5c8a009ee5d029138102ea0d39fa5ea781e0404e310f25b5f256306

live framework Sable boot mask
dd16d019fc36aefae3b3d6c624c372bf3d5ed8f4ce88aec3932c1816913f7b9e
```

Result:

```text
D2_SYSTEM_EXT_UI_IDENTITY=PASS
D3_PRODUCT_RRO_IDENTITY=PASS
D3_LIVE_BOOT_MASK_IDENTITY=PASS
PANTHER_D3_SLOT_B_BOOT=PASS_BOOT_COMPLETED
```

## D3-R3 bootloader-authoritative success closure — PASS

R3 performed no flash, no source mutation, no build and no slot change. It rebooted from the already-running D3 system to bootloader once, read the slot state, then returned to Android once.

Bootloader state:

```text
current_slot=b
snapshot_update_status=none
unlocked=yes

slot_a_successful=yes
slot_a_unbootable=no
slot_a_retry=2

slot_b_successful=yes
slot_b_unbootable=no
slot_b_retry=2
```

Slot-A rollback anchor readback remained exact:

```text
vendor_boot_a SHA-256
84fb46744cbe67e9a2dd67e67551fa2ebaa27d046ee587e58dd063a9bb9758a6
```

After the authorized return to Android, D3 again reported `sys.boot_completed=1`, `_b`, encrypted data and the same live Sable hashes.

Final state:

```text
PANTHER_D3_SLOT_B_BOOTLOADER_SUCCESS=PASS
GRAPHENE_CONTROL_SLOT_A_ROLLBACK_ANCHOR=PASS
DUAL_KNOWN_GOOD_SLOTS=PASS
D3_RUNTIME_IDENTITY_AFTER_RETURN=PASS

PANTHER_P1B_C2R33_D3_R3_RESULT=
PASS_D3_SLOT_B_BOOTLOADER_SUCCESS_AND_ANDROID_RETURN
```

## Current classification

```text
CANONICAL_ANDROID_PIXEL_BASE=GRAPHENEOS_2026081300
D3_BUILD=PASS
D3_BUILD_WARNING_AUDIT=PASS
D3_PRODUCT_RESIDUAL=PASS_BOUNDED_AUTO_GENERATED_RRO
D3_SYSTEM_FSVERITY_RESIDUAL=PASS_BOUNDED_DOWNSTREAM
D3_AVB=PASS
D3_PHYSICAL_SLOT_B_BOOT=PASS
D3_SLOT_B_BOOTLOADER_SUCCESS=PASS
GRAPHENE_CONTROL_SLOT_A=KNOWN_GOOD
D3_SLOT_B=KNOWN_GOOD
DUAL_KNOWN_GOOD_SLOTS=PASS
PRESERVED_SHARED_DATA_COMPATIBILITY=PASS
```

The runtime framework asset identity proves the active fallback boot-logo payload is the Sable asset. A separate human visual-observation statement is not recorded in this validation file unless explicitly added from device observation.

## Validated gate script seals

The final closure used these state-bound scripts:

```text
panther_c2r33_d3_r1c5_fsverity_system_avb_closure.sh
SHA-256 f0b86ef41f40b233cf92bdacad45f534d66796e99e92ebe0d8b4cff4900f4246

panther_c2r33_d3_r2b_minimal_slot_b_deploy_no_vbmeta_fetch.sh
SHA-256 626fc4478ccc8a22d922456733ec662899e0940c9edbe2b7a816acbb8154297f

panther_c2r33_d3_r3_readonly_slot_success_closure.sh
SHA-256 08eef5176f5cdd1b2e8900ee644a991bc917bec778924ceeaaff7314cce46dba
```

These are evidence seals for the validated run. Deployment scripts are state-bound; do not blindly rerun one against a device whose current slot/partition state differs from the state described by its guards.
