# Titan 2 N1I-A — V01.00.14 OEM IMS dependency closure

Status: **REAL V01.00.14 HOST AUDIT COMPLETE — ONE AUDIT CLASSIFICATION FIX REQUIRES RE-RUN**

This lane determines, from the exact retained stock V01.00.14 firmware, the
minimum OEM MediaTek IMS payload a Titan-specific SableOS system image would have
to supply **if** the GSI-native IMS path proves insufficient. It ports nothing.

```text
OFFLINE_ONLY=YES
DEVICE_CONTACT=NO
BUILD=NO
FLASH=NO
SOURCE_MUTATION_OUTSIDE_REPORT_OUTPUT=NO
STOCK_BLOB_IMPORT_TO_GIT=NO
CAUSE_13_IN_SCOPE=NO
```

## Stock source

The repository designates the V01.00.14 partition reference as the TEE14
bit-equivalence reference, not the `lichtmetzger-20260920` corpus (that corpus
is a dated firmware/OTA package set; `docs/TITAN2_STOCK_FIRMWARE_CORPUS.md` does
not map any package to V01.00.14):

```text
.../stock-firmware/unihertz-device-fota-20260922/inspection/bit-equivalence/TEE14-large-reference
```

The configured root differs between scripts (`/srv/sable-build/titan2/...` in
`build/titan2/n1d-c0.env.example`, `/srv/data/sable-build/titan2/...` in
`qualify-n1d-c0-offline.sh` and `qualify-n1d-c3b-e4-deployment-readiness.sh`).
The audit resolves both and requires exactly one existing directory by realpath,
or an explicit `--stock-ref-dir`.

Pinned inputs (fail closed on mismatch):

| input | SHA-256 | pin source |
|---|---|---|
| product.img | `de1fdecab38b3c5ad7f30beea13f1afb46fa02d98b6cc78d57749b34513aad37` | SABLEOS_N1C_HYBRID_SUPER_CHECKPOINT.md |
| system_ext.img | `1d9d25921def9b7e4e767c00a1f34d19ef5e7320138e3522545f2a2f2047d170` | same |
| vendor.img | `cfeacc74b4289e56921016fedf35a45a995121b874be3cd2f1561b8ed2d61ada` | same |
| C3A system.img | `4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16` | C3A baseline |

The stock `system.img` is required for bootclasspath membership, the stock
platform certificate and MTK framework-modification detection. No stock
`system.img` hash is pinned in the repository, so its SHA-256 is recorded in
`inputs.tsv` and must be reviewed. Without it the framework closure reports
`INCOMPLETE_NO_STOCK_SYSTEM` and feasibility is `UNDETERMINED_NO_STOCK_SYSTEM`.

## Run

```bash
cd /srv/sable-build/sableos/repo
build/titan2/audit-n1i-a-v010014-oem-ims.sh \
  --c3a-system <C3A system.img> \
  [--stock-ref-dir <TEE14-large-reference>] [--stock-system <stock system.img>] \
  [--tools-dir out/host/linux-x86/bin] [--out /srv/sable-build/evidence/titan2/n1i-a-oem-ims/<UTC>]
```

Host tools: `python3 aapt2 debugfs fsck.erofs simg2img openssl` (`apksigner`
preferred for v2/v3 certificates). Output stays under `--out` (refused inside the
repo); the run fails `N1I_A_NO_BLOB_IMPORT` if the repository's git status changes.

## Method

| scope | evidence | rule |
|---|---|---|
| A1 package | `aapt2 dump xmltree` of every system-side and vendor APK | the OEM IMS implementation is the APK with a service bound by `android.telephony.ims.ImsService` / `BIND_IMS_SERVICE`; other IMS-keyword APKs are listed with role `IMS_RELATED_OTHER`; more than one MediaTek provider is a FAIL (ambiguous) |
| A2 signing | `apksigner --print-certs` (v1 `META-INF` fallback); stock and C3A `framework-res.apk` certificates | `sharedUserId` `android.uid.phone`/`system` ⇒ `PLATFORM_RESIGN_REQUIRED=YES`, `CAN_USE_STOCK_SIGNATURE_UNCHANGED=NO` |
| A3 JARs | dex `type_ids`/`class_defs` parsed from the APK (vdex fallback) and from every stock and C3A framework jar, including C3A APEX `javalib` jars | REQUIRED: the APK references classes the jar defines that are absent from C3A, or `uses-library required=true`; transitive closure over other stock jars; OPTIONAL: `required=false` only |
| A3 framework modification | APK references defined in stock AOSP-named jars (`framework`, `telephony-common`, `ims-common`, `voip-common`, `services`) and absent from C3A | any hit ⇒ the OEM app depends on MediaTek changes to the AOSP framework |
| A4 natives | ELF `DT_NEEDED` closure from APK `lib/`, `System.loadLibrary` names in dex strings, and IMS-keyword binaries | system-side closure members absent from C3A ⇒ `MUST_BE_SUPPLIED_BY_SABLE_SYSTEM_IMAGE`; vendor-side ⇒ `ALREADY_PRESENT_IN_PRESERVED_VENDOR`; a system library needing a vendor-only library is UNRESOLVED (FAIL) |
| A5 init | every `.rc`: services, sockets, seclabels, `on property:` start/stop triggers; who sets each trigger (OEM IMS dex strings, rc `setprop`, vendor binaries) | a `disabled` VoLTE service whose trigger is set only by system-side OEM IMS code ⇒ `STOCK_FRAMEWORK_NORMALLY_STARTS_VENDOR_VOLTE_STACK=YES`, manual start on GSI `LIKELY`; static analysis never emits `PROVEN` |
| A6 permissions | `etc/permissions`, `sysconfig`, `default-permissions`, IMS-relevant RROs (`aapt2 dump resources`), carrier configuration files | privapp allowlist for the package or declaration of a required library ⇒ REQUIRED; sysconfig for the package / IMS feature ⇒ LIKELY_REQUIRED; others OPTIONAL |
| A7 SELinux | `seapp_contexts` domain for the package; IMS/VoLTE entries in all policy files; rules naming that domain | system_ext/product/system entries ⇒ must be supplied by the Sable image; vendor entries ⇒ preserved. No permissive or broad-allow proposals |
| A8 operator profile | `*.prop`, `build.prop`, rc `setprop` for `sbp usp_operator operator carrier simswitch c_capability_slot mims volte ims_support wfc epdg clientapi dynamic_ims` | inventory only, with runtime owner; no causal claim about Cause 13 |

Feasibility rule (the reviewer confirms or overrides it below):

```text
LARGE_FRAMEWORK_PORT          any APK reference into MTK-modified AOSP framework jars absent from C3A,
                              or com.mediatek references that resolve nowhere
MODERATE_TITAN_SPECIFIC_LAYER shared UID, required jars, system-side natives or system-driven triggers,
                              but no framework-modification references
MINIMAL_AND_REASONABLE        APK plus permission entries only
NOT_CURRENTLY_FEASIBLE        no unique OEM IMS provider found
```

## Tooling validation (synthetic fixtures, not stock evidence)

Exercised on generated EROFS/ext4/sparse images with real `aapt2` APKs signed
by `apksigner`, `dalvik-exchange` dex, ELF libraries, rc and policy files:

| fixture | result |
|---|---|
| MediaTek-style provider, shared UID phone, `uses-library` jar + transitive jar, JNI lib, vendor VoLTE daemon triggered by a property only the APK sets | `MODERATE_TITAN_SPECIFIC_LAYER`; 2 required jars, 2 system-side libs, trigger attributed to OEM IMS code; all scope markers PASS |
| same + reference into stock `telephony-common.jar` class absent from C3A, JNI lib needing a vendor-only lib | `LARGE_FRAMEWORK_PORT`; native closure `FAIL_UNRESOLVED_NEEDED` |
| built-in pins against non-canonical images | `N1I_A_V010014_STOCK_SOURCE=FAIL_SHA256_MISMATCH` |
| no stock system.img | `INCOMPLETE_NO_STOCK_SYSTEM`, `UNDETERMINED_NO_STOCK_SYSTEM` |
| `--out` inside the repo / missing C3A / unresolvable stock root | refused before any output is written |

## Results

The real build-host run used the exact C3A control image and the retained
V01.00.14 TEE14 reference. Both configured TEE14 roots contain identical pinned
`product.img`, `system_ext.img`, `vendor.img`, and an identical
`system.img`; the canonical `/srv/sable-build` root is selected for future
runs.

```text
STOCK_SYSTEM_SHA256=b2074e20afb6b1dccb87f804ec93b2b8cc64ac6f2366b8d3e6d52522f7f431bd
STOCK_SYSTEM_BYTES=757059584
C3A_SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
```

### OEM IMS provider

The V01.00.14 IMS provider is unambiguous:

```text
OEM_IMS_PACKAGE_PATH=/system_ext/priv-app/ImsService/ImsService.apk
OEM_IMS_PACKAGE_NAME=com.mediatek.ims
OEM_IMS_VERSION=16
OEM_IMS_TARGET_SDK=36
OEM_IMS_APK_SHA256=30db90de9e21d153f93deff2cf3d6c1a73f9c3fd7090533055267ee64cc66539
OEM_IMS_SHARED_UID=android.uid.phone
BIND_IMS_SERVICE_USED=YES
```

The APK is signed with the stock platform certificate
`328c836238b9baf6864d462cf31c03da58953758df88f833ff19b5a8282d0836`.
C3A uses a different platform certificate
`c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8`.
Therefore an OEM-port build cannot use the stock signature unchanged: the
provider must be admitted/resigned consistently with the SableOS platform
signature and the `android.uid.phone` shared-UID contract.

### Framework closure

The APK's Java dependency closure is substantially smaller than feared:

```text
REQUIRED_JARS=
  /system_ext/framework/mediatek-common.jar
  /system_ext/framework/mediatek-ims-base.jar

APK_REFS_UNRESOLVED_COUNT=0
APK_REFS_UNRESOLVED_MEDIATEK_COUNT=0
APK_REFS_INTO_STOCK_AOSP_FRAMEWORK_JARS_NOT_IN_C3A=0
```

This is the key result: the real OEM provider does **not** statically require
MediaTek modifications to AOSP `framework.jar`, `telephony-common.jar`,
`ims-common.jar`, or `services.jar` that are absent from C3A. An OEM IMS
fallback is therefore a Titan-specific compatibility layer, not presently a
large framework fork.

### Native closure

The first host run reported:

```text
N1I_A_NATIVE_DEPENDENCY_CLOSURE=FAIL_UNRESOLVED_NEEDED
NATIVE_UNRESOLVED=
  libandroidicu.so
  libdl_android.so
  libicu.so
  libnativehelper.so
```

Review found this to be an **audit classification defect**, not evidence of four
missing MediaTek libraries. These are Android platform/runtime module libraries:
the ICU libraries are supplied by the i18n module, `libnativehelper` by the ART
runtime module, and `libdl_android` by bionic/runtime. They can be absent from
the extracted flat `/system/lib64` tree while still being platform-provided at
runtime. The audit has been corrected to classify these as platform/APEX
dependencies. Re-run the corrected audit before marking the PR complete.

The stock analysis also identifies 32 relevant native/vendor components already
satisfied by the preserved V01.00.14 vendor, including the MTK RadioEx IMS
interface and VoLTE/RCS UA components. The candidate OEM fallback still brings a
non-trivial system-side native closure, so it remains a **moderate** Titan
compatibility layer rather than an APK-only change.

### Permissions, init, SELinux and dual IMS

Required/likely configuration includes the MediaTek privapp allowlists,
`system-ext-permissions-mediatek.xml`, and
`com.mediatek.ims.config.xml`. The preserved vendor contains the VoLTE client
service, but the static analysis does not prove that a GSI must manually start
it.

The stock vendor configuration includes:

```text
persist.vendor.ims_support=1
persist.vendor.mims_support=2
persist.vendor.mtk.volte.enable=1
persist.vendor.mtk_dynamic_ims_switch=1
persist.vendor.mtk_wfc_support=1
persist.vendor.volte_support=1
```

`persist.vendor.mims_support=2` is important for SableOS product requirements:
Titan 2 has two physical SIM slots and no eSIM fallback, so any final IMS
solution must support both physical subscriptions and dual-SIM operation. This
property is supporting stock evidence, not by itself proof that both slots work
under C3A.

### Reviewer feasibility decision

```text
OEM_MTKIMS_PORT_FEASIBILITY=MODERATE_TITAN_SPECIFIC_LAYER
REVIEWER_BASIS=API36 OEM provider; two required MTK framework jars; no unresolved Java/MediaTek references; no dependency on MTK-modified AOSP core framework; shared android.uid.phone signature boundary and non-trivial native/policy closure remain.
```

This makes OEM MtkIms a viable **fallback**, but not the preferred first
experiment. The existing TrebleDroid GSI-oriented MTK IMS provider should be
tested first because C3A already contains the corresponding compatibility
shims.

### Host-run markers

First real host run:

```text
N1I_A_V010014_STOCK_SOURCE=PASS
N1I_A_OEM_IMS_PACKAGE=PASS
N1I_A_OEM_IMS_SIGNATURE=PASS
N1I_A_FRAMEWORK_DEPENDENCY_CLOSURE=PASS
N1I_A_NATIVE_DEPENDENCY_CLOSURE=FAIL_UNRESOLVED_NEEDED
N1I_A_PERMISSIONS_SYSCONFIG=PASS
N1I_A_INIT_SERVICE_INVENTORY=PASS
N1I_A_SELINUX_INVENTORY=PASS
N1I_A_OPERATOR_PROFILE_INVENTORY=PASS
N1I_A_NO_BLOB_IMPORT=PASS
N1I_A_NO_DEVICE_CONTACT=PASS
N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE=FAIL
```

The sole failure is the corrected A4 platform/APEX classification above. A
second host run is required to confirm all markers PASS before #295 is marked
ready for review.
