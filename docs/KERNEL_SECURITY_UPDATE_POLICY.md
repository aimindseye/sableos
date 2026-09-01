# SableOS Independent Kernel Security Update Policy

Status: **normative project-wide security/build policy**.

SableOS may patch and distribute kernel security fixes independently of a full operating-system feature release when the update preserves the target's supported Android kernel/GKI/KMI/vendor-module contract and passes the required security, ABI, image, AVB, A/B and physical-runtime gates.

This capability exists to reduce exposure time to public kernel vulnerabilities. It does **not** authorize arbitrary upstream kernel flashing, bypass Android kernel compatibility requirements, weaken verified boot, or overstate the security state of proprietary vendor/firmware components.

## Core rule

> Prefer the smallest verified kernel security change that closes the vulnerability while preserving the supported device kernel contract.

The preferred order is:

```text
K1 specific security backport
        >
K2 same-KMI stable/GKI sublevel advance
        >>>
K3 cross-KMI/LTS migration
```

K1 and K2 may be delivered independently of a normal SableOS feature release. K3 is a device/platform migration and must not be represented as a routine kernel-only hotfix.

## Why independent kernel updates are valid

Android's Generic Kernel Image model defines a Kernel Module Interface (KMI) that can remain stable across kernel sublevel updates within the same Android/LTS/KMI generation. A same-KMI kernel can therefore receive security fixes without requiring a full framework/product feature release, provided the dependent module and device contracts remain valid.

The important boundaries are:

- KMI stability applies only within the appropriate Android/LTS/KMI family;
- vendor modules must remain compatible with the effective KMI;
- GKI modules in `system_dlkm` have no independent stable ABI against arbitrary GKI builds and must be built/updated together with their matching GKI kernel;
- device-specific modules/partitions such as `vendor_dlkm`, `vendor_boot`, DTB or DTBO are included only when the device's effective dependency graph requires them;
- AVB/signing metadata must match every updated partition;
- production distribution uses the supported signed A/B update path, not root or an unlocked bootloader.

Normative Android references include:

- AOSP stable KMI documentation: `https://source.android.com/docs/core/architecture/kernel/stable-kmi`
- GKI versioning: `https://source.android.com/docs/core/architecture/kernel/gki-versioning`
- GKI / `system_dlkm` partition model: `https://source.android.com/docs/core/architecture/partitions/gki-partitions`
- A/B update architecture: `https://source.android.com/docs/core/ota/ab`
- A/B implementation / `AB_OTA_PARTITIONS`: `https://source.android.com/docs/core/ota/ab/ab_implement`

## Update classes

### K1 — security backport

Preferred security-update class.

Characteristics:

```text
same Android kernel branch
same LTS family
same KMI version/generation
same supported device configuration unless the fix requires a bounded config correction
one or more provenance-recorded security patches
```

Use K1 when an upstream ACK/Linux/device fix can be backported without changing the supported KMI/device contract.

Required evidence includes:

- CVE/advisory identifier;
- vulnerability applicability proof;
- upstream fixing commit(s);
- Sable backport commit/patch;
- kernel source baseline and post-fix seal;
- config-delta classification;
- KMI/ABI check;
- matching GKI-module build where applicable;
- vendor-module compatibility proof;
- targeted vulnerability regression test when a safe reliable test exists;
- full kernel/device regression gates required by this document.

### K2 — same-KMI stable/GKI sublevel advance

Supported with broader regression testing.

Characteristics:

```text
same Android/LTS/KMI generation
higher allowed kernel sublevel
accumulated stable/security fixes
KMI remains unchanged
```

K2 is appropriate when moving to a later security/stable sublevel provides a better maintained fix set than carrying isolated backports.

A version increase alone is not proof of safety. The exact source manifest, kernel release, KMI, config, modules and device behavior must be validated.

### K3 — cross-KMI or LTS migration

Not a routine kernel-security hotfix.

Examples include movement between different Android kernel branches, LTS families or KMI generations.

K3 requires a full device/platform migration because dependent modules and vendor/device assumptions may no longer be compatible. It must use the same source/vendor/physical acceptance discipline as a major device baseline change.

## Canonical kernel baseline record

Every actively supported device should establish a sealed kernel baseline before SableOS claims independent kernel-update capability for that device.

Use these fields where applicable:

```text
SABLEOS_KERNEL_BASELINE=PASS|FAIL|NOT_RUN
SABLEOS_KERNEL_RELEASE=
SABLEOS_KERNEL_ANDROID_BRANCH=
SABLEOS_KERNEL_KMI_VERSION=
SABLEOS_KERNEL_KMI_GENERATION=
SABLEOS_KERNEL_SOURCE_COMMIT=
SABLEOS_KERNEL_SOURCE_MANIFEST_SHA256=
SABLEOS_KERNEL_CONFIG_SHA256=
SABLEOS_KERNEL_ABI_SYMBOL_LIST_SHA256=
SABLEOS_KERNEL_MODULE_MANIFEST_SHA256=
SABLEOS_KERNEL_GKI_MODULE_SET_SHA256=
SABLEOS_KERNEL_VENDOR_MODULE_SET_SHA256=
SABLEOS_KERNEL_BOOT_IMAGE_SHA256=
SABLEOS_KERNEL_SYSTEM_DLKM_SHA256=NOT_APPLICABLE|<sha256>
SABLEOS_KERNEL_VENDOR_DLKM_SHA256=NOT_APPLICABLE|<sha256>
SABLEOS_KERNEL_VENDOR_BOOT_SHA256=NOT_APPLICABLE|<sha256>
SABLEOS_KERNEL_DTBO_SHA256=NOT_APPLICABLE|<sha256>
SABLEOS_KERNEL_AB_OTA_PARTITIONS=
SABLEOS_KERNEL_BUILD_TOOLCHAIN_PROVENANCE=PASS|FAIL|NOT_RUN
SABLEOS_KERNEL_KMI_BASELINE_VALIDATION=PASS|FAIL|NOT_APPLICABLE|NOT_RUN
```

Use `NOT_APPLICABLE` only where a partition/capability is genuinely absent from the target architecture.

A normal product build which does not intentionally change kernel inputs may reference the previously sealed kernel baseline rather than rebuilding the kernel merely to satisfy this policy.

## Kernel security update record

Every K1/K2 candidate should emit a bounded machine/line-oriented record:

```text
SABLEOS_KERNEL_UPDATE_TYPE=K1_SECURITY_BACKPORT|K2_SAME_KMI_SUBLEVEL
SABLEOS_KERNEL_UPDATE_CVES=
SABLEOS_KERNEL_UPDATE_UPSTREAM_COMMITS=
SABLEOS_KERNEL_UPDATE_BASE_RELEASE=
SABLEOS_KERNEL_UPDATE_TARGET_RELEASE=
SABLEOS_KERNEL_UPDATE_KMI_BEFORE=
SABLEOS_KERNEL_UPDATE_KMI_AFTER=
SABLEOS_KERNEL_UPDATE_KMI_UNCHANGED=YES|NO
SABLEOS_KERNEL_UPDATE_SOURCE_PROVENANCE=PASS|FAIL
SABLEOS_KERNEL_UPDATE_CONFIG_DELTA=NONE|EXPECTED|UNEXPECTED
SABLEOS_KERNEL_UPDATE_ABI_KMI_CHECK=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_GKI_MODULE_MATCH=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_VENDOR_MODULE_COMPATIBILITY=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_BUILD=PASS|FAIL
SABLEOS_KERNEL_UPDATE_IMAGE_MANIFEST=PASS|FAIL
SABLEOS_KERNEL_UPDATE_AVB=PASS|FAIL
SABLEOS_KERNEL_UPDATE_VULN_REGRESSION=PASS|FAIL|NOT_AVAILABLE
SABLEOS_KERNEL_UPDATE_BOOT=PASS|FAIL
SABLEOS_KERNEL_UPDATE_MODULE_LOAD=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_SELINUX=PASS|FAIL
SABLEOS_KERNEL_UPDATE_HARDWARE_REGRESSION=PASS|FAIL
SABLEOS_KERNEL_UPDATE_AB_ROLLBACK=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_UPDATE_NATURAL_SLOT_SUCCESS=PASS|FAIL|NOT_APPLICABLE
SABLEOS_KERNEL_SECURITY_UPDATE=PASS|FAIL
```

A K1/K2 production candidate fails if the KMI is unexpectedly changed, required modules no longer load, AVB validation fails, the target cannot naturally boot/succeed, or an unexplained hardware regression is introduced.

## Build-system integration

Independent kernel security updates are a **separate controlled build path** from ordinary platform/product builds.

Normal product build:

```text
sealed device/kernel baseline
        +
platform/Sable changes
        -> normal product build
        -> kernel baseline referenced/verified
```

Kernel security update:

```text
sealed kernel baseline
        +
provenance-recorded K1/K2 change
        -> supported hermetic Android/device kernel build
        -> KMI/ABI/module validation
        -> affected kernel/module partition images
        -> target-files / OTA integration as required
        -> signed A/B kernel-security payload
```

Rules:

1. Do not download/flash an arbitrary "latest upstream" kernel binary as a production update.
2. Use the supported Android/device kernel build process and pinned toolchain/source manifest.
3. Do not use version strings alone to determine whether a CVE is fixed; backported fixes may exist without a sublevel change.
4. Do not change KMI/LTS family under a K1/K2 label.
5. Build matching GKI modules with the GKI kernel when `system_dlkm` is used.
6. Rebuild/include vendor/device module partitions only when their dependency/input graph requires it.
7. Preserve exact image hashes and an affected-partition manifest.
8. Production update artifacts must be Sable-signed and AVB-valid.
9. Development direct flashing may be used only under an explicit development gate on a verified target device.
10. No root/unlocked-bootloader requirement is permitted for the production update mechanism.

## A/B update and rollback model

On an A/B-capable production device, kernel security updates should use the ordinary signed inactive-slot update model.

```text
known-good active slot
        -> signed kernel-security OTA payload
        -> update affected inactive-slot A/B partitions
        -> verify payload/partition hashes + AVB
        -> activate target slot
        -> reboot
        -> runtime/kernel/module/security checks
        -> natural slot success
        -> preserve prior successful slot until closure
```

The exact affected partitions are device-specific and must be derived from the built product/device configuration, including `AB_OTA_PARTITIONS`, rather than hard-coded globally.

A kernel update must not modify the currently running slot as its normal production deployment mechanism.

## Security patch level honesty

Independent kernel patches do not automatically authorize advancing Android's `ro.build.version.security_patch`.

SableOS may truthfully publish a kernel-specific statement such as:

```text
SABLEOS_KERNEL_CVE_<ID>=PATCHED
```

while retaining an older Android SPL if other issues required by a newer SPL remain unresolved.

Android SPL claims remain governed by `SECURITY_MAINTENANCE.md`.

## Vendor/firmware security ceiling

A patched open-source kernel does not imply the complete device is current.

Track independently:

```text
AOSP/framework
kernel
vendor kernel modules
GPU/media/DSP firmware
radio/IMS/modem firmware
Wi-Fi/Bluetooth firmware
TEE / secure processor
bootloader
browser/WebView/updatable modules
```

If a kernel fix lands before the OEM/chipset vendor publishes a required proprietary correction, the release record must show the kernel as patched and the vendor/firmware layer as outstanding rather than claiming whole-device closure.

## Pixel / GKI-class devices

For supported Pixel/GKI-class devices, SableOS should establish the exact ACK/GKI branch, KMI generation, GKI module set, vendor module set and A/B partition graph during device qualification.

Same-KMI K1/K2 updates are preferred where supported. The production mechanism remains Sable-signed A/B OTA with locked/relockable verified boot, not root flashing.

## MediaTek / Zinwa devices

MediaTek/Zinwa ports may use the same K1/K2 capability when the target provides enough kernel source, module/build provenance and boot/update control to prove compatibility.

Do not assume that a MediaTek device is GKI-compatible merely because modern Android supports GKI generally. Probe and record the actual target's kernel branch, KMI/module model, vendor modules and partition/update topology.

If required proprietary kernel modules cannot be validated against a changed kernel, independent K1/K2 distribution is blocked for that target until a compatible module set is available. This blocks the kernel-update capability, not SableOS device eligibility as a whole.

## Kernel security update streams

SableOS security maintenance distinguishes at least:

```text
OS Release
    framework/system/product/vendor integration and features

Platform Security Update
    AOSP/framework/native security backports

Kernel Security Update
    K1/K2 kernel + required matching module/partition updates

Vendor/Firmware Security Update
    OEM/chipset proprietary components
```

These streams may ship together or independently when the target architecture safely supports it. Each stream has separate provenance and unresolved-risk state.

## Current Panther integration rule

The currently running Panther P1B product-integration build is **not invalidated or restarted** by adoption of this policy.

The Panther kernel security baseline should first be sealed during the post-target-files / V0 device-provenance sequence, when the exact built/stock kernel release, ACK/GKI branch, KMI, module partitions, A/B update topology and physical runtime can be measured together.

Future Panther gates which intentionally rebuild or modify the kernel must bind that sealed baseline and emit the kernel-update record above. Future product builds which do not change the kernel may simply verify/reference the sealed baseline.

## Validation priority

For a public kernel vulnerability:

```text
1. determine applicability from source/provenance, not version string alone
2. classify K1 vs K2 vs K3
3. select the smallest supported correction
4. seal pre-update kernel/KMI/module/image state
5. build with pinned supported kernel toolchain
6. validate KMI/ABI and module compatibility
7. run vulnerability regression test when safe/reliable
8. build and hash affected images
9. validate AVB/signing
10. deploy to inactive slot on physical reference hardware
11. validate boot, modules, SELinux and hardware capability parity
12. require natural slot success and preserve fallback
13. publish exact fixed-CVE and unresolved-risk state
```

## Change control

Weakening KMI/module/AVB/A/B requirements for convenience requires explicit architecture/security review.

Changing K3 into a routine hotfix class requires an explicit ADR and device-family proof; it must not happen implicitly because an upstream kernel happens to boot on a development device.

The objective is to let SableOS close open-source kernel vulnerabilities promptly **without waiting for a complete OS feature release**, while preserving Android's kernel compatibility, verified-boot, module and rollback guarantees.